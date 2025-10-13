import type { HttpRequest, InvocationContext } from '@azure/functions';
import {
  createLocalJWKSet,
  errors as joseErrors,
  jwtVerify,
  type JWK,
  type KeyLike,
} from 'jose';

type JoseJwkSet = {
  keys: JWK[];
};

export interface AuthenticatedUser {
  sub: string;
  tid?: string;
  claims: Record<string, unknown>;
  token: string;
}

type AuthErrorCode = 'missing_authorization' | 'invalid_token' | 'forbidden';

const AUTH_MESSAGES: Record<AuthErrorCode, string> = {
  missing_authorization: 'Authorization header is required.',
  invalid_token: 'Invalid or expired access token.',
  forbidden: 'Insufficient permissions for this resource.',
};

export class AuthenticationError extends Error {
  constructor(
    readonly code: AuthErrorCode,
    readonly status: 401 | 403,
    message?: string,
  ) {
    super(message ?? AUTH_MESSAGES[code]);
    this.name = 'AuthenticationError';
  }
}

interface AuthConfig {
  issuer: string;
  audience: string;
  jwksUrl: URL;
}

type JwkStore = (protectedHeader: { kid?: string | undefined }) => Promise<KeyLike>;

const BEARER_PREFIX = /^Bearer\s+/i;
const JWKS_CACHE_TTL_MS = 10 * 60 * 1000;

let resolvedConfig: AuthConfig | null = null;
let cachedJwkStore: JwkStore | null = null;
let jwksCacheExpiry = 0;
let cachedJwksUrl = '';

const logWarn = (context: InvocationContext, message: string): void => {
  if (typeof context.warn === 'function') {
    context.warn(message);
  } else if (typeof context.log === 'function') {
    context.log(message);
  }
};

const logError = (context: InvocationContext, message: string): void => {
  if (typeof context.error === 'function') {
    context.error(message);
  } else {
    logWarn(context, message);
  }
};

const ensureTrailingSlash = (value: string): string =>
  value.endsWith('/') ? value : `${value}/`;

const getAuthConfig = (): AuthConfig => {
  if (resolvedConfig) {
    return resolvedConfig;
  }

  const tenantId = process.env.ENTRA_TENANT_ID;
  const audience = process.env.ENTRA_EXPECTED_AUDIENCE;
  const issuerValue =
    process.env.ENTRA_ISSUER ?? (tenantId ? `https://login.microsoftonline.com/${tenantId}/v2.0` : undefined);

  if (!tenantId || !audience || !issuerValue) {
    throw new Error(
      'ENTRA_TENANT_ID, ENTRA_EXPECTED_AUDIENCE, and ENTRA_ISSUER environment variables must be configured.',
    );
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

const fetchJwkStore = async (
  context: InvocationContext,
  config: AuthConfig,
): Promise<JwkStore> => {
  const now = Date.now();
  if (
    cachedJwkStore &&
    jwksCacheExpiry > now &&
    cachedJwksUrl === config.jwksUrl.toString()
  ) {
    return cachedJwkStore;
  }

  let response: Response;
  try {
    response = await fetch(config.jwksUrl.toString());
  } catch (error) {
    logError(
      context,
      `[auth] Failed to fetch JWKS: ${(error as Error).message}`,
    );
    throw new Error('Failed to fetch JWKS for token validation.');
  }

  if (!response.ok) {
    logError(
      context,
      `[auth] JWKS endpoint responded with status ${response.status}`,
    );
    throw new Error('Failed to fetch JWKS for token validation.');
  }

  const jwks = (await response.json()) as JoseJwkSet;
  const keyStore = createLocalJWKSet(jwks as any);

  cachedJwkStore = keyStore;
  jwksCacheExpiry = now + JWKS_CACHE_TTL_MS;
  cachedJwksUrl = config.jwksUrl.toString();

  return keyStore;
};

const arrayifyClaim = (claim: unknown): string[] => {
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

export const authenticateRequest = async (
  request: HttpRequest,
  context: InvocationContext,
): Promise<AuthenticatedUser> => {
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
    const verification = await jwtVerify(token, keyStore, {
      issuer: config.issuer,
      audience: config.audience,
    });
    payload = verification.payload;
  } catch (error) {
    if (error instanceof AuthenticationError) {
      throw error;
    }

    if (error instanceof joseErrors.JWTExpired) {
      logWarn(context, '[auth] Token expired during verification.');
      throw new AuthenticationError('invalid_token', 401, 'Access token has expired.');
    }

    if (
      error instanceof joseErrors.JWTInvalid ||
      error instanceof joseErrors.JWTClaimValidationFailed ||
      error instanceof joseErrors.JOSEError
    ) {
      logWarn(context, `[auth] Token validation failed: ${(error as Error).message}`);
      throw new AuthenticationError('invalid_token', 401);
    }

    throw error;
  }

  const subject = typeof payload.sub === 'string' ? payload.sub : undefined;
  if (!subject) {
    throw new AuthenticationError('invalid_token', 401, 'Token subject claim is missing.');
  }

  const tenantId = typeof payload.tid === 'string' ? payload.tid : undefined;
  const payloadClaims = payload as Record<string, unknown>;
  const roles = arrayifyClaim(payloadClaims.roles);
  const appRoles = arrayifyClaim(payloadClaims.app_roles);

  const claims: Record<string, unknown> = {};
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

export const requireRole = (
  context: InvocationContext,
  user: AuthenticatedUser,
  role: string,
): void => {
  const claims = user.claims as Record<string, unknown>;
  const roles = new Set<string>([
    ...arrayifyClaim(claims.roles),
    ...arrayifyClaim(claims.appRoles),
  ]);

  if (!roles.has(role)) {
    logWarn(context, `[auth] Missing required role "${role}".`);
    throw new AuthenticationError('forbidden', 403);
  }
};

export const __dangerous__resetAuthState = (): void => {
  resolvedConfig = null;
  cachedJwkStore = null;
  jwksCacheExpiry = 0;
  cachedJwksUrl = '';
};
