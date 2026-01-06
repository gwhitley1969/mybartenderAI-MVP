# Friends via Code - APIM Configuration Guide

This guide covers the Azure API Management (APIM) configuration for the Friends via Code social sharing feature.

## Overview

The Friends via Code feature adds 7 new API endpoints to the MyBartenderAI API:

### User Profile
- `GET /v1/users/me` - Get or create user profile with system-generated alias
- `PATCH /v1/users/me` - Update display name

### Social Sharing
- `POST /v1/social/share-internal` - Share recipe with friend via alias
- `POST /v1/social/invite` - Create shareable invite link
- `GET /v1/social/invite/{token}` - Claim invite and add recipe
- `GET /v1/social/inbox` - View received recipe shares
- `GET /v1/social/outbox` - View sent shares and active invites

## Security Configuration

### JWT Validation

All social endpoints require JWT authentication with:
- **Issuer**: `https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0`
- **Audience**: `04551003-a57c-4dc2-97a1-37e0b3d1a2f6` (MyBartenderAI app client ID)
- **Required Claims**: `sub` (user ID)
- **Token Type**: Bearer

### Rate Limiting

Per-user rate limits (based on JWT sub claim):
- **Minute**: 5 requests/minute
- **Daily**: 100 requests/day

Rate limits only count successful responses (2xx status codes).

### CORS Configuration

Allowed origins:
- `https://share.mybartenderai.com` (static preview pages)
- `https://mybartenderai.com` (main website)

Allowed methods: GET, POST, PATCH, OPTIONS

## Deployment

### Prerequisites

1. Azure CLI installed and authenticated
2. PowerShell 5.1+ or PowerShell Core 7+
3. Access to `rg-mba-prod` resource group
4. APIM service `apim-mba-001` must exist

### Steps

1. **Navigate to scripts directory**:
   ```powershell
   cd infrastructure/apim/scripts
   ```

2. **Run deployment script**:
   ```powershell
   .\apply-social-policies.ps1
   ```

3. **Verify deployment**:
   - Check Azure Portal → APIM → APIs → MyBartenderAI
   - Verify operations are listed
   - Check operation policies are applied

### Manual Verification

```powershell
# List all operations
az apim api operation list `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --api-id mybartenderai-api `
  --query "[?contains(operationId, 'social') || contains(operationId, 'users-me')].[operationId,displayName]" `
  --output table

# Check specific operation policy
az apim api operation policy show `
  --resource-group rg-mba-prod `
  --service-name apim-mba-001 `
  --api-id mybartenderai-api `
  --operation-id social-share-internal
```

## Policy Details

### Key Policy Features

1. **JWT Validation**:
   - Validates signature using OIDC discovery
   - Checks expiration, audience, and issuer
   - Requires Bearer scheme

2. **User Identification**:
   - Extracts `sub` claim from JWT
   - Adds `X-User-Id` header for backend
   - Used as key for rate limiting

3. **Rate Limiting**:
   - Two-tier limits: minute and daily
   - Per-user counters (keyed by user ID)
   - Only increments on successful requests

4. **Security Headers**:
   - `X-Content-Type-Options: nosniff`
   - `X-Frame-Options: DENY`
   - `Strict-Transport-Security` with 1-year max-age

5. **Error Handling**:
   - Returns proper 401 for auth failures
   - Returns 429 with Retry-After for rate limits
   - Includes trace ID for debugging

## Testing

### Get User Profile

```bash
# Get JWT token from mobile app or auth flow
JWT_TOKEN="your-jwt-token-here"

# Call endpoint
curl -X GET "https://apim-mba-001.azure-api.net/v1/users/me" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Ocp-Apim-Subscription-Key: your-subscription-key"
```

Expected response:
```json
{
  "userId": "00000000-0000-0000-0000-000000000000",
  "alias": "@happy-penguin-42",
  "displayName": null,
  "createdAt": "2025-11-14T12:00:00Z",
  "lastSeen": "2025-11-14T12:00:00Z"
}
```

### Share Recipe Internally

```bash
curl -X POST "https://apim-mba-001.azure-api.net/v1/social/share-internal" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Ocp-Apim-Subscription-Key: your-subscription-key" \
  -H "Content-Type: application/json" \
  -d '{
    "toAlias": "@clever-dolphin-99",
    "recipeType": "standard",
    "recipeId": "11007",
    "message": "Try this amazing Margarita!"
  }'
```

### Test Rate Limiting

```bash
# Run this script to hit rate limit:
for i in {1..10}; do
  echo "Request $i"
  curl -X GET "https://apim-mba-001.azure-api.net/v1/users/me" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Ocp-Apim-Subscription-Key: your-subscription-key"
  echo ""
