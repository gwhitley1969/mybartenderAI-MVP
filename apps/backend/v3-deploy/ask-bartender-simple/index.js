const OpenAI = require('openai');

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

        context.log('Message received:', message);
        context.log('Conversation ID:', existingConversationId || 'new conversation');
        
        // Create OpenAI client configured for Azure
        const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
        const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

        const openai = new OpenAI({
            apiKey: apiKey,
            baseURL: `${azureEndpoint}/openai/deployments/${deployment}`,
            defaultQuery: { 'api-version': '2024-10-21' },
            defaultHeaders: { 'api-key': apiKey }
        });

        context.log('Azure OpenAI config:', {
            endpoint: azureEndpoint,
            deployment: deployment,
            hasKey: !!apiKey
        });

        // Call OpenAI
        const completion = await openai.chat.completions.create({
            model: deployment,
            messages: [
                {
                    role: 'system',
                    content: 'You are a sophisticated AI bartender for MyBartenderAI. Be helpful, friendly, and knowledgeable about cocktails.'
                },
                {
                    role: 'user',
                    content: message
                }
            ],
            temperature: 0.7,
            max_tokens: 500,
        });
        
        const responseText = completion.choices[0]?.message?.content || 'I apologize, but I could not process your request.';

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
                    promptTokens: completion.usage?.prompt_tokens || 0,
                    completionTokens: completion.usage?.completion_tokens || 0,
                    totalTokens: completion.usage?.total_tokens || 0,
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
