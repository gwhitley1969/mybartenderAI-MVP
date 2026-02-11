# APIM JWT Policy Deployment — Troubleshooting Guide

**Date**: February 11, 2026
**Status**: RESOLVED — Root cause was mobile app not sending JWT tokens (bare Dio, no auth interceptor)
**Resolution**: Fixed 4 mobile API providers to use authenticated Dio; deployed all 4 batches successfully

---

## What We're Trying to Do

Deploy `validate-jwt` policies to **13 unprotected APIM operations**. A security audit (Jan 30, 2026) found that 13 of 30 API operations on `apim-mba-002` lack JWT validation at the gateway. The other 17 operations already have working `validate-jwt` policies (deployed earlier via Azure Portal).

The goal is to bring all authenticated operations to parity — APIM validates the JWT before forwarding to the backend.

### The 13 Operations Needing Policies

| # | Operation ID | URL Template | Batch | Status |
|---|-------------|-------------|-------|--------|
| 1 | `subscription-config` | `/v1/subscription/config` | 1 | Deployed — BROKEN |
| 2 | `subscription-status` | `/v1/subscription/status` | 1 | Deployed — BROKEN |
| 3 | `ask-bartender` | `/v1/ask-bartender` | 2 | Deployed — BROKEN |
| 4 | `ask-bartender-simple` | `/v1/ask-bartender-simple` | 2 | Deployed — BROKEN (minimal policy) |
| 5 | `recommend` | `/v1/recommend` | 2 | Deployed — BROKEN |
| 6 | `refine-cocktail` | `/v1/create-studio/refine` | 2 | Deployed — BROKEN |
| 7 | `vision-analyze` | `/v1/vision-analyze` | 3 | Not yet deployed |
| 8 | `speech-token` | `/v1/speech-token` | 3 | Not yet deployed |
| 9 | `voice-bartender` | `/v1/voice-bartender` | 3 | Not yet deployed |
| 10 | `social-connect-start` | `/v1/social/{provider}/connect/start` | 4 | Not yet deployed |
| 11 | `social-share-external` | `/v1/social/{provider}/share` | 4 | Not yet deployed |
| 12 | `auth-exchange` | `/v1/auth/exchange` | 4 | Not yet deployed |
| 13 | `auth-rotate` | `/v1/auth/rotate` | 4 | Not yet deployed |

---

## What IS Working (Reference)

The `voice-session` operation has a `validate-jwt` policy that **works perfectly**. It was deployed earlier via the Azure Portal. Key details:

- **Same audience**: `f9f7f159-b847-4211-98c9-18e5b8193045`
- **Same issuer**: `https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0`
- **Same OpenID config URL**: `https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration`
- **Same required claim**: `sub` with `match="any"`
- Voice works end-to-end through the mobile app → Front Door → APIM → Function App

The working voice-session policy is saved at: `temp_voice_session_policy.xml` (root of repo)

---

## What Is NOT Working

After deploying `validate-jwt` policies to Batch 1 and Batch 2 operations:

- **AI Chat fails** in the mobile app — user sees "Sorry, I encountered an error. Please try again later."
- **Subscription config silently fails** — app defaults to free tier (no visible error to user)
- **Zero requests reach the backend** — confirmed via Application Insights query
- The mobile app calls `https://share.mybartenderai.com/api/v1/ask-bartender-simple` (through Azure Front Door)

### Confirmed: Front Door Is Not the Problem

The request flow was fully traced:

1. Mobile app → `https://share.mybartenderai.com/api/v1/ask-bartender-simple`
2. Front Door `route-api` (`/api/*`) → origin `apim-mba-002.azure-api.net` (no rule sets, no caching, no header manipulation)
3. APIM receives `/api/v1/ask-bartender-simple`, strips API path prefix `api`, matches operation
4. APIM API `serviceUrl` = `https://func-mba-fresh.azurewebsites.net/api`

