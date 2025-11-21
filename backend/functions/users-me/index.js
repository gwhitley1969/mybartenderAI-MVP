/**
 * User Profile Endpoint - GET/PATCH /v1/users/me
 *
 * Manages user profiles with system-generated aliases for Friends via Code feature
 *
 * GET: Retrieve current user's profile (auto-creates if not exists)
 * PATCH: Update display name
 */

const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const db = require('../shared/database');
const { generateUniqueAlias, validateDisplayName } = require('../shared/aliasGenerator');
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
 * Get or create user profile
 * @param {string} userId - User ID from JWT sub claim
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
 * Main handler
 */
module.exports = async function (context, req) {
    console.log(`User profile ${req.method} request received`);

    try {
        // Extract and verify JWT
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                endpoint: '/v1/users/me'
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
                endpoint: '/v1/users/me',
                error: error.message
            });
            context.res = {
                status: 401,
                body: { error: 'Invalid or expired token' }
            };
            return;
        }

        const userId = decodedToken.sub;

        // Handle GET request - Get or create profile
        if (req.method === 'GET') {
            const profile = await getOrCreateProfile(userId);

            context.res = {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'Cache-Control': 'private, max-age=60' // Cache for 1 minute
                },
                body: formatProfile(profile)
            };

            console.log(`Profile retrieved for user ${userId}: ${profile.alias}`);
        }
        // Handle PATCH request - Update display name
        else if (req.method === 'PATCH') {
            const { displayName } = req.body || {};

            if (displayName !== undefined && displayName !== null && typeof displayName !== 'string') {
                context.res = {
                    status: 400,
                    body: { error: 'displayName must be a string or null' }
                };
                return;
            }

            try {
                const profile = await updateDisplayName(userId, displayName);

                context.res = {
                    status: 200,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: formatProfile(profile)
                };

                console.log(`Display name updated for user ${userId}: ${displayName || '(removed)'}`);

            } catch (error) {
                if (error.message.includes('30 characters')) {
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
        console.error('User profile error:', error.message);
        console.error(error.stack);

        // Check for specific database errors
        if (error.code === '23505') { // Unique constraint violation
            context.res = {
                status: 409,
                body: { error: 'Profile conflict - please try again' }
            };
        } else {
            context.res = {
                status: 500,
                body: { error: 'Internal server error' }
            };
        }
    }
};
