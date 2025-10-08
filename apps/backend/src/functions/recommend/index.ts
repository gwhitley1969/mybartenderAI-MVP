import { randomUUID } from 'crypto';

import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from '@azure/functions';
import { TableClient, TableServiceError } from '@azure/data-tables';
import { z } from 'zod';

import {
  CACHE_KEY_HASH,
  COMPLETION_TOKEN_BUDGET,
  PROMPT_TOKEN_BUDGET,
} from '../../config/openaiConfig.js';
import {
  MonthlyTokenQuotaService,
  QuotaExceededError,
} from '../../services/monthlyTokenQuotaService.js';
import { OpenAIRecommendationService } from '../../services/openAIRecommendationService.js';
import type { ErrorPayload, RecommendRequestBody } from '../../types/api.js';

const requestSchema = z
  .object({
    inventory: z
      .object({
        spirits: z.array(z.string()).optional(),
        mixers: z.array(z.string()).optional(),
      })
      .strict(),
    tasteProfile: z
      .object({
        preferredFlavors: z.array(z.string()).optional(),
        dislikedFlavors: z.array(z.string()).optional(),
        abvRange: z.string().optional(),
      })
      .strict()
      .optional(),
  })
  .strict();

const openAiService = new OpenAIRecommendationService();

const monthlyLimit = parseInt(
  process.env.MONTHLY_TOKEN_LIMIT ?? '200000',
  10,
);

const tableConnectionString = process.env.AZURE_TABLE_CONNECTION_STRING;
const tableName = process.env.TOKEN_QUOTA_TABLE_NAME ?? 'MonthlyTokenQuotas';

if (!tableConnectionString) {
  throw new Error(
    'AZURE_TABLE_CONNECTION_STRING environment variable is required.',
  );
}

const tableClient = TableClient.fromConnectionString(
  tableConnectionString,
  tableName,
);

const quotaService = new MonthlyTokenQuotaService(
  tableClient,
  Number.isNaN(monthlyLimit) ? 200000 : monthlyLimit,
);

let tableReadyPromise: Promise<void> | null = null;

const ensureTableReady = async (): Promise<void> => {
  if (!tableReadyPromise) {
    tableReadyPromise = tableClient.createTable().catch((error) => {
      const status = (error as TableServiceError).statusCode;
      if (status === 409) {
        return;
      }
      throw error;
    });
  }
  await tableReadyPromise;
};

const buildErrorResponse = (
  status: number,
  code: string,
  message: string,
  traceId: string,
  details?: Record<string, unknown>,
): HttpResponseInit => {
  const errorBody: ErrorPayload = {
    code,
    message,
    traceId,
    ...(details ? { details } : {}),
  };

  return {
    status,
    headers: {
      'Content-Type': 'application/json',
    },
    jsonBody: errorBody,
  };
};

const recommendHandler = async (
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> => {
  if (request.method?.toUpperCase() !== 'POST') {
    return {
      status: 405,
      headers: { Allow: 'POST' },
    };
  }

  const traceId =
    request.headers.get('x-trace-id') ??
    request.headers.get('traceparent') ??
    randomUUID();

  const userId =
    request.headers.get('x-user-id') ??
    request.query.get('userId') ??
    undefined;

  if (!userId) {
    logTelemetry(context, traceId, false);
    return buildErrorResponse(
      400,
      'missing_user_id',
      'x-user-id header is required to enforce quota.',
      traceId,
    );
  }

  let payload: RecommendRequestBody;
  try {
    const json = await request.json();
    payload = requestSchema.parse(json);
  } catch (error) {
    logTelemetry(context, traceId, false);
    return buildErrorResponse(
      400,
      'invalid_request',
      'Request body does not match the expected schema.',
      traceId,
      {
        reason: (error as Error).message,
      },
    );
  }

  await ensureTableReady();

  try {
    await quotaService.ensureWithinQuota(
      userId,
      PROMPT_TOKEN_BUDGET + COMPLETION_TOKEN_BUDGET,
    );
  } catch (error) {
    if (error instanceof QuotaExceededError) {
      logTelemetry(context, traceId, false);
      return buildErrorResponse(
        429,
        'quota_exceeded',
        'Monthly token quota exceeded.',
        traceId,
        { remainingTokens: error.remaining },
      );
    }

    logTelemetry(context, traceId, false);
    throw error;
  }

  try {
    const result = await openAiService.recommend({
      inventory: payload.inventory,
      tasteProfile: payload.tasteProfile,
      traceId,
    });

    await quotaService.recordUsage(userId, result.usage.totalTokens);

    logTelemetry(context, traceId, result.cacheHit);

    return {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'X-Cache-Hit': String(result.cacheHit),
      },
      jsonBody: result.recommendations,
    };
  } catch (error) {
    logTelemetry(context, traceId, false);

    return buildErrorResponse(
      500,
      'server_error',
      'Failed to generate recommendations.',
      traceId,
      {
        reason: (error as Error).message,
      },
    );
  }
};

const logTelemetry = (
  context: InvocationContext,
  traceId: string,
  cacheHit: boolean,
): void => {
  context.log(
    JSON.stringify({
      traceId,
      cacheKeyHash: openAiService.cacheKeyHash,
      cacheHit,
    }),
  );
};

app.http('recommend', {
  methods: ['POST'],
  route: 'v1/recommend',
  authLevel: 'function',
  handler: recommendHandler,
});
