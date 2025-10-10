import type { InvocationContext } from '@azure/functions';
import type { PoolClient } from 'pg';

import { withTransaction } from '../shared/db/postgresPool.js';

const WINDOW_SECONDS = Number.isNaN(
  Number(process.env.RATE_LIMIT_WINDOW_SECONDS),
)
  ? 60
  : Number(process.env.RATE_LIMIT_WINDOW_SECONDS);

const USER_LIMIT = Number.isNaN(Number(process.env.RATE_LIMIT_PER_USER))
  ? 100
  : Number(process.env.RATE_LIMIT_PER_USER);

const IP_LIMIT = Number.isNaN(Number(process.env.RATE_LIMIT_PER_IP))
  ? 200
  : Number(process.env.RATE_LIMIT_PER_IP);

export class RateLimitError extends Error {
  constructor(
    message: string,
    readonly retryAfterSeconds: number = WINDOW_SECONDS,
  ) {
    super(message);
    this.name = 'RateLimitError';
  }
}

interface RateLimitKey {
  key: string;
  limit: number;
}

export interface RateLimitContext {
  userId?: string;
  ipAddress?: string;
  path: string;
}

const formatKey = (type: string, value: string): string => `${type}:${value}`;

const normalizeIp = (ip?: string): string => {
  if (!ip) {
    return '0.0.0.0';
  }
  return ip.split(',')[0]?.trim() ?? '0.0.0.0';
};

const evaluateKey = async (
  client: PoolClient,
  key: RateLimitKey,
  now: Date,
): Promise<void> => {
  const result = await client.query<{
    window_start: Date;
    count: number;
  }>(
    'SELECT window_start, count FROM rate_limit_counters WHERE key = $1 FOR UPDATE',
    [key.key],
  );

  const windowMs = WINDOW_SECONDS * 1000;
  let windowStart = result.rowCount ? new Date(result.rows[0].window_start) : null;
  const count = result.rowCount ? Number(result.rows[0].count) : 0;

  if (!windowStart || now.getTime() - windowStart.getTime() >= windowMs) {
    windowStart = now;
    if (result.rowCount) {
      await client.query(
        'UPDATE rate_limit_counters SET window_start = $1, count = $2 WHERE key = $3',
        [windowStart.toISOString(), 1, key.key],
      );
    } else {
      await client.query(
        'INSERT INTO rate_limit_counters(key, window_start, count) VALUES ($1, $2, $3)',
        [key.key, windowStart.toISOString(), 1],
      );
    }
    return;
  }

  const nextCount = count + 1;
  if (nextCount > key.limit) {
    throw new RateLimitError(`Rate limit exceeded for ${key.key}`);
  }

  await client.query(
    'UPDATE rate_limit_counters SET count = $1 WHERE key = $2',
    [nextCount, key.key],
  );
};

export const ensureWithinLimit = async (
  context: InvocationContext,
  payload: RateLimitContext,
  now: Date = new Date(),
): Promise<void> => {
  const keys: RateLimitKey[] = [];

  if (payload.userId) {
    keys.push({
      key: formatKey('user', payload.userId),
      limit: USER_LIMIT,
    });
  }

  const ip = normalizeIp(payload.ipAddress);
  keys.push({
    key: formatKey('ip', ip),
    limit: IP_LIMIT,
  });

  await withTransaction(async (client) => {
    for (const key of keys) {
      await evaluateKey(client, key, now);
    }

    await client.query(
      `INSERT INTO rate_limit_events(sub, ip, path)
       VALUES ($1, $2::inet, $3)`,
      [payload.userId ?? null, ip, payload.path],
    );
  }).catch((error) => {
    if (error instanceof RateLimitError) {
      if (typeof context.warn === 'function') {
        context.warn(`[rateLimiter] ${error.message}`);
      }
      throw error;
    }
    throw error;
  });
};
