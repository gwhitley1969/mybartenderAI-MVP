import OpenAI from 'openai';
import type { ResponseCreateParamsNonStreaming } from 'openai/resources/responses/responses';

import {
  CACHE_KEY_HASH,
  MODEL,
  RESPONSE_JSON_SCHEMA,
  SYSTEM_PROMPT_VERSION,
} from '../config/openaiConfig.js';
import type {
  Inventory,
  RecommendRequestBody,
  Recommendation,
  TasteProfile,
} from '../types/api.js';

interface RecommendParams {
  inventory: Inventory;
  tasteProfile?: TasteProfile;
  traceId: string;
}

interface RecommendResult {
  recommendations: Recommendation[];
  cacheHit: boolean;
  usage: {
    promptTokens: number;
    completionTokens: number;
    totalTokens: number;
  };
}

type OpenAIResponse = Awaited<
  ReturnType<OpenAI['responses']['create']>
>;

const SYSTEM_PROMPT = `System prompt v${SYSTEM_PROMPT_VERSION}
You are MyBartenderAI, an expert mixologist. Given a user's inventory and optional taste profile, output curated cocktail recommendations.
Response rules:
- Always return valid JSON that matches the provided schema.
- Ensure ingredient amounts are positive numbers with appropriate units.
- Provide concise instructions for preparing the cocktail.
- If you cannot produce any recommendation, return an empty array.`;

export class OpenAIRecommendationService {
  constructor(
    private readonly client = new OpenAI({
      // For Azure OpenAI: set apiKey to a dummy value, use defaultHeaders instead
      apiKey: process.env.AZURE_OPENAI_ENDPOINT ? 'azure' : process.env.OPENAI_API_KEY,
      baseURL: process.env.AZURE_OPENAI_ENDPOINT
        ? `${process.env.AZURE_OPENAI_ENDPOINT}/openai/deployments/${process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini'}`
        : undefined,
      defaultQuery: process.env.AZURE_OPENAI_ENDPOINT
        ? { 'api-version': '2024-10-21' }
        : undefined,
      defaultHeaders: process.env.AZURE_OPENAI_ENDPOINT
        ? { 'api-key': process.env.OPENAI_API_KEY }
        : undefined,
    }),
  ) {}

  get cacheKeyHash(): string {
    return CACHE_KEY_HASH;
  }

  async recommend(params: RecommendParams): Promise<RecommendResult> {
    const { inventory, tasteProfile, traceId } = params;

    const userContent = JSON.stringify(
      {
        inventory,
        tasteProfile,
      } satisfies RecommendRequestBody,
      null,
      2,
    );

    const request: ResponseCreateParamsNonStreaming = {
      model: MODEL,
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
        json_schema: RESPONSE_JSON_SCHEMA,
      },
      metadata: {
        traceId,
        cacheKeyHash: CACHE_KEY_HASH,
      },
    } as ResponseCreateParamsNonStreaming;

    (request as any).extra_body = {
      response_cache: {
        mode: 'prefer',
        key: CACHE_KEY_HASH,
      },
    };

    const response = await this.client.responses.create(request);

    const outputText =
      (response as any).output_text ?? extractTextFromResponse(response);
    if (!outputText) {
      throw new Error('Empty response from OpenAI');
    }

    let parsed: { recommendations: Recommendation[] };
    try {
      parsed = JSON.parse(outputText);
    } catch (error) {
      throw new Error(
        `Failed to parse OpenAI response as JSON: ${(error as Error).message}`,
      );
    }

    const headers =
      ((response as any)?.response?.headers as Record<string, string>) ?? {};
    const cacheStatus =
      headers['openai-cache-status'] ??
      headers['openai-prompt-cache'] ??
      headers['x-cache-hit'];
    const cacheHit =
      typeof cacheStatus === 'string'
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
}

const extractTextFromResponse = (response: OpenAIResponse): string | null => {
  const outputs = (response as any)?.output;
  if (!Array.isArray(outputs)) {
    return null;
  }

  for (const item of outputs) {
    const content = item?.content;
    if (!Array.isArray(content)) continue;
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
