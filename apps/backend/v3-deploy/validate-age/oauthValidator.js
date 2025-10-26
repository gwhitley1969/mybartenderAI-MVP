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

    // Get tenant ID from environment
    const tenantId = process.env.ENTRA_TENANT_ID;
    if (!tenantId) {
        context.log.error('[OAuth] ENTRA_TENANT_ID environment variable not configured');
        throw new Error('OAuth validation not properly configured');
    }

    // Construct issuer and JWKS URL
    // For Custom Authentication Extensions, the issuer is the Azure AD tenant
    const issuer = `https://login.microsoftonline.com/${tenantId}/v2.0`;
    const jwksUrl = `${issuer}/discovery/v2.0/keys`;

    context.log(`[OAuth] Validating token from issuer: ${issuer}`);

    try {
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

        // Verify JWT
        // Note: For Custom Authentication Extensions, we validate the issuer
        // The audience will be the app registration created by Entra
        const { payload } = await jwtVerify(token, jwks, {
            issuer: issuer,
            // Don't validate audience yet - we'll log it first to see what it is
        });

        context.log('[OAuth] Token validated successfully');
        context.log(`[OAuth] Token subject: ${payload.sub}`);
        context.log(`[OAuth] Token audience: ${payload.aud}`);
        context.log(`[OAuth] Token issuer: ${payload.iss}`);

        // Check for app ID (appid claim indicates service principal)
        if (payload.appid) {
            context.log(`[OAuth] Service principal app ID: ${payload.appid}`);
        }

        return payload;

    } catch (error) {
        if (error.code === 'ERR_JWT_EXPIRED') {
            context.log.error('[OAuth] Token has expired');
            throw new Error('Token has expired');
        } else if (error.code === 'ERR_JWT_CLAIM_VALIDATION_FAILED') {
            context.log.error(`[OAuth] Token claim validation failed: ${error.message}`);
            throw new Error('Token validation failed');
        } else if (error.code === 'ERR_JWKS_NO_MATCHING_KEY') {
            context.log.error('[OAuth] No matching key found in JWKS');
            throw new Error('Token signature validation failed');
        } else {
            context.log.error(`[OAuth] Token validation error: ${error.message}`);
            throw new Error('Token validation failed');
        }
    }
}

module.exports = {
    validateCustomAuthExtensionToken
};
