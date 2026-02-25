# Independent Code Review — MyBartenderAI MVP

**Date**: February 24, 2026
**Scope**: Full codebase (`backend/functions/`, `mobile/app/`, infrastructure & config)
**Reviewer**: Claude Code (AI-assisted review)
**Context**: Performed after a third-party review (`docs/codebase_review.md`) to provide deeper coverage, particularly on security

---

## Summary

| Severity | Count | Key Theme |
|----------|-------|-----------|
| **CRITICAL** | 2 | Committed secrets, webhook validation |
| **HIGH** | 3 | CORS, input validation, auth inconsistency |
| **MEDIUM** | 5 | Monolith, Flutter architecture, error exposure, race conditions, rate limiting |
| **LOW** | 3 | Config patterns, outdated deps, cosmetic |

---

## CRITICAL — Fix Before Public Launch

### 1. Database Password & Storage Keys Committed to Git

**Impact**: Complete database and storage compromise if repo is shared or leaked.

Real credentials exist in tracked files:

| File | What's Exposed |
|------|---------------|
| `backend/functions/local.settings.json` (line 6) | PostgreSQL connection string with password (`Advocate2!`) |
| `current-settings.json` (line 140) | PostgreSQL connection string with password |
| `current-settings.json` (lines 20, 24, 60, 104) | Full storage account keys for `mbacocktaildb3` (primary key) |
| `current-settings.json` (line 20) | Full storage account keys for `cocktaildbfun` (legacy, primary key) |
| `current-settings.json` (line 160) | Temporary OpenAI API key (`a5ffbf42d3be4a3896d8b6a99a0b9564`) |
| `rebuild-snapshot.js` (line 13) | PostgreSQL connection string hardcoded in script |
| `.claude/settings.local.json` (line 39) | psql command with password in tool permissions |

**Git tracking status**: `local.settings.json` and `current-settings.json` are listed in `.gitignore` and are **not currently tracked** by git (verified via `git ls-files`). However, `rebuild-snapshot.js` **is tracked** (not in `.gitignore`), and `.claude/settings.local.json` **is tracked** despite being in `.gitignore`. All credentials remain in **git history** regardless of current tracking status and would be exposed if the repository is shared or cloned.

**Remediation**:
1. Rotate the PostgreSQL password for `pgadmin` in Azure
2. Regenerate both primary and secondary keys for storage account `mbacocktaildb3`
3. Verify and revoke temp OpenAI key `a5ffbf42d3be4a3896d8b6a99a0b9564`
4. Check if `cocktaildbfun` storage account is still active; rotate or delete
5. Remove files from git tracking: `git rm --cached current-settings.json rebuild-snapshot.js`
6. Scrub git history with `git filter-repo` or BFG Repo-Cleaner
7. Add pre-commit hooks to prevent future secret commits

---

### 2. RevenueCat Webhook Processes Without Secret Validation

**File**: `backend/functions/index.js` (subscription-webhook handler)
**Impact**: Forged webhook events could grant free Pro subscriptions.

When `REVENUECAT_WEBHOOK_SECRET` is not configured, the handler logs a warning but **continues processing the webhook event**. An attacker who discovers the endpoint URL can forge events to:
- Grant themselves `entitlement = 'paid'`
- Modify subscription status for any user
- Bypass billing entirely

**Current behavior**:
```javascript
if (!webhookSecret) {
    context.warn('REVENUECAT_WEBHOOK_SECRET not configured - skipping signature verification');
    // Continues processing...
}
```

**Remediation**: Change to reject requests when secret is not configured:
```javascript
if (!webhookSecret) {
    context.error('REVENUECAT_WEBHOOK_SECRET not configured - rejecting request');
    return { status: 500, body: { error: 'Webhook not configured' } };
}
```

---

## HIGH — Should Fix Before Beta Expands

### 3. CORS Headers Set to Wildcard (`*`)

**File**: `backend/functions/index.js` (multiple handlers)
**Impact**: Any website can make cross-origin requests to your API.

Multiple functions return `Access-Control-Allow-Origin: '*'`. While APIM validates JWTs upstream, wildcard CORS combined with a token leak (XSS on any site the user visits) would allow full API access from an attacker's domain.

**Affected endpoints**: `ask-bartender-simple`, `refine-cocktail`, `vision-analyze`, `voice-session`, and others.

