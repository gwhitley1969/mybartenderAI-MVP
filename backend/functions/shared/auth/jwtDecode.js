"use strict";

/**
 * Lightweight JWT payload decoder (NO cryptographic verification).
 * Use only for non-security-critical data extraction (profile sync).
 * Actual token validation is handled by APIM validate-jwt policy.
 *
 * @param {string} authHeader - The Authorization header value ("Bearer eyJ...")
 * @returns {{ sub: string|null, email: string|null, name: string|null } | null}
 */
function decodeJwtClaims(authHeader) {
    try {
        if (!authHeader) return null;

        const token = authHeader.replace(/^Bearer\s+/i, '').trim();
        if (!token) return null;

        const parts = token.split('.');
        if (parts.length !== 3) return null;

        const payload = JSON.parse(
            Buffer.from(parts[1], 'base64url').toString('utf8')
        );

        return {
            sub: payload.sub || null,
            email: payload.email || payload.preferred_username || null,
            name: payload.name || null
        };
    } catch {
        return null;
    }
}

module.exports = { decodeJwtClaims };
