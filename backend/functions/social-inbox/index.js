/**
 * Social Inbox Endpoint - GET /v1/social/inbox
 *
 * Retrieves received recipe shares for the authenticated user
 * Supports pagination and filtering
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
 * Get user's inbox
 */
async function getInbox(userId, limit = 50, offset = 0, unreadOnly = false) {
    const limitNum = Math.min(parseInt(limit) || 50, 100); // Max 100
    const offsetNum = parseInt(offset) || 0;

    // Build query
    let query = `
        SELECT
            rs.id,
            rs.recipe_id,
            rs.custom_recipe_id,
            rs.recipe_type,
            rs.message,
            rs.tagline,
            rs.created_at,
            rs.viewed_at,
            up.alias as from_alias,
            up.display_name as from_display_name
        FROM recipe_share rs
        JOIN user_profile up ON rs.from_user_id = up.user_id
        WHERE rs.to_user_id = $1
    `;

    const params = [userId];

    // Add unread filter
    if (unreadOnly) {
        query += ` AND rs.viewed_at IS NULL`;
    }

    // Add ordering and pagination
    query += ` ORDER BY rs.created_at DESC LIMIT $2 OFFSET $3`;
    params.push(limitNum, offsetNum);

    const result = await db.query(query, params);

    // Get total count
    let countQuery = 'SELECT COUNT(*) as total FROM recipe_share WHERE to_user_id = $1';
    if (unreadOnly) {
        countQuery += ' AND viewed_at IS NULL';
    }

    const countResult = await db.query(countQuery, [userId]);
    const total = parseInt(countResult.rows[0].total);

    return {
        shares: result.rows.map(row => ({
            id: row.id.toString(),
            recipeType: row.recipe_type,
            recipeId: row.recipe_id,
            customRecipeId: row.custom_recipe_id,
            message: row.message,
            tagline: row.tagline,
            fromAlias: row.from_alias,
            fromDisplayName: row.from_display_name,
            createdAt: row.created_at,
            viewed: row.viewed_at !== null,
            viewedAt: row.viewed_at
        })),
        pagination: {
            limit: limitNum,
            offset: offsetNum,
            total: total,
            hasMore: offsetNum + limitNum < total
        }
    };
}

/**
 * Mark share as viewed
 */
async function markAsViewed(shareId, userId) {
    const result = await db.query(
        `UPDATE recipe_share
         SET viewed_at = now()
         WHERE id = $1 AND to_user_id = $2 AND viewed_at IS NULL
         RETURNING id`,
        [shareId, userId]
    );

    return result.rows.length > 0;
}

/**
 * Main handler
 */
module.exports = async function (context, req) {
    console.log('Inbox request received');

    try {
        // Extract and verify JWT
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                endpoint: '/v1/social/inbox'
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
                endpoint: '/v1/social/inbox',
                error: error.message
            });
            context.res = {
                status: 401,
                body: { error: 'Invalid or expired token' }
            };
            return;
        }

        const userId = decodedToken.sub;

        // Parse query parameters
        const limit = req.query.limit;
        const offset = req.query.offset;
        const unreadOnly = req.query.unread === 'true';
        const markViewed = req.query.markViewed; // Share ID to mark as viewed

        // If markViewed is specified, mark the share as viewed
        if (markViewed) {
            const marked = await markAsViewed(markViewed, userId);
            if (!marked) {
                context.res = {
                    status: 404,
                    body: { error: 'Share not found or already viewed' }
                };
                return;
            }
        }

        // Get inbox
        const inbox = await getInbox(userId, limit, offset, unreadOnly);

        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'private, no-cache' // Don't cache inbox
            },
            body: inbox
        };

        console.log(`Inbox retrieved for user ${userId}: ${inbox.shares.length} shares`);

    } catch (error) {
        console.error('Inbox error:', error.message);
        console.error(error.stack);

        context.res = {
            status: 500,
            body: { error: 'Internal server error' }
        };
    }
};
