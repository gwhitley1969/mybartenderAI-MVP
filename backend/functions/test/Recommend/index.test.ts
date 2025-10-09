import type { HttpRequest, InvocationContext } from '@azure/functions';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import recommend from '../../src/functions/Recommend/index';

type TestContext = InvocationContext & { res?: unknown };

const createContext = (traceParent = '00-test-trace'): TestContext => {
  const log = vi.fn();

  return {
    invocationId: 'test',
    executionContext: {
      invocationId: 'test',
      functionDirectory: '',
      functionName: 'Recommend',
    },
    traceContext: {
      traceParent,
      tracestate: '',
      attributes: {},
    },
    bindings: {},
    bindingData: {},
    log,
    trace: vi.fn(),
    debug: vi.fn(),
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    done: vi.fn(),
  } as unknown as TestContext;
};

const createRequest = (body: unknown): HttpRequest =>
  ({
    method: 'POST',
    url: 'http://localhost:7071/v1/recommend',
    headers: new Headers(),
    query: {} as URLSearchParams,
    params: {},
    json: vi.fn().mockResolvedValue(body),
    body,
  }) as unknown as HttpRequest;

describe('Recommend function', () => {
  let context: TestContext;

  beforeEach(() => {
    context = createContext();
  });

  it('returns recommendations when inventory is present', async () => {
    const req = createRequest({ inventory: { spirits: ['Rye'], mixers: ['Simple Syrup'] } });

    const response = await recommend(context, req);

    expect(response.status).toBe(200);
    expect(response.headers?.['X-Cache-Hit']).toBe('false');
    expect(Array.isArray(response.jsonBody)).toBe(true);
    expect((response.jsonBody as unknown[]).length).toBeGreaterThan(0);
  });

  it('returns 400 when inventory is missing', async () => {
    const req = createRequest({});

    const response = await recommend(context, req);

    expect(response.status).toBe(400);
    expect(response.headers?.['X-Cache-Hit']).toBe('false');
    const error = response.jsonBody as { message: string };
    expect(error.message).toContain('inventory');
  });
});
