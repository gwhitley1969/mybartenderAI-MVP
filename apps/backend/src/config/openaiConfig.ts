import type { Recommendation } from '../types/api.js';
import { sha256 } from '../utils/hash.js';

export const MODEL = 'gpt-4.1-mini';
export const SYSTEM_PROMPT_VERSION =
  process.env.PROMPT_SYSTEM_VERSION ?? '2025-10-08';

export const TOOL_LIST: string[] = [];
const toolListKey =
  TOOL_LIST.length > 0 ? TOOL_LIST.sort().join(',') : 'none';

export const RESPONSE_JSON_SCHEMA = {
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
} as const satisfies {
  name: string;
  schema: Record<string, unknown>;
};

export type RecommendationsSchemaPayload = {
  recommendations: Recommendation[];
};

export const SCHEMA_HASH = sha256(
  JSON.stringify(RESPONSE_JSON_SCHEMA.schema),
);

export const CACHE_KEY_HASH = sha256(
  [MODEL, SYSTEM_PROMPT_VERSION, SCHEMA_HASH, toolListKey].join('|'),
);

export const PROMPT_TOKEN_BUDGET = parseInt(
  process.env.PROMPT_TOKEN_BUDGET ?? '2000',
  10,
);

export const COMPLETION_TOKEN_BUDGET = parseInt(
  process.env.COMPLETION_TOKEN_BUDGET ?? '1000',
  10,
);
