# RevenueCat App User ID — Root Cause Analysis & Redesign

## Problem Overview

- **Original requirement:** RevenueCat App User IDs must be identifiable so support can locate customers in the RevenueCat dashboard.
- **Flawed approach (Build 15):** Used `Purchases.logIn(email)` — making the user's email the App User ID. This never worked reliably:
  1. **Google-federated CIAM users** — email extraction fails across all 6 layers (ID token, Graph API `mail`, `otherMails`, MSAL `Account.username`, `userPrincipalName`, `identities`). These users are blocked from subscribing entirely.
  2. **Email sign-up users** — even `vwhitley1967@gmail.com` (email sign-up) still shows a GUID-style App User ID. The email-based `logIn()` created a *new* RevenueCat customer record, but the user's existing purchases stayed with the original GUID record. RevenueCat's Transfer Behavior only migrates purchases from anonymous users — not between two identified users.
  3. **RevenueCat explicitly recommends against email as App User ID** — their docs state: *"We don't recommend using email addresses as App User IDs"* due to guessability and GDPR concerns. They recommend *"a non-guessable pseudo-random ID, like a UUID."*
- **Why it matters:** No user could be reliably located by email in the RevenueCat dashboard, Google-federated users couldn't subscribe at all, and existing users' purchases were stranded on GUID records.

## What the Entra `sub` Claim Is

Every user authenticated through Entra External ID receives a `sub` claim — a stable, opaque, unique identifier (GUID format). This is:
- **Always available** — present for email sign-up, Google-federated, and Apple-federated users
- **Already stored** in PostgreSQL as `azure_ad_sub`
- **Already the App User ID** for all existing users (vwhitley1967, Wild Heels, Xtend-AI, etc.)
- **Exactly what RevenueCat recommends** — non-guessable, pseudo-random ID

