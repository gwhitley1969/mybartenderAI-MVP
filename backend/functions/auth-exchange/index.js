const { DefaultAzureCredential } = require('@azure/identity');
const { ApiManagementClient } = require('@azure/arm-apimanagement');
const { TableClient } = require('@azure/data-tables');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const monitoring = require('../shared/monitoring');
const { ENTITLEMENT_QUOTAS, getEntitlementQuotas } = require('../services/userService');

// Configuration from environment variables
const APIM_SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID;
const APIM_RESOURCE_GROUP = 'rg-mba-prod';
const APIM_SERVICE_NAME = 'apim-mba-001';
const TENANT_ID = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';
const ISSUER = `https://mybartenderai.ciamlogin.com/${TENANT_ID}/v2.0`;
const AUDIENCE = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6'; // Your app registration client ID

// Rate limiting configuration
const RATE_LIMIT_TABLE = process.env.RATE_LIMIT_TABLE_NAME || 'authexchangeratelimit';
const RATE_LIMIT_WINDOW = 60 * 1000; // 1 minute window
const RATE_LIMIT_MAX_REQUESTS = 10; // Max 10 requests per minute per user

// JWKS client for token validation
const jwks = jwksClient({
    jwksUri: `${ISSUER}/discovery/v2.0/keys`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5
});

// Helper to mask sensitive data for logging
function maskKey(key) {
    if (!key || key.length < 8) return '****';
    return `****${key.slice(-4)}`;
}

// Rate limiting helper using Azure Table Storage
async function checkRateLimit(userId) {
    try {
        const credential = new DefaultAzureCredential();
        const tableClient = new TableClient(
            `https://${process.env.STORAGE_ACCOUNT_NAME || 'mbacocktaildb3'}.table.core.windows.net`,
            RATE_LIMIT_TABLE,
            credential
        );

        // Ensure table exists
        await tableClient.createTable().catch(() => {}); // Ignore if already exists

        const partitionKey = 'auth-exchange';
        const rowKey = userId;
        const now = Date.now();

        try {
            // Get existing rate limit record
            const entity = await tableClient.getEntity(partitionKey, rowKey);

            // Parse request timestamps
            const requests = JSON.parse(entity.requests || '[]');

            // Filter out requests outside the time window
            const recentRequests = requests.filter(timestamp =>
                now - timestamp < RATE_LIMIT_WINDOW
            );

            // Check if limit exceeded
            if (recentRequests.length >= RATE_LIMIT_MAX_REQUESTS) {
                const oldestRequest = Math.min(...recentRequests);
                const resetTime = new Date(oldestRequest + RATE_LIMIT_WINDOW);
                return {
                    allowed: false,
                    resetTime: resetTime,
                    remaining: 0
                };
            }

            // Add current request
            recentRequests.push(now);

            // Update entity
            await tableClient.updateEntity({
                partitionKey: partitionKey,
                rowKey: rowKey,
                requests: JSON.stringify(recentRequests),
                lastRequest: now
            }, 'Merge');

            return {
                allowed: true,
                remaining: RATE_LIMIT_MAX_REQUESTS - recentRequests.length
            };

        } catch (error) {
            if (error.statusCode === 404) {
                // First request from this user
                await tableClient.createEntity({
                    partitionKey: partitionKey,
                    rowKey: rowKey,
                    requests: JSON.stringify([now]),
                    lastRequest: now
                });

                return {
                    allowed: true,
                    remaining: RATE_LIMIT_MAX_REQUESTS - 1
                };
            }
            throw error;
        }
    } catch (error) {
        console.error('Rate limit check failed:', error.message);
        // Fail open - allow request if rate limiting fails
        return { allowed: true, remaining: RATE_LIMIT_MAX_REQUESTS };
    }
}

// Helper to determine user tier from JWT claims
function getUserTier(decodedToken) {
    // Check for tier claim from your user profile
    // This could come from app_metadata, custom claims, or database lookup
    const tier = decodedToken.tier || decodedToken.subscription_tier || 'free';

    // Validate tier is one of the allowed values
    const validTiers = ['free', 'premium', 'pro'];
    if (!validTiers.includes(tier.toLowerCase())) {
        return 'free';
    }

    return tier.toLowerCase();
}

// Helper to get APIM product ID based on tier
function getProductId(tier) {
    const productMap = {
        'free': 'free-tier',
        'premium': 'premium-tier',
        'pro': 'pro-tier'
    };
    return productMap[tier] || 'free-tier';
}

// Get verification key from JWKS
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

// Verify JWT token
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
                // Additional validation
                if (!decoded.sub) {
                    reject(new Error('Token missing subject claim'));
                    return;
                }

                // Check age verification claim if required
                if (!decoded.age_verified && decoded.age_verified !== true) {
                    reject(new Error('Age verification required'));
                    return;
                }

                resolve(decoded);
            }
        });
    });
}

