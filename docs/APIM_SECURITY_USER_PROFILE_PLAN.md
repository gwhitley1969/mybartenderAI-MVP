# Comprehensive Plan: APIM Security & User Profile Population

> **Author**: Claude Opus 4.5 | **Date**: January 29, 2026
> **Constraint**: Apple is actively testing the app -- ZERO disruption to existing functionality

---

## Executive Summary

### Three Critical Findings

| # | Finding | Severity | Impact |
|---|---------|----------|--------|
| 1 | **13 of 30 APIM operations had NO JWT validation** ✅ FIXED | HIGH | All 13 now have `validate-jwt` policies (deployed Feb 11, 2026) |
| 2 | **Email/display_name not populating** | MEDIUM | Fire-and-forget code deployed but APIM doesn't forward `X-User-Email`/`X-User-Name` headers |
| 3 | **Two different audience/client IDs in live APIM policies** | HIGH | `f9f7f159` (voice endpoints) vs `04551003` (users-me/social) -- needs investigation |

### What IS Working

- The mobile app authenticates with Entra External ID and sends JWT on every request
- APIM adds `x-functions-key` at the API level -- functions are NOT publicly accessible without going through APIM
- 17 of 30 operations DO have operation-level policies (most with `validate-jwt`)
- `getOrCreateUser()` in `userService.js` correctly accepts and stores email/displayName via COALESCE
- Fire-and-forget profile sync blocks are deployed in 4 handlers (just not receiving data)

### What is NOT Working

- The 4 fire-and-forget blocks read `x-user-id` from headers, but APIM never sets this header for AI endpoints (no `validate-jwt` + `set-header` policy on these operations)
- **No** APIM operation extracts `X-User-Email` or `X-User-Name` -- even the ones WITH `validate-jwt` only extract `X-User-Id`

---

## APIM Operation Audit (Complete Inventory)

### Operations WITH Policies (17)

| Operation | Has `validate-jwt`? | Audience | Extracts Headers |
|-----------|-------------------|----------|-----------------|
| `voice-session` | YES | `f9f7f159` (mobile app) | `X-User-Id` only |
| `voice-quota` | YES | `f9f7f159` | `X-User-Id` only |
| `voice-purchase` | YES | `f9f7f159` | `X-User-Id` only |
| `voice-usage` | YES | `f9f7f159` | `X-User-Id` only |
| `users-me-get` | YES | `04551003` (different!) | `X-User-Id` only |
| `users-me-update` | YES | `04551003` | `X-User-Id` only |
| `social-share-internal` | YES | `04551003` | `X-User-Id` only |
| `social-inbox` | YES | `04551003` | `X-User-Id` only |
| `social-outbox` | YES | `04551003` | `X-User-Id` only |
| `social-invite-create` | YES | `04551003` | `X-User-Id` only |
| `social-invite-claim` | YES | `04551003` | `X-User-Id` only |
| `social-connect-callback` | YES | `04551003` | `X-User-Id` only |
| `subscription-webhook` | Policy present | TBD | TBD |
| `health` | Policy present | N/A (public) | N/A |
| `snapshots-latest` | Policy present | N/A (public) | N/A |
| `cocktail-preview` | Policy present | N/A (public) | N/A |
| `validate-age` | Policy present | TBD | TBD |

### Operations WITHOUT Policies (13 -- NO JWT validation at APIM)

| Operation | Endpoint | Category | Should Have JWT? |
|-----------|----------|----------|-----------------|
| `ask-bartender` | POST /v1/ask-bartender | AI Chat | **YES** |
| `ask-bartender-simple` | POST /v1/ask-bartender-simple | AI Chat | **YES** |
| `recommend` | POST /v1/recommend | AI Recommend | **YES** |
| `vision-analyze` | POST /v1/vision/analyze | Smart Scanner | **YES** |
| `refine-cocktail` | POST /v1/refine-cocktail | Create Studio | **YES** |
| `voice-bartender` | POST /v1/voice-bartender | Legacy Voice | **YES** |
| `speech-token` | GET /v1/speech/token | Speech Service | **YES** |
| `subscription-config` | GET /v1/subscription/config | Subscription | **YES** |
| `subscription-status` | GET /v1/subscription/status | Subscription | **YES** |
| `social-connect-start` | POST /v1/social/connect/start | Social | **YES** |
| `social-share-external` | POST /v1/social/share/external | Social | Depends |
| `auth-exchange` | POST /v1/auth/exchange | Auth | Special |
| `auth-rotate` | POST /v1/auth/rotate | Auth | Special |

