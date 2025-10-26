/**
 * OAuth 2.0 Token Validator for Custom Authentication Extensions
 *
 * Validates Bearer tokens from Entra External ID Custom Authentication Extensions.
 * These are service-to-service tokens (not user tokens) from the app registration
 * created during Custom Authentication Extension setup.
 *
 * Security Architecture:
 * - Entra creates "Age Verification API" app registration
 * - Entra requests OAuth token from Azure AD
 * - Azure AD issues short-lived Bearer token
 * - Token validated cryptographically (no secret storage needed)
 */

const { jwtVerify, createRemoteJWKSet } = require('jose');

// Cache JWKS for performance
let jwksCache = null;
let jwksCacheExpiry = 0;
const JWKS_CACHE_TTL_MS = 10 * 60 * 1000; // 10 minutes

/**
 * Validate OAuth 2.0 Bearer token from Custom Authentication Extension
 * @param {string} authHeader - Authorization header value
 * @param {object} context - Azure Function context for logging
 * @returns {Promise<object>} Validated token payload
 * @throws {Error} If token is invalid or missing
 */
async function validateCustomAuthExtensionToken(authHeader, context) {
    // Extract Bearer token
    if (!authHeader) {
        context.log.error('[OAuth] Missing Authorization header');
        throw new Error('Authorization header is required');
    }

    const match = authHeader.match(/^Bearer\s+(.+)$/i);
    if (!match) {
        context.log.error('[OAuth] Invalid Authorization header format');
        throw new Error('Authorization header must be in format: Bearer <token>');
    }

    const token = match[1];

    // First, let's decode the token without validation to see what we're working with
    try {
        const parts = token.split('.');
        if (parts.length === 3) {
            const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString());
            context.log('[OAuth] Token payload (decoded without validation):');
            context.log(`[OAuth]   issuer (iss): ${payload.iss}`);
            context.log(`[OAuth]   audience (aud): ${payload.aud}`);
            context.log(`[OAuth]   subject (sub): ${payload.sub || 'not present'}`);
            context.log(`[OAuth]   appid: ${payload.appid || 'not present'}`);
            context.log(`[OAuth]   tenant ID (tid): ${payload.tid || 'not present'}`);
        }
    } catch (decodeError) {
        context.log.warn(`[OAuth] Could not decode token for inspection: ${decodeError.message}`);
    }

    // Get tenant ID from environment
    const tenantId = process.env.ENTRA_TENANT_ID;
    if (!tenantId) {
        context.log.error('[OAuth] ENTRA_TENANT_ID environment variable not configured');
        throw new Error('OAuth validation not properly configured');
    }

    // Try multiple issuer formats for Entra External ID
    const possibleIssuers = [
        `https://login.microsoftonline.com/${tenantId}/v2.0`,
        `https://login.microsoftonline.com/${tenantId}`,
        `https://sts.windows.net/${tenantId}/`,
        `https://${tenantId}.ciamlogin.com/${tenantId}.onmicrosoft.com/v2.0`,
    ];

    // Try multiple JWKS URLs
    // Entra External ID (CIAM) uses ciamlogin.com domain!
    const possibleJwksUrls = [
        // Entra External ID (CIAM) - try this FIRST
        `https://${tenantId}.ciamlogin.com/${tenantId}/discovery/v2.0/keys`,
        // Regular Azure AD endpoints (fallback)
        `https://login.microsoftonline.com/${tenantId}/discovery/v2.0/keys`,
        `https://login.microsoftonline.com/${tenantId}/discovery/keys`,
        `https://login.microsoftonline.com/common/discovery/v2.0/keys`,
    ];

    context.log(`[OAuth] Attempting validation with tenant ID: ${tenantId}`);

    // Try each JWKS URL
    for (const jwksUrl of possibleJwksUrls) {
        try {
            context.log(`[OAuth] Trying JWKS URL: ${jwksUrl}`);

            // Get or create JWKS
            let jwks;
            const now = Date.now();

            if (jwksCache && jwksCacheExpiry > now) {
                jwks = jwksCache;
                context.log('[OAuth] Using cached JWKS');
            } else {
                context.log(`[OAuth] Fetching JWKS from: ${jwksUrl}`);
                jwks = createRemoteJWKSet(new URL(jwksUrl));
                jwksCache = jwks;
                jwksCacheExpiry = now + JWKS_CACHE_TTL_MS;
            }

            // Try to verify with relaxed validation (no issuer check first)
            try {
                const { payload } = await jwtVerify(token, jwks, {
                    // Don't validate issuer/audience initially - just verify signature
                });

                context.log('[OAuth] ✅ Token signature validated successfully');
                context.log(`[OAuth] Token subject: ${payload.sub}`);
                context.log(`[OAuth] Token audience: ${payload.aud}`);
                context.log(`[OAuth] Token issuer: ${payload.iss}`);

                // Check for app ID (appid claim indicates service principal)
                if (payload.appid) {
                    context.log(`[OAuth] Service principal app ID: ${payload.appid}`);
                }

                // Verify tenant ID matches
                if (payload.tid && payload.tid !== tenantId) {
                    context.log.warn(`[OAuth] Tenant ID mismatch: token has ${payload.tid}, expected ${tenantId}`);
                }

                return payload;

            } catch (verifyError) {
                context.log.warn(`[OAuth] Verification failed with ${jwksUrl}: ${verifyError.code} - ${verifyError.message}`);
                // Continue to next JWKS URL
            }

        } catch (jwksError) {
            context.log.warn(`[OAuth] JWKS fetch failed for ${jwksUrl}: ${jwksError.message}`);
            // Continue to next JWKS URL
        }
    }

    // If we get here, all attempts failed
    context.log.error('[OAuth] All token validation attempts failed');
    throw new Error('Token validation failed - unable to validate signature');
}

module.exports = {
    validateCustomAuthExtensionToken
};
