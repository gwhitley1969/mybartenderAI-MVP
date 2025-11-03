const https = require('https');

module.exports = async function (context, req) {
    context.log('Speech Token - Request received');

    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
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
        // Get Speech Services credentials from environment
        const speechKey = process.env.AZURE_SPEECH_KEY;
        const region = process.env.AZURE_SPEECH_REGION;

        if (!speechKey || !region) {
            context.log.error('Azure Speech credentials not found in environment');
            context.res = {
                status: 500,
                headers: headers,
                body: {
                    error: 'Speech Services not configured',
                    message: 'The server is not properly configured. Please contact support.'
                }
            };
            return;
        }

        context.log('Requesting token for region:', region);

        // Exchange API key for ephemeral token (10 minutes)
        const token = await new Promise((resolve, reject) => {
            const options = {
                hostname: `${region}.api.cognitive.microsoft.com`,
                port: 443,
                path: '/sts/v1.0/issueToken',
                method: 'POST',
                headers: {
                    'Ocp-Apim-Subscription-Key': speechKey,
                    'Content-Length': '0'
                },
            };

            const tokenReq = https.request(options, (res) => {
                let tokenData = '';

                res.on('data', (chunk) => {
                    tokenData += chunk;
                });

                res.on('end', () => {
                    if (res.statusCode === 200) {
                        resolve(tokenData);
                    } else {
                        context.log.error('Token request failed:', res.statusCode, tokenData);
                        reject(new Error(`Token request failed: ${res.statusCode}`));
                    }
                });
            });

            tokenReq.on('error', (error) => {
                context.log.error('Token request error:', error);
                reject(error);
            });

            tokenReq.end();
        });

        context.log('Token retrieved successfully');

        // Return token with region and expiration info
        context.res = {
            status: 200,
            headers: headers,
            body: {
                token: token,
                region: region,
                expiresIn: 600 // 10 minutes in seconds
            }
        };

    } catch (error) {
        context.log.error('Error in speech-token:', error.message);
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
