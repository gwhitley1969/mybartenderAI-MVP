/**
 * Internal Recipe Share Endpoint - POST /v1/social/share-internal
 *
 * Enables users to share recipes with friends via their aliases
 * Supports both standard cocktails (TheCocktailDB) and custom recipes (Create Studio)
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const db = require('../shared/database');
const monitoring = require('../shared/monitoring');

// Configuration
const TENANT_ID = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';
const ISSUER = `https://mybartenderai.ciamlogin.com/${TENANT_ID}/v2.0`;
const AUDIENCE = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6';

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
 * Validate share request
 */
function validateShareRequest(body) {
    const { toAlias, recipeId, customRecipeId, recipeType, message, tagline } = body;

    // Recipient alias is required
    if (!toAlias || typeof toAlias !== 'string') {
        return { valid: false, error: 'toAlias is required and must be a string' };
    }

    // Must start with @ and match pattern
    if (!toAlias.startsWith('@') || !/^@[a-z]+-[a-z]+-\d{3}$/.test(toAlias)) {
        return { valid: false, error: 'Invalid alias format. Expected: @adjective-animal-###' };
    }

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

    return { valid: true };
}

/**
 * Share recipe internally
 */
async function shareRecipe(fromUserId, toAlias, recipeId, customRecipeId, recipeType, message, tagline) {
    return await db.transaction(async (client) => {
        // Look up recipient by alias
        const recipientResult = await client.query(
            'SELECT user_id FROM user_profile WHERE alias = $1',
            [toAlias]
        );

        if (recipientResult.rows.length === 0) {
            throw new Error(`Recipient not found with alias: ${toAlias}`);
        }

        const toUserId = recipientResult.rows[0].user_id;

        // Check if sharing with self
        if (fromUserId === toUserId) {
            throw new Error('Cannot share recipe with yourself');
        }

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
            if (recipe.user_id !== fromUserId && (!recipe.is_public || !recipe.allow_remix)) {
                throw new Error('You do not have permission to share this custom recipe');
            }
        }

        // Check for duplicate share (same recipe to same user within last 24 hours)
        const duplicateCheck = await client.query(
            `SELECT id FROM recipe_share
             WHERE from_user_id = $1
               AND to_user_id = $2
               AND recipe_type = $3
               AND (
                   (recipe_type = 'standard' AND recipe_id = $4) OR
                   (recipe_type = 'custom' AND custom_recipe_id = $5::uuid)
               )
               AND created_at > NOW() - INTERVAL '24 hours'`,
            [fromUserId, toUserId, recipeType, recipeId || null, customRecipeId || null]
        );

        if (duplicateCheck.rows.length > 0) {
            throw new Error('You already shared this recipe with this user in the last 24 hours');
        }

        // Insert share record
        const insertResult = await client.query(
            `INSERT INTO recipe_share (from_user_id, to_user_id, recipe_id, custom_recipe_id, recipe_type, message, tagline)
             VALUES ($1, $2, $3, $4::uuid, $5, $6, $7)
             RETURNING id, created_at`,
            [fromUserId, toUserId, recipeId || null, customRecipeId || null, recipeType, message || null, tagline || null]
        );

        const share = insertResult.rows[0];

        console.log(`Recipe shared: ${recipeType} recipe from ${fromUserId} to ${toUserId}`);

        return {
            shareId: share.id.toString(),
            recipientAlias: toAlias,
            recipeType: recipeType,
            recipeId: recipeId || null,
            customRecipeId: customRecipeId || null,
            createdAt: share.created_at
        };
    });
}

/**
 * Main handler
 */
module.exports = async function (context, req) {
    console.log('Internal share request received');

    try {
        // Extract and verify JWT
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                endpoint: '/v1/social/share-internal'
            });
            context.res = {
                status: 401,
                body: { error: 'Missing or invalid Authorization header' }
            };
            return;
        }

        const token = authHeader.substring(7);

        // Validate JWT
        let decodedToken;
        try {
            decodedToken = await verifyToken(token);
            console.log(`Token validated for user: ${decodedToken.sub}`);
        } catch (error) {
            console.error('JWT validation failed:', error.message);
            monitoring.trackAuthFailure('unknown', 'invalid_token', {
                endpoint: '/v1/social/share-internal',
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
        const validation = validateShareRequest(req.body || {});
        if (!validation.valid) {
            context.res = {
                status: 400,
                body: { error: validation.error }
            };
            return;
        }

        const { toAlias, recipeId, customRecipeId, recipeType, message, tagline } = req.body;

        // Share recipe
        try {
            const result = await shareRecipe(
                userId,
                toAlias,
                recipeId,
                customRecipeId,
                recipeType,
                message,
                tagline
            );

            context.res = {
                status: 201,
                headers: {
                    'Content-Type': 'application/json'
                },
                body: result
            };

            console.log(`Recipe shared successfully: ${result.shareId}`);

            // TODO: Send push notification to recipient

        } catch (error) {
            // Handle specific business logic errors
            if (error.message.includes('not found') ||
                error.message.includes('permission') ||
                error.message.includes('Cannot share') ||
                error.message.includes('already shared')) {
                context.res = {
                    status: 400,
                    body: { error: error.message }
                };
            } else {
                throw error;
            }
        }

    } catch (error) {
        console.error('Internal share error:', error.message);
        console.error(error.stack);

        context.res = {
            status: 500,
            body: { error: 'Internal server error' }
        };
    }
};