// Create or get APIM subscription for user
async function ensureApimSubscription(userId, tier) {
    try {
        const credential = new DefaultAzureCredential();
        const client = new ApiManagementClient(credential, APIM_SUBSCRIPTION_ID);

        const productId = getProductId(tier);
        const subscriptionName = `user-${userId}-${tier}`;

        // Try to get existing subscription
        try {
            const existing = await client.subscription.get(
                APIM_RESOURCE_GROUP,
                APIM_SERVICE_NAME,
                subscriptionName
            );

            if (existing) {
                console.log(`Found existing subscription: ${subscriptionName} (key: ${maskKey(existing.primaryKey)})`);
                return {
                    subscriptionId: existing.name,
                    primaryKey: existing.primaryKey,
                    secondaryKey: existing.secondaryKey,
                    state: existing.state,
                    productId: productId,
                    tier: tier
                };
            }
        } catch (err) {
            // Subscription doesn't exist, create it
            if (err.statusCode === 404) {
                console.log(`Creating new subscription: ${subscriptionName} for product: ${productId}`);

                const newSubscription = await client.subscription.createOrUpdate(
                    APIM_RESOURCE_GROUP,
                    APIM_SERVICE_NAME,
                    subscriptionName,
                    {
                        displayName: `User ${userId} - ${tier} tier`,
                        scope: `/products/${productId}`,
                        state: 'active'
                    }
                );

                console.log(`Created subscription: ${subscriptionName} (key: ${maskKey(newSubscription.primaryKey)})`);

                return {
                    subscriptionId: newSubscription.name,
                    primaryKey: newSubscription.primaryKey,
                    secondaryKey: newSubscription.secondaryKey,
                    state: newSubscription.state,
                    productId: productId,
                    tier: tier
                };
            }
            throw err;
        }
    } catch (error) {
        console.error('Error managing APIM subscription:', error.message);
        throw error;
    }
}

module.exports = async function (context, req) {
    console.log('Auth exchange request received');

    try {
        // Extract JWT from Authorization header
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            monitoring.trackAuthFailure('unknown', 'missing_auth_header', {
                endpoint: '/v1/auth/exchange'
            });
            context.res = {
                status: 401,
                body: { error: 'Missing or invalid Authorization header' }
            };
            return;
        }

        const token = authHeader.substring(7);
        console.log('Validating JWT token...');

        // Validate JWT
        let decodedToken;
        try {
            decodedToken = await verifyToken(token);
            console.log(`Token validated for user: ${decodedToken.sub}`);
        } catch (error) {
            console.error('JWT validation failed:', error.message);
            monitoring.trackJwtValidationFailure(error.message, {
                endpoint: '/v1/auth/exchange'
            });
            monitoring.checkFailureRate(); // Check if we're under attack
            context.res = {
                status: 401,
                body: { error: 'Invalid or expired token' }
            };
            return;
        }

        // Extract user ID and determine tier
        const userId = decodedToken.sub;

        // Check rate limit
        const rateLimitResult = await checkRateLimit(userId);
        if (!rateLimitResult.allowed) {
            console.log(`Rate limit exceeded for user ${userId}`);
            monitoring.trackRateLimitExceeded(userId, '/v1/auth/exchange', {
                resetTime: rateLimitResult.resetTime.toISOString()
            });
            monitoring.trackSuspiciousActivity(userId, 'excessive_token_exchange', {
                resetTime: rateLimitResult.resetTime.toISOString()
            });
            context.res = {
                status: 429,
                headers: {
                    'Retry-After': Math.ceil((rateLimitResult.resetTime - Date.now()) / 1000),
                    'X-RateLimit-Limit': RATE_LIMIT_MAX_REQUESTS,
                    'X-RateLimit-Remaining': 0,
                    'X-RateLimit-Reset': rateLimitResult.resetTime.toISOString()
                },
                body: {
                    error: 'Rate limit exceeded',
                    message: 'Too many token exchange requests. Please try again later.',
                    retryAfter: rateLimitResult.resetTime.toISOString()
                }
            };
            return;
        }

        const tier = getUserTier(decodedToken);
        console.log(`User ${userId} mapped to tier: ${tier}, rate limit remaining: ${rateLimitResult.remaining}`);

        // Ensure APIM subscription exists
        const subscription = await ensureApimSubscription(userId, tier);

        // Calculate token expiry (align with JWT expiry or set to 24 hours)
        const now = Math.floor(Date.now() / 1000);
        const jwtExpiry = decodedToken.exp || (now + 86400); // Default 24 hours
        const expiresIn = jwtExpiry - now;

        // Track successful authentication
        monitoring.trackAuthSuccess(userId, tier, {
            subscriptionId: subscription.subscriptionId,
            productId: subscription.productId,
            endpoint: '/v1/auth/exchange'
        });

        // Determine entitlement from tier (paid for pro/premium, none for free)
        const entitlement = (tier === 'pro' || tier === 'premium') ? 'paid' : 'none';

        // Return subscription key and metadata (no PII)
        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-store' // Never cache auth tokens
            },
            body: {
                subscriptionKey: subscription.primaryKey,
                tier: subscription.tier,          // kept for backward compat
                entitlement: entitlement,          // Phase 3 will use this
                productId: subscription.productId,
                expiresIn: expiresIn,
                expiresAt: new Date(jwtExpiry * 1000).toISOString(),
                quotas: getEntitlementQuotas(entitlement)
            }
        };

        console.log(`Exchange successful for user ${userId}, tier: ${tier}, entitlement: ${entitlement}, key: ${maskKey(subscription.primaryKey)}`);

    } catch (error) {
        console.error('Auth exchange error:', error.message);

        // Don't leak internal errors
        context.res = {
            status: 500,
            body: { error: 'Authentication service temporarily unavailable' }
        };
    }
};

// Legacy helper — kept for reference, no longer called.
// Quota lookup now uses getEntitlementQuotas() from userService.js
function getQuotasForTier(tier) {
    const entitlement = (tier === 'pro' || tier === 'premium') ? 'paid' : 'none';
    return getEntitlementQuotas(entitlement);
}