import { beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import type { HttpRequest, InvocationContext } from '@azure/functions';

process.env.OPENAI_API_KEY = process.env.OPENAI_API_KEY ?? 'test-key';

const ensureWithinLimitMock = vi.fn();
const incrementAndCheckMock = vi.fn();
const recommendSpy = vi.fn();

vi.mock('../src/shared/auth/jwtMiddleware.js', async () => {
  const actual = await vi.importActual<
    typeof import('../src/shared/auth/jwtMiddleware.js')
  >('../src/shared/auth/jwtMiddleware.js');

  return {
    ...actual,
    authenticateRequest: vi.fn().mockResolvedValue({
      sub: 'user-123',
      claims: {},
      token: 'stub-token',
    }),
  };
});

vi.mock('../src/services/pgRateLimiter.js', async () => {
  const actual = await vi.importActual<
    typeof import('../src/services/pgRateLimiter.js')
  >('../src/services/pgRateLimiter.js');

  return {
    ...actual,
    ensureWithinLimit: ensureWithinLimitMock,
  };
});

vi.mock('../src/services/pgTokenQuotaService.js', async () => {
  const actual = await vi.importActual<
    typeof import('../src/services/pgTokenQuotaService.js')
  >('../src/services/pgTokenQuotaService.js');

  return {
    ...actual,
    incrementAndCheck: incrementAndCheckMock,
  };
});

vi.mock('../src/services/openAIRecommendationService.js', () => ({
  OpenAIRecommendationService: vi.fn().mockImplementation(() => ({
    recommend: recommendSpy,
  })),
}));

let recommendHandler: typeof import('../src/functions/recommend/index.js').recommendHandler;
let RateLimitErrorCtor: typeof import('../src/services/pgRateLimiter.js').RateLimitError;
let QuotaExceededErrorCtor: typeof import('../src/services/pgTokenQuotaService.js').QuotaExceededError;

beforeAll(async () => {
  ({ recommendHandler } = await import('../src/functions/recommend/index.js'));
  ({ RateLimitError: RateLimitErrorCtor } = await import('../src/services/pgRateLimiter.js'));
  ({ QuotaExceededError: QuotaExceededErrorCtor } = await import('../src/services/pgTokenQuotaService.js'));
});

const createContext = (): InvocationContext =>
  ({
    log: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  }) as unknown as InvocationContext;

const createRequest = (body: Record<string, unknown>): HttpRequest => {
  const serialized = JSON.stringify(body);
  return {
    method: 'POST',
    url: 'https://example.com/v1/recommend',
    headers: new Headers({
      authorization: 'Bearer token',
      'content-type': 'application/json',
      'content-length': String(Buffer.byteLength(serialized)),
    }),
    json: async () => body,
  } as unknown as HttpRequest;
};

const inventoryPayload = {
  inventory: {
    spirits: ['vodka'],
  },
};

describe('recommendHandler', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    recommendSpy.mockResolvedValue({
      cacheHit: true,
      recommendations: [
        {
          id: '1',
          name: 'Example',
          description: 'desc',
          ingredients: [],
          instructions: [],
          difficulty: 'easy',
          estimatedTime: 5,
        },
      ],
      usage: {
        promptTokens: 10,
        completionTokens: 5,
        totalTokens: 15,
      },
    });
  });

  it('returns 200 with cache header when request is allowed', async () => {
    const response = await recommendHandler(
      createRequest(inventoryPayload),
      createContext(),
    );

    expect(ensureWithinLimitMock).toHaveBeenCalled();
    expect(incrementAndCheckMock).toHaveBeenCalledWith('user-123', 15);
    expect(response.status).toBe(200);
    expect(response.headers?.['X-Cache-Hit']).toBe('true');
    expect(Array.isArray(response.jsonBody)).toBe(true);
  });

  it('returns 429 when rate limiter blocks the request', async () => {
    ensureWithinLimitMock.mockRejectedValueOnce(
      new RateLimitErrorCtor('limited', 45),
    );

    const result = await recommendHandler(
      createRequest(inventoryPayload),
      createContext(),
    );

    expect(result.status).toBe(429);
    expect(result.jsonBody).toMatchObject({
      code: 'rate_limit_exceeded',
    });
  });

  it('returns 429 when quota is exceeded', async () => {
    incrementAndCheckMock.mockRejectedValueOnce(
      new QuotaExceededErrorCtor('quota', 0),
    );

    const response = await recommendHandler(
      createRequest(inventoryPayload),
      createContext(),
    );

    expect(response.status).toBe(429);
    expect(response.jsonBody).toMatchObject({
      code: 'quota_exceeded',
    });
  });
});
