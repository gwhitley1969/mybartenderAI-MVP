/**
 * User Profile Endpoint - GET/PATCH/DELETE /v1/users/me
 *
 * Manages user profiles with system-generated aliases for Friends via Code feature
 *
 * GET: Retrieve current user's profile (auto-creates if not exists)
 * PATCH: Update display name
 * DELETE: Delete account and all associated data (Apple guideline 5.1.1(v))
 *
 * Authentication: APIM validates JWT and sets x-user-id header
 */

const db = require('../shared/database');
const { generateUniqueAlias, validateDisplayName } = require('../shared/aliasGenerator');

/**
 * Get or create user profile
 * @param {string} userId - User ID from APIM x-user-id header (Entra sub claim)
 * @returns {Promise<object>} User profile
 */
async function getOrCreateProfile(userId) {
    // Try to get existing profile
    const result = await db.query(
        'SELECT user_id, alias, display_name, created_at, last_seen FROM user_profile WHERE user_id = $1',
        [userId]
    );

    if (result.rows.length > 0) {
        // Update last_seen
        await db.query(
            'UPDATE user_profile SET last_seen = now() WHERE user_id = $1',
            [userId]
        );

        return result.rows[0];
    }

    // Profile doesn't exist, create it
    console.log(`Creating new profile for user: ${userId}`);

    // Use transaction to ensure atomicity
    return await db.transaction(async (client) => {
        // Generate unique alias
        const alias = await generateUniqueAlias(client);

        // Insert new profile
        const insertResult = await client.query(
            `INSERT INTO user_profile (user_id, alias, created_at, last_seen)
             VALUES ($1, $2, now(), now())
             RETURNING user_id, alias, display_name, created_at, last_seen`,
            [userId, alias]
        );

        console.log(`Created profile with alias: ${alias}`);

        return insertResult.rows[0];
    });
}

/**
 * Update user's display name
 * @param {string} userId - User ID
 * @param {string} displayName - New display name (or null to remove)
 * @returns {Promise<object>} Updated profile
 */
async function updateDisplayName(userId, displayName) {
    // Validate display name
    const validation = validateDisplayName(displayName);
    if (!validation.valid) {
        throw new Error(validation.error);
    }

    // Update profile
    const result = await db.query(
        `UPDATE user_profile
         SET display_name = $1, last_seen = now()
         WHERE user_id = $2
         RETURNING user_id, alias, display_name, created_at, last_seen`,
        [displayName || null, userId]
    );

    if (result.rows.length === 0) {
        throw new Error('Profile not found');
    }

    return result.rows[0];
}

/**
 * Delete user account and all associated data
 * Uses database cascades for most cleanup:
 *   - user_profile CASCADE → custom_recipes, recipe_share, share_invite, friendships
 *   - users CASCADE → user_inventory, usage_tracking, voice_sessions → voice_messages,
 *     vision_scans, user_subscriptions, voice_addon_purchases, voice_purchase_transactions
 *   - subscription_events.user_id SET NULL (preserves audit trail)
 *
 * @param {string} userId - Entra sub claim (TEXT, used as user_profile.user_id)
 * @returns {Promise<void>}
 */
async function deleteAccount(userId) {
    return await db.transaction(async (client) => {
        // Step 1: Delete user_profile (TEXT PK = Entra sub)
        // Cascades to: custom_recipes, recipe_share, share_invite, friendships
        const profileResult = await client.query(
            'DELETE FROM user_profile WHERE user_id = $1',
            [userId]
        );

        // Step 2: Delete from users table (azure_ad_sub = Entra sub)
        // Cascades to: user_inventory, usage_tracking, voice_sessions → voice_messages,
        //   vision_scans, user_subscriptions, voice_addon_purchases, voice_purchase_transactions
        // SET NULL on: subscription_events (audit trail preserved)
        const userResult = await client.query(
            'DELETE FROM users WHERE azure_ad_sub = $1',
            [userId]
        );

        if (userResult.rowCount === 0 && profileResult.rowCount === 0) {
            throw new Error('User not found');
        }

        console.log(`Account deleted for user ${userId}: ${userResult.rowCount} user row(s), ${profileResult.rowCount} profile row(s)`);
    });
}

/**
 * Format profile for API response
 */
function formatProfile(profile) {
    return {
        userId: profile.user_id,
        alias: profile.alias,
        displayName: profile.display_name || null,
        createdAt: profile.created_at,
        lastSeen: profile.last_seen
    };
}

/**
 * Main handler - called from v4 index.js
 * Authentication is handled by APIM (validates JWT, sets x-user-id header)
 *
 * @param {object} context - Azure Functions v4 invocation context
 * @param {Request} request - Azure Functions v4 Request object
 */
module.exports = async function (context, request) {
    const method = request.method;
    console.log(`User profile ${method} request received`);

    try {
        // Get user ID from APIM header (set by validate-jwt policy)
        const userId = request.headers.get('x-user-id');
        if (!userId) {
            console.error('Missing x-user-id header — APIM should set this from JWT');
            return {
                status: 401,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: { error: 'Missing user ID' }
            };
        }

        // Handle GET request - Get or create profile
        if (method === 'GET') {
            const profile = await getOrCreateProfile(userId);

            console.log(`Profile retrieved for user ${userId}: ${profile.alias}`);
            return {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'Cache-Control': 'private, max-age=60'
                },
                jsonBody: formatProfile(profile)
            };
        }
        // Handle PATCH request - Update display name
        else if (method === 'PATCH') {
            let body = {};
            try {
                body = await request.json();
            } catch (e) {
                // empty body
            }
            const { displayName } = body;

            if (displayName !== undefined && displayName !== null && typeof displayName !== 'string') {
                return {
                    status: 400,
                    headers: { 'Content-Type': 'application/json' },
                    jsonBody: { error: 'displayName must be a string or null' }
                };
            }

            try {
                const profile = await updateDisplayName(userId, displayName);

                console.log(`Display name updated for user ${userId}: ${displayName || '(removed)'}`);
                return {
                    status: 200,
                    headers: { 'Content-Type': 'application/json' },
                    jsonBody: formatProfile(profile)
                };

            } catch (error) {
                if (error.message.includes('30 characters')) {
                    return {
                        status: 400,
                        headers: { 'Content-Type': 'application/json' },
                        jsonBody: { error: error.message }
                    };
                } else {
                    throw error;
                }
            }
        }
        // Handle DELETE request - Delete account and all data
        else if (method === 'DELETE') {
            try {
                await deleteAccount(userId);

                console.log(`Account deleted for user: ${userId}`);
                return {
                    status: 200,
                    headers: { 'Content-Type': 'application/json' },
                    jsonBody: {
                        success: true,
                        message: 'Account and all associated data have been deleted'
                    }
                };

            } catch (error) {
                if (error.message === 'User not found') {
                    return {
                        status: 404,
                        headers: { 'Content-Type': 'application/json' },
                        jsonBody: { error: 'User not found' }
                    };
                } else {
                    throw error;
                }
            }
        }

    } catch (error) {
        console.error('User profile error:', error.message);
        console.error(error.stack);

        // Check for specific database errors
        if (error.code === '23505') { // Unique constraint violation
            return {
                status: 409,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: { error: 'Profile conflict - please try again' }
            };
        } else {
            return {
                status: 500,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: { error: 'Internal server error' }
            };
        }
    }
};
