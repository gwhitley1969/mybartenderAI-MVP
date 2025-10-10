import type { HttpRequest, InvocationContext } from '@azure/functions';
import { generateKeyPair, exportJWK, SignJWT } from 'jose';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import {
  AuthenticationError,
  authenticateRequest,
  __dangerous__resetAuthState,
} from '../src/shared/auth/jwtMiddleware.js';

const TENANT_ID = '00000000-0000-0000-0000-000000000000';
const ISSUER = `https://login.microsoftonline.com/${TENANT_ID}/v2.0`;
const AUDIENCE = 'api://mybartenderai';

const createContext = (): InvocationContext =>
  ({
    log: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
  }) as unknown as InvocationContext;

const createRequest = (token: string): HttpRequest =>
  ({
    headers: new Headers({
      authorization: `Bearer ${token}`,
    }),
  }) as unknown as HttpRequest;

const createExpiredToken = async (
  privateKey: CryptoKey,
  kid: string,
): Promise<string> => {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT({
    aud: AUDIENCE,
    iss: ISSUER,
    sub: 'user-expired',
    tid: TENANT_ID,
  })
    .setProtectedHeader({ alg: 'RS256', kid })
    .setIssuedAt(now - 120)
    .setExpirationTime(now - 60)
    .sign(privateKey);
};

const createValidToken = async (
  privateKey: CryptoKey,
  kid: string,
  overrides: Record<string, unknown> = {},
): Promise<string> => {
  const builder = new SignJWT({
    aud: AUDIENCE,
    iss: ISSUER,
    sub: 'user-valid',
    tid: TENANT_ID,
    roles: ['reader'],
    app_roles: ['admin'],
    ...overrides,
  })
    .setProtectedHeader({ alg: 'RS256', kid })
    .setIssuedAt()
    .setExpirationTime('5m');

  return builder.sign(privateKey);
};

describe('authenticateRequest', () => {
  let privateKey: CryptoKey;
  let publicJwk: Record<string, unknown>;
  const fetchMock = vi.fn();

  beforeEach(async () => {
    const keyPair = await generateKeyPair('RS256');
    privateKey = keyPair.privateKey;
    publicJwk = await exportJWK(keyPair.publicKey);
    publicJwk.kid = 'test-key';

    fetchMock.mockResolvedValue(
      new Response(
        JSON.stringify({
          keys: [publicJwk],
        }),
        {
          status: 200,
          headers: {
            'content-type': 'application/json',
          },
        },
      ),
    );

    vi.stubGlobal('fetch', fetchMock);

    process.env.ENTRA_TENANT_ID = TENANT_ID;
    process.env.ENTRA_EXPECTED_AUDIENCE = AUDIENCE;
    process.env.ENTRA_ISSUER = ISSUER;

    __dangerous__resetAuthState();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    __dangerous__resetAuthState();
  });

  it('authenticates a valid token and extracts claims', async () => {
    const token = await createValidToken(privateKey, 'test-key');
    const user = await authenticateRequest(
      createRequest(token),
      createContext(),
    );

    expect(user.sub).toBe('user-valid');
    expect(user.tid).toBe(TENANT_ID);
    expect(user.claims.roles).toEqual(['reader']);
    expect(user.claims.appRoles).toEqual(['admin']);
  });

  it('rejects an expired token', async () => {
    const token = await createExpiredToken(privateKey, 'test-key');

    await expect(
      authenticateRequest(createRequest(token), createContext()),
    ).rejects.toMatchObject<Partial<AuthenticationError>>({
      code: 'invalid_token',
      status: 401,
    });
  });

  it('rejects a token with the wrong audience', async () => {
    const token = await createValidToken(privateKey, 'test-key', {
      aud: 'api://other-audience',
    });

    await expect(
      authenticateRequest(createRequest(token), createContext()),
    ).rejects.toMatchObject<Partial<AuthenticationError>>({
      code: 'invalid_token',
      status: 401,
    });
  });
});
