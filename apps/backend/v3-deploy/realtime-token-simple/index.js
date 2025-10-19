const https = require('https');

module.exports = async function (context, req) {
    context.log('Realtime Token Simple - Request received');
    
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
        const voice = body.voice || 'marin';
        
        context.log('Requesting token for voice:', voice);
        
        // Call OpenAI Realtime API to get session token
        const tokenResponse = await new Promise((resolve, reject) => {
            const data = JSON.stringify({
                model: 'gpt-4o-realtime-preview-2024-10-01',
                voice: voice,
            });
            
            const options = {
                hostname: 'api.openai.com',
                port: 443,
                path: '/v1/realtime/sessions',
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
                        context.log.error('OpenAI API error:', res.statusCode, responseData);
                        reject(new Error(`OpenAI API error: ${res.statusCode} - ${responseData}`));
                    }
                });
            });
            
            req.on('error', (error) => {
                context.log.error('Request error:', error);
                reject(error);
            });
            
            req.write(data);
            req.end();
        });
        
        context.log('Token received successfully');
        
        // Return the token response
        context.res = {
            status: 200,
            headers: headers,
            body: {
                client_secret: {
                    value: tokenResponse.client_secret.value,
                    expires_at: tokenResponse.client_secret.expires_at,
                },
                voice: tokenResponse.voice,
                model: tokenResponse.model,
            }
        };
        
    } catch (error) {
        context.log.error('Error in realtime-token-simple:', error.message);
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
