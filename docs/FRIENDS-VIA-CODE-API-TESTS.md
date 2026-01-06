# Friends via Code - API Test Scenarios

## Overview

This document provides comprehensive test scenarios for all Friends via Code API endpoints. Each scenario includes request format, expected responses, and edge cases.

## Test Data Setup

### Test Users
```json
{
  "user1": {
    "userId": "test-user-123",
    "alias": "@happy-penguin-42",
    "displayName": "TestUser1",
    "tier": "premium"
  },
  "user2": {
    "userId": "test-user-456",
    "alias": "@clever-dolphin-99",
    "displayName": "TestUser2",
    "tier": "free"
  },
  "user3": {
    "userId": "test-user-789",
    "alias": "@swift-eagle-17",
    "displayName": null,
    "tier": "pro"
  }
}
```

### Test Recipes
```json
{
  "standard": {
    "recipeId": 11007,
    "name": "Margarita"
  },
  "custom": {
    "customRecipeId": "custom-123-abc",
    "name": "Blue Sunset",
    "creatorAlias": "@happy-penguin-42"
  }
}
```

## 1. User Profile Management

### 1.1 Generate Alias - POST /v1/social/profile/generate-alias

**Test Case 1: First-time alias generation**
```http
POST /v1/social/profile/generate-alias
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "alias": "@happy-penguin-42",
  "displayName": null,
  "createdAt": "2025-11-14T10:00:00Z"
}
```

**Test Case 2: Duplicate generation attempt**
```http
POST /v1/social/profile/generate-alias
Authorization: Bearer {valid_jwt_existing_user}
X-Subscription-Key: {valid_apim_key}

Expected Response: 409 Conflict
{
  "error": "ALIAS_EXISTS",
  "message": "User already has an alias",
  "existingAlias": "@happy-penguin-42"
}
```

**Test Case 3: Invalid authentication**
```http
POST /v1/social/profile/generate-alias
Authorization: Bearer {invalid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 401 Unauthorized
{
  "error": "INVALID_TOKEN",
  "message": "JWT validation failed"
}
```

### 1.2 Update Display Name - PUT /v1/social/profile

**Test Case 1: Valid display name update**
```http
PUT /v1/social/profile
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "displayName": "CocktailMaster"
}

Expected Response: 200 OK
{
  "alias": "@happy-penguin-42",
  "displayName": "CocktailMaster",
  "updatedAt": "2025-11-14T10:05:00Z"
}
```

**Test Case 2: Display name too long**
```http
PUT /v1/social/profile
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "displayName": "ThisNameIsWayTooLongAndExceedsTheThirtyCharacterLimit"
}

Expected Response: 400 Bad Request
{
  "error": "INVALID_DISPLAY_NAME",
  "message": "Display name must be 30 characters or less"
}
```

**Test Case 3: Invalid characters in display name**
```http
PUT /v1/social/profile
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "displayName": "User<script>alert('xss')</script>"
}

Expected Response: 400 Bad Request
{
  "error": "INVALID_DISPLAY_NAME",
  "message": "Display name contains invalid characters"
}
```

## 2. Recipe Sharing

### 2.1 Share Standard Recipe - POST /v1/social/share

**Test Case 1: Share standard recipe successfully**
```http
POST /v1/social/share
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "recipeType": "standard",
  "recipeId": 11007,
  "customMessage": "Try this amazing Margarita!"
}

Expected Response: 200 OK
{
  "shareCode": "MARG-7X9K-2024",
  "shareUrl": "https://share.mybartender.ai/MARG-7X9K-2024",
  "expiresAt": "2025-12-14T10:00:00Z",
  "recipe": {
    "type": "standard",
    "id": 11007,
    "name": "Margarita"
  }
}
```

