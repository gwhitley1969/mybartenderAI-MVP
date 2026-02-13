"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.incrementAndCheck = exports.checkQuotaWithoutIncrement = exports.getCurrentUsage = exports.QuotaExceededError = void 0;

const postgresPool_js_1 = require("../shared/db/postgresPool.js");
const { TIER_QUOTAS, ENTITLEMENT_QUOTAS } = require("./userService.js");

/**
 * Default monthly cap (fallback if tier lookup fails)
 * This is the free tier limit as a safe default
 */
const DEFAULT_MONTHLY_CAP = 10000;

/**
 * Normalize a date to YYYY-MM format for monthly tracking
 */
const normalizeMonth = (date) => {
    const month = String(date.getUTCMonth() + 1).padStart(2, '0');
    return `${date.getUTCFullYear()}-${month}`;
};

class QuotaExceededError extends Error {
    constructor(message, remaining, limit, used) {
        super(message);
        this.remaining = remaining;
        this.limit = limit;
        this.used = used;
        this.name = 'QuotaExceededError';
    }
}
exports.QuotaExceededError = QuotaExceededError;

/**
 * Get the monthly token cap for a user based on their tier
 * Looks up the user's tier from the database
 *
 * @param {object} client - PostgreSQL client (from transaction)
 * @param {string} userId - The user's azure_ad_sub (JWT sub claim)
 * @returns {Promise<number>} Monthly token cap
 */
const getMonthlyCap = async (client, userId) => {
    try {
        // Look up user's tier and entitlement from the users table
        const result = await client.query(
            'SELECT tier, entitlement FROM users WHERE azure_ad_sub = $1',
            [userId]
        );

        if (result.rowCount === 0) {
            console.log(`[TokenQuota] User ${userId.substring(0, 8)}... not found, using default cap`);
            return DEFAULT_MONTHLY_CAP;
        }

        const { tier, entitlement } = result.rows[0];

        // Use entitlement-based quotas first, fall back to tier
        if (entitlement && ENTITLEMENT_QUOTAS[entitlement]) {
            const cap = ENTITLEMENT_QUOTAS[entitlement].tokensPerMonth;
            console.log(`[TokenQuota] User entitlement: ${entitlement}, monthly cap: ${cap}`);
            return cap;
        }

        const normalizedTier = tier || 'free';
        const quotas = TIER_QUOTAS[normalizedTier] || TIER_QUOTAS.free;
        console.log(`[TokenQuota] User tier: ${normalizedTier}, monthly cap: ${quotas.tokensPerMonth}`);
        return quotas.tokensPerMonth;

    } catch (error) {
        console.error(`[TokenQuota] Error looking up user tier: ${error.message}`);
        return DEFAULT_MONTHLY_CAP;
    }
};

/**
 * Upsert quota row - create or update the usage record
 */
const upsertQuotaRow = async (client, sub, month, tokensUsed, monthlyCap, now) => {
    const result = await client.query(
        'SELECT tokens_used, monthly_cap FROM token_quotas WHERE sub = $1 AND month = $2 FOR UPDATE',
        [sub, month]
    );

    if (result.rowCount === 0) {
        await client.query(
            `INSERT INTO token_quotas
            (sub, month, tokens_used, monthly_cap, window_start, updated_at)
           VALUES ($1, $2, $3, $4, $5, $5)`,
            [sub, month, tokensUsed, monthlyCap, now.toISOString()]
        );
        return;
    }

    // Update both usage and cap (cap may have changed if tier changed)
    await client.query(
        `UPDATE token_quotas
           SET tokens_used = $1,
               monthly_cap = $2,
               updated_at = $3
         WHERE sub = $4 AND month = $5`,
        [tokensUsed, monthlyCap, now.toISOString(), sub, month]
    );
};

