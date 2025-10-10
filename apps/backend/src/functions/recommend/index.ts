import {
  app,
  HttpRequest,
  HttpResponseInit,
  InvocationContext,
} from '@azure/functions';
import { TableClient } from '@azure/data-tables';
import { z } from 'zod';

import {
  CACHE_KEY_HASH,
  COMPLETION_TOKEN_BUDGET,
  PROMPT_TOKEN_BUDGET,
} from '../../config/openaiConfig.js';
import {
  authenticateRequest,
  AuthenticationError,
} from '../../shared/auth/jwtMiddleware.js';
import {
  getClientIp,
  enforceRequestGuards,
  RequestGuardError,
} from '../../shared/requestGuards.js';
import { rateLimiter, RateLimitError } from '../../shared/rateLimiter.js';
import {
  getOrCreateTraceId,
  sanitizeHeaders,
  trackEvent,
  trackException,
} from '../../shared/telemetry.js';
import {
  MonthlyTokenQuotaService,
  QuotaExceededError,
} from '../../services/monthlyTokenQuotaService.js';
import { OpenAIRecommendationService } from '../../services/openAIRecommendationService.js';
import type { ErrorPayload, RecommendRequestBody } from '../../types/api.js';

type AuthenticatedUser = Awaited<ReturnType<typeof authenticateRequest>>;

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
      const status = (error as { statusCode?: number }).statusCode;
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

  const traceId = getOrCreateTraceId(request);
  const requestPath = safeGetPathname(request.url);

  trackEvent(context, traceId, 'recommend.request.received', {
    path: requestPath,
    method: request.method,
    headers: sanitizeHeaders(request.headers),
  });

  try {
    enforceRequestGuards(request, context);
  } catch (error) {
    if (error instanceof RequestGuardError) {
      trackException(context, traceId, error);
      return buildErrorResponse(
        error.status,
        error.code,
        error.message,
        traceId,
      );
    }
    trackException(context, traceId, error as Error);
    throw error;
  }

  let authenticatedUser: AuthenticatedUser;
  try {
    authenticatedUser = await authenticateRequest(request, context);
  } catch (error) {
    if (error instanceof AuthenticationError) {
      trackException(context, traceId, error);
      return buildErrorResponse(
        error.status,
        error.code,
        error.message,
        traceId,
      );
    }
    trackException(context, traceId, error as Error);
    throw error;
  }

  const userId = authenticatedUser.sub;

  if (!userId) {
    trackException(
      context,
      traceId,
      new Error('Missing subject claim in authenticated principal.'),
      { reason: 'missing_sub_claim' },
    );
    return buildErrorResponse(
      400,
      'missing_user_id',
      'Authenticated principal must include a `sub` claim for quota enforcement.',
      traceId,
    );
  }

  const clientIp = getClientIp(request);

  try {
    await rateLimiter.ensureWithinLimit(context, {
      userId,
      ipAddress: clientIp,
      path: requestPath,
    });
  } catch (error) {
    if (error instanceof RateLimitError) {
      trackException(context, traceId, error);
      return buildErrorResponse(
        429,
        'rate_limit_exceeded',
        'Too many requests. Please retry later.',
        traceId,
        {
          retryAfterSeconds: error.retryAfterSeconds,
        },
      );
    }
    trackException(context, traceId, error as Error);
    throw error;
  }

  let payload: RecommendRequestBody;
  try {
    const json = await request.json();
    payload = requestSchema.parse(json);
  } catch (error) {
    trackException(context, traceId, error as Error);
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
      trackException(context, traceId, error);
      return buildErrorResponse(
        429,
        'quota_exceeded',
        'Monthly token quota exceeded.',
        traceId,
        { remainingTokens: error.remaining },
      );
    }

    trackException(context, traceId, error as Error);
    throw error;
  }

  try {
    const result = await openAiService.recommend({
      inventory: payload.inventory,
      tasteProfile: payload.tasteProfile,
      traceId,
    });

    await quotaService.recordUsage(userId, result.usage.totalTokens);

    trackEvent(context, traceId, 'recommend.response.success', {
      cacheHit: result.cacheHit,
      cacheKeyHash: openAiService.cacheKeyHash,
      promptTokens: result.usage.promptTokens,
      completionTokens: result.usage.completionTokens,
    });

    return {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'X-Cache-Hit': String(result.cacheHit),
      },
      jsonBody: result.recommendations,
    };
  } catch (error) {
    trackException(context, traceId, error as Error);

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

const safeGetPathname = (url: string): string => {
  try {
    return new URL(url).pathname;
  } catch {
    return '/v1/recommend';
  }
};

app.http('recommend', {
  methods: ['POST'],
  route: 'v1/recommend',
  authLevel: 'function',
  handler: recommendHandler,
});
