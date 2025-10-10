import { randomUUID } from 'crypto';

import type { HttpRequest, InvocationContext } from '@azure/functions';

const REDACTION_TOKEN = '[REDACTED]';
const SENSITIVE_PATTERNS = [
  /authorization/i,
  /cookie/i,
  /token/i,
  /email/i,
  /phone/i,
];

export const getOrCreateTraceId = (request: HttpRequest): string => {
  const explicit =
    request.headers.get('x-trace-id') ??
    request.headers.get('traceparent') ??
    request.headers.get('x-request-id');
  return explicit ?? randomUUID();
};

type HeaderLike =
  | Iterable<[string, string]>
  | {
      forEach: (callback: (value: string, key: string) => void) => void;
    };

export const sanitizeHeaders = (
  headers: HeaderLike,
): Record<string, string> => {
  const sanitized: Record<string, string> = {};

  if ('forEach' in headers) {
    headers.forEach((value, key) => {
      if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(key))) {
        sanitized[key] = REDACTION_TOKEN;
      } else {
        sanitized[key] = value;
      }
    });
  } else {
    for (const [key, value] of headers) {
      if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(key))) {
        sanitized[key] = REDACTION_TOKEN;
      } else {
        sanitized[key] = value;
      }
    }
  }

  return sanitized;
};

export const redactObject = (
  payload: Record<string, unknown>,
): Record<string, unknown> => {
  const clone: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(payload)) {
    if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(key))) {
      clone[key] = REDACTION_TOKEN;
    } else {
      clone[key] = value;
    }
  }
  return clone;
};

export const trackEvent = (
  context: InvocationContext,
  traceId: string,
  name: string,
  properties: Record<string, unknown> = {},
): void => {
  context.log(
    JSON.stringify({
      traceId,
      event: name,
      properties: redactObject(properties),
    }),
  );
};

export const trackException = (
  context: InvocationContext,
  traceId: string,
  error: Error,
  properties: Record<string, unknown> = {},
): void => {
  context.error(
    JSON.stringify({
      traceId,
      error: {
        name: error.name,
        message: error.message,
      },
      properties: redactObject(properties),
    }),
  );
};
