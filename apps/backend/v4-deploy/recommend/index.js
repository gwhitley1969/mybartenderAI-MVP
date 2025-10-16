"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions_1 = require("@azure/functions");
const zod_1 = require("zod");
const jwtMiddleware_js_1 = require("../shared/auth/jwtMiddleware.js");
const requestGuards_js_1 = require("../shared/requestGuards.js");
const pgRateLimiter_js_1 = require("../services/pgRateLimiter.js");
const telemetry_js_1 = require("../shared/telemetry.js");
const pgTokenQuotaService_js_1 = require("../services/pgTokenQuotaService.js");
const openAIRecommendationService_js_1 = require("../services/openAIRecommendationService.js");
const requestSchema = zod_1.z
    .object({
    inventory: zod_1.z
        .object({
        spirits: zod_1.z.array(zod_1.z.string()).optional(),
        mixers: zod_1.z.array(zod_1.z.string()).optional(),
    })
        .strict(),
    tasteProfile: zod_1.z
        .object({
        preferredFlavors: zod_1.z.array(zod_1.z.string()).optional(),
        dislikedFlavors: zod_1.z.array(zod_1.z.string()).optional(),
        abvRange: zod_1.z.string().optional(),
    })
        .strict()
        .optional(),
})
    .strict();
let openAiService = null;
const getOpenAiService = () => {
    if (!openAiService) {
        openAiService = new openAIRecommendationService_js_1.OpenAIRecommendationService();
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
        jsonBody: errorBody,
    };
};
const recommendHandler = async (request, context) => {
    if (request.method?.toUpperCase() !== 'POST') {
        return {
            status: 405,
            headers: { Allow: 'POST' },
        };
    }
    const traceId = (0, telemetry_js_1.getOrCreateTraceId)(request);
    const requestPath = safeGetPathname(request.url);
    (0, telemetry_js_1.trackEvent)(context, traceId, 'recommend.request.received', {
        path: requestPath,
        method: request.method,
        headers: (0, telemetry_js_1.sanitizeHeaders)(request.headers),
    });
    try {
        (0, requestGuards_js_1.enforceRequestGuards)(request, context);
    }
    catch (error) {
        if (error instanceof requestGuards_js_1.RequestGuardError) {
            (0, telemetry_js_1.trackException)(context, traceId, error);
            return buildErrorResponse(error.status, error.code, error.message, traceId);
        }
        (0, telemetry_js_1.trackException)(context, traceId, error);
        throw error;
    }
    let authenticatedUser;
    try {
        authenticatedUser = await (0, jwtMiddleware_js_1.authenticateRequest)(request, context);
    }
    catch (error) {
        if (error instanceof jwtMiddleware_js_1.AuthenticationError) {
            (0, telemetry_js_1.trackException)(context, traceId, error);
            return buildErrorResponse(error.status, error.code, error.message, traceId);
        }
        (0, telemetry_js_1.trackException)(context, traceId, error);
        throw error;
    }
    const userId = authenticatedUser.sub;
    if (!userId) {
        (0, telemetry_js_1.trackException)(context, traceId, new Error('Missing subject claim in authenticated principal.'), { reason: 'missing_sub_claim' });
        return buildErrorResponse(400, 'missing_user_id', 'Authenticated principal must include a `sub` claim for quota enforcement.', traceId);
    }
    const clientIp = (0, requestGuards_js_1.getClientIp)(request);
    try {
        await (0, pgRateLimiter_js_1.ensureWithinLimit)(context, {
            userId,
            ipAddress: clientIp,
            path: requestPath,
        });
    }
    catch (error) {
        if (error instanceof pgRateLimiter_js_1.RateLimitError) {
            (0, telemetry_js_1.trackException)(context, traceId, error);
            return buildErrorResponse(429, 'rate_limit_exceeded', 'Too many requests. Please retry later.', traceId, {
                retryAfterSeconds: error.retryAfterSeconds,
            });
        }
        (0, telemetry_js_1.trackException)(context, traceId, error);
        throw error;
    }
    let payload;
    try {
        const json = await request.json();
        payload = requestSchema.parse(json);
    }
    catch (error) {
        (0, telemetry_js_1.trackException)(context, traceId, error);
        return buildErrorResponse(400, 'invalid_request', 'Request body does not match the expected schema.', traceId, {
            reason: error.message,
        });
    }
    try {
        const result = await getOpenAiService().recommend({
            inventory: payload.inventory,
            tasteProfile: payload.tasteProfile,
            traceId,
        });
        try {
            await (0, pgTokenQuotaService_js_1.incrementAndCheck)(userId, result.usage.totalTokens);
        }
        catch (error) {
            if (error instanceof pgTokenQuotaService_js_1.QuotaExceededError) {
                (0, telemetry_js_1.trackException)(context, traceId, error);
                return buildErrorResponse(429, 'quota_exceeded', 'Monthly token quota exceeded.', traceId, { remainingTokens: error.remaining });
            }
            throw error;
        }
        (0, telemetry_js_1.trackEvent)(context, traceId, 'recommend.response.success', {
            cacheHit: result.cacheHit,
            cacheKeyHash: getOpenAiService().cacheKeyHash,
            promptTokens: result.usage.promptTokens,
            completionTokens: result.usage.completionTokens,
        });
        return {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'X-Cache-Hit': String(result.cacheHit),
            },
            jsonBody: result.recommendations,
        };
    }
    catch (error) {
        (0, telemetry_js_1.trackException)(context, traceId, error);
        return buildErrorResponse(500, 'server_error', 'Failed to generate recommendations.', traceId, {
            reason: error.message,
        });
    }
};

const safeGetPathname = (url) => {
    try {
        return new URL(url).pathname;
    }
    catch {
        return '/v1/recommend';
    }
};
functions_1.app.http('recommend', {
    methods: ['POST'],
    route: 'v1/recommend',
    authLevel: 'function',
    handler: recommendHandler,
});





