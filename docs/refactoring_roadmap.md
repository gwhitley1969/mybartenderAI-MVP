# Refactoring Roadmap — MyBartenderAI

**Date**: February 24, 2026
**Context**: Derived from the independent code review (`docs/independent_code_review.md`) and a deeper structural analysis of both backend and Flutter codebases.
**Scope**: Actionable refactoring opportunities with verified metrics. No aspirational rewrites — each item solves a concrete problem.

---

## Priority Summary

| # | Area | What | Effort | Impact | Depends On |
|---|------|------|--------|--------|------------|
| 1 | Backend | Extract auth/entitlement middleware | Medium | High — single place to audit auth | — |
| 2 | Backend | Consolidate JWT verification (3 copies → 1) | Low | High — security audit, single JWKS cache | — |
| 3 | Backend | Merge duplicate pool & telemetry | Low | Medium — removes infrastructure confusion | — |
| 4 | Backend | Extract handlers from `index.js` to `src/handlers/` | High | High — makes index.js a thin registration file | 1, 2, 3 |
| 5 | Flutter | Fix `chat_screen.dart` dual-state bug | Low | Medium — single source of truth for messages | — |
| 6 | Flutter | Extract shared Loading/Error/Empty widgets | Low-Med | Medium — consistent UX, less boilerplate | — |
| 7 | Flutter | Create subscription gate widget | Low | Low — DRY across 6 screens | — |

---

## Backend

### 1. Extract Auth/Entitlement Middleware

**Problem**: The same ~12-line auth block is duplicated in ~20 inline handlers.

**Current pattern** (repeated in `ask-bartender-simple`, `ask-bartender`, `refine-cocktail`, `vision-analyze`, `voice-session`, etc.):

```javascript
const userId = request.headers.get('x-user-id');
const authHeader = request.headers.get('authorization');
const jwtClaims = !userId && authHeader ? decodeJwtClaims(authHeader) : null;
const effectiveUserId = userId || jwtClaims?.sub;
if (!effectiveUserId) {
    return { status: 401, headers, jsonBody: { success: false, error: 'unauthorized' } };
}
const user = await getOrCreateUser(effectiveUserId, context, { ... });
if (user.entitlement !== 'paid') {
    return { status: 403, headers, jsonBody: { error: 'entitlement_required' } };
}
```

**Target**: A `withAuth(handler, options)` wrapper or middleware function:

```javascript
// shared/middleware/auth.js
async function withAuth(request, context, { requirePaid = true } = {}) {
    const userId = request.headers.get('x-user-id');
    if (!userId) return { error: { status: 401, ... } };
    const user = await getOrCreateUser(userId, context);
    if (requirePaid && user.entitlement !== 'paid') return { error: { status: 403, ... } };
    return { user };
}
```

**Estimated savings**: ~200 lines removed, 1 place to maintain auth logic.

**Files affected**:
- `backend/functions/index.js` — all 20+ inline handlers with auth blocks
- New: `backend/functions/shared/middleware/auth.js`

---

### 2. Consolidate JWT Verification

**Problem**: Three separate files implement identical `verifyToken()` + JWKS client setup (~35 lines each):

| File | Lines |
|------|-------|
| `backend/functions/auth-exchange/index.js` | 154-179 |
| `backend/functions/users-me/index.js` | 46-64 |
| `backend/functions/social-inbox/index.js` | 43-61 |

Each creates its own `jwksClient` instance with `expressJwtSecret()` and its own `verifyToken()` Promise wrapper.

**Target**: Single shared module:

```javascript
// shared/auth/jwtVerify.js
const jwksClient = expressJwtSecret({ ... }); // One cached instance
async function verifyToken(token) { ... }     // One implementation
module.exports = { verifyToken };
```

**Estimated savings**: ~70 lines removed, single JWKS cache (performance improvement), one place to update issuer/audience config.

**Files affected**:
- `backend/functions/auth-exchange/index.js`
- `backend/functions/users-me/index.js`
- `backend/functions/social-inbox/index.js`
- New: `backend/functions/shared/auth/jwtVerify.js`

---