**Test Case 2: Share custom recipe**
```http
POST /v1/social/share
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "recipeType": "custom",
  "customRecipeId": "custom-123-abc",
  "customMessage": "My signature cocktail creation!"
}

Expected Response: 200 OK
{
  "shareCode": "BLUE-3K9X-2024",
  "shareUrl": "https://share.mybartender.ai/BLUE-3K9X-2024",
  "expiresAt": "2025-12-14T10:00:00Z",
  "recipe": {
    "type": "custom",
    "id": "custom-123-abc",
    "name": "Blue Sunset",
    "creatorAlias": "@happy-penguin-42"
  }
}
```

**Test Case 3: Share non-existent recipe**
```http
POST /v1/social/share
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "recipeType": "standard",
  "recipeId": 99999
}

Expected Response: 404 Not Found
{
  "error": "RECIPE_NOT_FOUND",
  "message": "Recipe with ID 99999 not found"
}
```

**Test Case 4: Share custom recipe not owned by user**
```http
POST /v1/social/share
Authorization: Bearer {valid_jwt_user2}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "recipeType": "custom",
  "customRecipeId": "custom-123-abc"
}

Expected Response: 403 Forbidden
{
  "error": "NOT_RECIPE_OWNER",
  "message": "You can only share your own custom recipes"
}
```

**Test Case 5: Message too long**
```http
POST /v1/social/share
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "recipeType": "standard",
  "recipeId": 11007,
  "customMessage": "This message is way too long..." // 201+ characters
}

Expected Response: 400 Bad Request
{
  "error": "MESSAGE_TOO_LONG",
  "message": "Custom message must be 200 characters or less"
}
```

### 2.2 Get Share Info - GET /v1/social/share/{shareCode}

**Test Case 1: Valid share code**
```http
GET /v1/social/share/MARG-7X9K-2024
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "shareCode": "MARG-7X9K-2024",
  "recipe": {
    "type": "standard",
    "id": 11007,
    "name": "Margarita",
    "imageUrl": "https://mbacocktaildb3.blob.core.windows.net/images/11007.jpg",
    "ingredients": ["Tequila", "Triple sec", "Lime juice", "Salt"],
    "instructions": "Rub the rim of the glass..."
  },
  "sharer": {
    "alias": "@happy-penguin-42",
    "displayName": "CocktailMaster"
  },
  "customMessage": "Try this amazing Margarita!",
  "expiresAt": "2025-12-14T10:00:00Z",
  "viewCount": 5
}
```

**Test Case 2: Expired share code**
```http
GET /v1/social/share/OLD-CODE-2023
X-Subscription-Key: {valid_apim_key}

Expected Response: 410 Gone
{
  "error": "SHARE_EXPIRED",
  "message": "This share link has expired"
}
```

**Test Case 3: Invalid share code format**
```http
GET /v1/social/share/INVALID
X-Subscription-Key: {valid_apim_key}

Expected Response: 400 Bad Request
{
  "error": "INVALID_SHARE_CODE",
  "message": "Share code format is invalid"
}
```

## 3. Friend Invitations

### 3.1 Send Friend Invite - POST /v1/social/invite

**Test Case 1: Send invite successfully**
```http
POST /v1/social/invite
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "message": "Let's share cocktail recipes!"
}

Expected Response: 200 OK
{
  "inviteCode": "FRN-8K3M-2024",
  "inviteUrl": "https://share.mybartender.ai/invite/FRN-8K3M-2024",
  "expiresAt": "2025-11-21T10:00:00Z"
}
```

**Test Case 2: Too many pending invites**
```http
POST /v1/social/invite
Authorization: Bearer {valid_jwt_with_5_pending}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "message": "Another invite"
}

Expected Response: 429 Too Many Requests
{
  "error": "TOO_MANY_INVITES",
  "message": "Maximum of 5 pending invites allowed",
  "pendingCount": 5
}
```

### 3.2 Accept Friend Invite - POST /v1/social/invite/{inviteCode}/accept

**Test Case 1: Accept valid invite**
```http
POST /v1/social/invite/FRN-8K3M-2024/accept
Authorization: Bearer {valid_jwt_user2}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "success": true,
  "friend": {
    "alias": "@happy-penguin-42",
    "displayName": "CocktailMaster"
  },
  "message": "You are now friends with @happy-penguin-42"
}
```

