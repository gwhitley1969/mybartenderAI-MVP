# Implementation Plan: Friends via Code Feature

**For**: Sonnet 4.5 or other AI coding assistant
**Date**: November 14, 2025
**Priority**: High - Implement both flows simultaneously

## Overview

Implement a privacy-focused social sharing feature with two flows:

1. **Internal sharing** between app users via anonymous aliases
2. **External sharing** via invite links with static web previews

## Critical Design Decisions

### Aliases

- **System-generated only** (no user-chosen aliases)
- Format: `@{adjective}-{animal}-{3-digit-number}` (e.g., `@bitter-owl-592`)
- **Optional display name**: Users can add a 30-character display name shown alongside alias
- Share by alias only (the unique identifier), not display name

### Create Studio Recipe Sharing

- Support sharing both standard cocktails AND user-created recipes
- Custom recipes stored in separate table with full attribution
- Static previews include "Created by @alias using My AI Bartender"
- Future: Allow "remix" functionality

## Phase 1: Database Foundation (Implement First)

### Step 1.1: Create Migration File

**File**: `backend/functions/migrations/005_friends_via_code.sql`

```sql
-- User profile with system-generated alias
CREATE TABLE IF NOT EXISTS user_profile (
  user_id       TEXT PRIMARY KEY,              -- CIAM sub claim
  alias         TEXT UNIQUE NOT NULL,          -- e.g. '@bitter-owl-592'
  display_name  TEXT CHECK (char_length(display_name) <= 30), -- optional user-chosen name
  share_code    TEXT UNIQUE,                   -- optional backup code
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen     TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_user_profile_alias ON user_profile(alias);

-- Custom recipes from Create Studio
CREATE TABLE IF NOT EXISTS custom_recipes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  name          TEXT NOT NULL CHECK (char_length(name) <= 100),
  description   TEXT CHECK (char_length(description) <= 500),
  ingredients   JSONB NOT NULL,  -- [{name, amount, unit}]
  instructions  TEXT NOT NULL,
  glass_type    TEXT,
  garnish       TEXT,
  notes         TEXT,
  image_url     TEXT,            -- optional user-uploaded image
  is_public     BOOLEAN DEFAULT FALSE,
  allow_remix   BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_custom_recipes_user ON custom_recipes(user_id);

-- Recipe shares (both standard and custom)
CREATE TABLE IF NOT EXISTS recipe_share (
  id               BIGSERIAL PRIMARY KEY,
  from_user_id     TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  to_user_id       TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  recipe_id        TEXT,                    -- for standard cocktails
  custom_recipe_id UUID,                    -- for custom recipes
  recipe_type      TEXT NOT NULL CHECK (recipe_type IN ('standard', 'custom')),
  message          TEXT CHECK (char_length(message) <= 200),
  tagline          TEXT CHECK (char_length(tagline) <= 120),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  viewed_at        TIMESTAMPTZ,
  CONSTRAINT recipe_reference CHECK (
    (recipe_type = 'standard' AND recipe_id IS NOT NULL AND custom_recipe_id IS NULL) OR
    (recipe_type = 'custom' AND custom_recipe_id IS NOT NULL AND recipe_id IS NULL)
  )
);
CREATE INDEX idx_share_to_created ON recipe_share(to_user_id, created_at DESC);
CREATE INDEX idx_share_from_created ON recipe_share(from_user_id, created_at DESC);

-- External invite links
CREATE TABLE IF NOT EXISTS share_invite (
  token            TEXT PRIMARY KEY,           -- 22+ char random string
  recipe_id        TEXT,                       -- for standard cocktails
  custom_recipe_id UUID,                       -- for custom recipes
  recipe_type      TEXT NOT NULL CHECK (recipe_type IN ('standard', 'custom')),
  from_user_id     TEXT NOT NULL REFERENCES user_profile(user_id) ON DELETE CASCADE,
  message          TEXT CHECK (char_length(message) <= 200),
  tagline          TEXT CHECK (char_length(tagline) <= 120),
  one_time         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ DEFAULT (now() + interval '30 days'),
  claimed_by       TEXT REFERENCES user_profile(user_id),
  claimed_at       TIMESTAMPTZ,
  status           TEXT NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'claimed', 'expired', 'revoked')),
  CONSTRAINT invite_recipe_reference CHECK (
    (recipe_type = 'standard' AND recipe_id IS NOT NULL AND custom_recipe_id IS NULL) OR
    (recipe_type = 'custom' AND custom_recipe_id IS NOT NULL AND recipe_id IS NULL)
  )
);
CREATE INDEX idx_invite_from_created ON share_invite(from_user_id, created_at DESC);
```

