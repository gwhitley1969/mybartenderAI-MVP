/**
 * Database Connection Utility for PostgreSQL
 * Handles connection pooling and query execution
 */

const { Pool } = require('pg');

// Connection pool singleton
let pool = null;

/**
 * Get PostgreSQL connection pool
 * @returns {Pool} PostgreSQL connection pool
 */
function getPool() {
  if (!pool) {
    const connectionString = process.env.POSTGRES_CONNECTION_STRING;

    if (!connectionString) {
      throw new Error('POSTGRES_CONNECTION_STRING environment variable not set');
    }

    pool = new Pool({
      connectionString: connectionString,
      ssl: {
        rejectUnauthorized: false // Azure requires SSL
      },
      max: 20, // Maximum pool size
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 5000
    });

    // Log pool errors
    pool.on('error', (err) => {
      console.error('Unexpected error on idle client', err);
    });

    console.log('PostgreSQL connection pool initialized');
  }

  return pool;
}

/**
 * Execute a query with automatic error handling
 * @param {string} text - SQL query
 * @param {Array} params - Query parameters
 * @returns {Promise<object>} Query result
 */
async function query(text, params) {
  const start = Date.now();
  const pool = getPool();

  try {
    const result = await pool.query(text, params);
    const duration = Date.now() - start;

    console.log('Query executed:', {
      duration: `${duration}ms`,
      rows: result.rowCount
    });

    return result;
  } catch (error) {
    console.error('Database query error:', {
      error: error.message,
      query: text,
      params: params
    });
    throw error;
  }
}

/**
 * Get a client from the pool for transactions
 * @returns {Promise<PoolClient>} Database client
 */
async function getClient() {
  const pool = getPool();
  return await pool.connect();
}

/**
 * Execute a function within a transaction
 * @param {Function} callback - Async function to execute in transaction
 * @returns {Promise<any>} Result of callback
 */
async function transaction(callback) {
  const client = await getClient();

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
}

/**
 * Close the connection pool
 */
async function closePool() {
  if (pool) {
    await pool.end();
    pool = null;
    console.log('PostgreSQL connection pool closed');
  }
}

module.exports = {
  query,
  getClient,
  transaction,
  closePool,
  getPool
};
