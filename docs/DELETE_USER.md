# Account Deletion — Apple Guideline 5.1.1(v)

**Last Updated**: March 4, 2026

Apple requires all apps that support account creation to also offer account deletion. This document covers the full implementation across all layers.

---

## Overview

Account deletion removes **all** user data from PostgreSQL in a single transaction. The user is signed out and returned to the login screen. On next sign-in, a fresh account is created automatically (via `getOrCreateUser()`).

### What Gets Deleted

| Table | Deletion Method | Data Removed |
|-------|----------------|-------------|
| `user_profile` | Direct DELETE | Profile, alias, display name |
| `custom_recipes` | CASCADE from user_profile | User-created recipes |
| `recipe_share` | CASCADE from user_profile | Shared recipe records |
| `share_invite` | CASCADE from user_profile | Pending invite links |
| `friendships` | CASCADE from user_profile | Friend connections |
| `users` | Direct DELETE | Account record, email, entitlement, quotas |
| `user_inventory` | CASCADE from users | My Bar ingredients |
| `usage_tracking` | CASCADE from users | AI usage history |
| `voice_sessions` | CASCADE from users | Voice AI session records |
| `voice_messages` | CASCADE from voice_sessions | Voice conversation messages |
| `vision_scans` | CASCADE from users | Smart Scanner history |
| `user_subscriptions` | CASCADE from users | Subscription records |
| `voice_addon_purchases` | CASCADE from users | Voice minute purchases |
| `voice_purchase_transactions` | CASCADE from users | Purchase transaction records |
| `subscription_events` | SET NULL on user_id | **Preserved** — audit trail retained with user_id nulled |

### What Is NOT Deleted

- **Entra External ID account**: The identity provider account is not deleted. The user can still sign in — they'll get a fresh empty account.
- **RevenueCat subscriber record**: Store subscriptions persist in RevenueCat. If the user has an active subscription and re-signs in, the webhook will re-link them.
- **Subscription audit trail**: `subscription_events` rows are preserved with `user_id = NULL` for financial/compliance record-keeping.

---

## Architecture

```
Mobile App (Flutter)                    APIM                        Azure Function
─────────────────────               ────────────                ──────────────────
ProfileScreen                       validate-jwt                users-me/index.js
  └─ "Delete Account"              policy extracts:             (v4 pattern)
     ├─ Confirmation dialog #1       ├─ X-User-Id                │
     ├─ Confirmation dialog #2       ├─ X-User-Email             ├─ reads x-user-id
     └─ AuthNotifier.deleteAccount() └─ X-User-Name              ├─ DELETE user_profile
        ├─ BackendService.deleteAccount()  ───DELETE /v1/users/me──►  (CASCADE)
        │   └─ DELETE /v1/users/me                                ├─ DELETE users
        ├─ AuthService.signOut()                                  │   (CASCADE)
        └─ state = unauthenticated                                └─ return 200
```

### Authentication Flow

1. Mobile app sends `DELETE /v1/users/me` with JWT Bearer token
2. **APIM** validates the JWT and extracts the user's Entra `sub` claim into the `X-User-Id` header
3. **Backend function** reads `X-User-Id` from the header (does NOT re-validate JWT — trusts APIM)
4. Backend deletes all data in a transaction and returns `200`

> **Important**: The `users-me` function uses the v4 pattern (`request.headers.get('x-user-id')`) like all other endpoints. It does NOT do its own JWT validation.

---

## Backend Implementation

### File: `backend/functions/users-me/index.js`

The DELETE handler (lines 151-174):

```javascript
async function deleteAccount(userId) {
    return await db.transaction(async (client) => {
        // Step 1: Delete user_profile (TEXT PK = Entra sub)
        // Cascades to: custom_recipes, recipe_share, share_invite, friendships
        const profileResult = await client.query(
            'DELETE FROM user_profile WHERE user_id = $1',
            [userId]
        );

        // Step 2: Delete from users table (azure_ad_sub = Entra sub)
        // Cascades to: user_inventory, usage_tracking, voice_sessions → voice_messages,
        //   vision_scans, user_subscriptions, voice_addon_purchases, voice_purchase_transactions
        // SET NULL on: subscription_events (audit trail preserved)
        const userResult = await client.query(
            'DELETE FROM users WHERE azure_ad_sub = $1',
            [userId]
        );

        if (userResult.rowCount === 0 && profileResult.rowCount === 0) {
            throw new Error('User not found');
        }
    });
}
```

### Two DELETE Statements — Why?

The `users` and `user_profile` tables use **different primary keys** for the same user:

| Table | Key Column | Key Type | Value |
|-------|-----------|----------|-------|
| `user_profile` | `user_id` | TEXT | Entra `sub` claim directly |
| `users` | `id` | UUID | Auto-generated; `azure_ad_sub` column holds the Entra sub |

Both must be deleted separately because there's no foreign key between them — they're linked by the Entra sub value stored differently.

---

## APIM Configuration