Voice goes through the exact same Front Door route and works. Both direct-to-APIM and through-Front-Door return identical 401 for no-token requests. Front Door is eliminated as a cause.

---

## What We Have Tried

### Attempt 1: Full Policy Template
Deployed the complete `jwt-validation-entra-external-id.xml` policy which includes:
- `validate-jwt` block
- Three `<set-header>` blocks with C# expressions to extract `X-User-Id`, `X-User-Email`, `X-User-Name` from the JWT
- Custom `<on-error>` section with a `<choose>/<when>` that returns a JSON 401 body for JWT failures

**Result**: Chat fails. Zero requests reach backend.

### Attempt 2: Changed `required-claims` from `aud` to `sub`
The original policy had:
```xml
<required-claims>
    <claim name="aud" match="any">
        <value>f9f7f159-b847-4211-98c9-18e5b8193045</value>
    </claim>
</required-claims>
```
Changed to match the working voice-session pattern:
```xml
<required-claims>
    <claim name="sub" match="any" />
</required-claims>
```
Redeployed to all Batch 1 + Batch 2 operations.

**Result**: Still fails.

### Attempt 3: Minimal Policy (No C# Expressions)
Deployed an extremely minimal policy to `ask-bartender-simple` — only `validate-jwt` + `<base />` in all sections. No `<set-header>` blocks, no custom `<on-error>`, no C# expressions at all.

```xml
<policies>
    <inbound>
        <base />
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401"
            failed-validation-error-message="Unauthorized. Valid JWT token required."
            require-expiration-time="true" require-scheme="Bearer" require-signed-tokens="true">
            <openid-config url="https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration" />
            <audiences>
                <audience>f9f7f159-b847-4211-98c9-18e5b8193045</audience>
            </audiences>
            <issuers>
                <issuer>https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0</issuer>
            </issuers>
            <required-claims>
                <claim name="sub" match="any" />
            </required-claims>
        </validate-jwt>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

**Result**: STILL fails. This eliminates C# expressions as the cause.

### All No-Token Tests Pass

Requests without a JWT token correctly return **401** to all endpoints — both direct to APIM and through Front Door. This proves:
- The policy is deployed and compiled correctly
- The `validate-jwt` block is syntactically valid
- APIM is enforcing authentication

---

## What We Don't Know

1. **What HTTP status code does APIM return when a valid JWT is present?** We've only tested without tokens (which correctly returns 401). We have not been able to test with a valid JWT from the command line.

2. **Is the JWT token actually valid for these operations?** The mobile app's Dio interceptor adds the same token to all requests. Voice works, so the token should be valid. But we haven't confirmed what the app actually sends to ask-bartender-simple vs voice-session.

3. **Why does the identical `validate-jwt` configuration work on voice-session but fail on ask-bartender-simple?** The validate-jwt XML config (audience, issuer, openid-config URL, required claims) is the same between the working voice-session policy and our failing minimal policy.

4. **What do the APIM gateway logs show?** APIM has Application Insights diagnostics configured (pointing to `mybartenderai-func`, 100% sampling), but we were unable to query the logs successfully. The APIM gateway logs should show the exact response code and any error details for each request.

---

## Deployment Method

Policies were deployed via the **ARM REST API** using PowerShell:

```powershell
$body = @{
    properties = @{
        value  = $PolicyXml
        format = "rawxml"
    }
}
$jsonBody = $body | ConvertTo-Json -Depth 10
Invoke-RestMethod -Uri "$armBaseUrl/operations/$operationId/policies/policy?api-version=2022-08-01" `
    -Headers $headers -Method PUT -Body $jsonBody
```

The working voice-session policy was deployed via **Azure Portal** (not the ARM script). This is a potentially significant difference — the deployment method might affect how the policy XML is processed or stored.

---

## Key Differences Between Working and Failing Policies

