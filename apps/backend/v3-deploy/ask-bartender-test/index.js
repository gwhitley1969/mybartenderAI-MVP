const { z } = require('zod');
const { trackEvent, trackException, getOrCreateTraceId } = require('../shared/telemetry');
const OpenAI = require('openai');

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

// Create Azure OpenAI client
const getOpenAiClient = () => {
    const apiKey = process.env.OPENAI_API_KEY;
    const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
    const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

    return new OpenAI({
        apiKey: apiKey,
        baseURL: `${azureEndpoint}/openai/deployments/${deployment}`,
        defaultQuery: { 'api-version': '2024-10-21' },
        defaultHeaders: { 'api-key': apiKey }
    });
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
    
    // Call Azure OpenAI
    try {
        const openai = getOpenAiClient();
        const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

        const completion = await openai.chat.completions.create({
            model: deployment,
            messages: [
                {
                    role: 'system',
                    content: systemPrompt + contextInfo,
                },
                {
                    role: 'user',
                    content: payload.message,
                },
            ],
            temperature: 0.7,
            max_tokens: 500,
        });

        const responseText = completion.choices[0]?.message?.content ||
            'I apologize, but I couldn\'t process your request. Please try again.';

        trackEvent(context, traceId, 'ask-bartender-test.response.success', {
            promptTokens: completion.usage?.prompt_tokens || 0,
            completionTokens: completion.usage?.completion_tokens || 0,
            totalTokens: completion.usage?.total_tokens || 0,
        });

        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'X-Trace-Id': traceId,
            },
            body: {
                response: responseText,
                usage: {
                    promptTokens: completion.usage?.prompt_tokens || 0,
                    completionTokens: completion.usage?.completion_tokens || 0,
                    totalTokens: completion.usage?.total_tokens || 0,
                },
                conversationId: payload.context?.conversationId || traceId,
            },
        };
        
    } catch (error) {
        trackException(context, traceId, error);
        
        context.res = buildErrorResponse(500, 'ai_service_error', 'Failed to process your request. Please try again.', traceId);
    }
};
