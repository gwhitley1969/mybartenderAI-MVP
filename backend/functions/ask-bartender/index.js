const { z } = require('zod');
const { authenticateRequest, AuthenticationError } = require('../shared/auth/jwtMiddleware');
const { enforceRequestGuards, RequestGuardError, getClientIp } = require('../shared/requestGuards');
const { ensureWithinLimit, RateLimitError } = require('../services/pgRateLimiter');
const { trackEvent, trackException, getOrCreateTraceId, sanitizeHeaders } = require('../shared/telemetry');
const { incrementAndCheck, QuotaExceededError } = require('../services/pgTokenQuotaService');
const { OpenAIRecommendationService } = require('../services/openAIRecommendationService');

// Request validation schema
const requestSchema = z.object({
    message: z.string().min(1).max(500),
    context: z.object({
        inventory: z.object({
            spirits: z.array(z.string()).optional(),
            mixers: z.array(z.string()).optional(),
        }).optional(),
        preferences: z.object({
            preferredFlavors: z.array(z.string()).optional(),
            dislikedFlavors: z.array(z.string()).optional(),
            abvRange: z.string().optional(),
        }).optional(),
        conversationId: z.string().optional(),
    }).optional(),
}).strict();

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
    
    trackEvent(context, traceId, 'ask-bartender.request.received', {
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
        trackException(context, traceId, new Error('Missing subject claim in authenticated principal.'));
        context.res = buildErrorResponse(400, 'missing_user_id', 'Authenticated principal must include a `sub` claim.', traceId);
        return;
    }
    
    // Rate limiting
    const clientIp = getClientIp(req);
    try {
        await ensureWithinLimit(context, {
            userId,
            ipAddress: clientIp,
            path: '/v1/ask-bartender',
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
    
    // Process natural language query
    try {
        // Build context for the AI
        const systemPrompt = `You are an expert bartender AI assistant for MyBartenderAI, a premium mixology app. 
        Help users with cocktail recommendations, techniques, and bar knowledge.
        Be conversational, knowledgeable, and sophisticated.
        If the user has provided their inventory or preferences, use that information to personalize your response.`;
        
        const userContext = payload.context || {};
        let contextInfo = '';
        
        if (userContext.inventory) {
            contextInfo += `\nUser's bar inventory:`;
            if (userContext.inventory.spirits?.length) {
                contextInfo += `\nSpirits: ${userContext.inventory.spirits.join(', ')}`;
            }
            if (userContext.inventory.mixers?.length) {
                contextInfo += `\nMixers: ${userContext.inventory.mixers.join(', ')}`;
            }
        }
        
        if (userContext.preferences) {
            contextInfo += `\nUser preferences:`;
            if (userContext.preferences.preferredFlavors?.length) {
                contextInfo += `\nLikes: ${userContext.preferences.preferredFlavors.join(', ')}`;
            }
            if (userContext.preferences.dislikedFlavors?.length) {
                contextInfo += `\nDislikes: ${userContext.preferences.dislikedFlavors.join(', ')}`;
            }
            if (userContext.preferences.abvRange) {
                contextInfo += `\nAlcohol preference: ${userContext.preferences.abvRange}`;
            }
        }
        
        // For now, use the recommendation service's OpenAI client
        // In the future, we'll create a dedicated conversational AI service
        const result = await getOpenAiService().askBartender({
            message: payload.message,
            context: contextInfo,
            systemPrompt,
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
        
        trackEvent(context, traceId, 'ask-bartender.response.success', {
            promptTokens: result.usage.promptTokens,
            completionTokens: result.usage.completionTokens,
            conversationId: userContext.conversationId,
        });
        
        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
            },
            body: {
                response: result.response,
                conversationId: userContext.conversationId || traceId,
                usage: {
                    promptTokens: result.usage.promptTokens,
                    completionTokens: result.usage.completionTokens,
                },
            },
        };
        
    } catch (error) {
        trackException(context, traceId, error);
        context.res = buildErrorResponse(500, 'internal_error', 'An unexpected error occurred.', traceId);
    }
};
