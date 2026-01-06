# JWT Validation Restoration Guide

## Executive Summary

This guide documents the restoration of JWT validation for AI endpoints in Azure API Management (`apim-mba-001`), returning to a production-ready security posture with proper authentication.

## Current State (Before Fix)

- **JWT validation disabled** on AI endpoints
- **Authorization header stripped** by APIM policy
- **Subscription key hardcoded** in mobile app
- **Security weakened** for debugging purposes

## Target State (After Fix)

- **JWT validation required** for AI endpoints
- **Authorization header preserved** and validated
- **Dual authentication**: JWT + subscription key
- **Public endpoints** remain subscription-key only

## Architecture

```
Mobile App → APIM → Azure Functions
    ↓         ↓          ↓
  JWT +    Validate   Process
  Sub Key    Both     Request
```

## Policy Files Created

### 1. `ai-endpoints-jwt-policy.xml`
**Purpose**: JWT validation for protected AI endpoints
**Applies to**:
- `ask-bartender-simple`
- `ask-bartender`
- `recommendCocktails`

**Key Features**:
- Validates JWT against Entra External ID
- Checks issuer: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0`
- Accepts audiences: `f9f7f159-b847-4211-98c9-18e5b8193045` or `api://mybartenderai`
- Requires subscription key
- Preserves Authorization header for backend
- Adds function key for Azure Functions

### 2. `public-endpoints-policy.xml`
**Purpose**: Public endpoints without JWT requirement
**Applies to**:
- `snapshots-latest`
- `download-images`
- `health`

**Key Features**:
- Only requires subscription key
- No JWT validation
- Rate limiting per subscription
- Response caching (5 minutes)
- CORS headers for browser access

## Implementation Steps

### Step 1: Apply Policies to APIM

```powershell
# Review what will be changed (dry run)
.\apply-jwt-policies.ps1 -DryRun

# Apply the policies
.\apply-jwt-policies.ps1
```

### Step 2: Test JWT Validation

```powershell
# Test that endpoints require JWT
.\test-jwt-required.ps1

# Test with a valid JWT (obtain token first)
.\test-jwt-valid.ps1 -AccessToken "eyJ..."
```

### Step 3: Update Mobile App

Remove the temporary JWT-optional code from `ask_bartender_service.dart`:

```dart
// REMOVE this temporary bypass:
// if (accessToken == null || accessToken.isEmpty) {
//   // Temporarily skip auth requirement
// }

// RESTORE this requirement:
if (accessToken == null || accessToken.isEmpty) {
  throw Exception('Not authenticated. Please sign in to use AI Bartender.');
}

// Always send both headers:
final headers = <String, String>{
  'Authorization': 'Bearer $accessToken',
  'Ocp-Apim-Subscription-Key': subscriptionKey, // From secure storage
  'Content-Type': 'application/json',
};
```

## Test Checklist

### ✅ Security Tests

| Test | Command | Expected Result |
|------|---------|-----------------|
| AI endpoint without JWT | `curl -X POST {url} -H "Ocp-Apim-Subscription-Key: {key}"` | 401 Unauthorized |
| AI endpoint with invalid JWT | `curl -X POST {url} -H "Authorization: Bearer invalid"` | 401 Unauthorized |
| AI endpoint with expired JWT | `curl -X POST {url} -H "Authorization: Bearer {expired}"` | 401 Unauthorized |
| AI endpoint with valid JWT | `curl -X POST {url} -H "Authorization: Bearer {valid}"` | 200 OK |
| Public endpoint without JWT | `curl {url} -H "Ocp-Apim-Subscription-Key: {key}"` | 200 OK |

### ✅ Functional Tests

| Test | Description | Expected Result |
|------|-------------|-----------------|
| Backend receives JWT | Check Function logs | Authorization header present |
| User claims extracted | Check APIM trace | userId variable set from JWT |
| Rate limiting works | Exceed call limit | 429 Too Many Requests |
| CORS headers present | Check response headers | Access-Control-Allow-Origin: * |

## Security Validation

### Headers Required for AI Endpoints

```http
POST /api/v1/ask-bartender-simple HTTP/1.1
Host: apim-mba-001.azure-api.net
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsImtpZCI6Ik1yNS...
Ocp-Apim-Subscription-Key: a4f267a3dd1b4cdba4e9cb4d29e565c0
Content-Type: application/json

{
  "message": "What's a good cocktail?",
  "context": ""
}
```

### JWT Token Structure

The JWT must contain:
- **iss** (issuer): `https://mybartenderai.ciamlogin.com/{tenant-id}/v2.0`
- **aud** (audience): Client ID or `api://mybartenderai`
- **exp** (expiration): Not expired
- **sub** (subject): User identifier

## Rollback Plan

If issues arise, rollback by:

1. **Remove JWT validation** (emergency only):
```powershell
# Apply empty policy to AI operations
az apim api operation policy delete `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --api-id mybartenderai-api `
  --operation-id askBartenderSimple
```

2. **Restore previous policies** from backup:
```powershell
# If you backed up old policies
az apim api operation policy set `
  --policy @backup-policy.xml
```

## Monitoring

### APIM Analytics
- Monitor 401 response rates
- Check JWT validation failures
- Review subscription key usage

### Application Insights
```kusto
// JWT validation failures
requests
| where timestamp > ago(1h)
| where resultCode == "401"
| where url contains "ask-bartender"
| summarize Count = count() by bin(timestamp, 5m)
```

## Mobile App Requirements

### Authentication Flow
1. User signs in via Entra External ID
2. Receive access token (JWT)
3. Store token securely
4. Include token in all AI endpoint calls
5. Refresh token before expiration

### Storage Requirements
- **Access Token**: Secure storage (e.g., flutter_secure_storage)
- **Subscription Key**: Secure storage (not hardcoded)
- **Token Expiry**: Track and refresh proactively

## Production Checklist

Before going to production:

- [ ] Remove all hardcoded keys from source code
- [ ] JWT validation enabled on all AI endpoints
- [ ] Public endpoints work without JWT
- [ ] Mobile app handles 401 responses gracefully
- [ ] Token refresh implemented
- [ ] Subscription key stored securely
- [ ] APIM policies backed up
- [ ] Monitoring alerts configured
- [ ] Documentation updated

## Troubleshooting

### Common Issues

1. **401 on valid token**
   - Check token expiration
   - Verify audience claim matches
   - Confirm issuer is correct

2. **Token not found**
   - Check header name: `Authorization`
   - Format: `Bearer {token}` (space after Bearer)

3. **CORS errors**
   - Policy includes CORS headers
   - Check allowed origins

4. **Rate limiting**
   - Check subscription tier limits
   - Monitor usage in APIM portal

## Summary

This implementation:
- ✅ Restores JWT validation for AI endpoints
- ✅ Maintains public endpoint accessibility
- ✅ Provides clear separation of auth requirements
- ✅ Includes comprehensive testing approach
- ✅ Preserves backward compatibility for public endpoints
- ✅ Enables tier-based authorization via JWT claims

---

**Implementation Date**: November 2025
**Security Level**: Production-ready
**Compliance**: PII-minimal, JWT-based authentication