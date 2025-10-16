"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.trackException = exports.trackEvent = exports.redactObject = exports.sanitizeHeaders = exports.getOrCreateTraceId = void 0;
const crypto_1 = require("crypto");
const REDACTION_TOKEN = '[REDACTED]';
const SENSITIVE_PATTERNS = [
    /authorization/i,
    /cookie/i,
    /token/i,
    /email/i,
    /phone/i,
];
const getOrCreateTraceId = (request) => {
    const explicit = request.headers.get('x-trace-id') ??
        request.headers.get('traceparent') ??
        request.headers.get('x-request-id');
    return explicit ?? (0, crypto_1.randomUUID)();
};
exports.getOrCreateTraceId = getOrCreateTraceId;
const sanitizeHeaders = (headers) => {
    const sanitized = {};
    if ('forEach' in headers) {
        headers.forEach((value, key) => {
            if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(key))) {
                sanitized[key] = REDACTION_TOKEN;
            }
            else {
                sanitized[key] = value;
            }
        });
    }
    else {
        for (const [key, value] of headers) {
            if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(key))) {
                sanitized[key] = REDACTION_TOKEN;
            }
            else {
                sanitized[key] = value;
            }
        }
    }
    return sanitized;
};
exports.sanitizeHeaders = sanitizeHeaders;
const redactObject = (payload) => {
    const clone = {};
    for (const [key, value] of Object.entries(payload)) {
        if (SENSITIVE_PATTERNS.some((pattern) => pattern.test(key))) {
            clone[key] = REDACTION_TOKEN;
        }
        else {
            clone[key] = value;
        }
    }
    return clone;
};
exports.redactObject = redactObject;
const trackEvent = (context, traceId, name, properties = {}) => {
    context.log(JSON.stringify({
        traceId,
        event: name,
        properties: (0, exports.redactObject)(properties),
    }));
};
exports.trackEvent = trackEvent;
const trackException = (context, traceId, error, properties = {}) => {
    context.error(JSON.stringify({
        traceId,
        error: {
            name: error.name,
            message: error.message,
        },
        properties: (0, exports.redactObject)(properties),
    }));
};
exports.trackException = trackException;