### Step 1.2: Run Migration

```bash
# In Azure Functions project
npm run migrate
```

## Phase 2: Backend Functions Implementation

### Step 2.1: Alias Generation Utility

**File**: `backend/functions/shared/aliasGenerator.js`

```javascript
const adjectives = [
  'happy', 'clever', 'swift', 'bright', 'cool',
  'wild', 'calm', 'bold', 'wise', 'keen',
  'brave', 'quick', 'sharp', 'smooth', 'fresh',
  'crisp', 'warm', 'chill', 'mellow', 'zesty',
  'bitter', 'sweet', 'sour', 'spicy', 'tangy'
];

const animals = [
  'owl', 'fox', 'bear', 'wolf', 'hawk',
  'eagle', 'raven', 'lynx', 'otter', 'seal',
  'whale', 'shark', 'ray', 'crab', 'squid',
  'panda', 'koala', 'lemur', 'gecko', 'cobra'
];

function generateAlias() {
  const adjective = adjectives[Math.floor(Math.random() * adjectives.length)];
  const animal = animals[Math.floor(Math.random() * animals.length)];
  const number = Math.floor(Math.random() * 900) + 100; // 100-999
  return `@${adjective}-${animal}-${number}`;
}

module.exports = { generateAlias };
```

### Step 2.2: User Profile Endpoint

**File**: `backend/functions/users-me/index.js`

```javascript
// GET /v1/users/me
// Creates user profile if doesn't exist, returns alias
// Include proper JWT validation via APIM
```

### Step 2.3: Share Internal Endpoint

**File**: `backend/functions/social-share-internal/index.js`

```javascript
// POST /v1/social/share-internal
// Accepts: alias, recipeId OR customRecipeId, recipeType, message
// 1. Lookup recipient by alias
// 2. Insert into recipe_share
// 3. Send push notification via Azure Notification Hubs
// 4. Optional: Generate AI tagline with GPT-4o-mini
```

### Step 2.4: Create Invite Endpoint

**File**: `backend/functions/social-invite/index.js`

```javascript
// POST /v1/social/invite
// Accepts: recipeId OR customRecipeId, recipeType, message
// 1. Generate secure random token (22+ chars)
// 2. Insert into share_invite table
// 3. Generate static HTML page
// 4. Upload to Azure Blob Storage $web container
// 5. Return URL: https://share.mybartender.ai/i/{token}
```

### Step 2.5: Inbox/Outbox Endpoints

**Files**:

- `backend/functions/social-inbox/index.js`
- `backend/functions/social-outbox/index.js`

### Step 2.6: Push Registration

**File**: `backend/functions/push-register/index.js`

```javascript
// PUT /v1/push/register
// Register device with Azure Notification Hubs
// Tag format: "u:{user_id}"
```

## Phase 3: Azure Infrastructure Setup

### Step 3.1: Azure Notification Hubs

```bash
# Create Notification Hub namespace
az notification-hub namespace create \
  --resource-group rg-mba-prod \
  --name nhns-mybartenderai-prod \
  --sku Free \
  --location "South Central US"

# Create Notification Hub
az notification-hub create \
  --resource-group rg-mba-prod \
  --namespace-name nhns-mybartenderai-prod \
  --name nh-mybartenderai-prod

# Configure FCM (get from Firebase Console)
az notification-hub credential gcm update \
  --resource-group rg-mba-prod \
  --namespace-name nhns-mybartenderai-prod \
  --notification-hub-name nh-mybartenderai-prod \
  --google-api-key <FCM_SERVER_KEY>

# Configure APNs (get from Apple Developer)
az notification-hub credential apns update \
  --resource-group rg-mba-prod \
  --namespace-name nhns-mybartenderai-prod \
  --notification-hub-name nh-mybartenderai-prod \
  --apns-certificate <P12_CERT_BASE64> \
  --certificate-key <CERT_PASSWORD>
```

