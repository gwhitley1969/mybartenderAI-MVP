/**
 * Voice Minute Purchase Endpoint - POST /v1/voice/purchase
 *
 * Validates Google Play purchase and credits voice minutes to user account.
 * Writes to voice_addon_purchases (legacy) + voice_purchase_transactions (Phase 2)
 * and increments voice_minutes_purchased_balance on users table.
 *
 * Flow:
 * 1. Validate JWT and extract Azure AD sub
 * 2. Look up internal user UUID from users table
 * 3. Check entitlement (must be 'paid')
 * 4. Check for duplicate transaction_id (idempotent)
 * 5. Verify purchase with Google Play API
 * 6. Acknowledge purchase with Google Play
 * 7. Insert into voice_addon_purchases + voice_purchase_transactions
 * 8. Return success with updated quota from get_remaining_voice_minutes()
 */

const { google } = require('googleapis');
const jwt = require('jsonwebtoken');
const jwksClient = require('jwks-rsa');
const db = require('../shared/database');

// Configuration
const TENANT_ID = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';
const ISSUER = `https://mybartenderai.ciamlogin.com/${TENANT_ID}/v2.0`;
const AUDIENCE = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6';

// Google Play configuration
const PACKAGE_NAME = 'ai.mybartender.mybartenderai';
const PRODUCT_ID = 'voice_minutes_20';
const SECONDS_PER_PURCHASE = 1200; // 20 minutes = 1200 seconds ($4.99 for double the value!)
const PRICE_CENTS = 499; // $4.99

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
 * Verify purchase with Google Play API
 * @param {string} purchaseToken - Google Play purchase token
 * @returns {Promise<object>} Verification result
 */
async function verifyWithGooglePlay(purchaseToken) {
    try {
        // Get service account credentials from environment
        const credentialsJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
        if (!credentialsJson) {
            console.error('GOOGLE_PLAY_SERVICE_ACCOUNT_KEY not configured');
            return { valid: false, error: 'Purchase verification not configured' };
        }

        const credentials = JSON.parse(credentialsJson);

        const auth = new google.auth.GoogleAuth({
            credentials,
            scopes: ['https://www.googleapis.com/auth/androidpublisher']
        });

        const androidpublisher = google.androidpublisher({ version: 'v3', auth });

        console.log(`Verifying purchase for product ${PRODUCT_ID}...`);

        const response = await androidpublisher.purchases.products.get({
            packageName: PACKAGE_NAME,
            productId: PRODUCT_ID,
            token: purchaseToken
        });

        const purchase = response.data;
        console.log('Google Play response:', JSON.stringify(purchase, null, 2));

        // purchaseState: 0 = Purchased, 1 = Canceled/Refunded
        if (purchase.purchaseState !== 0) {
            console.log('Purchase was canceled or refunded');
            return { valid: false, error: 'Purchase was canceled or refunded' };
        }

        // acknowledgementState: 0 = Not acknowledged, 1 = Acknowledged
        // We should acknowledge if not already done
        if (purchase.acknowledgementState === 0) {
            console.log('Acknowledging purchase...');
            await androidpublisher.purchases.products.acknowledge({
                packageName: PACKAGE_NAME,
                productId: PRODUCT_ID,
                token: purchaseToken
            });
            console.log('Purchase acknowledged');
        }

        return {
            valid: true,
            orderId: purchase.orderId,
            // purchaseType: 0 = test (sandbox), 1+ = production
            environment: purchase.purchaseType === 0 ? 'sandbox' : 'production'
        };

    } catch (error) {
        console.error('Google Play verification error:', error.message);

        if (error.code === 404) {
            return { valid: false, error: 'Purchase not found' };
        }
        if (error.code === 401 || error.code === 403) {
            return { valid: false, error: 'Google Play authentication failed' };
        }

        throw error;
    }
}

/**
 * Main handler
 */
