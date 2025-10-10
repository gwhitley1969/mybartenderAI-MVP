import type { InvocationContext } from '@azure/functions';

export interface RateLimiterOptions {
  perUserLimit: number;
  perIpLimit: number;
  windowSeconds: number;
}

export interface RateLimitContext {
  userId?: string;
  ipAddress?: string;
  path: string;
}

export class RateLimitError extends Error {
  constructor(
    message: string,
    readonly retryAfterSeconds: number | undefined = undefined,
  ) {
    super(message);
    this.name = 'RateLimitError';
  }
}

const DEFAULT_OPTIONS: RateLimiterOptions = {
  perUserLimit: parseInt(process.env.RATE_LIMIT_PER_USER ?? '60', 10),
  perIpLimit: parseInt(process.env.RATE_LIMIT_PER_IP ?? '120', 10),
  windowSeconds: parseInt(process.env.RATE_LIMIT_WINDOW_SECONDS ?? '60', 10),
};

export class RateLimiter {
  constructor(private readonly options: RateLimiterOptions = DEFAULT_OPTIONS) {}

  async ensureWithinLimit(
    context: InvocationContext,
    payload: RateLimitContext,
  ): Promise<void> {
    // TODO: Persist sliding window counters in PostgreSQL (per user + per IP).
    context.log(
      '[rateLimiter] TODO implement persistent counters',
      JSON.stringify({
        userId: payload.userId ?? 'anonymous',
        ipAddress: payload.ipAddress ?? 'unknown',
        path: payload.path,
        windowSeconds: this.options.windowSeconds,
        perUserLimit: this.options.perUserLimit,
        perIpLimit: this.options.perIpLimit,
      }),
    );
  }
}

export const rateLimiter = new RateLimiter();
