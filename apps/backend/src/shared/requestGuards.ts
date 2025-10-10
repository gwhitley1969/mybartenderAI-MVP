import type { HttpRequest, InvocationContext } from '@azure/functions';

const JSON_MAX_BYTES = parseInt(process.env.MAX_JSON_BYTES ?? '524288', 10); // 512 KB default
const ALLOWED_CONTENT_TYPES = ['application/json'];

export class RequestGuardError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: string,
  ) {
    super(message);
    this.name = 'RequestGuardError';
  }
}

export const enforceRequestGuards = (
  request: HttpRequest,
  context: InvocationContext,
): void => {
  ensureAllowedContentType(request);
  ensureBodyWithinLimit(request, context);
};

const ensureAllowedContentType = (request: HttpRequest): void => {
  const contentType = request.headers.get('content-type') ?? '';
  if (!ALLOWED_CONTENT_TYPES.some((allowed) => contentType.startsWith(allowed))) {
    throw new RequestGuardError(
      `Unsupported content-type: ${contentType || 'none'}`,
      415,
      'unsupported_media_type',
    );
  }
};

const ensureBodyWithinLimit = (
  request: HttpRequest,
  context: InvocationContext,
): void => {
  const headerValue = request.headers.get('content-length');
  if (!headerValue) {
    // Functions runtime may not supply content-length for chunked requests.
    context.log('[requestGuards] Missing content-length header; skipping size check.');
    return;
  }

  const contentLength = parseInt(headerValue, 10);
  if (Number.isNaN(contentLength)) {
    throw new RequestGuardError(
      'content-length header must be numeric.',
      400,
      'invalid_content_length',
    );
  }

  if (contentLength > JSON_MAX_BYTES) {
    throw new RequestGuardError(
      `Payload exceeds ${JSON_MAX_BYTES} bytes limit.`,
      413,
      'payload_too_large',
    );
  }
};

export const getClientIp = (request: HttpRequest): string | undefined => {
  const headerNames = [
    'x-forwarded-for',
    'x-client-ip',
    'x-azure-clientip',
    'x-originating-ip',
  ];

  for (const name of headerNames) {
    const value = request.headers.get(name);
    if (value) {
      return value.split(',')[0]?.trim();
    }
  }

  return undefined;
};