### 3. Merge Duplicate Infrastructure

#### 3a. Two Database Pool Singletons

| File | Lines | Notes |
|------|-------|-------|
| `shared/database.js` | 122 | Primary pool, used by most handlers |
| `shared/db/postgresPool.js` | 69 | Has test override support (`overridePool`) |

**Target**: Keep `shared/db/postgresPool.js` (has test override support), make `shared/database.js` a thin re-export or remove it entirely.

#### 3b. Two Telemetry Systems

| File | Lines | Approach |
|------|-------|----------|
| `shared/telemetry.js` | 78 | Simple `context.log()` wrapper with sanitization |
| `shared/monitoring.js` | 248 | Full Application Insights integration |

Some handlers use `telemetry.js`, others use `monitoring.js`, some use neither.

**Target**: Standardize on `monitoring.js` (Application Insights). Remove `telemetry.js` or make it delegate to `monitoring.js`.

**Estimated savings**: ~120 lines removed, consistent observability.

---

### 4. Extract Handlers from `index.js`

**Problem**: `backend/functions/index.js` is 4,114 lines with 36 handlers.

**Current breakdown**:

| Category | Count | Lines | Notes |
|----------|-------|-------|-------|
| Complex inline handlers | 13 | ~3,200 | All business logic embedded |
| Thin delegated wrappers | 13 | ~100 | `require('./module-name')` pattern |
| Test/diagnostic handlers | 5 | ~450 | `health`, `test-*`, `validate-age` |
| Other (speech-token, etc.) | 5 | ~350 | Moderate complexity |

**Largest inline handlers** (extraction priority):

| Handler | Lines | Complexity |
|---------|-------|------------|
| `vision-analyze` | 421 | High — Claude API, image processing |
| `voice-session` | 336 | High — WebSocket, realtime audio |
| `voice-bartender` | 326 | High — Azure Speech Services |
| `subscription-webhook` | 321 | High — RevenueCat event processing |
| `voice-purchase` | 257 | Medium — IAP validation |
| `ask-bartender-simple` | 233 | Medium — GPT-4.1-mini chat |
| `refine-cocktail` | 213 | Medium — AI recipe refinement |
| `ask-bartender` | 207 | Medium — GPT-4.1-mini chat (legacy) |
| `recommend` | 195 | Medium — AI recommendations |

**Target structure**:
```
backend/functions/
├── index.js              ← Route registration only (~200 lines)
├── src/
│   ├── handlers/
│   │   ├── askBartender.js
│   │   ├── visionAnalyze.js
│   │   ├── voiceSession.js
│   │   ├── subscriptionWebhook.js
│   │   └── ... (one per handler)
│   └── middleware/
│       ├── auth.js       ← From refactoring #1
│       ├── cors.js
│       └── errorHandler.js
├── shared/               ← Existing utilities (kept)
└── services/             ← Existing services (kept)
```

**Depends on**: Items 1-3 should be done first so extracted handlers use the new shared middleware instead of carrying their boilerplate with them.

**Note on thin wrappers**: The 13 existing delegated modules (`auth-exchange/`, `users-me/`, etc.) should be moved into `src/handlers/` as well for consistency. The trivially simple ones (like `snapshots-latest` at 54 lines) can be inlined during the move.

---

## Flutter

### 5. Fix `chat_screen.dart` Dual-State Bug

**Problem**: `features/ask_bartender/chat_screen.dart` maintains a local `_messages` list via `setState()` while `chatProvider` (`features/ask_bartender/providers/chat_provider.dart`, 133 lines) already manages messages via a `ChatNotifier` StateNotifier.

This means:
- Two sources of truth for the message list
- State can drift between the local list and the provider
- The `chatProvider` exists but is underused

**Fix**: Remove the local `_messages` state. Use `ref.watch(chatProvider)` for the message list and `ref.read(chatProvider.notifier)` for mutations.

**Also**: `initial_sync_screen.dart` uses a `_syncStarted` boolean guard via `setState()` that belongs in the `snapshotSyncProvider` notifier. Low effort to fix alongside.

