"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.__dangerous__resetAuthState = exports.requireRole = exports.authenticateRequest = exports.AuthenticationError = void 0;
const jose_1 = require("jose");
const AUTH_MESSAGES = {
    missing_authorization: 'Authorization header is required.',
    invalid_token: 'Invalid or expired access token.',
    forbidden: 'Insufficient permissions for this resource.',
};
class AuthenticationError extends Error {
    constructor(code, status, message) {
        super(message ?? AUTH_MESSAGES[code]);
        this.code = code;
        this.status = status;
        this.name = 'AuthenticationError';
    }
}
exports.AuthenticationError = AuthenticationError;
const BEARER_PREFIX = /^Bearer\s+/i;
const JWKS_CACHE_TTL_MS = 10 * 60 * 1000;
let resolvedConfig = null;
let cachedJwkStore = null;
let jwksCacheExpiry = 0;
let cachedJwksUrl = '';
const logWarn = (context, message) => {
    if (typeof context.warn === 'function') {
        context.warn(message);
    }
    else if (typeof context.log === 'function') {
        context.log(message);
    }
};
const logError = (context, message) => {
    if (typeof context.error === 'function') {
        context.error(message);
    }
    else {
        logWarn(context, message);
    }
};
const ensureTrailingSlash = (value) => value.endsWith('/') ? value : `${value}/`;
const getAuthConfig = () => {
    if (resolvedConfig) {
        return resolvedConfig;
    }
    const tenantId = process.env.ENTRA_TENANT_ID;
    const audience = process.env.ENTRA_EXPECTED_AUDIENCE;
    const issuerValue = process.env.ENTRA_ISSUER ?? (tenantId ? `https://login.microsoftonline.com/${tenantId}/v2.0` : undefined);
    if (!tenantId || !audience || !issuerValue) {
        throw new Error('ENTRA_TENANT_ID, ENTRA_EXPECTED_AUDIENCE, and ENTRA_ISSUER environment variables must be configured.');
    }
    const issuer = issuerValue.replace(/\/$/, '');
    const jwksUrl = new URL('discovery/v2.0/keys', ensureTrailingSlash(issuer));
    resolvedConfig = {
        issuer,
        audience,
        jwksUrl,
    };
    return resolvedConfig;
};
const fetchJwkStore = async (context, config) => {
    const now = Date.now();
    if (cachedJwkStore &&
        jwksCacheExpiry > now &&
        cachedJwksUrl === config.jwksUrl.toString()) {
        return cachedJwkStore;
    }
    let response;
    try {
        response = await fetch(config.jwksUrl.toString());
    }
    catch (error) {
        logError(context, `[auth] Failed to fetch JWKS: ${error.message}`);
        throw new Error('Failed to fetch JWKS for token validation.');
    }
    if (!response.ok) {
        logError(context, `[auth] JWKS endpoint responded with status ${response.status}`);
        throw new Error('Failed to fetch JWKS for token validation.');
    }
    const jwks = (await response.json());
    const keyStore = (0, jose_1.createLocalJWKSet)(jwks);
    cachedJwkStore = keyStore;
    jwksCacheExpiry = now + JWKS_CACHE_TTL_MS;
    cachedJwksUrl = config.jwksUrl.toString();
    return keyStore;
};
const arrayifyClaim = (claim) => {
    if (!claim) {
        return [];
    }
    if (Array.isArray(claim)) {
        return claim.map(String);
    }
    if (typeof claim === 'string') {
        return [claim];
    }
    return [];
};
const authenticateRequest = async (request, context) => {
    const authorization = request.headers.get('authorization');
    if (!authorization) {
        throw new AuthenticationError('missing_authorization', 401);
    }
    const token = authorization.replace(BEARER_PREFIX, '').trim();
    if (!token) {
        throw new AuthenticationError('invalid_token', 401);
    }
    const config = getAuthConfig();
    const keyStore = await fetchJwkStore(context, config);
    let payload;
    try {
        const verification = await (0, jose_1.jwtVerify)(token, keyStore, {
            issuer: config.issuer,
            audience: config.audience,
        });
        payload = verification.payload;
    }
    catch (error) {
        if (error instanceof AuthenticationError) {
            throw error;
        }
        if (error instanceof jose_1.errors.JWTExpired) {
            logWarn(context, '[auth] Token expired during verification.');
            throw new AuthenticationError('invalid_token', 401, 'Access token has expired.');
        }
        if (error instanceof jose_1.errors.JWTInvalid ||
            error instanceof jose_1.errors.JWTClaimValidationFailed ||
            error instanceof jose_1.errors.JOSEError) {
            logWarn(context, `[auth] Token validation failed: ${error.message}`);
            throw new AuthenticationError('invalid_token', 401);
        }
        throw error;
    }
    const subject = typeof payload.sub === 'string' ? payload.sub : undefined;
    if (!subject) {
        throw new AuthenticationError('invalid_token', 401, 'Token subject claim is missing.');
    }
    const tenantId = typeof payload.tid === 'string' ? payload.tid : undefined;
    const payloadClaims = payload;
    const roles = arrayifyClaim(payloadClaims.roles);
    const appRoles = arrayifyClaim(payloadClaims.app_roles);
    const claims = {};
    if (roles.length) {
        claims.roles = roles;
    }
    if (appRoles.length) {
        claims.appRoles = appRoles;
    }
    if (tenantId) {
        claims.tid = tenantId;
    }
    return {
        sub: subject,
        tid: tenantId,
        claims,
        token,
    };
};
exports.authenticateRequest = authenticateRequest;
const requireRole = (context, user, role) => {
    const claims = user.claims;
    const roles = new Set([
        ...arrayifyClaim(claims.roles),
        ...arrayifyClaim(claims.appRoles),
    ]);
    if (!roles.has(role)) {
        logWarn(context, `[auth] Missing required role "${role}".`);
        throw new AuthenticationError('forbidden', 403);
    }
};
exports.requireRole = requireRole;
const __dangerous__resetAuthState = () => {
    resolvedConfig = null;
    cachedJwkStore = null;
    jwksCacheExpiry = 0;
    cachedJwksUrl = '';
};
exports.__dangerous__resetAuthState = __dangerous__resetAuthState;
