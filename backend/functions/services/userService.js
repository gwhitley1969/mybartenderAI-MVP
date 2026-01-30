"use strict";

/**
 * User Service - Centralized user lookup and tier management
 *
 * This service handles:
 * - Looking up users by their Entra External ID (JWT sub claim)
 * - Auto-creating user records for new users
 * - Providing tier-based quota information
 *
 * Source of truth: PostgreSQL `users` table
 */

const { getPool } = require('../shared/db/postgresPool');

/**
 * Tier quota definitions
 * These match the business model in CLAUDE.md
 */
const TIER_QUOTAS = {
    free: {
        tokensPerMonth: 10000,
        scansPerMonth: 2,
        voiceMinutesPerMonth: 0,
        aiEnabled: true,
        voiceEnabled: false
    },
    premium: {
        tokensPerMonth: 300000,
        scansPerMonth: 30,
        voiceMinutesPerMonth: 0,
        aiEnabled: true,
        voiceEnabled: false
    },
    pro: {
        tokensPerMonth: 1000000,
        scansPerMonth: 100,
        voiceMinutesPerMonth: 60,  // Pro tier: 60 min/month at $7.99/mo
        aiEnabled: true,
        voiceEnabled: true
    }
};

/**
 * Valid tier values (must match database constraint)
 */
const VALID_TIERS = ['free', 'premium', 'pro'];

/**
 * Get or create a user by their Azure AD subject claim (from JWT)
 *
 * @param {string} azureAdSub - The `sub` claim from the JWT token
 * @param {object} context - Azure Functions context for logging
 * @param {object} options - Optional profile data from APIM-forwarded JWT claims
 * @param {string|null} options.email - User email from x-user-email header
 * @param {string|null} options.displayName - User display name from x-user-name header
 * @returns {Promise<{id: string, azureAdSub: string, tier: string, email: string|null, displayName: string|null}>}
 */
async function getOrCreateUser(azureAdSub, context = null, options = {}) {
    const { email = null, displayName = null } = options;
    const log = context?.log || console;

    if (!azureAdSub || typeof azureAdSub !== 'string') {
        throw new Error('azureAdSub is required and must be a string');
    }

    const pool = getPool();

    try {
        // First, try to find existing user
        const selectResult = await pool.query(
            `SELECT id, azure_ad_sub, tier, email, display_name, created_at, last_login_at
             FROM users
             WHERE azure_ad_sub = $1`,
            [azureAdSub]
        );

        if (selectResult.rows.length > 0) {
            const user = selectResult.rows[0];

            // Update last_login_at and refresh email/display_name if provided
            const updateResult = await pool.query(
                `UPDATE users
                 SET last_login_at = NOW(), updated_at = NOW(),
                     email = COALESCE($2, email),
                     display_name = COALESCE($3, display_name)
                 WHERE id = $1
                 RETURNING id, azure_ad_sub, tier, email, display_name, created_at, last_login_at`,
                [user.id, email, displayName]
            );

            const updatedUser = updateResult.rows[0];

            log.info?.(`[UserService] Found existing user: ${updatedUser.id}, tier: ${updatedUser.tier}`) ||
                log(`[UserService] Found existing user: ${updatedUser.id}, tier: ${updatedUser.tier}`);

            return {
                id: updatedUser.id,
                azureAdSub: updatedUser.azure_ad_sub,
                tier: updatedUser.tier,
                email: updatedUser.email,
                displayName: updatedUser.display_name,
                createdAt: updatedUser.created_at,
                lastLoginAt: updatedUser.last_login_at
            };
        }

        // User doesn't exist - create with default 'pro' tier (beta testing)
        log.info?.(`[UserService] Creating new user for sub: ${azureAdSub.substring(0, 8)}...`) ||
            log(`[UserService] Creating new user for sub: ${azureAdSub.substring(0, 8)}...`);

        const insertResult = await pool.query(
            `INSERT INTO users (azure_ad_sub, tier, email, display_name, created_at, updated_at, last_login_at)
             VALUES ($1, 'pro', $2, $3, NOW(), NOW(), NOW())
             RETURNING id, azure_ad_sub, tier, email, display_name, created_at, last_login_at`,
            [azureAdSub, email, displayName]
        );

        const newUser = insertResult.rows[0];

        log.info?.(`[UserService] Created new user: ${newUser.id}, tier: pro`) ||
            log(`[UserService] Created new user: ${newUser.id}, tier: pro`);

        return {
            id: newUser.id,
            azureAdSub: newUser.azure_ad_sub,
            tier: newUser.tier,
            email: newUser.email,
            displayName: newUser.display_name,
            createdAt: newUser.created_at,
            lastLoginAt: newUser.last_login_at
        };

    } catch (error) {
        // Handle race condition where user was created between SELECT and INSERT
        if (error.code === '23505') { // unique_violation
            log.warn?.(`[UserService] Race condition detected, retrying lookup`) ||
                log(`[UserService] Race condition detected, retrying lookup`);

            const retryResult = await pool.query(
                `SELECT id, azure_ad_sub, tier, email, display_name, created_at, last_login_at
                 FROM users
                 WHERE azure_ad_sub = $1`,
                [azureAdSub]
            );

            if (retryResult.rows.length > 0) {
                const user = retryResult.rows[0];
                return {
                    id: user.id,
                    azureAdSub: user.azure_ad_sub,
                    tier: user.tier,
                    email: user.email,
                    displayName: user.display_name,
                    createdAt: user.created_at,
                    lastLoginAt: user.last_login_at
                };
            }
        }

        log.error?.(`[UserService] Error in getOrCreateUser: ${error.message}`) ||
            console.error(`[UserService] Error in getOrCreateUser: ${error.message}`);
        throw error;
    }
}

