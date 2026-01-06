# Friends via Code - API Documentation

## Overview

The Friends via Code API enables users to share cocktail recipes internally (by alias) and externally (via invite links). All endpoints require JWT authentication and are rate-limited based on user tier.

## Base URLs

- **APIM Gateway**: `https://apim-mba-002.azure-api.net/api`
- **Function App (Direct)**: `https://func-mba-fresh.azurewebsites.net/api`

**Note**: Always use APIM gateway in production for proper authentication, rate limiting, and analytics.

## Authentication

All endpoints require a valid JWT token from Entra External ID:

```http
Authorization: Bearer <JWT_TOKEN>
```

### JWT Claims Required

- `sub`: User ID (required)
- `tier` or `subscription_tier`: User tier (free, premium, pro) - defaults to "free"

## Rate Limits

### Per-User Rate Limiting

- **Burst Protection**: 5 requests per minute
- **Daily Quota** (tier-based):
  - **Free**: 100 requests/day
  - **Premium**: 1,000 requests/day
  - **Pro**: 5,000 requests/day

### Response Headers

```http
X-RateLimit-Limit-Minute: 5
X-Quota-Limit-Day: 100
X-User-Tier: free
```

### Rate Limit Errors

**HTTP 429 - Rate Limit Exceeded**
```json
{
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Rate limit exceeded. Maximum 5 requests per minute.",
  "retryAfter": 60,
  "traceId": "00-abc123..."
}
```

**HTTP 429 - Quota Exceeded**
```json
{
  "error": "QUOTA_EXCEEDED",
  "message": "Daily quota exceeded. Upgrade your plan for higher limits.",
  "tier": "free",
  "dailyLimit": 100,
  "retryAfter": 86400,
  "traceId": "00-abc123..."
}
```

## Endpoints

### 1. User Profile Management

#### GET /v1/users/me

Get current user's profile. Creates profile automatically on first access.

**Request**
```http
GET /api/v1/users/me
Authorization: Bearer <JWT_TOKEN>
```

**Response 200 OK**
```json
{
  "userId": "00000000-0000-0000-0000-000000000000",
  "alias": "@happy-dolphin-742",
  "displayName": null,
  "createdAt": "2025-11-15T20:00:00Z",
  "lastSeen": "2025-11-15T20:00:00Z"
}
```

**Response 401 Unauthorized**
```json
{
  "error": "UNAUTHORIZED",
  "message": "Valid authentication token required. Please sign in.",
  "traceId": "00-abc123..."
}
```

---

#### PATCH /v1/users/me

Update user profile (display name only).

**Request**
```http
PATCH /api/v1/users/me
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "displayName": "John Doe"
}
```

**Response 200 OK**
```json
{
  "userId": "00000000-0000-0000-0000-000000000000",
  "alias": "@happy-dolphin-742",
  "displayName": "John Doe",
  "createdAt": "2025-11-15T20:00:00Z",
  "lastSeen": "2025-11-15T20:30:00Z"
}
```

**Response 400 Bad Request**
```json
{
  "error": "INVALID_REQUEST",
  "message": "Display name is required"
}
```

---

### 2. Internal Recipe Sharing

#### POST /v1/social/share-internal

Share a recipe with another user by their alias.

**Request**
```http
POST /api/v1/social/share-internal
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "recipeId": "12345",
  "recipeName": "Margarita",
  "recipeType": "standard",
  "recipientAlias": "@cool-panda-123",
  "message": "Try this amazing margarita!"
}
```

**Request Body Fields**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `recipeId` | string | Yes | Recipe ID (TheCocktailDB or custom) |
| `recipeName` | string | Yes | Recipe name |
| `recipeType` | string | Yes | "standard" or "custom" |
| `recipientAlias` | string | Yes | Recipient's alias (e.g., "@cool-panda-123") |
| `message` | string | No | Optional personal message (max 500 chars) |

**Response 201 Created**
```json
{
  "shareId": "00000000-0000-0000-0000-000000000000",
  "recipeId": "12345",
  "recipeName": "Margarita",
  "recipeType": "standard",
  "sharedBy": "@happy-dolphin-742",
  "sharedTo": "@cool-panda-123",
  "message": "Try this amazing margarita!",
  "sharedAt": "2025-11-15T20:30:00Z",
  "status": "pending"
}
```

**Error Responses**

**400 - Invalid Request**
```json
{
  "error": "INVALID_REQUEST",
  "message": "Required fields: recipeId, recipeName, recipeType, recipientAlias"
}
```

**400 - Self Share**
```json
{
  "error": "INVALID_SHARE",
  "message": "Cannot share with yourself"
}
```

**404 - User Not Found**
```json
{
  "error": "USER_NOT_FOUND",
  "message": "User with alias @cool-panda-123 not found"
}
```

**409 - Duplicate Share**
```json
{
  "error": "DUPLICATE_SHARE",
  "message": "This recipe was already shared with this user in the last 24 hours"
}
```

---

### 3. External Recipe Sharing

#### POST /v1/social/invite

Create an external share link (invite) for a recipe.

**Request**
```http
POST /api/v1/social/invite
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "recipeId": "12345",
  "recipeName": "Margarita",
  "recipeType": "standard",
  "message": "Check out my favorite margarita recipe!"
}
```

**Response 201 Created**
```json
{
  "inviteId": "00000000-0000-0000-0000-000000000000",
  "token": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "shareUrl": "https://share.mybartenderai.com/a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6",
  "recipeId": "12345",
  "recipeName": "Margarita",
  "message": "Check out my favorite margarita recipe!",
  "createdBy": "@happy-dolphin-742",
  "createdAt": "2025-11-15T20:30:00Z",
  "expiresAt": "2025-12-15T20:30:00Z",
  "claimedCount": 0,
  "maxClaims": 100
}
```

