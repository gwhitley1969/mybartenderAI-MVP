"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OpenAIRecommendationService = void 0;
const openai_1 = __importDefault(require("openai"));
const openaiConfig_js_1 = require("../config/openaiConfig.js");
const SYSTEM_PROMPT = `System prompt v${openaiConfig_js_1.SYSTEM_PROMPT_VERSION}
You are MyBartenderAI, an expert mixologist. Given a user's inventory and optional taste profile, output curated cocktail recommendations.
Response rules:
- Always return valid JSON that matches the provided schema.
- Ensure ingredient amounts are positive numbers with appropriate units.
- Provide concise instructions for preparing the cocktail.
- If you cannot produce any recommendation, return an empty array.`;
class OpenAIRecommendationService {
    constructor(client = new openai_1.default({
        apiKey: process.env.OPENAI_API_KEY,
    })) {
        this.client = client;
    }
    get cacheKeyHash() {
        return openaiConfig_js_1.CACHE_KEY_HASH;
    }
    async recommend(params) {
        const { inventory, tasteProfile, traceId } = params;
        const userContent = JSON.stringify({
            inventory,
            tasteProfile,
        }, null, 2);
        const request = {
            model: openaiConfig_js_1.MODEL,
            input: [
                {
                    role: 'system',
                    content: SYSTEM_PROMPT,
                },
                {
                    role: 'user',
                    content: [
                        {
                            type: 'input_text',
                            text: `Request Trace: ${traceId}\nPayload:\n${userContent}`,
                        },
                    ],
                },
            ],
            response_format: {
                type: 'json_schema',
                json_schema: openaiConfig_js_1.RESPONSE_JSON_SCHEMA,
            },
            metadata: {
                traceId,
                cacheKeyHash: openaiConfig_js_1.CACHE_KEY_HASH,
            },
        };
        request.extra_body = {
            response_cache: {
                mode: 'prefer',
                key: openaiConfig_js_1.CACHE_KEY_HASH,
            },
        };
        const response = await this.client.responses.create(request);
        const outputText = response.output_text ?? extractTextFromResponse(response);
        if (!outputText) {
            throw new Error('Empty response from OpenAI');
        }
        let parsed;
        try {
            parsed = JSON.parse(outputText);
        }
        catch (error) {
            throw new Error(`Failed to parse OpenAI response as JSON: ${error.message}`);
        }
        const headers = response?.response?.headers ?? {};
        const cacheStatus = headers['openai-cache-status'] ??
            headers['openai-prompt-cache'] ??
            headers['x-cache-hit'];
        const cacheHit = typeof cacheStatus === 'string'
            ? cacheStatus.toLowerCase().includes('hit')
            : cacheStatus === true;
        return {
            recommendations: parsed.recommendations ?? [],
            cacheHit,
            usage: {
                promptTokens: response.usage?.input_tokens ?? 0,
                completionTokens: response.usage?.output_tokens ?? 0,
                totalTokens: response.usage?.total_tokens ?? 0,
            },
        };
    }
    
    async askBartender(params) {
        const { message, context, systemPrompt, traceId } = params;
        
        const request = {
            model: 'gpt-4o-mini',
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
        };
        
        const response = await this.client.chat.completions.create(request);
        
        const responseText = response.choices[0]?.message?.content || 'I apologize, but I couldn\'t process your request. Please try again.';
        
        return {
            response: responseText,
            usage: {
                promptTokens: response.usage?.prompt_tokens || 0,
                completionTokens: response.usage?.completion_tokens || 0,
                totalTokens: response.usage?.total_tokens || 0,
            },
        };
    }
}
exports.OpenAIRecommendationService = OpenAIRecommendationService;
const extractTextFromResponse = (response) => {
    const outputs = response?.output;
    if (!Array.isArray(outputs)) {
        return null;
    }
    for (const item of outputs) {
        const content = item?.content;
        if (!Array.isArray(content))
            continue;
        for (const block of content) {
            if (block?.type === 'output_text' && block.text) {
                return block.text;
            }
            if (typeof block?.text === 'string') {
                return block.text;
            }
        }
    }
    return null;
};

