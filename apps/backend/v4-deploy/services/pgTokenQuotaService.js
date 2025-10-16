"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.incrementAndCheck = exports.QuotaExceededError = void 0;
const postgresPool_js_1 = require("../shared/db/postgresPool.js");
const DEFAULT_MONTHLY_CAP = Number.isNaN(Number(process.env.MONTHLY_TOKEN_LIMIT))
    ? 200000
    : Number(process.env.MONTHLY_TOKEN_LIMIT);
const normalizeMonth = (date) => {
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    return `${date.getUTCFullYear()}-${month}`;
};
class QuotaExceededError extends Error {
    constructor(message, remaining) {
        super(message);
        this.remaining = remaining;
        this.name = 'QuotaExceededError';
    }
}
exports.QuotaExceededError = QuotaExceededError;
const upsertQuotaRow = async (client, sub, month, tokensUsed, monthlyCap, now) => {
    const result = await client.query('SELECT tokens_used, monthly_cap FROM token_quotas WHERE sub = $1 AND month = $2 FOR UPDATE', [sub, month]);
    if (result.rowCount === 0) {
        await client.query(`INSERT INTO token_quotas
        (sub, month, tokens_used, monthly_cap, window_start, updated_at)
       VALUES ($1, $2, $3, $4, $5, $5)`, [sub, month, tokensUsed, monthlyCap, now.toISOString()]);
        return;
    }
    await client.query(`UPDATE token_quotas
       SET tokens_used = $1,
           updated_at = $2
     WHERE sub = $3 AND month = $4`, [tokensUsed, now.toISOString(), sub, month]);
};
const incrementAndCheck = async (userId, tokensUsed, now = new Date()) => {
    if (tokensUsed <= 0) {
        return;
    }
    const month = normalizeMonth(now);
    await (0, postgresPool_js_1.withTransaction)(async (client) => {
        const current = await client.query('SELECT tokens_used, monthly_cap FROM token_quotas WHERE sub = $1 AND month = $2 FOR UPDATE', [userId, month]);
        const monthlyCap = current.rowCount
            ? Number(current.rows[0].monthly_cap ?? DEFAULT_MONTHLY_CAP)
            : DEFAULT_MONTHLY_CAP;
        const existingUsage = current.rowCount
            ? Number(current.rows[0].tokens_used ?? 0)
            : 0;
        const newUsage = existingUsage + tokensUsed;
        if (newUsage > monthlyCap) {
            const remaining = Math.max(monthlyCap - existingUsage, 0);
            throw new QuotaExceededError(`Monthly token quota exceeded for ${userId}`, remaining);
        }
        await upsertQuotaRow(client, userId, month, newUsage, monthlyCap, now);
    });
};
exports.incrementAndCheck = incrementAndCheck;