### Step 3.2: Blob Storage Static Website

```bash
# Enable static website
az storage blob service-properties update \
  --account-name mbacocktaildb3 \
  --static-website \
  --index-document index.html \
  --404-document 404.html

# The static website will be available at:
# https://mbacocktaildb3.z13.web.core.windows.net
```

### Step 3.3: Domain Configuration

1. Purchase `mybartender.ai` domain (if not owned)
2. Add CNAME record: `share.mybartenderai.com` → `mbacocktaildb3.z13.web.core.windows.net`
3. Configure custom domain in Azure Storage

### Step 3.4: Key Vault Secrets

```bash
# Add Notification Hub connection string
az keyvault secret set \
  --vault-name kv-mybartenderai-prod \
  --name NOTIFICATION-HUB-CONNECTION \
  --value "<NH_CONNECTION_STRING>"
```

## Phase 4: APIM Configuration

### Step 4.1: OpenAPI Specification Update

**File**: `spec/openapi-social.yaml`

Add all new endpoints with proper schemas.

### Step 4.2: APIM Policy Update

```xml
<policies>
  <inbound>
    <base />
    <!-- JWT validation -->
    <validate-jwt header-name="Authorization" require-expiration-time="true">
      <openid-config url="https://mybartenderai.ciamlogin.com/{tenantId}/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience>04551003-a57c-4dc2-97a1-37e0b3d1a2f6</audience>
      </audiences>
      <required-claims>
        <claim name="age_verified" value="true" />
      </required-claims>
    </validate-jwt>

    <!-- Extract user ID -->
    <set-variable name="userSub" value="@(context.Request.Jwt.Claims.GetValueOrDefault("sub", ""))" />

    <!-- Per-user rate limits for sharing -->
    <rate-limit-by-key calls="5" renewal-period="60"
      counter-key="@("share-" + context.Variables.GetValueOrDefault<string>("userSub"))"
      increment-condition="@(context.Request.Url.Path.Contains("/social/share"))" />

    <!-- Daily quota -->
    <quota-by-key calls="100" renewal-period="86400"
      counter-key="@("share-quota-" + context.Variables.GetValueOrDefault<string>("userSub"))"
      increment-condition="@(context.Request.Url.Path.Contains("/social/share"))" />

    <!-- Forward user ID to backend -->
    <set-header name="X-User-Id" exists-action="override">
      <value>@(context.Variables.GetValueOrDefault<string>("userSub"))</value>
    </set-header>
  </inbound>
</policies>
```

## Phase 5: Flutter Mobile App Implementation

### Step 5.1: Models

**File**: `mobile/app/lib/src/models/social_models.dart`

```dart
@freezed
class UserProfile with _$UserProfile {
  factory UserProfile({
    required String userId,
    required String alias,
    String? displayName,
    String? shareCode,
    required DateTime createdAt,
  }) = _UserProfile;
}

@freezed
class RecipeShare with _$RecipeShare {
  factory RecipeShare({
    required String id,
    required String senderAlias,
    String? senderDisplayName,
    required String recipeId,
    String? customRecipeId,
    required RecipeType recipeType,
    required String recipeName,
    String? message,
    String? tagline,
    required DateTime createdAt,
    DateTime? viewedAt,
  }) = _RecipeShare;
}

enum RecipeType { standard, custom }
```

### Step 5.2: Services

**Files**:

- `mobile/app/lib/src/services/social_service.dart`
- `mobile/app/lib/src/services/push_notification_service.dart`

### Step 5.3: UI Screens

**Files**:

- `mobile/app/lib/src/features/profile/profile_screen.dart` (show alias)
- `mobile/app/lib/src/features/social/share_recipe_screen.dart`
- `mobile/app/lib/src/features/social/inbox_screen.dart`
- `mobile/app/lib/src/features/social/outbox_screen.dart`

### Step 5.4: Firebase Setup

1. Add Firebase to Flutter project
2. Configure Firebase Messaging
3. Handle push notifications
4. Register device tokens with backend

## Phase 6: Static HTML Template

### Step 6.1: Create HTML Template

