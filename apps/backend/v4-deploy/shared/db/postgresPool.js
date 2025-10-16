"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.__dangerous__resetPool = exports.__dangerous__setPool = exports.withTransaction = exports.getPool = void 0;
const pg_1 = require("pg");
const DEFAULT_SSL_MODE = process.env.PG_SSL_MODE ?? 'disable';
let internalPool = null;
let overridePool = null;
const createPool = () => {
    const connectionString = process.env.PG_CONNECTION_STRING;
    if (!connectionString) {
        throw new Error('PG_CONNECTION_STRING environment variable is required for PostgreSQL access.');
    }
    const config = {
        connectionString,
        allowExitOnIdle: false,
    };
    if (DEFAULT_SSL_MODE !== 'disable') {
        config.ssl = {
            rejectUnauthorized: DEFAULT_SSL_MODE !== 'allow',
        };
    }
    else if (process.env.PG_SSL === 'true') {
        config.ssl = {
            rejectUnauthorized: false,
        };
    }
    return new pg_1.Pool(config);
};
const getPool = () => {
    if (overridePool) {
        return overridePool;
    }
    if (!internalPool) {
        internalPool = createPool();
    }
    return internalPool;
};
exports.getPool = getPool;
const withTransaction = async (callback) => {
    const client = await (0, exports.getPool)().connect();
    try {
        await client.query('BEGIN');
        const result = await callback(client);
        await client.query('COMMIT');
        return result;
    }
    catch (error) {
        await client.query('ROLLBACK');
        throw error;
    }
    finally {
        client.release();
    }
};
exports.withTransaction = withTransaction;
const __dangerous__setPool = (pool) => {
    overridePool = pool;
};
exports.__dangerous__setPool = __dangerous__setPool;
const __dangerous__resetPool = async () => {
    if (internalPool) {
        await internalPool.end().catch(() => { });
        internalPool = null;
    }
    overridePool = null;
};
exports.__dangerous__resetPool = __dangerous__resetPool;

