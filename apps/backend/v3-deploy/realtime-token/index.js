const { z } = require('zod');
const { authenticateRequest, AuthenticationError } = require('../shared/auth/jwtMiddleware');
const { enforceRequestGuards, RequestGuardError } = require('../shared/requestGuards');
const { trackEvent, trackException, getOrCreateTraceId } = require('../shared/telemetry');
const https = require('https');

// Request validation schema
const requestSchema = z.object({
    voice: z.enum(['marin', 'nova', 'ash', 'echo', 'fable', 'onyx', 'shimmer']).optional().default('marin'),
    instructions: z.string().optional(),
}).strict();

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

// Function to call OpenAI API to generate ephemeral token
async function generateRealtimeToken(sessionConfig) {
    const apiKey = process.env.OPENAI_API_KEY;
    
    return new Promise((resolve, reject) => {
        const data = JSON.stringify({ session: sessionConfig });
        
        const options = {
            hostname: 'api.openai.com',
            port: 443,
            path: '/v1/realtime/client_secrets',
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
                'Content-Length': data.length,
            },
        };
        
        const req = https.request(options, (res) => {
            let responseData = '';
            
            res.on('data', (chunk) => {
                responseData += chunk;
            });
            
            res.on('end', () => {
                if (res.statusCode === 200) {
                    try {
                        const parsed = JSON.parse(responseData);
                        resolve(parsed);
                    } catch (error) {
                        reject(new Error('Failed to parse OpenAI response'));
                    }
                } else {
                    reject(new Error(`OpenAI API error: ${res.statusCode} - ${responseData}`));
                }
            });
        });
        
        req.on('error', (error) => {
            reject(error);
        });
        
        req.write(data);
        req.end();
    });
}

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
    
    trackEvent(context, traceId, 'realtime-token.request.received', {
        method: req.method,
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
    
    // Generate ephemeral token
    try {
        // Prepare session configuration for OpenAI
        const sessionConfig = {
            type: 'realtime',
            model: 'gpt-realtime',
            audio: {
                output: { 
                    voice: payload.voice,
                },
            },
        };
        
        // Add custom instructions if provided
        if (payload.instructions) {
            sessionConfig.instructions = payload.instructions;
        } else {
            // Default bartender instructions
            sessionConfig.instructions = `You are a sophisticated AI bartender for MyBartenderAI, a premium mixology app. 
            You have extensive knowledge of cocktails, spirits, techniques, and bar culture. 
            Be conversational, helpful, and engaging. Help users discover new cocktails, perfect their techniques, 
            and elevate their home bartending experience. When suggesting cocktails, consider the user's preferences 
            and available ingredients if mentioned.`;
        }
        
        // Call OpenAI to generate ephemeral token
        const tokenResponse = await generateRealtimeToken(sessionConfig);
        
        trackEvent(context, traceId, 'realtime-token.response.success', {
            userId,
            voice: payload.voice,
        });
        
        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
            },
            body: {
                token: tokenResponse.value,
                expiresIn: 3600, // Tokens typically expire in 1 hour
                voice: payload.voice,
                model: 'gpt-realtime',
            },
        };
        
    } catch (error) {
        trackException(context, traceId, error);
        context.res = buildErrorResponse(500, 'token_generation_failed', 'Failed to generate realtime token.', traceId);
    }
};
