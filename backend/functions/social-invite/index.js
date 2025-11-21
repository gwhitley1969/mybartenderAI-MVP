/**
 * Recipe Invite Endpoint - POST/GET /v1/social/invite/{token?}
 *
 * POST: Create shareable invite link for external sharing
 * GET: Claim invite and add recipe to user's collection
 *
 * Supports both standard cocktails (TheCocktailDB) and custom recipes (Create Studio)
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const crypto = require('crypto');
const db = require('../shared/database');
const monitoring = require('../shared/monitoring');

// Configuration
const TENANT_ID = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';
const ISSUER = `https://mybartenderai.ciamlogin.com/${TENANT_ID}/v2.0`;
const AUDIENCE = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6';
const SHARE_BASE_URL = 'https://share.mybartenderai.com';

// JWKS client for token validation
const jwks = jwksClient({
    jwksUri: `${ISSUER}/discovery/v2.0/keys`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5
});

/**
 * Get verification key from JWKS
 */
function getSigningKey(header, callback) {
    jwks.getSigningKey(header.kid, (err, key) => {
        if (err) {
            callback(err);
        } else {
            const signingKey = key.publicKey || key.rsaPublicKey;
            callback(null, signingKey);
        }
    });
}

/**
 * Verify JWT token
 */
async function verifyToken(token) {
    return new Promise((resolve, reject) => {
        jwt.verify(token, getSigningKey, {
            algorithms: ['RS256'],
            issuer: ISSUER,
            audience: AUDIENCE
        }, (err, decoded) => {
            if (err) {
                reject(err);
            } else {
                if (!decoded.sub) {
                    reject(new Error('Token missing subject claim'));
                    return;
                }
                resolve(decoded);
            }
        });
    });
}

/**
 * Generate cryptographically secure random token
 * @returns {string} URL-safe 32-character token
 */
function generateInviteToken() {
    return crypto.randomBytes(24).toString('base64url'); // 32 characters URL-safe
}

/**
 * Validate invite creation request
 */
function validateInviteRequest(body) {
    const { recipeId, customRecipeId, recipeType, message, tagline, oneTime } = body;

    // Recipe type is required
    if (!recipeType || !['standard', 'custom'].includes(recipeType)) {
        return { valid: false, error: 'recipeType must be either "standard" or "custom"' };
    }

    // Validate recipe ID based on type
    if (recipeType === 'standard') {
        if (!recipeId || typeof recipeId !== 'string') {
            return { valid: false, error: 'recipeId is required for standard recipes' };
        }
        if (customRecipeId) {
            return { valid: false, error: 'Cannot specify customRecipeId for standard recipes' };
        }
    } else if (recipeType === 'custom') {
        if (!customRecipeId || typeof customRecipeId !== 'string') {
            return { valid: false, error: 'customRecipeId is required for custom recipes' };
        }
        if (recipeId) {
            return { valid: false, error: 'Cannot specify recipeId for custom recipes' };
        }
    }

    // Optional message validation
    if (message !== undefined && message !== null) {
        if (typeof message !== 'string') {
            return { valid: false, error: 'message must be a string' };
        }
        if (message.length > 200) {
            return { valid: false, error: 'message must be 200 characters or less' };
        }
    }

    // Optional tagline validation
    if (tagline !== undefined && tagline !== null) {
        if (typeof tagline !== 'string') {
            return { valid: false, error: 'tagline must be a string' };
        }
        if (tagline.length > 120) {
            return { valid: false, error: 'tagline must be 120 characters or less' };
        }
    }

    // Optional oneTime validation
    if (oneTime !== undefined && typeof oneTime !== 'boolean') {
        return { valid: false, error: 'oneTime must be a boolean' };
    }

    return { valid: true };
}

/**
 * Create invite
 */