| Aspect | Voice-Session (WORKS) | Our Policy (FAILS) |
|--------|----------------------|---------------------|
| Deployed via | Azure Portal | ARM REST API (`rawxml` format) |
| validate-jwt config | Same audience, issuer, openid-config | Identical |
| C# expressions | Uses `<set-variable>` with HTML-encoded C# | Uses `<set-header>` with inline C# (but minimal test had NONE) |
| `<set-backend-service>` | Explicitly set to `https://func-mba-fresh.azurewebsites.net/api` | Not present (inherited from API-level `serviceUrl`) |
| Rate limiting | Has `<rate-limit-by-key>` | Not present |
| Custom on-error | Has JSON error response with HTML-encoded entities | Has JSON error response (but minimal test had NONE) |

**Note**: The minimal policy test (Attempt 3) eliminated all differences except the deployment method and the absence of `<set-backend-service>`.

---

## Environment Details

- **APIM Service**: `apim-mba-002` (Basic V2 tier, South Central US)
- **Function App**: `func-mba-fresh` (Premium Consumption plan)
- **Front Door**: `fd-mba-share` (Standard tier)
- **Custom Domain**: `share.mybartenderai.com`
- **Auth Tenant**: Entra External ID (`mybartenderai.onmicrosoft.com`)
- **Client ID**: `f9f7f159-b847-4211-98c9-18e5b8193045`
- **Tenant ID**: `a82813af-1054-4e2d-a8ec-c6b9c2908c91`

### APIM API Configuration
- **API ID**: `mybartenderai-api`
- **Path prefix**: `api`
- **Service URL**: `https://func-mba-fresh.azurewebsites.net/api`
- **API-level policy**: Only sets `x-functions-key` header

---

## Key Files