### The Dual-Audience Problem

```
Mobile app (auth_config.dart):   clientId = 'f9f7f159-b847-4211-98c9-18e5b8193045'
Voice APIM policies:             audience = 'f9f7f159-b847-4211-98c9-18e5b8193045'  <-- matches app
Users-me/Social APIM policies:   audience = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6'  <-- DIFFERENT
users-me/index.js (function):    AUDIENCE = '04551003-a57c-4dc2-97a1-37e0b3d1a2f6'  <-- DIFFERENT
jwt-validation-entra-external-id.xml (repo): audience = 'f9f7f159'  <-- matches app
```

**Key Question**: What `aud` claim does the JWT token actually contain? This determines which audience ID is correct. The mobile app authenticates as `f9f7f159`, but depending on the token request scope, the token might have `aud: f9f7f159` OR `aud: 04551003`. Both endpoints apparently work, which means either:
- (a) The app requests tokens with different audiences for different endpoints, OR
- (b) One audience check is wrong but masked by some other behavior, OR
- (c) Entra External ID accepts both audience values for this tenant

**This MUST be investigated before deploying APIM JWT policies broadly.**

---

## Phase 1: Backend JWT Parsing (SAFE -- No APIM Changes)

### Goal
Populate `email` and `display_name` in the `users` table by decoding the JWT token directly in the function code, bypassing the need for APIM-forwarded headers.