async function createInvite(userId, recipeId, customRecipeId, recipeType, message, tagline, oneTime) {
    return await db.transaction(async (client) => {
        // If custom recipe, verify it exists and user has permission
        if (recipeType === 'custom') {
            const recipeResult = await client.query(
                'SELECT id, user_id, is_public, allow_remix FROM custom_recipes WHERE id = $1',
                [customRecipeId]
            );

            if (recipeResult.rows.length === 0) {
                throw new Error('Custom recipe not found');
            }

            const recipe = recipeResult.rows[0];

            // Only the owner or public remixable recipes can be shared
            if (recipe.user_id !== userId && (!recipe.is_public || !recipe.allow_remix)) {
                throw new Error('You do not have permission to share this custom recipe');
            }
        }

        // Generate unique token
        let token;
        let attempts = 0;
        while (attempts < 5) {
            token = generateInviteToken();

            // Check if token already exists
            const existingResult = await client.query(
                'SELECT 1 FROM share_invite WHERE token = $1',
                [token]
            );

            if (existingResult.rows.length === 0) {
                break; // Unique token found
            }

            attempts++;
        }

        if (attempts >= 5) {
            throw new Error('Failed to generate unique invite token');
        }

        // Insert invite record
        const insertResult = await client.query(
            `INSERT INTO share_invite (
                token, recipe_id, custom_recipe_id, recipe_type,
                from_user_id, message, tagline, one_time,
                created_at, expires_at, status
             )
             VALUES ($1, $2, $3::uuid, $4, $5, $6, $7, $8, now(), now() + interval '30 days', 'issued')
             RETURNING token, created_at, expires_at`,
            [
                token,
                recipeId || null,
                customRecipeId || null,
                recipeType,
                userId,
                message || null,
                tagline || null,
                oneTime !== false // Default to true if not specified
            ]
        );

        const invite = insertResult.rows[0];

        console.log(`Invite created: ${token} for ${recipeType} recipe by ${userId}`);

        return {
            token: invite.token,
            shareUrl: `${SHARE_BASE_URL}/${invite.token}`,
            recipeType: recipeType,
            recipeId: recipeId || null,
            customRecipeId: customRecipeId || null,
            oneTime: oneTime !== false,
            createdAt: invite.created_at,
            expiresAt: invite.expires_at
        };
    });
}

/**
 * Claim invite
 */
async function claimInvite(token, userId) {
    return await db.transaction(async (client) => {
        // Get invite details
        const inviteResult = await client.query(
            `SELECT token, recipe_id, custom_recipe_id, recipe_type, from_user_id,
                    message, tagline, one_time, expires_at, status, claimed_by
             FROM share_invite
             WHERE token = $1`,
            [token]
        );

        if (inviteResult.rows.length === 0) {
            throw new Error('Invite not found');
        }

        const invite = inviteResult.rows[0];

        // Check invite status
        if (invite.status === 'revoked') {
            throw new Error('This invite has been revoked');
        }

        if (invite.status === 'expired') {
            throw new Error('This invite has expired');
        }

        // Check expiry
        if (new Date(invite.expires_at) < new Date()) {
            await client.query(
                'UPDATE share_invite SET status = $1 WHERE token = $2',
                ['expired', token]
            );
            throw new Error('This invite has expired');
        }

        // Check if already claimed (for one-time invites)
        if (invite.one_time && invite.status === 'claimed') {
            throw new Error('This invite has already been claimed');
        }

        // Cannot claim your own invite
        if (invite.from_user_id === userId) {
            throw new Error('Cannot claim your own invite');
        }

        // Update invite status
        if (invite.one_time) {
            await client.query(
                `UPDATE share_invite
                 SET status = 'claimed', claimed_by = $1, claimed_at = now()
                 WHERE token = $2`,
                [userId, token]
            );
        } else {
            // Multi-use invite - just track the claim
            await client.query(
                `UPDATE share_invite
                 SET claimed_at = now()
                 WHERE token = $1 AND claimed_at IS NULL`,
                [token]
            );
        }

        console.log(`Invite claimed: ${token} by ${userId}`);

        return {
            recipeType: invite.recipe_type,
            recipeId: invite.recipe_id,
            customRecipeId: invite.custom_recipe_id,
            message: invite.message,
            tagline: invite.tagline,
            fromUserId: invite.from_user_id
        };
    });
}

