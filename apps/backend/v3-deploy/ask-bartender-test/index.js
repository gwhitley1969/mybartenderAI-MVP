const { z } = require('zod');
const { trackEvent, trackException, getOrCreateTraceId } = require('../shared/telemetry');
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
    
    trackEvent(context, traceId, 'ask-bartender-test.request.received', {
        method: req.method,
    });
    
    // Parse and validate request body
    let payload;
    try {
        const json = req.body || {};
        payload = requestSchema.parse(json);
    } catch (error) {
        trackException(context, traceId, error);
        context.res = buildErrorResponse(400, 'invalid_request', 'Request body does not match the expected schema.', traceId, {
            reason: error.message,
        });
        return;
    }
    
    // Build context for the AI
    let contextInfo = '';
    if (payload.context) {
        if (payload.context.inventory?.spirits?.length > 0) {
            contextInfo += `\nAvailable spirits: ${payload.context.inventory.spirits.join(', ')}.`;
        }
        if (payload.context.inventory?.mixers?.length > 0) {
            contextInfo += `\nAvailable mixers: ${payload.context.inventory.mixers.join(', ')}.`;
        }
        if (payload.context.preferences?.preferredFlavors?.length > 0) {
            contextInfo += `\nPreferred flavors: ${payload.context.preferences.preferredFlavors.join(', ')}.`;
        }
        if (payload.context.preferences?.dislikedFlavors?.length > 0) {
            contextInfo += `\nDisliked flavors: ${payload.context.preferences.dislikedFlavors.join(', ')}.`;
        }
        if (payload.context.preferences?.abvRange) {
            contextInfo += `\nABV preference: ${payload.context.preferences.abvRange}.`;
        }
    }
    
    // Default system prompt for the bartender
    const systemPrompt = `You are a sophisticated AI bartender for MyBartenderAI, a premium mixology app. 
    You have extensive knowledge of cocktails, spirits, techniques, and bar culture. 
    Be conversational, helpful, and engaging. Help users discover new cocktails, perfect their techniques, 
    and elevate their home bartending experience. When suggesting cocktails, consider the user's preferences 
    and available ingredients if mentioned.`;
    
    // Call OpenAI service
    try {
        const result = await getOpenAiService().askBartender({
            message: payload.message,
            context: contextInfo,
            systemPrompt,
            traceId,
        });
        
        trackEvent(context, traceId, 'ask-bartender-test.response.success', {
            promptTokens: result.usage.promptTokens,
            completionTokens: result.usage.completionTokens,
            totalTokens: result.usage.totalTokens,
        });
        
        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'X-Trace-Id': traceId,
            },
            body: {
                response: result.response,
                usage: result.usage,
                conversationId: payload.context?.conversationId || traceId,
            },
        };
        
    } catch (error) {
        trackException(context, traceId, error);
        
        context.res = buildErrorResponse(500, 'ai_service_error', 'Failed to process your request. Please try again.', traceId);
    }
};