### Operation: `users-me-delete`

| Property | Value |
|----------|-------|
| Display Name | Delete user account |
| Method | DELETE |
| URL Template | `/v1/users/me` |
| API | mybartenderai-api |

### JWT Validation Policy

The `users-me-delete` operation uses the same JWT policy as all authenticated operations:

- **Audience**: `f9f7f159-b847-4211-98c9-18e5b8193045` (mobile app client ID)
- **Issuer**: `https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0`
- **OpenID Config**: `https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration`
- **Header Extraction**: X-User-Id (sub), X-User-Email, X-User-Name

> **Historical note (March 4, 2026)**: The `users-me-get`, `users-me-update`, and `users-me-delete` operations were originally created with the wrong audience (`04551003...`, the API app registration instead of the mobile app client ID). This bug was hidden because the mobile app never called GET or PATCH on `/v1/users/me` through APIM. DELETE was the first call, which exposed the mismatch. All three were fixed simultaneously.

---

## Flutter Implementation

### BackendService (`mobile/app/lib/src/services/backend_service.dart`)

```dart
Future<bool> deleteAccount() async {
    try {
      final response = await _dio.delete('/v1/users/me');
      return response.statusCode == 200;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Authentication expired. Please sign in again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Account not found.');
      }
      throw Exception('Failed to delete account. Please try again.');
    }
  }
```

### AuthNotifier (`mobile/app/lib/src/providers/auth_provider.dart`)

```dart
Future<void> deleteAccount() async {
    try {
      // NOTE: Do NOT set state = AuthState.loading() here.
      // The profile screen shows its own loading dialog, and changing
      // auth state triggers RouterRefreshNotifier which can interfere
      // with the in-flight DELETE request.

      // Step 1: Delete all server-side data
      await _backendService.deleteAccount();

      // Step 2: Sign out (clear tokens, MSAL session)
      await _authService.signOut();
    } finally {
      state = const AuthState.unauthenticated();
    }
}
```

> **Why no `AuthState.loading()`?** Setting loading state triggers `RouterRefreshNotifier`, which can navigate away from the profile screen mid-request, causing the DELETE to fail or the success dialog to never appear.

### ProfileScreen (`mobile/app/lib/src/features/profile/profile_screen.dart`)

The UI presents two confirmation dialogs before deletion:
1. **First dialog**: "Delete Account?" with warning that this action cannot be undone
2. **Second dialog**: "Are you sure?" — requires the user to confirm again

On success, shows a brief "Account deleted" SnackBar, then the `AuthState.unauthenticated()` state change triggers the router to navigate to the login screen.

---

## Verification

### Check if a user was deleted

```sql
-- Should return 0 rows after deletion
SELECT id, display_name, email FROM users WHERE display_name ILIKE '%username%';
SELECT * FROM user_profile WHERE user_id = 'ENTRA_SUB_VALUE';
SELECT * FROM user_subscriptions WHERE user_id = 'USER_UUID';
SELECT * FROM user_inventory WHERE user_id = 'USER_UUID';
```

### Check audit trail preservation

```sql
-- subscription_events should still exist but with user_id = NULL
SELECT id, event_type, revenuecat_app_user_id, user_id, created_at
FROM subscription_events
WHERE revenuecat_app_user_id = 'ENTRA_SUB_VALUE';
```

### One-liner (macOS)

```bash
psql 'postgresql://pgadmin:Advocate2%21@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require' \
  -c "SELECT id, display_name, email FROM users WHERE display_name ILIKE '%huffman%';"
```

---

## Troubleshooting

### DELETE returns 401

1. **Check APIM policy audience**: Must be `f9f7f159-b847-4211-98c9-18e5b8193045` (mobile app client ID), not `04551003...` (API app registration)
2. **Check backend function**: `users-me/index.js` must read `x-user-id` from APIM header (v4 pattern), NOT do its own JWT validation
3. **Check token expiry**: If the user's JWT has expired, APIM rejects it. The mobile app should refresh the token before calling DELETE

### DELETE returns 404

The user's Entra `sub` doesn't match any `azure_ad_sub` or `user_profile.user_id` in the database. This can happen if:
- The user account was already deleted
- The user signed in with a different identity provider (different `sub` claim)

### User re-signs in after deletion

This is expected and correct. `getOrCreateUser()` in the backend creates a fresh user record on the next API call. The user starts with `free`/`none` entitlement. If they had an active subscription, the next RevenueCat webhook event will re-link them.

---

## Related Documentation

- `ARCHITECTURE.md` — Overall system architecture
- `SUBSCRIPTION_DEPLOYMENT.md` — Subscription system and webhook lifecycle
- `USER_SUBSCRIPTION_MANAGEMENT.md` — PostgreSQL admin guide
- `CLAUDE.md` — Project context and conventions

---

*Implemented: March 4, 2026*
*Verified: Account deletion tested end-to-end on iPhone 15 (iOS). All user data confirmed removed from PostgreSQL.*
