import type { PoolClient } from 'pg';

import { withTransaction } from '../shared/db/postgresPool.js';

const DEFAULT_MONTHLY_CAP = Number.isNaN(
  Number(process.env.MONTHLY_TOKEN_LIMIT),
)
  ? 200_000
  : Number(process.env.MONTHLY_TOKEN_LIMIT);

const normalizeMonth = (date: Date): string => {
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  return `${date.getUTCFullYear()}-${month}`;
};

export class QuotaExceededError extends Error {
  constructor(
    message: string,
    readonly remaining: number,
  ) {
    super(message);
    this.name = 'QuotaExceededError';
  }
}

const upsertQuotaRow = async (
  client: PoolClient,
  sub: string,
  month: string,
  tokensUsed: number,
  monthlyCap: number,
  now: Date,
): Promise<void> => {
  const result = await client.query<{
    tokens_used: string;
    monthly_cap: string;
  }>(
    'SELECT tokens_used, monthly_cap FROM token_quotas WHERE sub = $1 AND month = $2 FOR UPDATE',
    [sub, month],
  );

  if (result.rowCount === 0) {
    await client.query(
      `INSERT INTO token_quotas
        (sub, month, tokens_used, monthly_cap, window_start, updated_at)
       VALUES ($1, $2, $3, $4, $5, $5)`,
      [sub, month, tokensUsed, monthlyCap, now.toISOString()],
    );
    return;
  }

  await client.query(
    `UPDATE token_quotas
       SET tokens_used = $1,
           updated_at = $2
     WHERE sub = $3 AND month = $4`,
    [tokensUsed, now.toISOString(), sub, month],
  );
};

export const incrementAndCheck = async (
  userId: string,
  tokensUsed: number,
  now: Date = new Date(),
): Promise<void> => {
  if (tokensUsed <= 0) {
    return;
  }

  const month = normalizeMonth(now);

  await withTransaction(async (client) => {
    const current = await client.query<{
      tokens_used: string;
      monthly_cap: string;
    }>(
      'SELECT tokens_used, monthly_cap FROM token_quotas WHERE sub = $1 AND month = $2 FOR UPDATE',
      [userId, month],
    );

    const monthlyCap = current.rowCount
      ? Number(current.rows[0].monthly_cap ?? DEFAULT_MONTHLY_CAP)
      : DEFAULT_MONTHLY_CAP;
    const existingUsage = current.rowCount
      ? Number(current.rows[0].tokens_used ?? 0)
      : 0;

    const newUsage = existingUsage + tokensUsed;
    if (newUsage > monthlyCap) {
      const remaining = Math.max(monthlyCap - existingUsage, 0);
      throw new QuotaExceededError(
        `Monthly token quota exceeded for ${userId}`,
        remaining,
      );
    }

    await upsertQuotaRow(client, userId, month, newUsage, monthlyCap, now);
  });
};
