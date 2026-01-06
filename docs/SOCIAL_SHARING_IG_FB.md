# SOCIAL_SHARING_IG_FB.md

# Feature: Social Sharing — Instagram & Facebook (Phase 1 Only)

**App**: My AI Bartender  
**Status**: Ready for implementation  
**Phase**: Production / Release Candidate  
**Related**: `ARCHITECTURE.md`, relevant ADR for social tokens (e.g. `00XX-social-sharing-ig-fb-phase1.md`), `PLAN.md`

---

## 1. Scope & Non-Goals

### In Scope (Phase 1)

For a signed-in My AI Bartender user:

- Connect **Instagram** and/or **Facebook** to their account.
- From a cocktail detail screen:
  - Tap **“Share to Instagram”**
  - Tap **“Share to Facebook”**
- Backend posts **one cocktail** to the chosen provider with:
  - Cocktail hero image (from existing Blob asset)
  - Caption including:
    - Cocktail name
    - Short description / key ingredients
    - A referral-capable **share URL** to the recipe preview page (static HTML + deep link into app)

### Explicitly Out of Scope

Do **not** implement any of the following:

- No reading content from Instagram or Facebook (no feeds, no pulling posts).
- No in-app social feed / community timeline.
- No social engagement analytics pulled from Meta.
- No extra scopes beyond what is needed to:
  - Connect the account, and
  - Publish posts on the user’s behalf.

If it looks like “Phase 2 social features”, **do not build it**.

---

## 2. User Stories

1. **Connect provider**
   
   - As a user, I can connect my **Instagram** or **Facebook** account in Settings so that My AI Bartender can post cocktails on my behalf.

2. **Share a cocktail**
   
   - As a user, from any cocktail detail screen, I can tap **Share to Instagram** or **Share to Facebook** and have:
     - The correct cocktail image,
     - A meaningful caption,
     - And a link back to My AI Bartender posted to my chosen social account.

3. **Handle token issues cleanly**
   
   - As a user, if my connection expires or is invalid, sharing should fail with a clear message and offer a simple way to reconnect.

---

## 3. Backend Design (Azure Functions + APIM)

### 3.1 Endpoints (High Level)

All endpoints are exposed via **APIM** under the existing **My AI Bartender API**.

- `POST /social/{provider}/connect/start`
  
  - `provider ∈ {"instagram", "facebook"}`
  - Auth: Entra External ID JWT (pseudonymous `userId`), APIM product/subscription
  - Purpose: Start OAuth flow with Meta.

- `GET /social/{provider}/connect/callback`
  
  - Called by Meta (browser redirect).
  - Auth: Valid `state` param (CSRF protection).
  - Purpose: Exchange `code` for access token, persist encrypted token, then deep-link back to app.

- `POST /social/{provider}/share`
  
  - Auth: Entra External ID JWT, APIM product/subscription
  - Body:
    
    ```json
    {
      "cocktailId": "string"
    }
    ```
  - Purpose: Publish a single cocktail post (image + caption + link) to the connected provider.

### 3.2 Contracts (Concrete but Minimal)

**POST `/social/{provider}/connect/start`**

Request (JSON):

```json
{
  "redirectAfterAuth": "mybartender://social/connect/result" 
}
```

{
"authUrl": "https://www.facebook.com/vXX/dialog/oauth?...",
  "state": "opaque_csrf_token"
}

**GET `/social/{provider}/connect/callback`**

Query:

* `code` (from Meta)

* `state` (must match previously issued value)

Behavior:

* Validate `state`.

* Exchange `code` → access token with Meta Graph API.

* Upsert `social_accounts` record for (`userId`, `provider`).

* Return a small HTML page that **immediately triggers a deep link** back into the app, e.g.:
  
  * `mybartender://social/connect/result?provider=instagram&status=success`

**POST `/social/{provider}/share`**

{
"cocktailId": "old_fashioned_001"
}

{
"success": true,
  "provider": "instagram",
  "remotePostId": "1234567890"
}

{
"success": false,
  "provider": "instagram",
  "errorCode": "TOKEN_INVALID",
  "message": "Your Instagram connection has expired. Please reconnect and try again."
}

4. Data Model

-------------

### 4.1 `social_accounts` Table (PostgreSQL)

New table (pseudocode):

* `id` (UUID, PK)

* `user_id` (UUID, FK → internal users table)

* `provider` (ENUM: `instagram`, `facebook`)

