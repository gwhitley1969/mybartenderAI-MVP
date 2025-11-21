/**
 * Social Outbox Endpoint - GET /v1/social/outbox
 *
 * Retrieves sent recipe shares and active invites for the authenticated user
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
 * Get user's sent shares
 */
async function getSentShares(userId, limit = 50, offset = 0) {
    const limitNum = Math.min(parseInt(limit) || 50, 100); // Max 100
    const offsetNum = parseInt(offset) || 0;

    const query = `
        SELECT
            rs.id,
            rs.recipe_id,
            rs.custom_recipe_id,
            rs.recipe_type,
            rs.message,
            rs.tagline,
            rs.created_at,
            rs.viewed_at,
            up.alias as to_alias,
            up.display_name as to_display_name
        FROM recipe_share rs
        JOIN user_profile up ON rs.to_user_id = up.user_id
        WHERE rs.from_user_id = $1
        ORDER BY rs.created_at DESC
        LIMIT $2 OFFSET $3
    `;

    const result = await db.query(query, [userId, limitNum, offsetNum]);

    // Get total count
    const countResult = await db.query(
        'SELECT COUNT(*) as total FROM recipe_share WHERE from_user_id = $1',
        [userId]
    );
    const total = parseInt(countResult.rows[0].total);

    return {
        shares: result.rows.map(row => ({
            id: row.id.toString(),
            recipeType: row.recipe_type,
            recipeId: row.recipe_id,
            customRecipeId: row.custom_recipe_id,
            message: row.message,
            tagline: row.tagline,
            toAlias: row.to_alias,
            toDisplayName: row.to_display_name,
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
 * Get user's active invites
 */
async function getActiveInvites(userId, limit = 50, offset = 0) {
    const limitNum = Math.min(parseInt(limit) || 50, 100); // Max 100
    const offsetNum = parseInt(offset) || 0;

    const query = `
        SELECT
            token,
            recipe_id,
            custom_recipe_id,
            recipe_type,
            message,
            tagline,
            one_time,
            created_at,
            expires_at,
            status,
            view_count,
            claimed_by,
            claimed_at
        FROM share_invite
        WHERE from_user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
    `;

    const result = await db.query(query, [userId, limitNum, offsetNum]);

    // Get total count
    const countResult = await db.query(
        'SELECT COUNT(*) as total FROM share_invite WHERE from_user_id = $1',
        [userId]
    );
    const total = parseInt(countResult.rows[0].total);

    return {
        invites: result.rows.map(row => ({
            token: row.token,
            shareUrl: `${SHARE_BASE_URL}/${row.token}`,
            recipeType: row.recipe_type,
            recipeId: row.recipe_id,
            customRecipeId: row.custom_recipe_id,
            message: row.message,
            tagline: row.tagline,
            oneTime: row.one_time,
            createdAt: row.created_at,
            expiresAt: row.expires_at,
            status: row.status,
            viewCount: row.view_count,
            claimedBy: row.claimed_by,
            claimedAt: row.claimed_at
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
 * Main handler
 */
module.exports = async function (context, req) {
    console.log('Outbox request received');

    try {
        // Extract and verify JWT
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                endpoint: '/v1/social/outbox'
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
                endpoint: '/v1/social/outbox',
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
        const type = req.query.type || 'all'; // 'shares', 'invites', or 'all'

        // Get outbox data based on type
        let response = {};

        if (type === 'shares' || type === 'all') {
            const shares = await getSentShares(userId, limit, offset);
            response.shares = shares.shares;
            response.sharesPagination = shares.pagination;
        }

        if (type === 'invites' || type === 'all') {
            const invites = await getActiveInvites(userId, limit, offset);
            response.invites = invites.invites;
            response.invitesPagination = invites.pagination;
        }

        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'private, max-age=30' // Cache for 30 seconds
            },
            body: response
        };

        console.log(`Outbox retrieved for user ${userId}`);

    } catch (error) {
        console.error('Outbox error:', error.message);
        console.error(error.stack);

        context.res = {
            status: 500,
            body: { error: 'Internal server error' }
        };
    }
};