---

#### GET /v1/social/invite/{token}

Claim/view an external invite link.

**Request**
```http
GET /api/v1/social/invite/a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
Authorization: Bearer <JWT_TOKEN>
```

**Response 200 OK**
```json
{
  "recipeId": "12345",
  "recipeName": "Margarita",
  "recipeType": "standard",
  "sharedBy": "@happy-dolphin-742",
  "message": "Check out my favorite margarita recipe!",
  "sharedAt": "2025-11-15T20:30:00Z"
}
```

**Error Responses**

**404 - Invite Not Found**
```json
{
  "error": "INVITE_NOT_FOUND",
  "message": "Share invite not found or expired"
}
```

**410 - Invite Expired**
```json
{
  "error": "INVITE_EXPIRED",
  "message": "This share invite has expired"
}
```

**410 - Max Claims Reached**
```json
{
  "error": "INVITE_EXHAUSTED",
  "message": "This share invite has reached its maximum number of claims"
}
```

---

### 4. Recipe Inbox

#### GET /v1/social/inbox

Get recipes shared with the current user.

**Request**
```http
GET /api/v1/social/inbox?limit=20&offset=0&status=pending
Authorization: Bearer <JWT_TOKEN>
```

**Query Parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 20 | Max results (1-100) |
| `offset` | integer | 0 | Pagination offset |
| `status` | string | all | Filter: "pending", "accepted", "rejected", "all" |

**Response 200 OK**
```json
{
  "items": [
    {
      "shareId": "00000000-0000-0000-0000-000000000000",
      "recipeId": "12345",
      "recipeName": "Margarita",
      "recipeType": "standard",
      "sharedBy": "@happy-dolphin-742",
      "message": "Try this amazing margarita!",
      "sharedAt": "2025-11-15T20:30:00Z",
      "status": "pending",
      "viewedAt": null
    }
  ],
  "total": 1,
  "limit": 20,
  "offset": 0
}
```

---

### 5. Recipe Outbox

#### GET /v1/social/outbox

Get recipes shared by the current user.

**Request**
```http
GET /api/v1/social/outbox?limit=20&offset=0&type=internal
Authorization: Bearer <JWT_TOKEN>
```

**Query Parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 20 | Max results (1-100) |
| `offset` | integer | 0 | Pagination offset |
| `type` | string | all | Filter: "internal", "invite", "all" |

**Response 200 OK**
```json
{
  "internalShares": [
    {
      "shareId": "00000000-0000-0000-0000-000000000000",
      "recipeId": "12345",
      "recipeName": "Margarita",
      "sharedTo": "@cool-panda-123",
      "message": "Try this!",
      "sharedAt": "2025-11-15T20:30:00Z",
      "status": "pending"
    }
  ],
  "invites": [
    {
      "inviteId": "00000000-0000-0000-0000-000000000000",
      "token": "a1b2c3d4...",
      "shareUrl": "https://share.mybartenderai.com/a1b2c3d4...",
      "recipeId": "12345",
      "recipeName": "Margarita",
      "createdAt": "2025-11-15T20:30:00Z",
      "expiresAt": "2025-12-15T20:30:00Z",
      "claimedCount": 5,
      "maxClaims": 100
    }
  ],
  "total": 2,
  "limit": 20,
  "offset": 0
}
```

---

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 400 | INVALID_REQUEST | Missing or invalid request parameters |
| 400 | INVALID_SHARE | Business rule violation (e.g., self-share) |
| 401 | UNAUTHORIZED | Invalid or missing JWT token |
| 404 | USER_NOT_FOUND | Recipient alias not found |
| 404 | RECIPE_NOT_FOUND | Recipe ID not found |
| 404 | INVITE_NOT_FOUND | Share invite not found |
| 409 | DUPLICATE_SHARE | Recipe already shared recently |
| 410 | INVITE_EXPIRED | Share invite expired |
| 410 | INVITE_EXHAUSTED | Max claims reached |
| 429 | RATE_LIMIT_EXCEEDED | Rate limit exceeded |
| 429 | QUOTA_EXCEEDED | Daily quota exceeded |
| 500 | INTERNAL_ERROR | Server error |
| 503 | SERVICE_UNAVAILABLE | Temporary service issue |

## Testing

### Test JWT Token

For testing, obtain a JWT token from Entra External ID:

```bash
# Using device code flow
az login --tenant mybartenderai.onmicrosoft.com --allow-no-subscriptions
az account get-access-token --resource 04551003-a57c-4dc2-97a1-37e0b3d1a2f6
```

### Example cURL Requests

**Get User Profile**
```bash
curl -X GET https://apim-mba-001.azure-api.net/api/v1/users/me \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY"
```

**Share Recipe Internally**
```bash
curl -X POST https://apim-mba-001.azure-api.net/api/v1/social/share-internal \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "recipeId": "12345",
    "recipeName": "Margarita",
    "recipeType": "standard",
    "recipientAlias": "@cool-panda-123",
    "message": "Try this!"
  }'
```

**Create Share Invite**
```bash
curl -X POST https://apim-mba-001.azure-api.net/api/v1/social/invite \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Ocp-Apim-Subscription-Key: $APIM_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "recipeId": "12345",
    "recipeName": "Margarita",
    "recipeType": "standard",
    "message": "Check this out!"
  }'
```

## Postman Collection

A Postman collection is available at: `docs/FRIENDS-VIA-CODE-API-TESTS.md`

## Support

For issues or questions:
- Review: `TROUBLESHOOTING_DOCUMENTATION.md`
- Monitoring: `infrastructure/monitoring/MONITORING-SETUP.md`
- Deployment: `FRIENDS-VIA-CODE-DEPLOYMENT-RUNBOOK.md`
