const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');

module.exports = async function (context, req) {
    context.log('Ask Bartender Simple - Request received');

    // Simple CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
    };

    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
        context.res = {
            status: 200,
            headers: headers,
            body: ''
        };
        return;
    }

    try {
        // Check for API key
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) {
            context.log.error('OPENAI_API_KEY not found in environment');
            context.res = {
                status: 500,
                headers: headers,
                body: {
                    error: 'OpenAI API key not configured',
                    message: 'The server is not properly configured. Please contact support.'
                }
            };
            return;
        }

        // Parse request body
        const body = req.body || {};
        const message = body.message || 'Hello';
        const existingConversationId = body.context?.conversationId;
        const inventory = body.context?.inventory;

        context.log('Message received:', message);
        context.log('Conversation ID:', existingConversationId || 'new conversation');
        context.log('Inventory received:', inventory ? 'Yes' : 'No');
        if (inventory) {
            context.log('Spirits:', inventory.spirits);
            context.log('Mixers:', inventory.mixers);
        }

        // Create Azure OpenAI client
        const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
        const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

        const client = new OpenAIClient(
            azureEndpoint,
            new AzureKeyCredential(apiKey)
        );

        context.log('Azure OpenAI config:', {
            endpoint: azureEndpoint,
            deployment: deployment,
            hasKey: !!apiKey
        });

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

        context.log('System prompt length:', systemPrompt.length);

        // Call Azure OpenAI
        const messages = [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: message }
        ];

        const result = await client.getChatCompletions(deployment, messages, {
            temperature: 0.7,
            maxTokens: 500
        });

        const responseText = result.choices[0]?.message?.content || 'I apologize, but I could not process your request.';

        // Generate or use existing conversation ID
        const conversationId = existingConversationId || `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

        context.log('Response generated successfully');
        context.log('Using conversation ID:', conversationId);

        // Return success response
        context.res = {
            status: 200,
            headers: headers,
            body: {
                response: responseText,
                conversationId: conversationId,
                usage: {
                    promptTokens: result.usage?.promptTokens || 0,
                    completionTokens: result.usage?.completionTokens || 0,
                    totalTokens: result.usage?.totalTokens || 0,
                }
            }
        };

    } catch (error) {
        context.log.error('Error in ask-bartender-simple:', error.message);
        context.log.error('Stack trace:', error.stack);

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