/**
 * Get current usage without incrementing
 *
 * @param {string} userId - The user's azure_ad_sub (JWT sub claim)
 * @param {Date} now - Current date (defaults to new Date())
 * @returns {Promise<{used: number, limit: number, remaining: number}>}
 */
const getCurrentUsage = async (userId, now = new Date()) => {
    const month = normalizeMonth(now);
    const pool = postgresPool_js_1.getPool();

    // Get user's entitlement and tier
    const tierResult = await pool.query(
        'SELECT tier, entitlement FROM users WHERE azure_ad_sub = $1',
        [userId]
    );

    const entitlement = tierResult.rows[0]?.entitlement;
    const tier = tierResult.rows[0]?.tier || 'free';

    // Use entitlement-based cap first, fall back to tier
    const monthlyCap = (entitlement && ENTITLEMENT_QUOTAS[entitlement])
        ? ENTITLEMENT_QUOTAS[entitlement].tokensPerMonth
        : (TIER_QUOTAS[tier]?.tokensPerMonth || DEFAULT_MONTHLY_CAP);

    // Get current usage
    const usageResult = await pool.query(
        'SELECT tokens_used FROM token_quotas WHERE sub = $1 AND month = $2',
        [userId, month]
    );

    const used = usageResult.rows[0]?.tokens_used || 0;
    const remaining = Math.max(monthlyCap - used, 0);

    return {
        used: Number(used),
        limit: monthlyCap,
        remaining
    };
};
exports.getCurrentUsage = getCurrentUsage;

/**
 * Check if user has quota remaining without incrementing
 *
 * @param {string} userId - The user's azure_ad_sub (JWT sub claim)
 * @param {number} tokensNeeded - Number of tokens to check for
 * @param {Date} now - Current date
 * @returns {Promise<{hasQuota: boolean, used: number, limit: number, remaining: number}>}
 */
const checkQuotaWithoutIncrement = async (userId, tokensNeeded = 0, now = new Date()) => {
    const usage = await getCurrentUsage(userId, now);
    const hasQuota = usage.remaining >= tokensNeeded;

    return {
        hasQuota,
        ...usage
    };
};
exports.checkQuotaWithoutIncrement = checkQuotaWithoutIncrement;

/**
 * Increment token usage and check against quota
 * Throws QuotaExceededError if the new usage would exceed the limit
 *
 * @param {string} userId - The user's azure_ad_sub (JWT sub claim)
 * @param {number} tokensUsed - Number of tokens to add to usage
 * @param {Date} now - Current date (defaults to new Date())
 * @throws {QuotaExceededError} If quota would be exceeded
 */
const incrementAndCheck = async (userId, tokensUsed, now = new Date()) => {
    if (tokensUsed <= 0) {
        return;
    }

    const month = normalizeMonth(now);

    await (0, postgresPool_js_1.withTransaction)(async (client) => {
        // Get the user's tier-based monthly cap
        const monthlyCap = await getMonthlyCap(client, userId);

        // Get current usage with row lock
        const current = await client.query(
            'SELECT tokens_used FROM token_quotas WHERE sub = $1 AND month = $2 FOR UPDATE',
            [userId, month]
        );

        const existingUsage = current.rowCount
            ? Number(current.rows[0].tokens_used ?? 0)
            : 0;

        const newUsage = existingUsage + tokensUsed;

        if (newUsage > monthlyCap) {
            const remaining = Math.max(monthlyCap - existingUsage, 0);
            throw new QuotaExceededError(
                `Monthly token quota exceeded. Used: ${existingUsage}, Limit: ${monthlyCap}, Attempted: ${tokensUsed}`,
                remaining,
                monthlyCap,
                existingUsage
            );
        }

        await upsertQuotaRow(client, userId, month, newUsage, monthlyCap, now);

        console.log(`[TokenQuota] User ${userId.substring(0, 8)}...: ${existingUsage} + ${tokensUsed} = ${newUsage} / ${monthlyCap}`);
    });
};
exports.incrementAndCheck = incrementAndCheck;