**Test Case 2: Accept own invite**
```http
POST /v1/social/invite/FRN-8K3M-2024/accept
Authorization: Bearer {valid_jwt_user1}
X-Subscription-Key: {valid_apim_key}

Expected Response: 400 Bad Request
{
  "error": "CANNOT_ACCEPT_OWN_INVITE",
  "message": "You cannot accept your own invitation"
}
```

**Test Case 3: Already friends**
```http
POST /v1/social/invite/FRN-9X2K-2024/accept
Authorization: Bearer {valid_jwt_already_friends}
X-Subscription-Key: {valid_apim_key}

Expected Response: 409 Conflict
{
  "error": "ALREADY_FRIENDS",
  "message": "You are already friends with @happy-penguin-42"
}
```

## 4. Friends List Management

### 4.1 Get Friends List - GET /v1/social/friends

**Test Case 1: Get friends with pagination**
```http
GET /v1/social/friends?page=1&limit=20
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "friends": [
    {
      "alias": "@clever-dolphin-99",
      "displayName": "TestUser2",
      "friendsSince": "2025-11-10T15:30:00Z",
      "sharedRecipes": 3,
      "lastActivity": "2025-11-14T09:00:00Z"
    },
    {
      "alias": "@swift-eagle-17",
      "displayName": null,
      "friendsSince": "2025-11-08T12:00:00Z",
      "sharedRecipes": 0,
      "lastActivity": "2025-11-12T14:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 2,
    "hasMore": false
  }
}
```

**Test Case 2: Empty friends list**
```http
GET /v1/social/friends
Authorization: Bearer {valid_jwt_no_friends}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "friends": [],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 0,
    "hasMore": false
  }
}
```

### 4.2 Remove Friend - DELETE /v1/social/friends/{alias}

**Test Case 1: Remove friend successfully**
```http
DELETE /v1/social/friends/@clever-dolphin-99
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "success": true,
  "message": "Friend removed successfully"
}
```

**Test Case 2: Remove non-existent friend**
```http
DELETE /v1/social/friends/@unknown-user-99
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 404 Not Found
{
  "error": "NOT_FRIENDS",
  "message": "You are not friends with @unknown-user-99"
}
```

## 5. Feed and Activity

### 5.1 Get Friend Activity Feed - GET /v1/social/feed

**Test Case 1: Get recent activity**
```http
GET /v1/social/feed?limit=10
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "activities": [
    {
      "id": "activity-123",
      "type": "recipe_shared",
      "friend": {
        "alias": "@clever-dolphin-99",
        "displayName": "TestUser2"
      },
      "recipe": {
        "type": "standard",
        "id": 17222,
        "name": "A1"
      },
      "timestamp": "2025-11-14T09:00:00Z",
      "message": "Just discovered this classic!"
    },
    {
      "id": "activity-124",
      "type": "recipe_created",
      "friend": {
        "alias": "@swift-eagle-17",
        "displayName": null
      },
      "recipe": {
        "type": "custom",
        "id": "custom-456-def",
        "name": "Tropical Storm"
      },
      "timestamp": "2025-11-13T18:00:00Z"
    }
  ],
  "hasMore": true,
  "lastActivityId": "activity-124"
}
```

**Test Case 2: Pagination with lastActivityId**
```http
GET /v1/social/feed?limit=10&after=activity-124
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 200 OK
{
  "activities": [...],
  "hasMore": false,
  "lastActivityId": "activity-130"
}
```

## 6. Error Scenarios

### 6.1 Rate Limiting

**Test Case: Exceed rate limit**
```http
# Send 11 requests within 1 minute
POST /v1/social/share (×11)
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response on 11th request: 429 Too Many Requests
{
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Too many requests. Please try again later.",
  "retryAfter": 60
}
```

