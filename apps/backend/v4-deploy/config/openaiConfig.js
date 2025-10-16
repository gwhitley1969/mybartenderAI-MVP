"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.COMPLETION_TOKEN_BUDGET = exports.PROMPT_TOKEN_BUDGET = exports.CACHE_KEY_HASH = exports.SCHEMA_HASH = exports.RESPONSE_JSON_SCHEMA = exports.TOOL_LIST = exports.SYSTEM_PROMPT_VERSION = exports.MODEL = void 0;
const hash_js_1 = require("../utils/hash.js");
exports.MODEL = 'gpt-4.1-mini';
exports.SYSTEM_PROMPT_VERSION = process.env.PROMPT_SYSTEM_VERSION ?? '2025-10-08';
exports.TOOL_LIST = [];
const toolListKey = exports.TOOL_LIST.length > 0 ? exports.TOOL_LIST.sort().join(',') : 'none';
exports.RESPONSE_JSON_SCHEMA = {
    name: 'recommendations_response',
    schema: {
        type: 'object',
        additionalProperties: false,
        required: ['recommendations'],
        properties: {
            recommendations: {
                type: 'array',
                items: {
                    type: 'object',
                    additionalProperties: false,
                    required: ['id', 'name', 'ingredients', 'instructions'],
                    properties: {
                        id: { type: 'string' },
                        name: { type: 'string' },
                        reason: { type: 'string' },
                        ingredients: {
                            type: 'array',
                            items: {
                                type: 'object',
                                additionalProperties: false,
                                required: ['name', 'amount', 'unit'],
                                properties: {
                                    name: { type: 'string' },
                                    amount: { type: 'number' },
                                    unit: { type: 'string' },
                                },
                            },
                        },
                        instructions: { type: 'string' },
                        glassware: { type: 'string' },
                        garnish: { type: 'string' },
                    },
                },
            },
        },
    },
};
exports.SCHEMA_HASH = (0, hash_js_1.sha256)(JSON.stringify(exports.RESPONSE_JSON_SCHEMA.schema));
exports.CACHE_KEY_HASH = (0, hash_js_1.sha256)([exports.MODEL, exports.SYSTEM_PROMPT_VERSION, exports.SCHEMA_HASH, toolListKey].join('|'));
exports.PROMPT_TOKEN_BUDGET = parseInt(process.env.PROMPT_TOKEN_BUDGET ?? '2000', 10);
exports.COMPLETION_TOKEN_BUDGET = parseInt(process.env.COMPLETION_TOKEN_BUDGET ?? '1000', 10);