### Why This Is Safe
- **No APIM changes** -- nothing changes at the API gateway
- **No mobile app changes** -- the app already sends `Authorization: Bearer <token>` on every request
- **Fire-and-forget** -- not awaited, cannot block the response
- **No cryptographic verification** -- just base64 decodes the JWT payload (verification is APIM's job)
- **Graceful fallback** -- if decode fails, profile sync is simply skipped

### New File: `backend/functions/shared/auth/jwtDecode.js`

A lightweight utility that base64-decodes the JWT payload section to extract claims without cryptographic verification. This is appropriate because:
- We're only using the data for profile sync (not authorization decisions)
- The token travels over HTTPS (can't be tampered in transit)
- APIM validates the token at the gateway (for endpoints that have `validate-jwt`)
- The fire-and-forget pattern means failures are harmless

```javascript
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
```

### Modified File: `backend/functions/index.js`

**Line 3 area** -- Add import (after existing `getOrCreateUser` import):
```javascript
const { decodeJwtClaims } = require('./shared/auth/jwtDecode');
```

**4 handlers to update** (replace existing fire-and-forget blocks):

| # | Handler | Location in index.js | Current Line |
|---|---------|---------------------|--------------|
| 1 | `ask-bartender-simple` | Start of try block | ~line 54 |
| 2 | `voice-bartender` | Start of try block | ~line 951 |
| 3 | `refine-cocktail` | Start of try block | ~line 1455 |
| 4 | `vision-analyze` | Start of try block | ~line 1653 |

**New fire-and-forget pattern** (replaces existing 6-line block at each location):

```javascript
// Fire-and-forget: sync user profile from JWT
const userId = request.headers.get('x-user-id');
const authHeader = request.headers.get('authorization');
const jwtClaims = !userId && authHeader ? decodeJwtClaims(authHeader) : null;
const effectiveUserId = userId || jwtClaims?.sub;
if (effectiveUserId) {
    const userEmail = request.headers.get('x-user-email') || jwtClaims?.email || null;
    const userName = request.headers.get('x-user-name') || jwtClaims?.name || null;
    getOrCreateUser(effectiveUserId, context, { email: userEmail, displayName: userName })
        .catch(err => context.log.warn?.(`[Profile] Non-blocking sync failed: ${err.message}`)
                      || context.log(`[Profile] Non-blocking sync failed: ${err.message}`));
}
```

**How this works:**
1. First tries `x-user-id` header (set by APIM if `validate-jwt` + `set-header` policy exists)
2. If absent, decodes the JWT directly from the `Authorization` header
3. Uses whichever source provided the user ID
4. Email and name also fall back to JWT claims if APIM headers are missing
5. Calls `getOrCreateUser()` in fire-and-forget mode

### Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| JWT decode fails | Zero -- returns null, sync skipped | try/catch in decodeJwtClaims |
| Token has no `sub` | Zero -- effectiveUserId is null, guard skips sync | `if (effectiveUserId)` check |
| DB unreachable | Zero -- `.catch()` logs warning | Fire-and-forget pattern |
| Performance | ~0.01ms for base64 decode | Negligible |
| Apple testing | Zero -- endpoint responses unchanged | Only side effect is DB write |

### Deployment & Verification

```bash
# Deploy from backend/functions directory
func azure functionapp publish func-mba-fresh
```

```sql
-- After sending a chat message from mobile app:
SELECT id, email, display_name, tier, last_login_at
FROM users
ORDER BY last_login_at DESC NULLS LAST
LIMIT 10;
```

- Confirm email and display_name are populated for the calling user
- Check App Insights for `[Profile]` or `[UserService]` log messages

---

## Phase 2: APIM JWT Validation Deployment (CAREFUL -- Staged Rollout)

### Goal
Close the security gap by deploying `validate-jwt` policies to the 13 unprotected operations.

### Pre-Requisite: Audience ID Investigation (MUST DO FIRST)

Before deploying ANY APIM JWT policy, we must determine the correct audience.

**Step 1**: Capture a real JWT token from the mobile app. Options:
- Check App Insights traces for Authorization header
- Use mobile app debug mode / network inspector
- Check `context.log` output from a handler that logs the header

**Step 2**: Decode the token:
```powershell
$token = "<paste-jwt-here>"
$parts = $token.Split('.')
# Pad base64 if needed and decode
$payload = $parts[1].Replace('-','+').Replace('_','/')
$mod = $payload.Length % 4
if ($mod -gt 0) { $payload += '=' * (4 - $mod) }
[System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload))
```

**Step 3**: Check these claims:
- `aud` -- Which audience? `f9f7f159` or `04551003`?
- `iss` -- Which issuer format?
- `email` -- Is the email claim present?
- `name` -- Is the display name present?

**Step 4**: List Entra app registrations:
```bash
az ad app list --display-name "mybartender" --query "[].{name:displayName, appId:appId}" -o table
```

### Phase 2a: Fix Deployment Script

**File**: `infrastructure/apim/scripts/apply-jwt-policies02.ps1`

Critical fix -- the existing scripts target `apim-mba-001` (old APIM) but the live APIM is `apim-mba-002`:
- **Line 8**: Change `$ApimServiceName = "apim-mba-001"` to `"apim-mba-002"`

Update `$jwtOperationMatches` to include ALL 13 unprotected operations:
```powershell
$jwtOperationMatches = @(
    # AI Endpoints (highest priority)
    @{ Name = "ask-bartender";        Match = "/v1/ask-bartender"        },
    @{ Name = "ask-bartender-simple"; Match = "/v1/ask-bartender-simple" },
    @{ Name = "recommend";            Match = "/v1/recommend"            },
    @{ Name = "vision-analyze";       Match = "/v1/vision/analyze"       },
    @{ Name = "refine-cocktail";      Match = "/v1/refine-cocktail"      },
    @{ Name = "voice-bartender";      Match = "/v1/voice-bartender"      },
    @{ Name = "speech-token";         Match = "/v1/speech/token"         },
    # Subscription endpoints
    @{ Name = "subscription-config";  Match = "/v1/subscription/config"  },
    @{ Name = "subscription-status";  Match = "/v1/subscription/status"  },
    # Social endpoints
    @{ Name = "social-connect-start";    Match = "/v1/social/connect/start"    },
    @{ Name = "social-share-external";   Match = "/v1/social/share/external"   },
    # Auth endpoints (may need special handling)
    @{ Name = "auth-exchange";        Match = "/v1/auth/exchange"        },
    @{ Name = "auth-rotate";          Match = "/v1/auth/rotate"          }
)
```

### Phase 2b: DryRun Test

```powershell
cd "C:\backup dev02\mybartenderAI-MVP\infrastructure\apim\scripts"
.\apply-jwt-policies02.ps1 -ApimServiceName "apim-mba-002" -DryRun
```

Review output: Confirm all 13 operations are found and matched by name/URL.

### Phase 2c: Staged Deployment Order

Deploy in order of risk, testing after each batch:

**Batch 1 -- Low-traffic** (test safety):
- `subscription-config`, `subscription-status`
- Test: Open app, check subscription screen loads

**Batch 2 -- Core AI endpoints** (highest value):
- `ask-bartender`, `ask-bartender-simple`, `recommend`, `refine-cocktail`
- Test: Send a chat message, try Create Studio

**Batch 3 -- Scanner and voice**:
- `vision-analyze`, `speech-token`, `voice-bartender`
- Test: Try Smart Scanner

**Batch 4 -- Social and auth** (may need special policy):
- `social-connect-start`, `social-share-external`, `auth-exchange`, `auth-rotate`
- Test: Try social features, verify token refresh

### Phase 2d: Add Email/Name Headers to Policy

Once audience is confirmed and JWT validation is deployed, update the `jwt-validation-entra-external-id.xml` policy to also extract `X-User-Email` and `X-User-Name` headers. The current repo version (lines 56-78) already has these -- just needs to be deployed.

Once deployed, the backend will have BOTH paths:
- APIM-forwarded headers (preferred, instant)
- Direct JWT decode fallback (Phase 1 code, belt-and-suspenders)

### Phase 2 Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Wrong audience breaks endpoint | HIGH -- 401 for all requests | Audience investigation FIRST; DryRun; staged batches |
| Apple tester hits newly-protected endpoint | LOW -- app already sends JWT | Token sent on every request; APIM just starts validating |
| OpenID config URL unreachable | MEDIUM -- 500 errors | APIM caches JWKS; test batch-by-batch |
| Issuer format mismatch | HIGH -- 401 | Confirm from real JWT before deploying |

---

## Phase 3: Audience ID Standardization

### After Investigation, One of Three Outcomes

**Option A** -- If `aud = f9f7f159` in the token:
- The canonical policy (`jwt-validation-entra-external-id.xml`) is correct
- Need to update users-me and social APIM policies to use `f9f7f159`
- Update `users-me/index.js` line 19 AUDIENCE constant to `f9f7f159`

**Option B** -- If `aud = 04551003` in the token:
- Users-me/social policies are correct
- Need to update voice APIM policies to use `04551003`
- Update `jwt-validation-entra-external-id.xml` to use `04551003`

**Option C** -- If both audiences appear in different tokens:
- Document the multi-audience architecture
- Create separate policy templates per audience context

---

## Phase 4: Tier Simplification Considerations

### Current 3-Tier Model (In Code)

| Location | Tiers Defined |
|----------|--------------|
| `userService.js` TIER_QUOTAS | free, premium, pro |
| `schema.sql` CHECK constraint | free, premium, pro |
| `subscription_service.dart` enum | free, premium, pro |
| RevenueCat products | premium_monthly, premium_yearly, pro_monthly, pro_yearly |

### ~~Proposed: Single Pro Tier~~ — SUPERSEDED

> **Note (February 2026):** This Phase 4 proposal was superseded by the binary `paid`/`none` entitlement model. The actual implementation uses $9.99/month (or $99.99/year) with 60 voice minutes/month and $5.99/60 min add-ons. See `SUBSCRIPTION_DEPLOYMENT.md` for details.

### Original Proposal (archived): Single Pro Tier ($9.99/month, 3-Day Free Trial, 20 Voice Minutes)

> **Decision (2026-01-30):** Price changed from $7.99 to $9.99/month. Voice minutes changed from 60 to 20/month.
> **Decision (2026-01-30):** Wait for Apple approval before making ANY tier/quota changes — deploy backend + Flutter together to avoid UI mismatch.

If you proceed with this simplification:

**Backend changes needed:**
1. `userService.js` -- Simplify TIER_QUOTAS (keep `free` for trial-expired users), remove `premium`, change `voiceMinutesPerMonth: 60` → `20`
2. `schema.sql` -- Update CHECK constraint to `IN ('free', 'pro')`, update quota function `ELSE 60 END` → `ELSE 20 END`, migrate existing premium users
3. Various handlers in `index.js` -- Simplify tier checks

**Mobile app changes needed:**
4. `subscription_service.dart` -- Remove premium tier, add trial logic
5. RevenueCat configuration -- Remove premium products, configure 3-day free trial
6. UI screens -- Remove tier comparison, simplify paywall
7. `voice_ai_service.dart` lines 965, 981 -- Change default `3600` (60 min) → `1200` (20 min)
8. `quota_display.dart:163` -- Change "60 min/month" → "20 min/month"
9. `voice_ai_screen.dart:213-214` -- Change "60 minutes" → "20 minutes"

**Store changes needed:**
10. App Store Connect -- Configure subscription with free trial, set price $9.99
11. Google Play Console -- Same

### Recommendation
- **NOT for this session** -- tier simplification requires mobile app + store configuration changes
- Apple is currently testing the existing 3-tier model
- **Recommended sequence**: Complete Apple approval first, then simplify tiers in next release
- Backend + Flutter changes MUST ship together to avoid "UI says 60 min, backend enforces 20 min" mismatch
- The backend already defaults new users to `'pro'` tier (beta mode), which is effectively the desired behavior

---

## Implementation Order

```
Phase 1 (DONE ✅)   -> Backend JWT decode helper + update fire-and-forget blocks
                       Deployed 2026-01-30 17:11 UTC. Health check passed.
                       Files: jwtDecode.js (created) + index.js (modified 4 handlers)

Phase 2a (DONE ✅)  -> Investigated audience ID. Confirmed: aud = f9f7f159 (mobile client ID)
                       The 04551003 audience on users-me/social was a different app registration
                       Used f9f7f159 for all new policies

Phase 2b (DONE ✅)  -> Fixed deployment script (apim-mba-001 -> apim-mba-002), DryRun verified
                       Script: apply-jwt-policies02.ps1 with batch support

Phase 2c (DONE ✅)  -> Deployed JWT validation in 4 staged batches (Feb 11, 2026)
                       Batch 1: subscription-config, subscription-status
                       Batch 2: ask-bartender, ask-bartender-simple, recommend, refine-cocktail
                       Batch 3: vision-analyze, speech-token, voice-bartender
                       Batch 4: social-connect-start, social-share-external, auth-exchange, auth-rotate

                       CRITICAL DISCOVERY: Batches 1+2 revealed a mobile app bug —
                       4 API providers used bare Dio (no JWT). Fixed all 4 providers
                       to use backendServiceProvider.dio. See BUG_FIXES.md BUG-008.

Phase 3 (FUTURE)    -> Standardize audience IDs across all APIM operations
                       Risk: LOW (once all policies use f9f7f159, update legacy 04551003 policies)

Phase 4 (FUTURE)    -> Tier simplification (next release cycle)
                       Risk: LOW (planned change with store updates)
                       Price: $9.99/month, 20 voice min (decision 2026-01-30)
                       NOTE: Backend + Flutter must ship together
```

---

## Files Created/Modified

| File | Action | Phase | Status |
|------|--------|-------|--------|
| `backend/functions/shared/auth/jwtDecode.js` | **CREATE** | 1 | ✅ Done |
| `backend/functions/index.js` (import + 4 handlers) | **MODIFY** | 1 | ✅ Done |
| `infrastructure/apim/scripts/apply-jwt-policies02.ps1` | **MODIFY** | 2 | ✅ Done (batch support added) |
| `infrastructure/apim/policies/jwt-validation-entra-external-id.xml` | **VERIFY** | 2 | ✅ Done (audience f9f7f159 confirmed correct) |
| `mobile/app/lib/src/api/ask_bartender_api.dart` | **MODIFY** | 2c | ✅ Done (switched to authenticated Dio) |
| `mobile/app/lib/src/api/recommend_api.dart` | **MODIFY** | 2c | ✅ Done (switched to authenticated Dio) |
| `mobile/app/lib/src/api/create_studio_api.dart` | **MODIFY** | 2c | ✅ Done (switched to authenticated Dio) |
| `mobile/app/lib/src/providers/vision_provider.dart` | **MODIFY** | 2c | ✅ Done (switched to authenticated Dio) |
| `docs/DEPLOYMENT_STATUS.md` | **UPDATE** | After deployment | ✅ Done |

---

## Verification Checklist

### After Phase 1 Deployment
- [x] `func azure functionapp publish func-mba-fresh` succeeds (2026-01-30 17:11 UTC)
- [x] Health check passed: `status: ok` — "Azure Functions v4 Programming Model on Windows Premium"
- [x] 33 functions synced with no errors
- [ ] Send a chat message from mobile app → verify email/display_name populated in PostgreSQL
- [ ] Check App Insights for `[Profile]` or `[UserService]` log messages

### After Phase 2 Deployment (Each Batch)
- [x] DryRun passes with all operations found
- [x] After each batch: test affected endpoints from mobile app
- [x] No unexpected 401 errors in App Insights
- [x] Confirm endpoints still return correct data
- [x] **Discovered mobile auth bug**: 4 providers used bare Dio without JWT (BUG-008)
- [x] **Fixed all 4 providers**: askBartenderApi, recommendApi, createStudioApi, visionApi
- [x] **All 4 batches deployed** (13 operations protected)
- [x] **5 public endpoints verified** (no accidental JWT policies)

### Audience Investigation
- [x] Captured real JWT token from mobile app
- [x] Confirmed `aud = f9f7f159-b847-4211-98c9-18e5b8193045` (mobile client ID)
- [x] Determined correct audience ID — all new policies use `f9f7f159`
- [ ] Phase 3: Standardize legacy `04551003` policies to also use `f9f7f159` (future)