### 6.2 Invalid JWT

**Test Case: Expired JWT**
```http
GET /v1/social/friends
Authorization: Bearer {expired_jwt}
X-Subscription-Key: {valid_apim_key}

Expected Response: 401 Unauthorized
{
  "error": "TOKEN_EXPIRED",
  "message": "JWT has expired"
}
```

### 6.3 Invalid APIM Key

**Test Case: Missing subscription key**
```http
GET /v1/social/friends
Authorization: Bearer {valid_jwt}

Expected Response: 401 Unauthorized
{
  "error": "MISSING_SUBSCRIPTION_KEY",
  "message": "Subscription key is required"
}
```

## 7. Batch Operations

### 7.1 Get Multiple Recipes - POST /v1/social/recipes/batch

**Test Case: Get mixed recipe types**
```http
POST /v1/social/recipes/batch
Authorization: Bearer {valid_jwt}
X-Subscription-Key: {valid_apim_key}
Content-Type: application/json

{
  "recipes": [
    {"type": "standard", "id": 11007},
    {"type": "standard", "id": 17222},
    {"type": "custom", "id": "custom-123-abc"}
  ]
}

Expected Response: 200 OK
{
  "recipes": [
    {
      "type": "standard",
      "id": 11007,
      "name": "Margarita",
      "found": true
    },
    {
      "type": "standard",
      "id": 17222,
      "name": "A1",
      "found": true
    },
    {
      "type": "custom",
      "id": "custom-123-abc",
      "name": "Blue Sunset",
      "creatorAlias": "@happy-penguin-42",
      "found": true
    }
  ]
}
```

## 8. Analytics Events

### 8.1 Track Share View - POST /v1/social/share/{shareCode}/view

**Test Case: Track anonymous view**
```http
POST /v1/social/share/MARG-7X9K-2024/view
Content-Type: application/json

{
  "source": "web",
  "userAgent": "Mozilla/5.0..."
}

Expected Response: 204 No Content
```

### 8.2 Track Share Click - POST /v1/social/share/{shareCode}/click

**Test Case: Track app install click**
```http
POST /v1/social/share/MARG-7X9K-2024/click
Content-Type: application/json

{
  "action": "install_app",
  "platform": "android"
}

Expected Response: 204 No Content
```

## Testing Checklist

### Unit Tests
- [ ] JWT validation with correct JWKS endpoint
- [ ] Alias generation uniqueness
- [ ] Display name validation
- [ ] Share code generation and expiry
- [ ] Friend relationship symmetry
- [ ] Rate limiting logic
- [ ] Custom recipe ownership validation

### Integration Tests
- [ ] End-to-end share flow (create → view → accept)
- [ ] Friend invite flow (send → accept → verify friendship)
- [ ] Push notification delivery
- [ ] Static website preview generation
- [ ] Database transaction consistency
- [ ] APIM quota enforcement

### Load Tests
- [ ] 1000 concurrent share creations
- [ ] 5000 share views per minute
- [ ] Friend list with 500+ friends
- [ ] Activity feed with 10000+ items

### Security Tests
- [ ] SQL injection in all text fields
- [ ] XSS in display names and messages
- [ ] JWT signature validation
- [ ] Rate limit bypass attempts
- [ ] Authorization checks for all endpoints
- [ ] CORS configuration validation

### Edge Cases
- [ ] Unicode characters in display names
- [ ] Maximum length inputs
- [ ] Concurrent friend operations
- [ ] Network failures and retries
- [ ] Database deadlocks
- [ ] Expired tokens mid-flow

## Performance Benchmarks

### Response Time Targets
- Profile operations: < 200ms
- Share creation: < 300ms
- Friend list (20 items): < 250ms
- Activity feed (10 items): < 300ms
- Batch recipe fetch (10 items): < 400ms

### Throughput Targets
- 100 shares/second
- 500 profile reads/second
- 50 friend accepts/second
- 1000 share views/second

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Next Review**: Post-implementation testing phase