/**
 * Main handler
 */
module.exports = async function (context, req) {
    const method = req.method;
    const token = req.params.token;

    console.log(`Invite ${method} request received`);

    try {
        // POST - Create invite (requires authentication)
        if (method === 'POST') {
            // Extract and verify JWT
            const authHeader = req.headers.authorization;
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                    endpoint: '/v1/social/invite'
                });
                context.res = {
                    status: 401,
                    body: { error: 'Missing or invalid Authorization header' }
                };
                return;
            }

            const jwtToken = authHeader.substring(7);

            // Validate JWT
            let decodedToken;
            try {
                decodedToken = await verifyToken(jwtToken);
                console.log(`Token validated for user: ${decodedToken.sub}`);
            } catch (error) {
                console.error('JWT validation failed:', error.message);
                monitoring.trackAuthFailure('unknown', 'invalid_token', {
                    endpoint: '/v1/social/invite',
                    error: error.message
                });
                context.res = {
                    status: 401,
                    body: { error: 'Invalid or expired token' }
                };
                return;
            }

            const userId = decodedToken.sub;

            // Validate request body
            const validation = validateInviteRequest(req.body || {});
            if (!validation.valid) {
                context.res = {
                    status: 400,
                    body: { error: validation.error }
                };
                return;
            }

            const { recipeId, customRecipeId, recipeType, message, tagline, oneTime } = req.body;

            // Create invite
            try {
                const result = await createInvite(
                    userId,
                    recipeId,
                    customRecipeId,
                    recipeType,
                    message,
                    tagline,
                    oneTime
                );

                context.res = {
                    status: 201,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: result
                };

                console.log(`Invite created successfully: ${result.token}`);

            } catch (error) {
                if (error.message.includes('not found') ||
                    error.message.includes('permission')) {
                    context.res = {
                        status: 400,
                        body: { error: error.message }
                    };
                } else {
                    throw error;
                }
            }
        }
        // GET - Claim invite (requires authentication)
        else if (method === 'GET') {
            if (!token) {
                context.res = {
                    status: 400,
                    body: { error: 'Invite token is required' }
                };
                return;
            }

            // Extract and verify JWT
            const authHeader = req.headers.authorization;
            if (!authHeader || !authHeader.startsWith('Bearer ')) {
                monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                    endpoint: '/v1/social/invite'
                });
                context.res = {
                    status: 401,
                    body: { error: 'Missing or invalid Authorization header' }
                };
                return;
            }

            const jwtToken = authHeader.substring(7);

            // Validate JWT
            let decodedToken;
            try {
                decodedToken = await verifyToken(jwtToken);
                console.log(`Token validated for user: ${decodedToken.sub}`);
            } catch (error) {
                console.error('JWT validation failed:', error.message);
                monitoring.trackAuthFailure('unknown', 'invalid_token', {
                    endpoint: '/v1/social/invite',
                    error: error.message
                });
                context.res = {
                    status: 401,
                    body: { error: 'Invalid or expired token' }
                };
                return;
            }

            const userId = decodedToken.sub;

            // Claim invite
            try {
                const result = await claimInvite(token, userId);

                context.res = {
                    status: 200,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: result
                };

                console.log(`Invite claimed successfully by ${userId}`);

            } catch (error) {
                if (error.message.includes('not found') ||
                    error.message.includes('expired') ||
                    error.message.includes('revoked') ||
                    error.message.includes('claimed') ||
                    error.message.includes('Cannot claim')) {
                    context.res = {
                        status: 400,
                        body: { error: error.message }
                    };
                } else {
                    throw error;
                }
            }
        }

    } catch (error) {
        console.error('Invite error:', error.message);
        console.error(error.stack);

        context.res = {
            status: 500,
            body: { error: 'Internal server error' }
        };
    }
};