| File | Purpose |
|------|---------|
| `infrastructure/apim/policies/jwt-validation-entra-external-id.xml` | Policy template (full version with C# expressions) |
| `infrastructure/apim/scripts/apply-jwt-policies02.ps1` | Main deployment script (deploys to batches of operations) |
| `infrastructure/apim/scripts/deploy-minimal-jwt-temp.ps1` | Minimal policy deployment script (diagnostic) |
| `infrastructure/apim/scripts/check-api-config-temp.ps1` | Flow tracing script |
| `temp_voice_session_policy.xml` | Working voice-session policy (retrieved from APIM) |
| `temp_usersme_policy.xml` | Working users-me policy (different audience — `04551003`) |
| `mobile/app/lib/src/config/auth_config.dart` | Mobile app auth configuration |
| `mobile/app/lib/src/services/backend_service.dart` | Dio interceptor that adds JWT to requests |
| `mobile/app/lib/src/api/ask_bartender_api.dart` | **THE FIX** — provider was using bare `dioProvider`, switched to `backendServiceProvider.dio` |
| `mobile/app/lib/src/api/recommend_api.dart` | Same fix as above |
| `mobile/app/lib/src/api/create_studio_api.dart` | Same fix as above |
| `mobile/app/lib/src/providers/vision_provider.dart` | Same fix as above |
| `backend/functions/shared/auth/jwtMiddleware.js` | Backend JWT verification (runs after APIM) |

---

## RESOLUTION (February 11, 2026)

### Root Cause Found

**The APIM policies were correct all along.** The root cause was in the **mobile app**: 4 API providers used a bare `dioProvider` from `bootstrap.dart` that had **no auth interceptor** — no `Authorization: Bearer <token>` header was ever sent to these endpoints.

### Why It Looked Like an APIM Problem

Before `validate-jwt` was deployed, APIM passed tokenless requests through to the backend functions, which worked because the functions didn't strictly require JWT (they used the fire-and-forget `jwtDecode.js` fallback). Deploying `validate-jwt` correctly exposed the mobile app bug — APIM now properly rejected requests without a valid JWT.

### The Two Dio Instances Problem

| Code Path | Dio Instance | Auth Token | Used By |
|-----------|-------------|------------|---------|
| `backendServiceProvider` → `BackendService` | Own Dio with `getIdToken` interceptor | ID token (correct) | `chatProvider`, subscription |
| `dioProvider` from `bootstrap.dart` | Bare Dio, NO auth interceptor | **NONE** | `askBartenderApiProvider` (chat screen), `recommendApiProvider`, `createStudioApiProvider`, `visionApiProvider` |

**Voice worked** because `voice_ai_service.dart` manages its own Dio with `getValidIdToken()`, completely independent of both code paths.

### Fix Applied

All 4 providers switched from `dioProvider` to `backendServiceProvider.dio`:

```dart
// BEFORE (broken):
final askBartenderApiProvider = Provider<AskBartenderApi>((ref) {
  final dio = ref.watch(dioProvider);  // bare Dio, NO auth
  return AskBartenderApi(dio);
});

// AFTER (fixed):
final askBartenderApiProvider = Provider<AskBartenderApi>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  return AskBartenderApi(backendService.dio);  // authenticated Dio with ID token
});
```

### Deployment Completed

After fixing the mobile app, all 4 APIM batches were deployed successfully:
- Batch 1: subscription-config, subscription-status (previously deployed)
- Batch 2: ask-bartender, ask-bartender-simple, recommend, refine-cocktail (previously deployed)
- Batch 3: vision-analyze, speech-token, voice-bartender (deployed after fix)
- Batch 4: social-connect-start, social-share-external, auth-exchange, auth-rotate (deployed after fix)

**All 13 operations now have JWT validation. 5 public endpoints verified unaffected.**

### Lessons Learned

1. **Always check the client first**: When a gateway policy "breaks" authenticated requests, verify the client is actually sending the auth token
2. **Two Dio instances is an anti-pattern**: Having both `dioProvider` (bare) and `backendServiceProvider` (authenticated) created a trap for new API providers
3. **Voice working was a red herring**: Voice used its own Dio, so it couldn't diagnose the shared Dio problem
4. **The deployment method (ARM REST API vs Portal) was NOT the issue**: Both methods work correctly for policy deployment

See `BUG_FIXES.md` (BUG-008) for full technical details.

---

## Previous Suggested Next Steps (Now Resolved)

1. **Check APIM gateway logs** — Query `ApiManagementGatewayLogs` in Log Analytics workspace `DefaultWorkspace-a30b74bc-d8dd-4564-8356-2269a68a9e18-EUS` for actual response codes and error details on ask-bartender-simple requests.

2. **Test with a valid JWT directly against APIM** — Get a real JWT token (from Flutter debug output or by authenticating via Entra External ID) and test `ask-bartender-simple` directly at `https://apim-mba-002.azure-api.net/api/v1/ask-bartender-simple` to see the exact response.

3. **Try deploying via Azure Portal** — Manually paste the minimal policy XML into the Azure Portal for `ask-bartender-simple` to see if the deployment method matters.

4. **Roll back** — Delete the policies from all 6 broken operations to restore chat functionality while investigating. Use the script's `Clear-OperationPolicy` function or delete via Azure Portal.

### Rollback Command
```powershell
# To remove a policy from a specific operation:
$token = az account get-access-token --resource "https://management.azure.com/" --query accessToken -o tsv
$subId = (az account show | ConvertFrom-Json).id
$headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
$base = "https://management.azure.com/subscriptions/$subId/resourceGroups/rg-mba-prod/providers/Microsoft.ApiManagement/service/apim-mba-002/apis/mybartenderai-api"

# Delete policy from each broken operation:
@("ask-bartender-simple", "ask-bartender", "recommend", "refine-cocktail", "subscription-config", "subscription-status") | ForEach-Object {
    Invoke-RestMethod -Uri "$base/operations/$_/policies/policy?api-version=2022-08-01" -Headers $headers -Method DELETE
    Write-Host "Removed policy from $_"
}
```