/**
 * Get quota limits for a given tier
 *
 * @param {string} tier - The user's subscription tier ('free', 'premium', 'pro')
 * @returns {object} Quota limits for the tier
 */
function getTierQuotas(tier) {
    const normalizedTier = (tier || 'free').toLowerCase();

    if (!VALID_TIERS.includes(normalizedTier)) {
        console.warn(`[UserService] Invalid tier '${tier}', defaulting to 'free'`);
        return TIER_QUOTAS.free;
    }

    return TIER_QUOTAS[normalizedTier];
}

/**
 * Check if a user has access to a specific feature based on their tier
 *
 * @param {string} tier - The user's subscription tier
 * @param {string} feature - The feature to check ('ai', 'voice', 'scan')
 * @returns {boolean} Whether the user has access to the feature
 */
function hasFeatureAccess(tier, feature) {
    const quotas = getTierQuotas(tier);

    switch (feature) {
        case 'ai':
            return quotas.aiEnabled;
        case 'voice':
            return quotas.voiceEnabled;
        case 'scan':
            return quotas.scansPerMonth > 0;
        default:
            return false;
    }
}

/**
 * Update a user's tier (for admin/billing purposes)
 *
 * @param {string} azureAdSub - The user's Azure AD subject claim
 * @param {string} newTier - The new tier to set ('free', 'premium', 'pro')
 * @param {object} context - Azure Functions context for logging
 * @returns {Promise<{success: boolean, user: object}>}
 */
async function updateUserTier(azureAdSub, newTier, context = null) {
    const log = context?.log || console;

    if (!VALID_TIERS.includes(newTier.toLowerCase())) {
        throw new Error(`Invalid tier: ${newTier}. Must be one of: ${VALID_TIERS.join(', ')}`);
    }

    const pool = getPool();

    const result = await pool.query(
        `UPDATE users
         SET tier = $2, updated_at = NOW()
         WHERE azure_ad_sub = $1
         RETURNING id, azure_ad_sub, tier, email, display_name`,
        [azureAdSub, newTier.toLowerCase()]
    );

    if (result.rows.length === 0) {
        throw new Error(`User not found: ${azureAdSub}`);
    }

    const user = result.rows[0];
    log.info?.(`[UserService] Updated user ${user.id} tier to: ${newTier}`) ||
        log(`[UserService] Updated user ${user.id} tier to: ${newTier}`);

    return {
        success: true,
        user: {
            id: user.id,
            azureAdSub: user.azure_ad_sub,
            tier: user.tier,
            email: user.email,
            displayName: user.display_name
        }
    };
}

/**
 * Get user by ID (UUID)
 *
 * @param {string} userId - The user's UUID
 * @returns {Promise<object|null>}
 */
async function getUserById(userId) {
    const pool = getPool();

    const result = await pool.query(
        `SELECT id, azure_ad_sub, tier, email, display_name, created_at, last_login_at
         FROM users
         WHERE id = $1`,
        [userId]
    );

    if (result.rows.length === 0) {
        return null;
    }

    const user = result.rows[0];
    return {
        id: user.id,
        azureAdSub: user.azure_ad_sub,
        tier: user.tier,
        email: user.email,
        displayName: user.display_name,
        createdAt: user.created_at,
        lastLoginAt: user.last_login_at
    };
}

module.exports = {
    getOrCreateUser,
    getTierQuotas,
    hasFeatureAccess,
    updateUserTier,
    getUserById,
    TIER_QUOTAS,
    VALID_TIERS
};
