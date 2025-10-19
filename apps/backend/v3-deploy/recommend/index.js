const { z } = require('zod');
const { authenticateRequest, AuthenticationError } = require('../shared/auth/jwtMiddleware');
const { enforceRequestGuards, RequestGuardError, getClientIp } = require('../shared/requestGuards');
const { ensureWithinLimit, RateLimitError } = require('../services/pgRateLimiter');
const { trackEvent, trackException, getOrCreateTraceId, sanitizeHeaders } = require('../shared/telemetry');
const { incrementAndCheck, QuotaExceededError } = require('../services/pgTokenQuotaService');
const { OpenAIRecommendationService } = require('../services/openAIRecommendationService');

// Request validation schema
const requestSchema = z
    .object({
        inventory: z
            .object({
                spirits: z.array(z.string()).optional(),
                mixers: z.array(z.string()).optional(),
            })
            .strict(),
        tasteProfile: z
            .object({
                preferredFlavors: z.array(z.string()).optional(),
                dislikedFlavors: z.array(z.string()).optional(),
                abvRange: z.string().optional(),
            })
            .strict()
            .optional(),
    })
    .strict();

// Lazy initialization for OpenAI service
let openAiService = null;
const getOpenAiService = () => {
    if (!openAiService) {
        openAiService = new OpenAIRecommendationService();
    }
    return openAiService;
};

const buildErrorResponse = (status, code, message, traceId, details) => {
    const errorBody = {
        code,
        message,
        traceId,
        ...(details ? { details } : {}),
    };
    
    return {
        status,
        headers: {
            'Content-Type': 'application/json',
        },
        body: errorBody,
    };
};

const safeGetPathname = (url) => {
    try {
        if (!url) return undefined;
        const urlObj = new URL(url, 'http://localhost');
        return urlObj.pathname;
    } catch {
        return undefined;
    }
};

module.exports = async function (context, req) {
    // Check method
    if (req.method?.toUpperCase() !== 'POST') {
        context.res = {
            status: 405,
            headers: { 'Allow': 'POST' },
            body: { error: 'Method not allowed' }
        };
        return;
    }
    
    const traceId = getOrCreateTraceId(req);
    const requestPath = safeGetPathname(req.url);
    
    trackEvent(context, traceId, 'recommend.request.received', {
        path: requestPath,
        method: req.method,
        headers: sanitizeHeaders(req.headers),
    });
    
    // Apply request guards
    try {
        enforceRequestGuards(req, context);
    } catch (error) {
        if (error instanceof RequestGuardError) {
            trackException(context, traceId, error);
            context.res = buildErrorResponse(error.status, error.code, error.message, traceId);
            return;
        }
        trackException(context, traceId, error);
        throw error;
    }
    
    // Authenticate request
    let authenticatedUser;
    try {
        authenticatedUser = await authenticateRequest(req, context);
    } catch (error) {
        if (error instanceof AuthenticationError) {
            trackException(context, traceId, error);
            context.res = buildErrorResponse(error.status, error.code, error.message, traceId);
            return;
        }
        trackException(context, traceId, error);
        throw error;
    }
    
    const userId = authenticatedUser.sub;
    if (!userId) {
        trackException(context, traceId, new Error('Missing subject claim in authenticated principal.'), { reason: 'missing_sub_claim' });
        context.res = buildErrorResponse(400, 'missing_user_id', 'Authenticated principal must include a `sub` claim for quota enforcement.', traceId);
        return;
    }
    
    // Rate limiting
    const clientIp = getClientIp(req);
    try {
        await ensureWithinLimit(context, {
            userId,
            ipAddress: clientIp,
            path: requestPath,
        });
    } catch (error) {
        if (error instanceof RateLimitError) {
            trackException(context, traceId, error);
            context.res = buildErrorResponse(429, 'rate_limit_exceeded', 'Too many requests. Please retry later.', traceId, {
                retryAfterSeconds: error.retryAfterSeconds,
            });
            return;
        }
        trackException(context, traceId, error);
        throw error;
    }
    
    // Parse and validate request body
    let payload;
    try {
        const json = req.body;
        payload = requestSchema.parse(json);
    } catch (error) {
        trackException(context, traceId, error);
        context.res = buildErrorResponse(400, 'invalid_request', 'Request body does not match the expected schema.', traceId, {
            reason: error.message,
        });
        return;
    }
    
    // Generate recommendations
    try {
        const result = await getOpenAiService().recommend({
            inventory: payload.inventory,
            tasteProfile: payload.tasteProfile,
            traceId,
        });
        
        // Check token quota
        try {
            await incrementAndCheck(userId, result.usage.totalTokens);
        } catch (error) {
            if (error instanceof QuotaExceededError) {
                trackException(context, traceId, error);
                context.res = buildErrorResponse(429, 'quota_exceeded', 'Monthly token quota exceeded.', traceId, { 
                    remainingTokens: error.remaining 
                });
                return;
            }
            throw error;
        }
        
        trackEvent(context, traceId, 'recommend.response.success', {
            cacheHit: result.cacheHit,
            cacheKeyHash: getOpenAiService().cacheKeyHash,
            promptTokens: result.usage.promptTokens,
            completionTokens: result.usage.completionTokens,
        });
        
        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'X-Cache-Hit': String(result.cacheHit),
            },
            body: result.recommendations,
        };
        
    } catch (error) {
        trackException(context, traceId, error);
        context.res = buildErrorResponse(500, 'internal_error', 'An unexpected error occurred.', traceId);
    }
};
