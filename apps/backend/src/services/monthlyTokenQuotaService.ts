import { TableClient, TableEntity } from '@azure/data-tables';

const RETRY_ATTEMPTS = 5;

export class QuotaExceededError extends Error {
  constructor(message: string, readonly remaining: number) {
    super(message);
    this.name = 'QuotaExceededError';
  }
}

interface TokenQuotaEntity extends TableEntity {
  tokensUsed: number;
  monthlyCap: number;
  windowStart: string;
}

type TokenQuotaRecord = TokenQuotaEntity & { etag?: string };

const normalizeMonth = (input: Date): string => {
  const month = String(input.getUTCMonth() + 1).padStart(2, '0');
  return `${input.getUTCFullYear()}-${month}`;
};

export class MonthlyTokenQuotaService {
  constructor(
    private readonly tableClient: TableClient,
    private readonly defaultMonthlyCap: number,
  ) {}

  async ensureWithinQuota(
    userId: string,
    estimatedTokens: number,
    now: Date = new Date(),
  ): Promise<void> {
    const entity = await this.getOrCreateQuota(userId, now);
    if (entity.tokensUsed + estimatedTokens > entity.monthlyCap) {
      const remaining = Math.max(entity.monthlyCap - entity.tokensUsed, 0);
      throw new QuotaExceededError(
        `Monthly token quota exceeded for ${userId}`,
        remaining,
      );
    }
  }

  async recordUsage(
    userId: string,
    tokensConsumed: number,
    now: Date = new Date(),
  ): Promise<void> {
    await this.withRetry(userId, now, async (entity) => {
      const updated = {
        ...entity,
        tokensUsed: entity.tokensUsed + tokensConsumed,
      };

      if (updated.tokensUsed > updated.monthlyCap) {
        const remaining = Math.max(updated.monthlyCap - entity.tokensUsed, 0);
        throw new QuotaExceededError(
          `Monthly token quota exceeded for ${userId}`,
          remaining,
        );
      }

      return updated;
    });
  }

  private async getOrCreateQuota(
    userId: string,
    now: Date,
  ): Promise<TokenQuotaRecord> {
    const monthKey = normalizeMonth(now);
    try {
      const result = await this.tableClient.getEntity<TokenQuotaEntity>(
        userId,
        monthKey,
      );

      const entity: TokenQuotaRecord = {
        ...result,
        etag: result.etag,
      };
      if (entity.windowStart !== monthKey) {
        const resetEntity: TokenQuotaRecord = {
          partitionKey: userId,
          rowKey: monthKey,
          tokensUsed: 0,
          monthlyCap: entity.monthlyCap ?? this.defaultMonthlyCap,
          windowStart: monthKey,
        };
        await this.tableClient.upsertEntity(resetEntity, 'Replace');
        return resetEntity;
      }

      if (!entity.monthlyCap) {
        entity.monthlyCap = this.defaultMonthlyCap;
      }

      return entity;
    } catch (error) {
      const statusCode = (error as { statusCode?: number }).statusCode;
      if (statusCode === 404) {
        const freshEntity: TokenQuotaRecord = {
          partitionKey: userId,
          rowKey: monthKey,
          tokensUsed: 0,
          monthlyCap: this.defaultMonthlyCap,
          windowStart: monthKey,
        };
        await this.tableClient.createEntity(freshEntity);
        return freshEntity;
      }
      throw error;
    }
  }

  private async withRetry(
    userId: string,
    now: Date,
    mutate: (entity: TokenQuotaRecord) => Promise<TokenQuotaRecord>,
  ): Promise<void> {
    const monthKey = normalizeMonth(now);
    let attempts = 0;

    // eslint-disable-next-line no-constant-condition
    while (true) {
      attempts += 1;
      const current = await this.getOrCreateQuota(userId, now);
      const currentEtag = current.etag ?? '*';

      const mutated = await mutate(current);
      mutated.partitionKey = userId;
      mutated.rowKey = monthKey;
      mutated.windowStart = monthKey;

      try {
        await this.tableClient.updateEntity(
          mutated,
          'Replace',
          {
            etag: currentEtag,
          },
        );
        return;
      } catch (error) {
        const statusCode = (error as { statusCode?: number }).statusCode;
        const isConflict = statusCode === 412;
        if (!isConflict || attempts >= RETRY_ATTEMPTS) {
          throw error;
        }
      }
    }
  }
}
