const { DefaultAzureCredential } = require('@azure/identity');
const { ApiManagementClient } = require('@azure/arm-apimanagement');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');

// Configuration from environment variables
const APIM_SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID;
const APIM_RESOURCE_GROUP = 'rg-mba-prod';
const APIM_SERVICE_NAME = 'apim-mba-001';
const TENANT_ID = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';
const ISSUER = `https://mybartenderai.ciamlogin.com/${TENANT_ID}/v2.0`;
const AUDIENCE = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6'; // Your app registration client ID

// JWKS client for token validation
const jwks = jwksClient({
    jwksUri: `${ISSUER}/.well-known/openid-configuration`,
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5
});

// Helper to mask sensitive data for logging
function maskKey(key) {
    if (!key || key.length < 8) return '****';
    return `****${key.slice(-4)}`;
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
            context.res = {
                status: 401,
                body: { error: 'Invalid or expired token' }
            };
            return;
        }

        // Extract user ID and determine tier
        const userId = decodedToken.sub;
        const tier = getUserTier(decodedToken);
        console.log(`User ${userId} mapped to tier: ${tier}`);

        // Ensure APIM subscription exists
        const subscription = await ensureApimSubscription(userId, tier);

        // Calculate token expiry (align with JWT expiry or set to 24 hours)
        const now = Math.floor(Date.now() / 1000);
        const jwtExpiry = decodedToken.exp || (now + 86400); // Default 24 hours
        const expiresIn = jwtExpiry - now;

        // Return subscription key and metadata (no PII)
        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Cache-Control': 'no-store' // Never cache auth tokens
            },
            body: {
                subscriptionKey: subscription.primaryKey,
                tier: subscription.tier,
                productId: subscription.productId,
                expiresIn: expiresIn,
                expiresAt: new Date(jwtExpiry * 1000).toISOString(),
                quotas: getQuotasForTier(tier)
            }
        };

        console.log(`Exchange successful for user ${userId}, tier: ${tier}, key: ${maskKey(subscription.primaryKey)}`);

    } catch (error) {
        console.error('Auth exchange error:', error.message);

        // Don't leak internal errors
        context.res = {
            status: 500,
            body: { error: 'Authentication service temporarily unavailable' }
        };
    }
};

// Helper to get quota information for tier
function getQuotasForTier(tier) {
    const quotas = {
        'free': {
            tokensPerMonth: 10000,
            scansPerMonth: 2,
            aiEnabled: true  // Now enabled with limited quota
        },
        'premium': {
            tokensPerMonth: 300000,
            scansPerMonth: 30,
            aiEnabled: true
        },
        'pro': {
            tokensPerMonth: 1000000,
            scansPerMonth: 100,
            aiEnabled: true
        }
    };

    return quotas[tier] || quotas.free;
}