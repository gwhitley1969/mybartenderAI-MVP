import { Pool, type PoolClient, type PoolConfig } from 'pg';

const DEFAULT_SSL_MODE = process.env.PG_SSL_MODE ?? 'disable';

let internalPool: Pool | null = null;
let overridePool: Pool | null = null;

const createPool = (): Pool => {
  const connectionString = process.env.PG_CONNECTION_STRING;
  if (!connectionString) {
    throw new Error(
      'PG_CONNECTION_STRING environment variable is required for PostgreSQL access.',
    );
  }

  const config: PoolConfig = {
    connectionString,
    allowExitOnIdle: false,
  };

  if (DEFAULT_SSL_MODE !== 'disable') {
    config.ssl = {
      rejectUnauthorized: DEFAULT_SSL_MODE !== 'allow',
    };
  } else if (process.env.PG_SSL === 'true') {
    config.ssl = {
      rejectUnauthorized: false,
    };
  }

  return new Pool(config);
};

export const getPool = (): Pool => {
  if (overridePool) {
    return overridePool;
  }

  if (!internalPool) {
    internalPool = createPool();
  }

  return internalPool;
};

export const withTransaction = async <T>(
  callback: (client: PoolClient) => Promise<T>,
): Promise<T> => {
  const client = await getPool().connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const __dangerous__setPool = (pool: Pool | null): void => {
  overridePool = pool;
};

export const __dangerous__resetPool = async (): Promise<void> => {
  if (internalPool) {
    await internalPool.end().catch(() => {});
    internalPool = null;
  }
  overridePool = null;
};
