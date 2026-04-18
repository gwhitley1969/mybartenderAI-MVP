# User Subscription Management — PostgreSQL

**Last Updated**: April 18, 2026 — v1.2.0+33 hard paywall rollout

This guide explains how to view and modify user subscription status directly in the PostgreSQL database (`pg-mybartenderdb`).

---

## Prerequisites

- **Azure CLI** authenticated (`az login`)
- **psql** installed (comes with PostgreSQL client tools)
- **PowerShell** available (required on Windows — see [Password Encoding Gotcha](#password-encoding-gotcha) below)

---

## Connecting to the Database

### Step 1: Retrieve the Connection String

```bash
az keyvault secret show \
  --vault-name kv-mybartenderai-prod \
  --name POSTGRES-CONNECTION-STRING \
  --query value -o tsv
```

This returns a connection string in the format:

```
postgresql://pgadmin:<password>@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require
```

### Step 2: Connect with psql

**From PowerShell (recommended on Windows):**

```powershell
psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require'
```

> **Important:** The `!` in the password must be URL-encoded as `%21` in the connection string. See [Password Encoding Gotcha](#password-encoding-gotcha) for details.

---

## Password Encoding Gotcha

The database password contains an exclamation mark (`!`), which causes problems in multiple shells:

| Shell | Problem | Workaround |
|-------|---------|------------|
| **Bash** | `!` triggers history expansion, even inside double quotes | URL-encode as `%21` in the connection string |
| **PowerShell** | Generally handles `!` fine, but piping through bash can re-introduce the issue | Use PowerShell directly with `%21` encoding |
| **Git Bash on Windows** | Same history expansion issue as bash | Run via `powershell.exe -Command "..."` |

### What Works

```powershell
# PowerShell — URL-encode the ! as %21
psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' -c "SELECT * FROM users;"
```

### What Fails

```bash
# Bash — ! gets interpreted as history expansion
psql 'postgresql://pgadmin:Advocate2!@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require'

# Bash — even PGPASSWORD with ! can fail
PGPASSWORD='Advocate2!' psql -h pg-mybartenderdb.postgres.database.azure.com -U pgadmin -d mybartender
```

### Running from Git Bash (Claude Code / VS Code Terminal)

If your terminal is Git Bash, wrap the command in PowerShell:

```bash
powershell.exe -Command "psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' -c \"YOUR SQL HERE\""
```

### SQL Operator Note

When writing SQL through PowerShell, avoid `!=` (the `!` gets escaped). Use the SQL-standard `<>` operator instead:

```sql
-- This fails through PowerShell (! gets escaped to \!)
WHERE entitlement != 'paid'

-- This works
WHERE entitlement <> 'paid'
```

---

## User Subscription Schema

The `users` table contains these identity and subscription columns:

| Column | Type | Values | Purpose |
|--------|------|--------|---------|
| `id` | UUID | auto-generated | Internal primary key (used in foreign keys) |
| `azure_ad_sub` | TEXT | Entra External ID `sub` claim | Links to Entra identity provider |
| `email` | TEXT | user's email or NULL | Populated from Microsoft Graph API on sign-in (real email, not UPN). See [Email Population](#email-population-via-graph-api) |
| `display_name` | TEXT | user's name or NULL | Populated from JWT `name` claim on every API call — **most reliable identifier today** |
| `tier` | VARCHAR(20) | `free`, `premium`, `pro` | Legacy tier (still used for quota limits) |
| `entitlement` | TEXT | `paid`, `none` | **Primary access gate** — all Azure Functions check this |
| `subscription_status` | TEXT | `trialing`, `active`, `expired`, `none` | Subscription lifecycle state |
| `monthly_voice_minutes_included` | INTEGER | `30` (trial), `60` (pro) | Voice AI quota per billing cycle |
| `voice_minutes_used_this_cycle` | NUMERIC(8,2) | 0+ | Consumed voice minutes this cycle |
| `voice_minutes_purchased_balance` | NUMERIC(8,2) | 0+ | Top-up voice minutes remaining |
| `voice_cycle_started_at` | TIMESTAMPTZ | timestamp or NULL | When current voice cycle began |
| `billing_interval` | TEXT | `monthly`, `annual`, NULL | Subscription frequency |

### How Entitlement Checks Work

**4-layer paywall defense (v1.2.0+33 — April 2026):**

1. **Router-level gate (Flutter — primary enforcement):** `subscriptionGateProvider` is a synchronous tri-state provider (`checking | paid | unpaid`) read inside the GoRouter `redirect` function in `main.dart`. Resolution order: server-side kill switch → RevenueCat fast path → wait while async sources are loading → backend PostgreSQL authoritative check. Unpaid users are redirected to a dedicated `/paywall` full-screen route *before any screen mounts*. The cocktail deep-link redirect was restructured so unpaid users tapping a Today's Special notification also land on `/paywall` instead of the cocktail detail screen.
2. **Profile dual-source `isPaidProvider` (Flutter — Riverpod):** Checks RevenueCat SDK cache first (fast, local, no network). If RevenueCat says not-paid, falls back to `backendEntitlementProvider` (PostgreSQL authoritative, returns null until the user is authenticated). Displayed in Profile's subscription card.
3. **Per-screen `EntitlementRequiredException` handlers (Flutter):** Defense-in-depth in AI feature screens (Chat, Voice, Smart Scanner) in case the router gate is bypassed. Each catches 403 responses from the backend and shows a contextual paywall.
4. **Backend enforcement (Azure Functions):** Every protected function checks entitlement in PostgreSQL:

```javascript
if (user.entitlement !== 'paid') {
    return { status: 403, body: { error: 'entitlement_required' } };
}
```

**What gets gated:** as of v1.2.0+33, **every in-app feature requires `entitlement = 'paid'`** — Recipe Vault, My Bar, Favorites, Today's Special, Academy, Pro Tools, Create Studio, Social, Chat, Voice, Smart Scanner, and AI Refine. The only routes reachable without a paid entitlement are `/login`, `/age-verification`, `/paywall`, Sign Out, and Delete Account.

**Server-side kill switch:** `subscription-config` returns a `paywallEnabled` boolean controlled by the `PAYWALL_ENABLED` env var on the Function App (default `true`). Flipping it to `false` globally disables the router gate — `subscriptionGateProvider` short-circuits to `paid` for everyone. Use in an emergency rollback scenario when a paywall bug is breaking users and a new mobile release isn't viable in time.

**Why two sources of truth?** RevenueCat tracks real store purchases (Google Play / App Store). PostgreSQL `users.entitlement` is the authoritative column that backend functions check. They normally stay in sync via the RevenueCat webhook → `subscription_events` → `user_subscriptions` → trigger → `users.entitlement`. But for manual DB overrides (e.g., `UPDATE users SET entitlement = 'paid'` for beta testers and reviewer demo accounts), RevenueCat has no purchase record. `backendEntitlementProvider` bridges this gap on the mobile side — and since v1.2.0+33 it explicitly `ref.watch`es `authNotifierProvider` so the fetch is deferred until after sign-in (prevents a cached 401 failure from sticking around forever and breaking the override path).

---

## Finding a User

The `users` table has three identity columns that map to the same person:

| Column | Source | When to Use |
|--------|--------|-------------|
| `display_name` | JWT `name` claim (refreshed on every API call) | **Most practical today** — populated for most active users |
| `email` | Microsoft Graph API `GET /me` on sign-in | **Recommended** — populated via Microsoft Graph API on sign-in (Feb 26, 2026) |
| `azure_ad_sub` | Entra External ID `sub` claim (set on first login) | When you have the Entra identity token |
| `id` | Auto-generated UUID (internal primary key) | When referencing from other tables or scripts |

### Find by Display Name (Recommended — works today)

```sql
-- Partial match (case-insensitive)
SELECT id, email, display_name, tier, entitlement, subscription_status,
       monthly_voice_minutes_included, voice_minutes_used_this_cycle, last_login_at
FROM users
WHERE display_name ILIKE '%whitley%';
```

### Find by Email (Recommended)

```sql
SELECT id, email, display_name, tier, entitlement, subscription_status,
       monthly_voice_minutes_included, voice_minutes_used_this_cycle, last_login_at
FROM users
WHERE email = 'user@example.com';
```

### Find by Entra Sub Claim (Account ID)

The user's Entra sub is displayed as **"Account ID"** in the mobile app's Profile → Account Information card (tap to copy). This is also the RevenueCat App User ID. Ask the user to copy it from their profile and send it to you.

> **Note:** Use `LOWER()` for case-insensitive matching. RevenueCat normalizes App User IDs to lowercase, but the stored `azure_ad_sub` may contain mixed case. See `BUG_FIXES.md` SUB-004.

```sql
SELECT id, email, tier, entitlement, subscription_status
FROM users
WHERE LOWER(azure_ad_sub) = LOWER('THE-SUB-CLAIM-VALUE');
```

### List All Users

```sql
SELECT id, email, display_name, entitlement, subscription_status, last_login_at
FROM users
ORDER BY last_login_at DESC;
```

### Git Bash One-Liner: Find User by Display Name (works today)

```bash
powershell.exe -Command "psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' -c \"SELECT id, display_name, email, tier, entitlement, subscription_status FROM users WHERE display_name ILIKE '%whitley%';\""
```

### Git Bash One-Liner: Find User by Email

```bash
powershell.exe -Command "psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' -c \"SELECT id, email, tier, entitlement, subscription_status FROM users WHERE email = 'user@example.com';\""
```

---

## Common Operations

### View All Users and Their Status

```sql
SELECT id, email, tier, entitlement, subscription_status,
       monthly_voice_minutes_included, voice_minutes_used_this_cycle
FROM users;
```

### Set a Single User to Pro

```sql
-- By display_name (most practical today — use ILIKE for partial match)
UPDATE users
SET tier = 'pro',
    entitlement = 'paid',
    subscription_status = 'active',
    monthly_voice_minutes_included = 60,
    voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NOW(),
    updated_at = NOW()
WHERE display_name ILIKE '%whitley%';

-- By email
UPDATE users
SET tier = 'pro',
    entitlement = 'paid',
    subscription_status = 'active',
    monthly_voice_minutes_included = 60,
    voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NOW(),
    updated_at = NOW()
WHERE email = 'user@example.com';
```

> You can also use `WHERE id = 'UUID-HERE'` if you already have the user's UUID from a previous query.
> **Tip:** Always run a SELECT first to verify the display_name matches exactly one user before running UPDATE.

### Set ALL Users to Pro (Beta Testing)

```sql
UPDATE users
SET tier = 'pro',
    entitlement = 'paid',
    subscription_status = 'active',
    monthly_voice_minutes_included = 60,
    voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NOW(),
    updated_at = NOW()
WHERE entitlement <> 'paid' OR subscription_status <> 'active';
```

### Revert a User to Free Tier

```sql
-- By display_name (most practical today)
UPDATE users
SET tier = 'free',
    entitlement = 'none',
    subscription_status = 'none',
    monthly_voice_minutes_included = 0,
    voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NULL,
    updated_at = NOW()
WHERE display_name ILIKE '%username%';

-- By email
UPDATE users
SET tier = 'free',
    entitlement = 'none',
    subscription_status = 'none',
    monthly_voice_minutes_included = 0,
    voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NULL,
    updated_at = NOW()
WHERE email = 'user@example.com';
```

> You can also use `WHERE id = 'UUID-HERE'` if you already have the user's UUID from a previous query.

### Reset a User's Voice Minutes

```sql
-- By display_name (most practical today)
UPDATE users
SET voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NOW(),
    updated_at = NOW()
WHERE display_name ILIKE '%username%';

-- By email
UPDATE users
SET voice_minutes_used_this_cycle = 0,
    voice_cycle_started_at = NOW(),
    updated_at = NOW()
WHERE email = 'user@example.com';
```

> You can also use `WHERE id = 'UUID-HERE'` if you already have the user's UUID from a previous query.

### Find a User by Entra External ID Sub Claim

```sql
SELECT id, email, tier, entitlement, subscription_status
FROM users
WHERE LOWER(azure_ad_sub) = LOWER('THE-SUB-CLAIM-VALUE');
```

> **Important:** Always use `LOWER()` for `azure_ad_sub` lookups — RevenueCat normalizes IDs to lowercase. See `BUG_FIXES.md` SUB-004.
> See the [Finding a User](#finding-a-user) section above for the recommended email-based lookup approach.

### Delete a User Account (Apple Guideline 5.1.1(v))

Account deletion is normally done through the mobile app (Profile → Delete Account), which calls `DELETE /v1/users/me`. The backend deletes all data in a transaction using database cascades.

If you need to manually delete a user from SQL:

```sql
-- Step 1: Find the user and note both IDs
SELECT id, azure_ad_sub, display_name, email FROM users WHERE display_name ILIKE '%username%';

-- Step 2: Delete from user_profile (cascades to custom_recipes, recipe_share, share_invite, friendships)
DELETE FROM user_profile WHERE user_id = 'AZURE_AD_SUB_VALUE';

-- Step 3: Delete from users (cascades to user_inventory, usage_tracking, voice_sessions,
--   vision_scans, user_subscriptions, voice_addon_purchases, voice_purchase_transactions)
-- subscription_events.user_id is SET NULL (audit trail preserved)
DELETE FROM users WHERE azure_ad_sub = 'AZURE_AD_SUB_VALUE';
```

### Verify Account Deletion

```sql
-- All should return 0 rows
SELECT * FROM users WHERE display_name ILIKE '%username%';
SELECT * FROM user_profile WHERE user_id = 'AZURE_AD_SUB_VALUE';

-- Audit trail should still exist with user_id = NULL
SELECT id, event_type, user_id FROM subscription_events
WHERE revenuecat_app_user_id = 'AZURE_AD_SUB_VALUE';
```

> See `docs/DELETE_USER.md` for full details on the deletion architecture, cascade paths, and troubleshooting.

---

## Full One-Liner Examples (Git Bash → PowerShell)

**View all users:**

```bash
powershell.exe -Command "psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' -c \"SELECT id, email, tier, entitlement, subscription_status FROM users;\""
```

**Set all users to Pro:**

```bash
powershell.exe -Command "psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' -c \"UPDATE users SET tier = 'pro', entitlement = 'paid', subscription_status = 'active', monthly_voice_minutes_included = 60, voice_minutes_used_this_cycle = 0, voice_cycle_started_at = NOW(), updated_at = NOW() WHERE entitlement <> 'paid' OR subscription_status <> 'active';\""
```

---

## Email Population via Graph API

The `email` column in the `users` table is populated via **Microsoft Graph API** during Flutter sign-in (since Feb 26, 2026).

### Background

Entra External ID (CIAM) tokens do **not** include email claims even when the `email` optional claim is configured in Token Configuration. The `name` claim IS present (which is why `display_name` populates), but `email`, `emails`, `preferred_username`, and `unique_name` are all absent from CIAM tokens. Adding custom claims via the Enterprise App's Attributes & Claims blade triggers `AADSTS50146` (requires application-specific signing key), breaking authentication.

### Solution: 6-Layer Email Extraction Chain

The Flutter app uses a 6-layer fallback chain to resolve the user's real email during sign-in:

| Layer | Source | Works For |
|-------|--------|-----------|
| 1 | ID token `emails` array | Email sign-up users |
| 2 | ID token `email` / `preferred_username` / `unique_name` | Standard OIDC providers |
| 3 | MSAL `Account.username` | Some federated IdPs (no network cost) |
| 4 | Graph API `mail` field | Email sign-up users |
| 5 | Graph API `otherMails[0]` | Users with alternate emails |
| 6 | Graph API `identities[].issuerAssignedId` | Federated users (if email-format) |

Graph API call: `GET /me?$select=mail,otherMails,userPrincipalName,identities` using the MSAL access token (audience: `graph.microsoft.com`, scope: `User.Read`).

**Known limitation**: For Google-federated CIAM users, layers 1-5 may all return empty/null. Layer 6 checks `identities` but Google's `issuerAssignedId` is typically a numeric sub (not the email). Entra claim mapping may be needed to fully resolve this — see `docs/REVENUECAT_EMAIL_ID_ANALYSIS.md`.

**Code location**: `mobile/app/lib/src/services/auth_service.dart` → `_handleAuthResult()` (layers 1-3) and `_fetchEmailFromGraph()` (layers 4-6)

### How Email Reaches the Database

1. User signs in → Flutter calls Graph API → real email stored in `User.email`
2. Flutter sends `x-user-email` header with every API call (belt-and-suspenders, from Dio interceptor)
3. APIM extracts email from JWT if present (may still be empty for CIAM tokens)
4. Backend `getOrCreateUser()` writes email via `COALESCE($2, email)` — preserves existing data

Email populates on the user's **next sign-in** with the updated app.

### Verification

```sql
SELECT id, email, display_name, last_login_at
FROM users
ORDER BY last_login_at DESC
LIMIT 5;
```

Email should show real addresses (e.g., `paulawhitley1971@gmail.com`) for users who have signed in with the updated app.

---

## Related Tables

| Table | Purpose | Managed By |
|-------|---------|------------|
| `users` | Primary user record with entitlement columns | App + direct SQL |
| `user_subscriptions` | Active subscription details (product, expiry, auto-renew) | RevenueCat webhooks only |
| `subscription_events` | Immutable audit log of all subscription events | RevenueCat webhooks only |
| `voice_purchase_transactions` | One-time voice minute purchase records | RevenueCat webhooks only |

> **Note:** The `user_subscriptions` table has a PostgreSQL trigger (`sync_user_tier_from_subscription`) that automatically syncs changes to the `users` table. When making manual changes, update the `users` table directly — do not modify `user_subscriptions` unless you want the trigger to fire.

---

## RevenueCat Webhook Configuration

The `subscription-webhook` function receives RevenueCat server-to-server notifications:

- **Webhook URL**: `https://apim-mba-002.azure-api.net/api/v1/subscription/webhook` (routes through APIM)
- **Authentication**: RevenueCat sends `Authorization: Bearer <secret>` header
- **Secret**: `REVENUECAT_WEBHOOK_SECRET` app setting → Key Vault reference → `REVENUECAT-WEBHOOK-SECRET` in `kv-mybartenderai-prod`
- **Verified working**: Feb 25, 2026 (Android production), Feb 27, 2026 (iOS sandbox)
- **App User ID format** (Feb 26, 2026): All subscribers use the Entra `sub` claim (opaque GUID) as `app_user_id`. Email is set as the `$email` subscriber attribute for RevenueCat Ctrl+K dashboard search. Backend webhook looks up users via `WHERE LOWER(azure_ad_sub) = LOWER($1)` (case-insensitive — RevenueCat normalizes App User IDs to lowercase, but Entra subs contain mixed case; see `BUG_FIXES.md` SUB-004). The email lookup path (`WHERE LOWER(email)`) remains for backward compatibility. See `docs/REVENUECAT_EMAIL_ID_ANALYSIS.md` for the full redesign rationale
- **Auto-create on race condition** (Feb 27, 2026): If the webhook arrives before the mobile app's first API call creates the user record, the webhook now auto-creates a minimal user with `azure_ad_sub`, `$email`, and `$displayName` from the webhook payload. See `BUG_FIXES.md` SUB-005

### Troubleshooting Webhook 401 Errors

If the webhook starts returning 401:
1. Check that `REVENUECAT_WEBHOOK_SECRET` app setting is a Key Vault reference (not a raw value)
2. Verify the Key Vault reference resolves: `az functionapp config appsettings list --name func-mba-fresh --resource-group rg-mba-prod --query "[?name=='REVENUECAT_WEBHOOK_SECRET']"`
3. If it shows `@Microsoft.KeyVault(...)` but the function gets the literal string, **restart the Function App**: `az functionapp restart --name func-mba-fresh --resource-group rg-mba-prod`
4. Key Vault references sometimes don't resolve until the first restart after being set

### RevenueCat Dashboard Known Quirk

The **Customers list views** (Active subscription, Sandbox, etc.) may show 0 even when subscribers exist. This is a dashboard propagation delay for new projects. To verify subscribers:
- Use the **Overview** page (shows real-time metrics: Active Subscriptions, Revenue, MRR)
- Use **Ctrl+K** to search for a specific customer by app_user_id
- Use the RevenueCat REST API or MCP tools to query `get_overview_metrics`

---

## After Making Changes

- Users need to **close and reopen the app** (or pull-to-refresh on the profile screen) to fetch their updated status from the server
- The `users-me` Azure Function returns the current tier/entitlement on every call, so the app picks up changes on next API call
- RevenueCat webhook events will overwrite manual changes when real subscriptions are processed — this is expected and correct
