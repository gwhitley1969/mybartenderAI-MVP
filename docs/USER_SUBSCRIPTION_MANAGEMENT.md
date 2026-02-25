# User Subscription Management — PostgreSQL

**Last Updated**: February 25, 2026

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
| `email` | TEXT | user's email or NULL | Populated from JWT — **requires Entra `email` optional claim** (see [Entra Token Configuration](#entra-token-configuration-critical)) |
| `display_name` | TEXT | user's name or NULL | Populated from JWT `name` claim on every API call — **most reliable identifier today** |
| `tier` | VARCHAR(20) | `free`, `premium`, `pro` | Legacy tier (still used for quota limits) |
| `entitlement` | TEXT | `paid`, `none` | **Primary access gate** — all Azure Functions check this |
| `subscription_status` | TEXT | `trialing`, `active`, `expired`, `none` | Subscription lifecycle state |
| `monthly_voice_minutes_included` | INTEGER | `10` (trial), `60` (pro) | Voice AI quota per billing cycle |
| `voice_minutes_used_this_cycle` | NUMERIC(8,2) | 0+ | Consumed voice minutes this cycle |
| `voice_minutes_purchased_balance` | NUMERIC(8,2) | 0+ | Top-up voice minutes remaining |
| `voice_cycle_started_at` | TIMESTAMPTZ | timestamp or NULL | When current voice cycle began |
| `billing_interval` | TEXT | `monthly`, `annual`, NULL | Subscription frequency |

### How Entitlement Checks Work

**4-layer paywall defense (Feb 2026):**

1. **Dual-source `isPaidProvider` (Flutter — Riverpod):** Checks RevenueCat SDK cache first (fast, local, no network). If RevenueCat says not-paid, falls back to `backendEntitlementProvider` which fetches `entitlement` from the backend `subscription-status` endpoint (PostgreSQL authoritative source). This handles manual DB overrides (beta testers) and RevenueCat init failures. Result is cached per session. Includes `developer.log` diagnostic logging (filterable via `adb logcat | grep -i Subscription`).
2. **Pre-navigation gate (Flutter):** `navigateOrGate()` reads `isPaidProvider` at tap time. If the backend entitlement is still loading, it awaits the result before deciding. Free users see the subscription sheet *before* navigating to the AI screen. **11 buttons gated across 6 screens**: Home (Scan My Bar, Chat, Voice), Recipe Vault (Chat, Voice), Academy (Chat CTA, Voice CTA), Pro Tools (Chat CTA, Voice CTA), My Bar (AppBar scanner, empty-state Scanner).
3. **Per-screen handlers (Flutter):** Each AI screen catches `EntitlementRequiredException` from backend 403 responses and shows a contextual paywall. Profile screen also uses `isPaidProvider` (dual-source) for subscription card display.
4. **Backend enforcement (Azure Functions):** Every protected function checks entitlement in PostgreSQL:

```javascript
if (user.entitlement !== 'paid') {
    return { status: 403, body: { error: 'entitlement_required' } };
}
```

This gates access to: Voice AI, Smart Scanner, AI Bartender, and AI Refine. Free features (Recipe Vault browse/search, My Bar manual add/remove, Favorites, Today's Special, Academy content, Pro Tools content, Create Studio manual editing, Social sharing) are never gated.

**Why two sources of truth?** RevenueCat tracks real store purchases (Google Play / App Store). PostgreSQL `users.entitlement` is the authoritative column that backend functions check. They normally stay in sync via the RevenueCat webhook → `subscription_events` → `user_subscriptions` → trigger → `users.entitlement`. But for manual DB overrides (e.g., `UPDATE users SET entitlement = 'paid'` for beta testers), RevenueCat has no purchase record. The `backendEntitlementProvider` bridges this gap on the mobile side.

---

## Finding a User

The `users` table has three identity columns that map to the same person:

| Column | Source | When to Use |
|--------|--------|-------------|
| `display_name` | JWT `name` claim (refreshed on every API call) | **Most practical today** — populated for most active users |
| `email` | JWT `email` claim (requires Entra optional claim config) | **Best identifier once configured** — currently NULL for all users |
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

### Find by Email (once Entra email claim is configured)

```sql
SELECT id, email, display_name, tier, entitlement, subscription_status,
       monthly_voice_minutes_included, voice_minutes_used_this_cycle, last_login_at
FROM users
WHERE email = 'user@example.com';
```

### Find by Entra Sub Claim

```sql
SELECT id, email, tier, entitlement, subscription_status
FROM users
WHERE azure_ad_sub = 'THE-SUB-CLAIM-VALUE';
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

### Git Bash One-Liner: Find User by Email (once configured)

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

-- By email (once Entra email claim is configured)
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

-- By email (once Entra email claim is configured)
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

-- By email (once Entra email claim is configured)
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
WHERE azure_ad_sub = 'THE-SUB-CLAIM-VALUE';
```

> See the [Finding a User](#finding-a-user) section above for the recommended email-based lookup approach.

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

## Entra Token Configuration (Critical)

The `email` column in the `users` table is **NULL for all users** because the Entra External ID app registration does not include the `email` optional claim in ID tokens. The `name` claim IS present (which is why `display_name` populates), but no email claim exists in the token.

### Root Cause

App registration `f9f7f159-b847-4211-98c9-18e5b8193045` is missing the `email` optional claim on ID tokens. Without this, neither APIM extraction nor backend `jwtDecode.js` can find an email that isn't in the token.

### Fix: Add Email Optional Claim (Azure Portal)

1. Go to **Microsoft Entra admin center** → **Applications** → **App registrations**
2. Find app **`f9f7f159-b847-4211-98c9-18e5b8193045`**
3. Go to **Token configuration** → **Add optional claim**
4. Select **ID** token type → check **`email`** → Save
5. If prompted about Microsoft Graph `email` permission, **accept it**

**Why this is safe:** Adding an optional claim only adds data to the token payload. It doesn't change validation, audience, issuer, or any security properties. Existing app behavior is unchanged.

### What Happens After Configuration

- APIM's `GetValueOrDefault("email", "")` will find the claim in the JWT
- The `X-User-Email` header will be set correctly by APIM policy
- Backend `jwtDecode.js` will extract it and pass to `getOrCreateUser()`
- Email populates in the database on each user's **next API call** (no app rebuild needed)

### Verification

After configuring Entra, open the app and make any API call (chat, scan, etc.), then run:

```sql
SELECT id, email, display_name, last_login_at
FROM users
ORDER BY last_login_at DESC
LIMIT 5;
```

Email should now be populated for the user who just made the call.

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

## After Making Changes

- Users need to **close and reopen the app** (or pull-to-refresh on the profile screen) to fetch their updated status from the server
- The `users-me` Azure Function returns the current tier/entitlement on every call, so the app picks up changes on next API call
- RevenueCat webhook events will overwrite manual changes when real subscriptions are processed — this is expected and correct