module.exports = async function (context, req) {
    console.log('Voice purchase request received');

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, Ocp-Apim-Subscription-Key'
    };

    // Handle OPTIONS preflight
    if (req.method === 'OPTIONS') {
        context.res = { status: 200, headers, body: '' };
        return;
    }

    try {
        // Extract and verify JWT
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            context.res = {
                status: 401,
                headers,
                body: { success: false, error: 'Missing or invalid Authorization header' }
            };
            return;
        }

        const token = authHeader.substring(7);

        // Validate JWT
        let decodedToken;
        try {
            decodedToken = await verifyToken(token);
            console.log(`Token validated for Azure AD sub: ${decodedToken.sub.substring(0, 8)}...`);
        } catch (error) {
            console.error('JWT validation failed:', error.message);
            context.res = {
                status: 401,
                headers,
                body: { success: false, error: 'Invalid or expired token' }
            };
            return;
        }

        const azureAdSub = decodedToken.sub;

        // Validate request body
        const { purchaseToken, productId } = req.body || {};

        if (!purchaseToken) {
            context.res = {
                status: 400,
                headers,
                body: { success: false, error: 'Missing purchaseToken' }
            };
            return;
        }

        if (productId !== PRODUCT_ID) {
            context.res = {
                status: 400,
                headers,
                body: { success: false, error: `Invalid productId. Expected: ${PRODUCT_ID}` }
            };
            return;
        }

        // Look up internal user UUID from Azure AD sub (same pattern as voice-session)
        const userResult = await db.query(
            'SELECT id, tier, entitlement FROM users WHERE azure_ad_sub = $1',
            [azureAdSub]
        );

        if (userResult.rows.length === 0) {
            context.res = {
                status: 404,
                headers,
                body: { success: false, error: 'User not found' }
            };
            return;
        }

        const user = userResult.rows[0];
        const internalUserId = user.id; // Internal UUID
        console.log(`User found: internal ID ${internalUserId}, tier: ${user.tier}, entitlement: ${user.entitlement}`);

        // Check user entitlement - only paid users can purchase voice minutes
        if (user.entitlement !== 'paid') {
            context.res = {
                status: 403,
                headers,
                body: {
                    success: false,
                    error: 'entitlement_required',
                    message: 'Voice minute purchases require an active subscription',
                    currentTier: user.tier,
                    entitlement: user.entitlement
                }
            };
            return;
        }

        // Check if purchase already processed (idempotent check)
        // Using transaction_id column in existing voice_addon_purchases table
        const existingPurchase = await db.query(
            'SELECT id FROM voice_addon_purchases WHERE transaction_id = $1',
            [purchaseToken]
        );

        if (existingPurchase.rows.length > 0) {
            console.log('Purchase already processed, returning success (idempotent)');

            // Get current quota to return
            const quotaResult = await db.query(
                'SELECT * FROM get_remaining_voice_minutes($1)',
                [internalUserId]
            );
            const quota = quotaResult.rows[0];

            context.res = {
                status: 200,
                headers,
                body: {
                    success: true,
                    minutesAdded: 0,
                    message: 'Purchase already credited',
                    alreadyProcessed: true,
                    quota: {
                        remainingMinutes: parseFloat(quota.total_remaining),
                        includedRemaining: parseFloat(quota.included_remaining),
                        purchasedRemaining: parseFloat(quota.purchased_remaining)
                    }
                }
            };
            return;
        }

        // Verify with Google Play API
        console.log('Verifying purchase with Google Play...');
        const verification = await verifyWithGooglePlay(purchaseToken);

        if (!verification.valid) {
            console.log('Purchase verification failed:', verification.error);
            context.res = {
                status: 400,
                headers,
                body: { success: false, error: verification.error }
            };
            return;
        }

        console.log('Purchase verified successfully, order:', verification.orderId);

        const minutesCredited = SECONDS_PER_PURCHASE / 60;

        // Insert into EXISTING voice_addon_purchases table (backward compat)
        await db.query(
            `INSERT INTO voice_addon_purchases
                (user_id, seconds_purchased, price_cents, transaction_id, platform, purchased_at)
             VALUES ($1, $2, $3, $4, $5, NOW())`,
            [internalUserId, SECONDS_PER_PURCHASE, PRICE_CENTS, purchaseToken, 'android']
        );

        // Also update purchased balance on users table and record in new transactions table
        await db.query(
            'UPDATE users SET voice_minutes_purchased_balance = voice_minutes_purchased_balance + $2 WHERE id = $1',
            [internalUserId, minutesCredited]
        );
        await db.query(
            'INSERT INTO voice_purchase_transactions (user_id, transaction_id, minutes_credited) VALUES ($1, $2, $3)',
            [internalUserId, purchaseToken, minutesCredited]
        );

        console.log(`Credited ${minutesCredited} minutes to user ${internalUserId}`);

        // Get updated quota using new function
        const quotaResult = await db.query(
            'SELECT * FROM get_remaining_voice_minutes($1)',
            [internalUserId]
        );
        const quota = quotaResult.rows[0];

        // Return success with quota info
        context.res = {
            status: 200,
            headers,
            body: {
                success: true,
                minutesAdded: minutesCredited,
                message: `${minutesCredited} voice minutes added to your account`,
                quota: {
                    remainingMinutes: parseFloat(quota.total_remaining),
                    includedRemaining: parseFloat(quota.included_remaining),
                    purchasedRemaining: parseFloat(quota.purchased_remaining)
                }
            }
        };

        console.log(`Purchase completed. Purchased balance remaining: ${quota.purchased_remaining}`);

    } catch (error) {
        console.error('Voice purchase error:', error.message);
        console.error(error.stack);

        context.res = {
            status: 500,
            headers,
            body: { success: false, error: 'Purchase processing failed' }
        };
    }
};