**Remediation**:
- For mobile-only API: remove CORS headers entirely (mobile apps don't use CORS)
- For shared endpoints (cocktail-preview): restrict to `https://share.mybartenderai.com`
- Better: handle CORS at the APIM level with a policy, not in individual functions

---

### 4. No Input Size Validation on AI Endpoints

**Files**: `backend/functions/index.js`
**Affected endpoints**: `ask-bartender-simple`, `refine-cocktail`, `vision-analyze`
**Impact**: Token quota exhaustion, high Azure OpenAI costs.

User input is passed to Azure OpenAI without maximum size limits. A single malicious request with a 10MB body could:
- Consume entire monthly token quota in one call
- Generate a large Azure OpenAI bill
- Enable prompt injection attacks

**Example** (`refine-cocktail`, lines 1667-1676):
```javascript
if (!cocktail.name || !cocktail.ingredients || cocktail.ingredients.length === 0) {
    return { status: 400, ... };
}
// No length validation before passing to AI
```

**Remediation**: Add validators before AI calls:
- `name`: max 200 characters
- `ingredients`: max 50 items, each max 200 characters
- `instructions`: max 5,000 characters
- `message` (ask-bartender): max 2,000 characters

---

### 5. Inconsistent Authentication Patterns

**File**: `backend/functions/index.js`
**Impact**: Difficult to audit which endpoints enforce auth correctly.

Three different auth patterns are used across v4 handlers:

| Pattern | Example | How It Works |
|---------|---------|-------------|
| Header + JWT fallback | `ask-bartender-simple` (line 69) | Reads `x-user-id` header, falls back to JWT decode |
| Header only | `voice-session` (line 2786) | Requires `x-user-id`, no fallback |
| Delegated to module | `auth-exchange` (line 2358) | `require('./auth-exchange')` — auth pattern unknown without reading module |

**Risk**: The JWT fallback pattern (`decodeJwtClaims` in `shared/auth/jwtDecode.js`) decodes without cryptographic verification. This is safe **only** because APIM validates the JWT first. If APIM is misconfigured or bypassed, the fallback accepts unverified tokens.

**Remediation**:
- Standardize on one auth pattern (prefer header-only, since APIM validates upstream)
- Remove JWT decode fallback — if the header is missing, return 401
- Audit all delegated module files for consistent auth enforcement

---

## MEDIUM — Technical Debt

### 6. Monolithic `index.js` (4,114 lines)

**File**: `backend/functions/index.js`
**Impact**: Maintainability, testability, and safe modification.

All 40+ Azure Function handlers live in one file. Key duplication metrics:

| Pattern | Occurrences |
|---------|------------|
| `buildErrorResponse` | 14 |
| `trackException` | 17 |
| `trackEvent` | 9 |
| Entitlement checks (`user.entitlement !== 'paid'`) | 8 |

Additionally, ~13 handlers use a "thin wrapper" pattern that `require()`s the old v3 module directory for actual business logic. The other ~18 have fully inline logic.

**Remediation** (when ready):
- Extract each handler into `src/handlers/<name>.js`
- Create shared middleware for auth, validation, telemetry, and error handling
- Keep `index.js` as a thin route registration file

---

### 7. Flutter Architecture Inconsistency

**Directory**: `mobile/app/lib/src/`
**Impact**: Code organization doesn't match stated architecture.

The project claims "feature-first clean architecture" but only 1 of 5 examined features follows it:

| Feature | Has domain/data/presentation layers? |
|---------|--------------------------------------|
| `ask_bartender` | Yes (models/, providers/) |
| `recipe_vault` | No — presentation only |
| `smart_scanner` | No — presentation only |
| `my_bar` | No — presentation only |
| `create_studio` | No — presentation only |

Business logic is scattered across global directories (`/src/providers/`, `/src/services/`, `/src/api/`).

**Additional Flutter issues**:
- **7 files** mix `setState()` with Riverpod (should use one or the other)
- Missing `onDispose` cleanup in several providers (memory leak risk)
- `addPostFrameCallback` called on every build in `ask_bartender_screen.dart` (performance)
- Image caching does 2 async checks per widget per build

**Remediation**: Address incrementally — when touching a feature, move its providers/services into the feature directory.

---

### 8. Error Messages Expose Stack Traces

**File**: `backend/functions/index.js` (multiple locations, e.g., line 253)
**Impact**: Information disclosure if `NODE_ENV` is misconfigured.

```javascript
details: process.env.NODE_ENV === 'development' ? error.stack : undefined
```

If `NODE_ENV` is accidentally set to `'development'` in production, full stack traces leak to clients, revealing file paths, library versions, and internal function names.

**Worse**: The `vision-analyze` endpoint (line 2120) returns `stack: error.stack` **unconditionally** — no `NODE_ENV` check at all. This endpoint leaks full stack traces to clients in all environments.

**Remediation**: Remove all development-conditional error detail exposure. Fix `vision-analyze` to remove unconditional stack exposure. Always return generic messages to clients; log full errors server-side via Application Insights.

---

### 9. Race Condition in User Creation (Partially Mitigated)

**File**: `backend/functions/services/userService.js` (lines 150-173)
**Impact**: Thundering herd on concurrent first-login.

The `getOrCreateUser()` function handles the `23505` unique violation error (two concurrent requests both try to INSERT). The retry logic works but:
- No exponential backoff or jitter
- Could cause a burst of retries under load

**Remediation**: Use `INSERT ... ON CONFLICT DO NOTHING RETURNING *` for idempotent upserts.

---

### 10. No Rate Limiting on Anonymous Endpoints

**File**: `backend/functions/index.js`
**Impact**: Denial of service on public endpoints.

These endpoints have `authLevel: 'anonymous'` with no rate limiting:
- `health` (line 9)
- `validate-age` (line 299)
- `auth-exchange` (line 2355)
- `users-me` (line 2379)
- `snapshots-latest` (line 2392)
- `snapshots-latest-mi` (line 2405)
- `social-inbox` (line 2444)
- `social-invite` (line 2457)
- `social-outbox` (line 2470)
- `social-share-internal` (line 2483)
- `well-known-assetlinks` (line 2568)
- `cocktail-preview` (line 2599)
- `subscription-webhook` (line 3623)

**Remediation**: Configure IP-based rate limiting in Azure Front Door (100 req/min per IP for public endpoints).

---

## LOW — Future Improvements

### 11. Hardcoded Endpoints in Flutter

**Files**: `mobile/app/lib/src/config/app_config.dart`, `auth_config.dart`

API base URL, CIAM tenant ID, and client ID are hardcoded as static constants. This is acceptable for a single-environment app — tenant IDs and client IDs are public OAuth values that ship in every compiled binary.

**When to fix**: Only when you need staging/production separation. Use Flutter build flavors (not `flutter_dotenv` as the third-party reviewer suggested — `.env` files aren't secure in mobile apps).

---

### 12. Outdated Dependencies

**File**: `backend/functions/package.json`

- `axios: ^1.6.2` — should update to `^1.6.5+` (security patches)

**Note**: `sql.js` (^1.11.0) was initially flagged as unused, but it IS actively used in `services/sqliteSnapshotBuilder.js` for building mobile SQLite snapshots. Do not remove.

**Remediation**: `npm update axios`

---

### 13. Dual Entitlement/Tier Model

**File**: `backend/functions/services/userService.js` (lines 20-52)

Two quota systems coexist: `TIER_QUOTAS` (free/premium/pro) and `ENTITLEMENT_QUOTAS` (none/paid/trialing). The `entitlement` field is the primary gate, but `tier` is still referenced for quota limits. This creates confusion about which field is authoritative.

**Remediation** (long-term): Fully migrate to the entitlement model and deprecate `tier`.

---

## Comparison: Third-Party vs. Independent Review

| Finding | Third-Party | Independent |
|---------|------------|-------------|
| v3 folders lingering | Found (Critical) | Confirmed, but noted 13 are still `require()`d by `index.js` — can't delete all |
| Monolithic `index.js` | Found (Maintainability) | Confirmed with duplication metrics |
| Hardcoded fallback values | Found (Config) | Confirmed; also found `cocktaildbfun` bug (now fixed) |
| Code duplication | Found | Confirmed — symptom of the monolith |
| Flutter dotenv suggestion | Recommended `flutter_dotenv` | **Disagree** — build flavors are correct for mobile |
| **Committed secrets** | **MISSED** | Found (CRITICAL) — PostgreSQL password, storage keys in git |
| **Webhook validation gap** | **MISSED** | Found (CRITICAL) — billing bypass risk |
| **CORS wildcards** | **MISSED** | Found (HIGH) — every endpoint returns `*` |
| **Input validation gaps** | **MISSED** | Found (HIGH) — AI endpoints accept unlimited input |
| **Auth inconsistency** | **MISSED** | Found (HIGH) — three different patterns |
| **Flutter state management** | **MISSED** | Found (MEDIUM) — 7 files mix setState + Riverpod |
| **Error stack trace exposure** | **MISSED** | Found (MEDIUM) |
| **Race condition in user creation** | **MISSED** | Found (MEDIUM) — partially mitigated |

---

## Recommended Fix Order

### Immediate (before expanding beta)
1. Rotate PostgreSQL password and storage account keys
2. Remove committed secrets from git tracking
3. Enforce webhook secret validation (reject if not configured)

### This sprint
4. Add input size validation on AI endpoints
5. Fix CORS headers (restrict or remove)
6. Remove `NODE_ENV` stack trace exposure

### Next sprint
7. Standardize auth pattern across all endpoints
8. Add rate limiting via Azure Front Door
9. Audit delegated v3 module files for auth consistency

### When refactoring
10. Break `index.js` into modular handler files
11. Migrate Flutter features to proper clean architecture incrementally
12. Deprecate `tier` field in favor of `entitlement` only

---

**Note**: This review focused on production readiness. The app is functionally complete and works well for beta testing. The security findings are the priority; the architectural issues are technical debt that can be addressed incrementally as the codebase matures.