* `provider_user_id` (STRING, can be hashed before storage)

* `access_token_ciphertext` (TEXT)

* `refresh_token_ciphertext` (TEXT, nullable)

* `token_expires_at` (TIMESTAMPTZ, nullable)

* `scopes` (JSONB or TEXT[]; minimal needed)

* `created_at` (TIMESTAMPTZ, default now)

* `updated_at` (TIMESTAMPTZ, default now)

* `last_used_at` (TIMESTAMPTZ, nullable)

Indexes:

* `idx_social_accounts_user_provider` on (`user_id`, `provider`)

### 4.2 Tokens & Security

* Encryption key stored in **Azure Key Vault** (e.g. `social-tokens-encryption-key`).

* Functions:
  
  * Load key at startup.
  
  * Encrypt/decrypt tokens in code.

* Logs:
  
  * Never log tokens or `provider_user_id`.
  
  * Only log:
    
    * `userId` (internal),
    
    * `provider`,
    
    * high-level error codes (e.g. `META_INVALID_TOKEN`, `META_RATE_LIMITED`).

* * *

5. Mobile App (Flutter) Behavior

--------------------------------

### 5.1 Settings Screen

* Show connection status for:
  
  * Instagram
  
  * Facebook

* Actions:
  
  * Connect / Reconnect → calls `POST /social/{provider}/connect/start`, opens `authUrl` in browser.
  
  * Handle callback via deep link and update status.
  
  * Optional: Disconnect (delete `social_accounts` row via a small backend endpoint if added later).

### 5.2 Cocktail Detail Screen

* For each recipe:
  
  * Buttons:
    
    * “Share to Instagram”
    
    * “Share to Facebook”

* If provider not connected:
  
  * Disable button or show a prompt to go to Settings to connect.

* On share:
  
  * Call `POST /social/{provider}/share` with `cocktailId`.
  
  * Show:
    
    * Success toast if `success: true`.
    
    * Clear error message + option to reconnect on `TOKEN_INVALID`.

* * *

6. Guardrails for Implementation (Important for Claude)

-------------------------------------------------------

These rules apply when implementing this feature:

1. **Do not modify or break existing features**
   
   * Do not change existing Functions, routes, DTOs, or Flutter screens unless they are explicitly part of this Social Sharing feature.
   
   * Prefer **new Functions** and **minimal diffs**.

2. **Respect existing architecture and docs**
   
   * `ARCHITECTURE.md`, ADRs, and `PLAN.md` are the source of truth.
   
   * Align Function naming, APIM routes, and data access with the existing patterns.

3. **Outbound-only social integration**
   
   * No new APIs that read data from Instagram or Facebook.
   
   * No new UI for showing IG/FB content inside the app.

4. **Security and privacy**
   
   * Pseudonymous `userId` only; no user names, emails, or DOB stored.
   
   * Social tokens must be encrypted at rest.
   
   * No secrets or tokens in logs, telemetry, or crash reports.

5. **Minimal, focused changes**
   
   * Only touch:
     
     * New social Functions,
     
     * `social_accounts` data model,
     
     * Settings + cocktail detail UI,
     
     * Any necessary configuration for Meta app IDs/secrets (via Key Vault/envs).

* * *

7. Implementation Checklist (For Claude / Other Implementers)

-------------------------------------------------------------

**Backend**

* Add `social_accounts` table migration.

* Implement Functions:
  
  * `POST /social/{provider}/connect/start`
  
  * `GET /social/{provider}/connect/callback`
  
  * `POST /social/{provider}/share`

* Integrate Meta Graph API for:
  
  * Code → token exchange
  
  * Posting media + caption

* Wire tokens encryption using Key Vault key.

* Update APIM:
  
  * Add `/social/*` operations under My AI Bartender API.
  
  * Apply JWT + subscription key validation.
  
  * Add rate limiting on social endpoints.

**Mobile**

* Settings screen:
  
  * Display IG/FB connection status.
  
  * Implement connect/reconnect flows.

* Cocktail detail screen:
  
  * Add “Share to Instagram/Facebook” actions.
  
  * Wire to `/social/{provider}/share` and handle responses.

* Deep-link handling for connect callback.

**Testing**

* Unit tests for token encryption/decryption and callback logic.

* Integration tests with Meta mocked:
  
  * Happy path connect + share.
  
  * Invalid/expired token.

* Widget tests for Settings + cocktail detail social UI.

* Manual test on real devices with Meta sandbox apps.