**File**: `backend/functions/templates/invite-preview.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{recipeName}} - MyBartenderAI</title>
  <meta property="og:title" content="{{recipeName}}" />
  <meta property="og:description" content="{{tagline}}" />
  <style>
    /* Mobile-first responsive design */
    body { font-family: system-ui, -apple-system, sans-serif; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .recipe-card { background: #fff; border-radius: 12px; padding: 24px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
    .ingredients { background: #f5f5f5; padding: 16px; border-radius: 8px; margin: 16px 0; }
    .cta-button { display: inline-block; background: #007AFF; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; }
    .attribution { color: #666; font-size: 14px; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="recipe-card">
      <h1>{{recipeName}}</h1>
      {{#if tagline}}<p class="tagline">{{tagline}}</p>{{/if}}
      {{#if message}}<blockquote>"{{message}}"</blockquote>{{/if}}

      <div class="ingredients">
        <h3>Ingredients</h3>
        <ul>
          {{#each ingredients}}
          <li>{{amount}} {{unit}} {{name}}</li>
          {{/each}}
        </ul>
      </div>

      <div class="instructions">
        <h3>Instructions</h3>
        <p>{{instructions}}</p>
      </div>

      {{#if customRecipe}}
      <p class="attribution">Created by {{senderAlias}} using MyBartenderAI Create Studio</p>
      {{/if}}

      <div class="cta">
        <a href="mybartender://claim?token={{token}}" class="cta-button">Open in MyBartenderAI</a>
        <p>Don't have the app? <a href="https://mybartender.ai/download">Download it here</a></p>
      </div>
    </div>
  </div>
</body>
</html>
```

## Testing Checklist

### Database Tests

- [ ] User profile creation with unique alias
- [ ] Alias uniqueness constraint
- [ ] Custom recipe storage
- [ ] Recipe share with both types
- [ ] Invite token generation and expiry

### API Tests

- [ ] JWT validation on all endpoints
- [ ] Rate limiting (5/min, 100/day)
- [ ] Alias lookup (valid and invalid)
- [ ] Push notification delivery
- [ ] Static HTML generation
- [ ] Blob storage upload

### Flutter Tests

- [ ] Alias display in profile
- [ ] Share by alias flow
- [ ] Share link generation
- [ ] Inbox/outbox display
- [ ] Push notification handling
- [ ] Deep link handling for invites

### Integration Tests

- [ ] End-to-end internal share
- [ ] End-to-end external share
- [ ] Invite claim flow
- [ ] Custom recipe sharing
- [ ] Push notification delivery

## Security Considerations

1. **No PII Storage**: Only store user_id, alias, and user-generated content
2. **Token Security**: Use cryptographically secure random tokens (22+ chars)
3. **Rate Limiting**: Prevent spam via APIM policies
4. **Input Validation**: Validate all inputs, especially alias format
5. **SQL Injection**: Use parameterized queries
6. **XSS Prevention**: Sanitize HTML in static pages
7. **JWT Validation**: Verify age_verified claim

## Monitoring

1. **Application Insights Events**:
   
   - `ShareCreated` (internal/external)
   - `InviteClaimed`
   - `PushSent`
   - `AliasGenerated`

2. **Metrics**:
   
   - Shares per day
   - Invite conversion rate
   - Push delivery rate
   - Custom vs standard recipe shares

## Rollback Plan

If issues arise:

1. Disable new endpoints in APIM
2. Keep database tables (no data loss)
3. Feature flag in mobile app
4. Fix issues and re-deploy

## Success Criteria

1. **Internal Sharing**: 95% push delivery rate
2. **External Sharing**: Static pages load in <2 seconds
3. **No PII Leaks**: Audit confirms no personal data stored
4. **Rate Limits**: No user can exceed 100 shares/day
5. **Custom Recipes**: Users can share Create Studio recipes

---

**Implementation Order**:

1. Database setup (Day 1)
2. User profile & alias endpoints (Day 2-3)
3. Internal sharing + push (Day 4-6)
4. External sharing + static HTML (Day 7-9)
5. Flutter UI implementation (Day 10-14)
6. Testing & refinement (Day 15-16)

**Total Estimated Time**: 16 days for full implementation

This plan provides explicit, step-by-step instructions that Sonnet 3.5 can follow to implement the complete feature.