**Files affected**:
- `mobile/app/lib/src/features/ask_bartender/chat_screen.dart`
- `mobile/app/lib/src/features/initial_sync/initial_sync_screen.dart`

**Note on the other 5 files**: `edit_cocktail_screen.dart`, `smart_scanner_screen.dart`, `subscription_sheet.dart`, `recipe_vault_screen.dart`, and `add_ingredient_screen.dart` all use `setState()` for genuinely local UI state (form fields, search queries, image bytes, loading flags). This is correct Flutter practice — **no refactoring needed** for these files.

---

### 6. Extract Shared Loading/Error/Empty Widgets

**Problem**: ~27 screens repeat the same AsyncValue `.when()` pattern with inline loading spinners and error text. The `widgets/` directory has 11 reusable components but is missing three fundamental ones.

**Current pattern** (repeated 20+ times across screens):
```dart
cocktailsAsync.when(
  data: (cocktails) => ListView(...),
  loading: () => Center(child: CircularProgressIndicator()),
  error: (e, st) => Center(child: Text('Error: $e')),
)
```

**Target widgets**:
- `AppLoadingWidget` — centered spinner with optional message
- `AppErrorWidget` — error message + retry button
- `AppEmptyStateWidget` — illustration + message + action button

**Files to create**:
- `mobile/app/lib/src/widgets/app_loading_widget.dart`
- `mobile/app/lib/src/widgets/app_error_widget.dart`
- `mobile/app/lib/src/widgets/app_empty_state_widget.dart`

---

### 7. Subscription Gate Widget

**Problem**: 6 screens independently check `isPaidProvider` and show the subscription sheet:
- `smart_scanner_screen.dart`
- `voice_ai_screen.dart`
- `create_studio_screen.dart`
- `ask_bartender_screen.dart`
- Home screen feature cards
- Pro tools screen

**Current pattern**:
```dart
final isPaid = ref.watch(isPaidProvider);
if (!isPaid) {
  showSubscriptionSheet(context);
  return;
}
```

**Target**: A reusable `SubscriptionGateWidget` that wraps Pro-only content:
```dart
SubscriptionGateWidget(
  child: ProFeatureContent(),
)
```

**File to create**: `mobile/app/lib/src/widgets/subscription_gate_widget.dart`

---

## What Doesn't Need Refactoring

These areas were analyzed and found to be appropriately structured:

- **Global providers** (71 across 13 files) — all genuinely shared, no single-feature providers polluting the global namespace
- **Global services** (20 files) — well-distributed, no overloaded god-services
- **GoRouter configuration** — functional, deep linking works. TypedGoRoute migration is a "nice to have," not a need
- **API client files** (4 files, ~300 lines) — clean, focused interfaces

---

## Recommended Execution Order

```
Phase 1: Backend infrastructure (items 1-3)
  ├── 1. Extract auth middleware      ← Can be done standalone
  ├── 2. Consolidate JWT verification ← Can be done standalone
  └── 3. Merge pool + telemetry       ← Can be done standalone

Phase 2: Backend restructuring (item 4)
  └── 4. Extract handlers from index.js ← Depends on Phase 1

Phase 3: Flutter cleanup (items 5-7)
  ├── 5. Fix chat_screen dual state   ← Can be done standalone
  ├── 6. Extract shared widgets       ← Can be done standalone
  └── 7. Subscription gate widget     ← Can be done standalone
```

Phase 1 items are independent of each other and can be done in any order (or in parallel). Phase 2 depends on Phase 1. Phase 3 is entirely independent of the backend work.

---

## Cross-References

- Security findings that should be fixed **before** refactoring: see `docs/independent_code_review.md` (Critical items 1-2, High items 3-5)
- Original third-party review: `docs/codebase_review.md`
- The monolithic `index.js` finding (review item #6) is addressed by refactoring items 1-4 above
- The Flutter architecture finding (review item #7) is addressed by items 5-7 above
- The auth inconsistency finding (review item #5) is directly solved by refactoring item 1

---

**Note**: This roadmap focuses on structural improvements that reduce duplication and improve maintainability. It does not include the security fixes from the independent code review — those should be addressed first, before any refactoring work begins.
