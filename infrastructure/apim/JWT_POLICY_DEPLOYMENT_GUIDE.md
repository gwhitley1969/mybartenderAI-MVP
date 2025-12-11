# JWT Validation Policy Deployment Guide

**Date:** 2025-10-24
**Purpose:** Apply JWT validation to Premium/Pro tier operations

---

## Configuration Summary

- **Tenant**: mybartenderai.onmicrosoft.com
- **Tenant ID**: a82813af-1054-4e2d-a8ec-c6b9c2908c91
- **Client ID**: f9f7f159-b847-4211-98c9-18e5b8193045
- **User Flow**: mba-signin-signup
- **OpenID Config**: https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration
- **Issuer**: https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0

---

## Operations Requiring JWT Validation

Apply JWT policy to these Premium/Pro operations:

| Operation | Method | Path | Tier Required | Reason |
|-----------|--------|------|---------------|--------|
| askBartender | POST | /v1/ask-bartender | Premium/Pro | AI recommendations |
| recommendCocktails | POST | /v1/recommend | Premium/Pro | AI recommendations |
| getSpeechToken | GET | /v1/speech/token | Premium/Pro | Voice assistant |

## Operations WITHOUT JWT Validation

These operations remain accessible with APIM subscription key only:

| Operation | Method | Path | Tier | Reason |
|-----------|--------|------|------|--------|
| getLatestSnapshot | GET | /v1/snapshots/latest | All | Public snapshot access |
| getHealth | GET | /health | All | Health check |
| getImageManifest | GET | /v1/images/manifest | All | Public image manifest |
| triggerSync | POST | /v1/admin/sync | Admin | Uses function key auth |

---

## Deployment Steps

### Step 1: Navigate to APIM in Azure Portal

1. Go to Azure Portal: https://portal.azure.com
2. Search for **API Management** → **apim-mba-001**
3. Click **APIs** in the left menu
4. Select **MyBartenderAI API**

### Step 2: Apply JWT Policy to Premium Operations

**For each operation that requires JWT** (askBartender, recommendCocktails, getSpeechToken):

1. Click on the operation (e.g., **askBartender**)
2. In the **Inbound processing** section, click **</>** (code editor)
3. Replace the `<inbound>` section with the content from:
   - File: `infrastructure/apim/policies/jwt-validation-entra-external-id.xml`
   - Copy everything inside the `<inbound>` tags

4. The policy should look like:

```xml
<inbound>
    <base />

    <!-- Validate JWT token -->
    <validate-jwt header-name="Authorization" ...>
        <openid-config url="https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration" />
        <audiences>
            <audience>f9f7f159-b847-4211-98c9-18e5b8193045</audience>
        </audiences>
        <issuers>
            <issuer>https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0</issuer>
        </issuers>
    </validate-jwt>

    <!-- Extract user headers -->
    <set-header name="X-User-Id" ...>...</set-header>
    <set-header name="X-User-Email" ...>...</set-header>
    <set-header name="X-User-Name" ...>...</set-header>
</inbound>
```

5. Click **Save**

### Step 3: Verify Policy Application

For each operation with JWT validation:

1. Click on the operation
2. Click **Test** tab
3. Without Authorization header → Should return **401 Unauthorized**
4. With invalid token → Should return **401 Unauthorized**
5. With valid token → Should return **200 OK** (or backend response)

---

## Testing JWT Validation

### Test 1: Without Token (Should Fail)

```bash
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: 6af6fa24de984526b1e5a0704d6537e3" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'
```

**Expected**: `401 Unauthorized` with message:
```json
{
  "code": "UNAUTHORIZED",
  "message": "Valid authentication token required. Please sign in.",
  "traceId": "..."
}
```

### Test 2: With Valid Token (Should Succeed)

```bash
# First, get a token from Entra External ID
# (requires mobile app or Postman OAuth flow)

curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: 6af6fa24de984526b1e5a0704d6537e3" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'
```

**Expected**: `200 OK` (once backend function is deployed)

### Test 3: Public Endpoints Still Work (No JWT Required)

```bash
curl https://apim-mba-001.azure-api.net/api/v1/snapshots/latest \
  -H "Ocp-Apim-Subscription-Key: 8de5c2083aff4953b099ae61b34b6e45"
```

**Expected**: `200 OK` with snapshot data (no JWT needed)

---

## Troubleshooting

### Error: "Unauthorized. Valid JWT token required."

**Cause**: JWT validation failed

**Check**:
1. Token is present in `Authorization: Bearer <token>` header
2. Token is not expired (check `exp` claim)
3. Token audience matches client ID: `f9f7f159-b847-4211-98c9-18e5b8193045`
4. Token issuer matches: `https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/...`

### Error: "The remote name could not be resolved"

**Cause**: OpenID config URL incorrect

**Fix**: Verify URL is exactly: `https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration`

### Policy Not Applied

**Cause**: Policy saved but not taking effect

**Fix**:
1. Check policy is saved at **operation level** (not API level)
2. Clear browser cache
3. Wait 30 seconds for APIM cache refresh
4. Test in Incognito/Private window

---

## Headers Forwarded to Backend

When JWT validation succeeds, these headers are added for backend functions:

| Header | Source | Example |
|--------|--------|---------|
| `X-User-Id` | JWT `sub` claim | `a1b2c3d4-e5f6-...` |
| `X-User-Email` | JWT `email` or `preferred_username` | `user@example.com` |
| `X-User-Name` | JWT `name` claim | `John Doe` |

Backend functions can use these headers to identify the authenticated user without parsing the JWT.

---

## Mobile App Configuration

For Flutter app integration, configure:

```dart
// lib/src/config/auth_config.dart
class AuthConfig {
  static const String authority =
      'https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com';

  static const String clientId = 'f9f7f159-b847-4211-98c9-18e5b8193045';

  static const String redirectUri = 'com.mybartenderai.app://auth';

  static const String userFlow = 'mba-signin-signup';

  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
  ];
// MSAL receives refresh tokens automatically; offline_access is not required.
}
```

---

## Next Steps

1. ✅ JWT policy created with correct Entra External ID configuration
2. ✅ Apply policy to Premium/Pro operations (askBartender, recommendCocktails, getSpeechToken)
3. ⬜ Test with valid JWT token (requires mobile app or Postman OAuth flow)
4. ⬜ Update mobile app with Entra External ID authentication
5. ⬜ Document user registration/login flow for mobile app

---

**Note**: This policy validates tokens issued by Entra External ID (CIAM). It uses the modern `.ciamlogin.com` domain, not the legacy `.b2clogin.com` domain.
