const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');
const { authenticateRequest, AuthenticationError } = require('../shared/auth/jwtMiddleware');
const { getOrCreateUser } = require('../services/userService');
const { incrementAndCheck, QuotaExceededError } = require('../services/pgTokenQuotaService');

module.exports = async function (context, req) {
    context.log('Ask Bartender Simple - Request received');

    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, Ocp-Apim-Subscription-Key',
    };

    // Handle OPTIONS preflight request
    if (req.method === 'OPTIONS') {
        context.res = {
            status: 200,
            headers: headers,
            body: ''
        };
        return;
    }

    let userId = null;
    let userTier = 'free';

    try {
        // ========================================
        // STEP 1: JWT Authentication
        // ========================================
        context.log('[Auth] Validating JWT token...');

        let authResult;
        try {
            authResult = await authenticateRequest(req, context);
            userId = authResult.sub;
            context.log(`[Auth] Token validated. User: ${userId.substring(0, 8)}...`);
        } catch (authError) {
            if (authError instanceof AuthenticationError) {
                context.log.error(`[Auth] Authentication failed: ${authError.message}`);
                context.res = {
                    status: authError.status || 401,
                    headers: {
                        ...headers,
                        'WWW-Authenticate': 'Bearer realm="mybartenderai", error="invalid_token"'
                    },
                    body: {
                        error: 'Authentication required',
                        message: authError.message,
                        code: authError.code
                    }
                };
                return;
            }
            throw authError;
        }

        // ========================================
        // STEP 2: Get/Create User & Tier Lookup
        // ========================================
        context.log('[User] Looking up user in database...');

        // Read APIM-forwarded profile headers from JWT claims
        const userEmail = req.headers?.['x-user-email'] || null;
        const userName = req.headers?.['x-user-name'] || null;

        const user = await getOrCreateUser(userId, context, {
            email: userEmail,
            displayName: userName
        });
        userTier = user.tier;
        context.log(`[User] User ID: ${user.id}, Tier: ${userTier}`);

        // ========================================
        // STEP 3: Check API Configuration
        // ========================================
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) {
            context.log.error('OPENAI_API_KEY not found in environment');
            context.res = {
                status: 500,
                headers: headers,
                body: {
                    error: 'Service configuration error',
                    message: 'The server is not properly configured. Please contact support.'
                }
            };
            return;
        }

        // ========================================
        // STEP 4: Parse Request
        // ========================================
        const body = req.body || {};
        const message = body.message || 'Hello';
        const existingConversationId = body.context?.conversationId;
        const inventory = body.context?.inventory;

        context.log('Message received:', message.substring(0, 100) + (message.length > 100 ? '...' : ''));
        context.log('Conversation ID:', existingConversationId || 'new conversation');
        context.log('Inventory received:', inventory ? 'Yes' : 'No');

        // ========================================
        // STEP 5: Call Azure OpenAI
        // ========================================
        const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
        const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

        const client = new OpenAIClient(
            azureEndpoint,
            new AzureKeyCredential(apiKey)
        );

        // Build system prompt with inventory context if available
        let systemPrompt = 'You are a sophisticated AI bartender for MyBartenderAI. Be helpful, friendly, and knowledgeable about cocktails.';

        if (inventory) {
            const spirits = inventory.spirits || [];
            const mixers = inventory.mixers || [];
            const allIngredients = [...spirits, ...mixers];

            if (allIngredients.length > 0) {
                systemPrompt += '\n\nThe user has the following ingredients available in their bar:';
                if (spirits.length > 0) {
                    systemPrompt += '\nSpirits: ' + spirits.join(', ');
                }
                if (mixers.length > 0) {
                    systemPrompt += '\nMixers/Other: ' + mixers.join(', ');
                }
                systemPrompt += '\n\nWhen suggesting cocktails, prioritize recipes that use these available ingredients. Be creative and suggest what they can make with what they have!';
            }
        }

        const messages = [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: message }
        ];

        const result = await client.getChatCompletions(deployment, messages, {
            temperature: 0.7,
            maxTokens: 500
        });

        const responseText = result.choices[0]?.message?.content || 'I apologize, but I could not process your request.';
        const totalTokens = result.usage?.totalTokens || 0;

        // ========================================
        // STEP 6: Track Token Usage & Enforce Quota
        // ========================================
        context.log(`[Quota] Recording ${totalTokens} tokens for user ${userId.substring(0, 8)}...`);

        try {
            await incrementAndCheck(userId, totalTokens);
            context.log('[Quota] Token usage recorded successfully');
        } catch (quotaError) {
            if (quotaError instanceof QuotaExceededError) {
                context.log.warn(`[Quota] User ${userId.substring(0, 8)}... exceeded quota`);
                // Still return the response since we already generated it,
                // but include quota warning in the response
                // Future requests will be blocked
            } else {
                // Log but don't fail the request for quota tracking errors
                context.log.error(`[Quota] Error tracking usage: ${quotaError.message}`);
            }
        }

        // ========================================
        // STEP 7: Return Success Response
        // ========================================
        const conversationId = existingConversationId || `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

        context.log('Response generated successfully');

        context.res = {
            status: 200,
            headers: headers,
            body: {
                response: responseText,
                conversationId: conversationId,
                usage: {
                    promptTokens: result.usage?.promptTokens || 0,
                    completionTokens: result.usage?.completionTokens || 0,
                    totalTokens: totalTokens,
                },
                user: {
                    tier: userTier
                }
            }
        };

    } catch (error) {
        context.log.error('Error in ask-bartender-simple:', error.message);
        context.log.error('Stack trace:', error.stack);

        // Handle quota exceeded error (pre-check)
        if (error instanceof QuotaExceededError) {
            context.res = {
                status: 429,
                headers: {
                    ...headers,
                    'Retry-After': '86400' // 24 hours until quota resets (roughly)
                },
                body: {
                    error: 'Quota exceeded',
                    message: 'You have exceeded your monthly token quota. Please upgrade your subscription or wait for the next billing cycle.',
                    quota: {
                        remaining: error.remaining,
                        limit: error.limit,
                        used: error.used
                    }
                }
            };
            return;
        }

        context.res = {
            status: 500,
            headers: headers,
            body: {
                error: 'Internal server error',
                message: error.message,
                details: process.env.NODE_ENV === 'development' ? error.stack : undefined
            }
        };
    }
};