done
```

After 5 requests, you should get:
```json
{
  "error": "RATE_LIMIT_EXCEEDED",
  "message": "Rate limit exceeded. Please try again later.",
  "retryAfter": 60,
  "traceId": "..."
}
```

## Monitoring

### APIM Analytics

1. Navigate to Azure Portal → APIM → Analytics
2. Filter by:
   - Operations: `social-*`, `users-me-*`
   - Time range: Last 24 hours
3. Check metrics:
   - Request count
   - Success rate
   - Average latency
   - Error rate

### Application Insights

Social endpoints log to Application Insights via backend functions:
- Operation names: `users-me`, `social-share-internal`, etc.
- Custom properties: `userId`, `recipeType`, `shareId`
- Rate limit events: `RateLimitExceeded`

### Key Metrics to Monitor

- **Total Shares**: Count of successful share-internal calls
- **Invite Creation**: Count of successful invite POST calls
- **Inbox Activity**: GET /inbox call volume
- **Rate Limit Hits**: Count of 429 responses
- **Auth Failures**: Count of 401 responses

## Troubleshooting

### Common Issues

#### 401 Unauthorized
- **Cause**: Invalid or expired JWT token
- **Solution**: Refresh token via auth flow
- **Check**: Token expiration, audience, issuer claims

#### 429 Rate Limit Exceeded
- **Cause**: User exceeded 5/minute or 100/day limit
- **Solution**: Wait for rate limit reset (check Retry-After header)
- **Prevention**: Implement client-side throttling

#### 404 Not Found
- **Cause**: Operation not registered in APIM
- **Solution**: Run `apply-social-policies.ps1` again
- **Check**: Operation exists in APIM portal

#### 500 Internal Server Error
- **Cause**: Backend function failure
- **Solution**: Check function logs in Azure Portal
- **Check**: Database connection, JWT validation in backend

### Debug Steps

1. **Check APIM policy execution**:
   - Enable APIM request tracing
   - Add `Ocp-Apim-Trace: true` header
   - Review trace logs in response

2. **Verify JWT token**:
   - Use jwt.io to decode token
   - Check `iss`, `aud`, `sub`, `exp` claims
   - Verify signature with OIDC keys

3. **Test backend directly**:
   - Call Function App URL directly (bypass APIM)
   - Include same JWT token
   - Check if error is in APIM or backend

## Maintenance

### Updating Policies

1. Edit `policies/social-endpoints-policy.xml`
2. Run `scripts/apply-social-policies.ps1`
3. Test updated policy
4. Monitor for errors

### Adding New Social Endpoints

1. Create Azure Function
2. Add operation to `$socialEndpoints` array in script
3. Run deployment script
4. Verify operation and policy

### Rate Limit Adjustments

To change rate limits, edit the policy XML:

```xml
<!-- Minute limit -->
<rate-limit-by-key
    calls="10"  <!-- Change from 5 to 10 -->
    renewal-period="60"
    ... />

<!-- Daily limit -->
<rate-limit-by-key
    calls="200"  <!-- Change from 100 to 200 -->
    renewal-period="86400"
    ... />
```

## Migration Notes

### From Development to Production

When moving to Consumption tier APIM:
1. Export current API configuration
2. Create new Consumption tier APIM
3. Import API configuration
4. Reapply policies
5. Update DNS for `apim-mba-001.azure-api.net`
6. Update mobile app endpoint configuration

### Backend URL Updates

If Function App URL changes:
1. Update API backend in APIM
2. No policy changes needed
3. Test all operations

## Security Considerations

### Best Practices

1. **Never log JWT tokens**: Policies extract user ID only
2. **Use HTTPS only**: All endpoints require TLS
3. **Validate on backend too**: APIM is defense-in-depth, not sole security
4. **Rotate subscription keys**: Regularly rotate APIM subscription keys
5. **Monitor suspicious activity**: Alert on unusual rate limit patterns

### Privacy Compliance

- User IDs (sub claims) are stored for rate limiting
- No PII is logged in APIM policies
- CORS restricts access to trusted domains
- Rate limits prevent enumeration attacks

## Related Documentation

- [FEATURE-FriendsViaCode.md](../../FEATURE-FriendsViaCode.md) - Feature specification
- [IMPLEMENTATION-PLAN-FriendsViaCode.md](../../IMPLEMENTATION-PLAN-FriendsViaCode.md) - Implementation plan
- [JWT_POLICY_DEPLOYMENT_GUIDE.md](./JWT_POLICY_DEPLOYMENT_GUIDE.md) - General JWT policy guide

## Support

For issues or questions:
1. Check Application Insights logs
2. Review APIM analytics
3. Test with curl/Postman
4. Verify database connectivity
5. Check Function App logs

---

**Last Updated**: 2025-11-14
**Version**: 1.0
**Author**: Claude + Development Team
