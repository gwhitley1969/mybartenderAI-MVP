const https = require('https');

class AzureOpenAIService {
    constructor() {
        this.endpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
        this.apiKey = process.env.OPENAI_API_KEY;
        this.deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

        // Log configuration for debugging (without exposing full API key)
        console.log('AzureOpenAIService initialized:', {
            endpoint: this.endpoint,
            deployment: this.deployment,
            hasApiKey: !!this.apiKey,
            apiKeyPrefix: this.apiKey ? this.apiKey.substring(0, 8) + '...' : 'MISSING'
        });
    }

    async askBartender(params) {
        const { message, context, systemPrompt, traceId } = params;

        const requestBody = JSON.stringify({
            messages: [
                {
                    role: 'system',
                    content: systemPrompt + (context || ''),
                },
                {
                    role: 'user',
                    content: message,
                },
            ],
            temperature: 0.7,
            max_tokens: 500,
        });

        const url = new URL(`${this.endpoint}/openai/deployments/${this.deployment}/chat/completions?api-version=2024-10-21`);

        return new Promise((resolve, reject) => {
            const options = {
                hostname: url.hostname,
                port: 443,
                path: url.pathname + url.search,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'api-key': this.apiKey,
                    'Content-Length': Buffer.byteLength(requestBody)
                }
            };

            const req = https.request(options, (res) => {
                let data = '';

                res.on('data', (chunk) => {
                    data += chunk;
                });

                res.on('end', () => {
                    try {
                        console.log(`Azure OpenAI response status: ${res.statusCode}`);

                        if (res.statusCode !== 200) {
                            console.error(`Azure OpenAI error: ${res.statusCode}`);
                            console.error(`Response body: ${data}`);
                            reject(new Error(`Azure OpenAI returned ${res.statusCode}: ${data}`));
                            return;
                        }

                        const response = JSON.parse(data);
                        console.log('Azure OpenAI success, tokens used:', response.usage?.total_tokens);

                        const responseText = response.choices[0]?.message?.content ||
                            'I apologize, but I couldn\'t process your request. Please try again.';

                        resolve({
                            response: responseText,
                            usage: {
                                promptTokens: response.usage?.prompt_tokens || 0,
                                completionTokens: response.usage?.completion_tokens || 0,
                                totalTokens: response.usage?.total_tokens || 0,
                            },
                        });
                    } catch (e) {
                        console.error('Error parsing Azure OpenAI response:', e);
                        reject(e);
                    }
                });
            });

            req.on('error', (e) => {
                console.error('Request error:', e);
                reject(e);
            });

            req.write(requestBody);
            req.end();
        });
    }
}

module.exports = { AzureOpenAIService };