# Testing APIM Subscription Limitations

## Test Scenarios

### 1. Free Tier Testing
**Subscription Key**: (Get from Azure Portal after creation)
**Expected Behavior**:
- ✅ Can access: `/health`, `/v1/snapshots/latest`
- ❌ Blocked from: `/v1/speech/token`, `/v1/vision/*`
- 📊 Rate limit: 10 calls/minute, 100 calls/day

```bash
# Test allowed endpoint
curl -X GET https://apim-mba-001.azure-api.net/api/health \
  -H "Ocp-Apim-Subscription-Key: YOUR_FREE_KEY"

# Test blocked AI endpoint (should return 403)
curl -X GET https://apim-mba-001.azure-api.net/api/v1/speech/token \
  -H "Ocp-Apim-Subscription-Key: YOUR_FREE_KEY"

# Test rate limiting (run 11 times rapidly, 11th should fail)
for i in {1..11}; do
  curl -X GET https://apim-mba-001.azure-api.net/api/health \
    -H "Ocp-Apim-Subscription-Key: YOUR_FREE_KEY" \
    -w "\\nAttempt $i: HTTP %{http_code}\\n"
  sleep 0.5
done
```

### 2. Premium Tier Testing
**Subscription Key**: (Get from Azure Portal after creation)
**Expected Behavior**:
- ✅ Full access to all endpoints
- 📊 Rate limit: 20 calls/minute, 1,000 calls/day
- 🎤 Voice features accessible (30 min/month tracked by backend)

```bash
# Test AI endpoint (should work)
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: YOUR_PREMIUM_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Margarita?"}'

# Test voice token endpoint
curl -X GET https://apim-mba-001.azure-api.net/api/v1/speech/token \
  -H "Ocp-Apim-Subscription-Key: YOUR_PREMIUM_KEY"

# Check headers for tier info
curl -I https://apim-mba-001.azure-api.net/api/health \
  -H "Ocp-Apim-Subscription-Key: YOUR_PREMIUM_KEY"
```

### 3. Pro Tier Testing
**Subscription Key**: (Get from Azure Portal after creation)
**Expected Behavior**:
- ✅ Unlimited access to all features
- 📊 Rate limit: 50 calls/minute, 10,000 calls/day
- 🚀 Priority processing (X-Priority-User header)

```bash
# Test high-volume requests
for i in {1..30}; do
  curl -X GET https://apim-mba-001.azure-api.net/api/health \
    -H "Ocp-Apim-Subscription-Key: YOUR_PRO_KEY" \
    -w "\\nAttempt $i: HTTP %{http_code}\\n" &
done
wait

# Verify priority header is set
curl -I https://apim-mba-001.azure-api.net/api/health \
  -H "Ocp-Apim-Subscription-Key: YOUR_PRO_KEY" | grep "X-Priority-User"
```

## Expected Error Responses

### Rate Limit Exceeded (429)
```json
{
  "statusCode": 429,
  "message": "Rate limit exceeded. Please retry after 60 seconds"
}
```

### Feature Not Available (403)
```json
{
  "code": "UPGRADE_REQUIRED",
  "message": "Voice features require Premium or Pro subscription",
  "currentTier": "free",
  "requiredTier": "premium",
  "upgradeUrl": "https://mybartenderai.com/upgrade"
}
```

### Daily Quota Exceeded (403)
```json
{
  "statusCode": 403,
  "message": "Quota exceeded. Daily limit: 100 calls"
}
```

## Monitoring & Verification

### Via Azure Portal
1. Go to APIM → **Analytics** → **Request**
2. Filter by Product to see usage per tier
3. Check **Metrics** for rate limit violations

### Via Application Insights
```kusto
// Query to see rate limiting in action
requests
| where cloud_RoleName == "apim-mba-001"
| where resultCode == "429"
| summarize count() by bin(timestamp, 1m), operation_Name
| render timechart

// Query to see tier distribution
requests
| where cloud_RoleName == "apim-mba-001"
| extend tier = tostring(customDimensions["X-User-Tier"])
| summarize count() by tier
| render piechart
```

## Backend Quota Tracking

The backend Functions track feature-specific quotas in PostgreSQL:
- AI recommendations: Free (10/mo), Premium (100/mo), Pro (unlimited)
- Voice minutes: Premium (30 min/mo), Pro (5 hours/mo)
- Vision scans: Premium (5/mo), Pro (50/mo)

These are enforced separately from APIM rate limits and return appropriate error messages when exceeded.

## Troubleshooting

### Policy Not Applied
- Check APIM → Products → [Tier] → Policies
- Ensure XML is valid (use Portal's code editor validation)
- Verify backend service URL in policy matches Function App URL

### Subscription Key Issues
- Ensure subscription is in "Active" state
- Check key hasn't been regenerated
- Verify correct header name: `Ocp-Apim-Subscription-Key`

### Rate Limiting Not Working
- Policies are evaluated in order: Product → API → Operation
- Check for conflicting policies at different levels
- Verify `renewal-period` is in seconds (86400 = 24 hours)