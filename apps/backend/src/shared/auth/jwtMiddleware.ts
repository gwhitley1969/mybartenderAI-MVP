import type { HttpRequest, InvocationContext } from '@azure/functions';

export interface AuthenticatedUser {
  sub: string;
  tid?: string;
  claims: Record<string, unknown>;
  token: string;
}

export class AuthenticationError extends Error {
  constructor(
    message: string,
    readonly code: 'missing_authorization' | 'invalid_token' | 'forbidden' = 'missing_authorization',
    readonly status: 401 | 403 = 401,
  ) {
    super(message);
    this.name = 'AuthenticationError';
  }
}

const BEARER_PREFIX = /^Bearer\s+/i;

export const authenticateRequest = async (
  request: HttpRequest,
  context: InvocationContext,
): Promise<AuthenticatedUser> => {
  const authorization = request.headers.get('authorization');
  if (!authorization) {
    throw new AuthenticationError('Authorization header is required.');
  }

  const token = authorization.replace(BEARER_PREFIX, '').trim();
  if (!token) {
    throw new AuthenticationError(
      'Authorization header must contain a Bearer token.',
      'invalid_token',
    );
  }

  // TODO: Integrate Microsoft Entra External ID JWT validation.
  context.log(
    '[auth] TODO: validate Microsoft Entra External ID JWT and map claims.',
  );

  const fallbackUserId =
    request.headers.get('x-user-id') ??
    request.headers.get('x-ms-client-principal-id') ??
    'anonymous';

  return {
    sub: fallbackUserId,
    tid: request.headers.get('x-tenant-id') ?? undefined,
    claims: {},
    token,
  };
};