Source: [RevenueCat Identifying Customers](https://www.revenuecat.com/docs/customers/identifying-customers)

## Why the Email-Based Approach Failed

### Failure 1: Email Extraction for Google-Federated Users
Entra External ID CIAM tokens for Google-federated users contain no email claim. The 6-layer extraction chain added in Build 16 checks:
1. ID token `emails` array → empty
2. ID token `email` claim → null
3. MSAL `Account.username` → null or UPN
4. Graph API `mail` → null
5. Graph API `otherMails` → empty
6. Graph API `identities[].issuerAssignedId` → Google numeric sub (not email)

**Result:** `user.email` is empty. Build 16's email validation guard (`if (email.isEmpty) return`) skips RevenueCat initialization entirely. Google-federated users cannot subscribe.

### Failure 2: Transfer Behavior Doesn't Migrate Purchases
The app calls `Purchases.configure()` (anonymous) then `Purchases.logIn(email)`. RevenueCat's Transfer Behavior:
- Transfers purchases from an **anonymous** user to the identified user
- Does **NOT** transfer between two **identified** users

Since existing users already have purchases under their Entra sub (GUID) — an identified user — calling `logIn(email)` creates a *new*, empty customer record. The purchases stay with the GUID record. This is why vwhitley1967@gmail.com still appeared with a cryptic App User ID.

### Failure 3: Dashboard Searchability
RevenueCat's Ctrl+K search works with the `$email` **subscriber attribute**, not the App User ID. Setting email as the App User ID was unnecessary for searchability and introduced all the above failures.

Source: [RevenueCat Customer Search](https://www.revenuecat.com/docs/dashboard-and-metrics/supporting-your-customers)

## Build 16 Patches (Superseded)

Build 16 (`1.0.0+16`) attempted to fix the email-based approach:
1. Fixed `_attemptLazyInit()` to pass `user.email` instead of `user.id`
2. Added `@` guard in `initialize()` to reject non-email strings
3. Fixed `logout()` to reset `_isInitialized`
4. Expanded email extraction to 6 layers
5. Added comprehensive ID token claim logging
6. Fixed `HttpClient` resource leak in `_fetchEmailFromGraph()`

**Why these patches are insufficient:**
- They prevent GUIDs from reaching RevenueCat but don't solve the fundamental problem
- Google-federated users are still blocked (email extraction fails → init skipped)
- Existing users' purchases still stranded on GUID records
- The entire approach conflicts with RevenueCat's own best practices

Build 16 was **never deployed** to production. It is superseded by the redesign below.

---

## Redesign — Build 17 (Feb 26, 2026)

### Approach: Entra Sub as App User ID + Email as Subscriber Attribute

| Component | Before (Broken) | After (Redesign) |
|-----------|-----------------|-------------------|
| App User ID | `Purchases.logIn(email)` — fails when email unavailable | `Purchases.logIn(userId)` — always works (Entra sub) |
| Email searchability | Broken — email not always available | `Purchases.setEmail(email)` — `$email` subscriber attribute, searchable via Ctrl+K |
| Init dependency | Blocked by 6-layer email extraction | Zero dependency on email — init always succeeds |
| Google-federated users | Can't subscribe (init skipped) | Can subscribe immediately |
| Existing users | Stuck on GUID, can't migrate | Reconnect automatically (same Entra sub) |

### What This Solves
- **ALL users can subscribe** — RevenueCat init never fails (Entra sub always available)
- **Dashboard searchable by email** — `$email` subscriber attribute works in RevenueCat Ctrl+K search
- **Existing users reconnect** — their App User IDs are already the Entra sub (same GUID)
- **Simpler code** — remove complex email validation guards; email extraction no longer blocks subscription
- **Aligns with RevenueCat best practices** — opaque ID, not email

### Code Changes

**File 1: `subscription_service.dart`**
- Change `initialize()` signature: first parameter becomes `userId` (Entra sub), `email` becomes optional named parameter
- `Purchases.logIn(userId)` — uses Entra sub, always available
- `Purchases.setEmail(normalizedEmail)` — sets `$email` attribute when email is available
- `Purchases.setDisplayName(displayName)` — sets `$displayName` attribute
- Remove all email-format validation guards from `logIn()` path
- Keep `logout()` fix from Build 16 (reset `_isInitialized`)

**File 2: `auth_provider.dart`**
- Update `_initializeSubscription()` signature: primary param = `userId`, add optional `email`
- All 4 call sites pass `user.id` (Entra sub) as primary, `user.email` as optional
- Call sites: `quickRelogin`, `_checkAuthStatus`, `signIn`, `signUp`

**File 3: `subscription_sheet.dart`**
- Simplify `_attemptLazyInit()`: pass `user.id` (always available), no email guard needed
- Google-federated users can now reach subscription offerings

**File 4: Backend `index.js`** — Case-insensitive lookup fix (Feb 27, 2026 — SUB-004)
- Existing dual-lookup webhook handler supports `azure_ad_sub` lookup
- `app_user_id` in webhook payloads will always be the Entra sub → matched via `WHERE LOWER(azure_ad_sub) = LOWER($1)`
- **Important**: RevenueCat normalizes App User IDs to lowercase. The Entra `sub` claim is base64url-encoded with mixed case. All 10 `azure_ad_sub` lookups across 3 backend files use `LOWER()` for case-insensitive matching. See `BUG_FIXES.md` SUB-004

**File 5: `auth_service.dart`** — Keep Build 16 improvements
- 6-layer email extraction still valuable (populates `$email` attribute)
- Difference: email extraction no longer **blocks** RevenueCat initialization
- Keep diagnostic logging, HttpClient fix

### What Happens to Existing Users

| User Type | Current App User ID | After Redesign |
|-----------|-------------------|----------------|
| vwhitley1967, ehuffman, etc. | Entra sub (GUID) | **Reconnect automatically** — same ID |
| Wild Heels, Xtend-AI (subscribers) | Entra sub (GUID) | **Reconnect automatically** — purchases intact |
| Any Build-15 email-based users (if any) | email address | New record under Entra sub — use `Restore Purchases` to migrate |

**Most likely scenario**: No users have email-based IDs (vwhitley1967 confirmed still on GUID). All existing users reconnect automatically with zero migration needed.

## Verification Plan

1. **Static analysis**: `flutter analyze --no-pub` — zero new errors
2. **Build**: `flutter build appbundle --release` — version `1.0.0+17`
3. **Google-federated user**: Sign in → verify `logIn successful` in logcat → open subscription sheet → offerings load (previously failed) → check RevenueCat dashboard: Entra sub as App User ID, `$email` set if extracted
4. **Email sign-up user**: Sign in → verify App User ID = Entra sub, `$email` attribute = email → search by email in Ctrl+K
5. **Existing subscriber**: Sign in → verify subscription recognized (same Entra sub) → entitlements work
6. **Purchase flow**: Complete trial purchase → webhook processes correctly (`azure_ad_sub` lookup) → dashboard shows purchase under correct customer

---

## Lessons Learned

1. **Follow the vendor's recommendations.** RevenueCat explicitly says don't use email as App User ID. We should have used their recommended pattern from day one.
2. **Subscriber attributes solve searchability.** The `$email` attribute indexed by Ctrl+K gives the same dashboard manageability as email-based App User IDs — without the fragility.
3. **Test with real users, not just log output.** Build 16's "verification" confirmed `logIn(email)` didn't throw an error, but never checked whether the App User ID actually changed in the RevenueCat dashboard.
4. **Transfer Behavior has limits.** RevenueCat only transfers purchases from anonymous → identified. You cannot migrate between identified users via `logIn()`.
5. **RevenueCat lowercases App User IDs.** When sending webhook events, RevenueCat normalizes the `app_user_id` to lowercase. If your user IDs contain mixed case (like base64url-encoded Entra `sub` claims), all database lookups must be case-insensitive (`LOWER(col) = LOWER($1)`). This was discovered as SUB-004 (Feb 27, 2026) when trial users' webhooks silently failed to update their entitlements.
