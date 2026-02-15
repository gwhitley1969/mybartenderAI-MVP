# Voice AI Production Implementation Plan

> **Note (February 2026):** This document was written during the Free/Premium/Pro tier model. The subscription model has since been simplified to a binary `paid`/`none` entitlement managed via RevenueCat. References to "Pro tier" below should be read as "paid entitlement (subscriber)." See `SUBSCRIPTION_DEPLOYMENT.md` for the current model and `VOICE_AI_DEPLOYED.md` for the current voice architecture.

**Created:** December 11, 2025
**Last Updated:** January 7, 2026
**Status:** ✅ Implemented
**Estimated Effort:** 1.5-2 hours

---

## Executive Summary

This plan transitions Voice AI from direct Function App access (testing mode) to production-ready architecture using Azure API Management (APIM) for security, rate limiting, and consistent authentication.

### Current State (Testing)
```
Mobile App → Direct to Function App (func-mba-fresh)
             Using x-functions-key header (currently EMPTY)
             Result: 401 Unauthorized
```

### Target State (Production)
```
Mobile App → Front Door → APIM (JWT validation) → Function App
                                    ↓
                          Extracts user ID from JWT
                          Enforces tier/quota at function level

Then for voice conversation:
Mobile App ←══ WebRTC ══→ Azure OpenAI Realtime API (direct)
```

---

## Architecture Deep Dive

### Why This Architecture is Correct

**Voice AI has two distinct traffic types:**

| Traffic Type | Path | Latency Sensitivity |
|--------------|------|---------------------|
| Session Setup (REST) | APIM → Function | LOW (one-time, ~500ms OK) |
| Voice Conversation (WebRTC) | Direct to Azure OpenAI | HIGH (real-time audio) |

**Key Insight:** APIM only affects the session setup call (adds ~20-50ms once). The actual real-time audio conversation goes directly to Azure OpenAI - it never touches APIM, Front Door, or our Function App.

### Security Model (Microsoft Best Practices)

1. **Ephemeral Token Pattern** (Already Implemented)
   - Token valid for only 1 minute
   - Minted by our Function App using Azure OpenAI API key
   - API key stored in Key Vault, accessed via Managed Identity
   - Mobile app NEVER sees the actual API key

2. **JWT Authentication at APIM**
   - Entra External ID issues JWT to mobile app
   - APIM validates JWT (signature, issuer, audience, expiry)
   - APIM extracts user ID (sub claim) and passes to function
   - Function handles tier/quota logic

3. **No Secrets in Mobile App**
   - No function keys
   - No API keys
   - Only user's JWT token (from normal auth flow)

---

## Implementation Phases

### Phase 1: APIM Configuration

#### Step 1.1: Create Voice Operations in APIM

Create three API operations:

| Operation Name | Method | URL Template | Backend Function |
|----------------|--------|--------------|------------------|
| voice-session | POST | /v1/voice/session | voice-session |
| voice-quota | GET | /v1/voice/quota | voice-quota |
| voice-usage | POST | /v1/voice/usage | voice-usage |

#### Step 1.2: Create Voice Policy XML

File: `infrastructure/apim/policies/voice-endpoints-policy.xml`

```xml
<policies>
    <inbound>
        <base />

        <!-- JWT Validation for Entra External ID -->
        <validate-jwt
            header-name="Authorization"
            failed-validation-httpcode="401"
            failed-validation-error-message="Voice AI requires authentication. Please sign in."
            require-expiration-time="true"
            require-scheme="Bearer"
            require-signed-tokens="true">
            <openid-config url="https://mybartenderai.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0/.well-known/openid-configuration" />
            <audiences>
                <audience>f9f7f159-b847-4211-98c9-18e5b8193045</audience>
            </audiences>
            <issuers>
                <issuer>https://a82813af-1054-4e2d-a8ec-c6b9c2908c91.ciamlogin.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0</issuer>
            </issuers>
        </validate-jwt>

        <!-- Extract User ID from JWT and pass to backend -->
        <set-header name="X-User-Id" exists-action="override">
            <value>@{
                Jwt jwt;
                if (context.Request.Headers.GetValueOrDefault("Authorization","")
                    .Replace("Bearer ", "").TryParseJwt(out jwt))
                {
                    return jwt?.Subject ?? "";
                }
                return "";
            }</value>
        </set-header>

        <!-- Add correlation ID for tracing -->
        <set-header name="X-Correlation-Id" exists-action="override">
            <value>@(context.RequestId.ToString())</value>
        </set-header>

        <!-- Per-user rate limiting -->
        <rate-limit-by-key
            calls="10"
            renewal-period="60"
            counter-key="@("voice-" + context.Request.Headers.GetValueOrDefault("X-User-Id", "anonymous"))"
            increment-condition="@(context.Response.StatusCode >= 200 && context.Response.StatusCode < 300)" />

        <!-- Set backend -->
        <set-backend-service base-url="https://func-mba-fresh.azurewebsites.net/api" />
    </inbound>

    <backend>
        <base />
    </backend>

    <outbound>
        <base />
        <!-- Remove sensitive headers from response -->
        <set-header name="X-Powered-By" exists-action="delete" />
        <set-header name="X-AspNet-Version" exists-action="delete" />
    </outbound>

    <on-error>
        <base />
        <choose>
            <when condition="@(context.Response.StatusCode == 401)">
                <set-body>@{
                    return new JObject(
                        new JProperty("error", "unauthorized"),
                        new JProperty("message", "Voice AI requires authentication. Please sign in.")
                    ).ToString();
                }</set-body>
            </when>
            <when condition="@(context.Response.StatusCode == 429)">
                <set-body>@{
                    return new JObject(
                        new JProperty("error", "rate_limited"),
                        new JProperty("message", "Too many requests. Please wait a moment.")
                    ).ToString();
                }</set-body>
            </when>
        </choose>
    </on-error>
</policies>
```

#### Step 1.3: Create Deployment Script

File: `infrastructure/apim/scripts/apply-voice-policies.ps1`

```powershell
# Apply Voice AI APIM Policies
# Usage: .\apply-voice-policies.ps1

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# Configuration
$resourceGroup = "rg-mba-prod"
$serviceName = "apim-mba-002"
$apiId = "mybartenderai-api"
$backendUrl = "https://func-mba-fresh.azurewebsites.net/api"

# Voice operations to create
$voiceOperations = @(
    @{
        Name = "voice-session"
        DisplayName = "Voice Session - Start"
        Method = "POST"
        UrlTemplate = "/v1/voice/session"
        Description = "Start a voice AI session and get ephemeral WebRTC token"
    },
    @{
        Name = "voice-quota"
        DisplayName = "Voice Quota - Get"
        Method = "GET"
        UrlTemplate = "/v1/voice/quota"
        Description = "Get current voice AI quota for the user"
    },
    @{
        Name = "voice-usage"
        DisplayName = "Voice Usage - Record"
        Method = "POST"
        UrlTemplate = "/v1/voice/usage"
        Description = "Record voice session usage after completion"
    }
)

Write-Host "Voice AI APIM Policy Deployment" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

if ($DryRun) {
    Write-Host "[DRY RUN MODE]" -ForegroundColor Yellow
}

# Get access token
Write-Host "`nGetting Azure access token..."
$token = az account get-access-token --query accessToken -o tsv
if (-not $token) {
    throw "Failed to get access token. Run 'az login' first."
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}

# Get subscription ID
$subscriptionId = az account show --query id -o tsv

# Read policy file
$policyPath = Join-Path $PSScriptRoot "..\policies\voice-endpoints-policy.xml"
if (-not (Test-Path $policyPath)) {
    throw "Policy file not found: $policyPath"
}
$policyContent = Get-Content $policyPath -Raw

Write-Host "Policy file loaded: $policyPath"

# Create/update each operation
foreach ($op in $voiceOperations) {
    Write-Host "`nProcessing operation: $($op.Name)" -ForegroundColor Cyan

    $operationUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.ApiManagement/service/$serviceName/apis/$apiId/operations/$($op.Name)?api-version=2022-08-01"

    # Create operation
    $operationBody = @{
        properties = @{
            displayName = $op.DisplayName
            method = $op.Method
            urlTemplate = $op.UrlTemplate
            description = $op.Description
        }
    } | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would create/update operation: $($op.Name)"
    } else {
        try {
            $response = Invoke-RestMethod -Uri $operationUri -Method PUT -Headers $headers -Body $operationBody
            Write-Host "  Created/updated operation: $($op.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to create operation: $_" -ForegroundColor Red
            continue
        }
    }

    # Apply policy to operation
    $policyUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.ApiManagement/service/$serviceName/apis/$apiId/operations/$($op.Name)/policies/policy?api-version=2022-08-01"

    $policyBody = @{
        properties = @{
            format = "xml"
            value = $policyContent
        }
    } | ConvertTo-Json -Depth 10

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would apply policy to: $($op.Name)"
    } else {
        try {
            $response = Invoke-RestMethod -Uri $policyUri -Method PUT -Headers $headers -Body $policyBody
            Write-Host "  Applied policy to: $($op.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to apply policy: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "`nNext steps:"
Write-Host "1. Test endpoints with valid JWT token"
Write-Host "2. Update mobile app (_bypassApim = false)"
Write-Host "3. Build and test APK"
```

---

### Phase 2: Mobile App Changes

#### Step 2.1: Update voice_ai_service.dart

**Current Code:**
```dart
// Direct Function App configuration for testing (bypassing APIM)
static const String _functionAppBaseUrl = 'https://func-mba-fresh.azurewebsites.net/api';
static const String _functionKey = String.fromEnvironment('VOICE_FUNCTION_KEY', defaultValue: '');
static const bool _bypassApim = true; // Set to false when APIM is ready
```

**Updated Code:**
```dart
// Production: Use APIM for secure access
static const bool _bypassApim = false; // APIM is now configured for voice endpoints

// Direct Function App URL only for emergency fallback (not used in production)
static const String _functionAppBaseUrl = 'https://func-mba-fresh.azurewebsites.net/api';
```

#### Step 2.2: Remove Function Key Logic

Remove all references to `_functionKey` since we're using APIM subscription keys.

#### Step 2.3: Update Header Logic

**Current:**
```dart
Future<Map<String, dynamic>> _getAuthHeaders() async {
  final headers = <String, dynamic>{};
  if (_bypassApim) {
    final userId = await _getUserId();
    if (userId != null && userId.isNotEmpty) {
      headers['x-user-id'] = userId;
    }
  }
  return headers;
}
```

**Updated:**
```dart
Future<Map<String, dynamic>> _getAuthHeaders() async {
  // When using APIM, headers are already set by the shared Dio instance
  // APIM extracts user ID from JWT and sets X-User-Id header
  return {};
}
```

---

### Phase 3: Testing & Verification

#### Step 3.1: Test APIM Endpoints

```powershell
# Get a valid JWT token first (from mobile app or test script)
$token = "eyJ0eXAi..."

# Test voice-session endpoint
Invoke-RestMethod -Uri "https://share.mybartenderai.com/api/v1/voice/session" `
    -Method POST `
    -Headers @{
        "Authorization" = "Bearer $token"
        "Ocp-Apim-Subscription-Key" = "<your-subscription-key>"
        "Content-Type" = "application/json"
    } `
    -Body "{}"
```

#### Step 3.2: Build and Test APK

```powershell
cd mobile/app
flutter clean
flutter pub get
flutter build apk --release
```

#### Step 3.3: Verify on Device

1. Install APK on test device
2. Sign in with test account (Pro tier)
3. Navigate to Voice AI
4. Tap microphone
5. Verify connection establishes
6. Test voice conversation

---

## Rollback Plan

If issues arise after deployment:

### Quick Rollback (Mobile App Only)
1. Set `_bypassApim = true` in voice_ai_service.dart
2. Build with function key: `flutter build apk --dart-define=VOICE_FUNCTION_KEY=<key>`
3. APIM operations remain but are unused

### Full Rollback (Remove APIM Operations)
```powershell
# Delete voice operations from APIM
az apim api operation delete --resource-group rg-mba-prod --service-name apim-mba-002 --api-id mybartenderai-api --operation-id voice-session
az apim api operation delete --resource-group rg-mba-prod --service-name apim-mba-002 --api-id mybartenderai-api --operation-id voice-quota
az apim api operation delete --resource-group rg-mba-prod --service-name apim-mba-002 --api-id mybartenderai-api --operation-id voice-usage
```

---

## Security Checklist

- [ ] JWT validation enabled on all voice operations
- [ ] User ID extracted from JWT (not from client)
- [ ] Rate limiting configured per user
- [ ] No API keys or function keys in mobile app
- [ ] Ephemeral token pattern maintained (1-minute expiry)
- [ ] Azure OpenAI API key remains in Key Vault only
- [ ] Function App uses Managed Identity for Key Vault access

---

## Files to Create/Modify Summary

### Create
| File | Purpose |
|------|---------|
| `infrastructure/apim/policies/voice-endpoints-policy.xml` | APIM policy for voice endpoints |
| `infrastructure/apim/scripts/apply-voice-policies.ps1` | Deployment script |

### Modify
| File | Changes |
|------|---------|
| `mobile/app/lib/src/services/voice_ai_service.dart` | Set `_bypassApim = false`, remove function key |

### No Changes Required
| File | Reason |
|------|--------|
| `backend/functions/index.js` | Voice functions already expect X-User-Id header |
| `mobile/app/lib/src/app/bootstrap.dart` | Already configures APIM headers |
| `mobile/app/lib/src/services/apim_subscription_service.dart` | Already handles APIM auth |

---

## Appendix: Header Flow Diagram

```
MOBILE APP                    APIM                         FUNCTION APP
    |                          |                               |
    |-- Authorization: Bearer JWT                              |
    |-- Ocp-Apim-Subscription-Key -------->                    |
    |                          |                               |
    |                     [Validate JWT]                       |
    |                     [Extract sub claim]                  |
    |                          |                               |
    |                          |-- X-User-Id: <sub claim> ---->|
    |                          |-- X-Correlation-Id: <uuid> -->|
    |                          |-- Authorization: Bearer JWT ->|
    |                          |                               |
    |                          |                          [Lookup user by azure_ad_sub]
    |                          |                          [Check tier = 'pro']
    |                          |                          [Check quota]
    |                          |                          [Get ephemeral token]
    |                          |                               |
    |<-- session info + ephemeral token ----------------------|
    |                                                          |
    |                                                          |
    |========== WebRTC Connection (Direct to Azure OpenAI) ===|
    |                                                          |
```

---

**Document Version:** 1.3
**Last Updated:** February 16, 2026

---

## Note: Bar Inventory Integration (December 27, 2025)

The original plan included passing user inventory context via the backend during session creation. This approach did not work for WebRTC sessions.

**Solution:** Inventory context is now sent directly via the WebRTC data channel using a `session.update` event after connection. This is handled entirely client-side in `voice_ai_service.dart`. See `VOICE_AI_DEPLOYED.md` for implementation details.

---

## Note: iOS Background Audio Capture Fix (February 15, 2026)

On iOS, `track.enabled = false` does not fully silence WebRTC audio — the microphone hardware stays active with `AVAudioSession` in `playAndRecord` + `voiceChat` mode. Background audio (TV, conversations) leaked through to Azure, producing unwanted user transcript bubbles even when the push-to-talk button was not held. Two-layer fix applied:

1. **Transcript guard**: `_isMuted` check on `conversation.item.input_audio_transcription.completed` drops leaked transcripts
2. **iOS `replaceTrack(null)`**: Swaps audio sender track to silence at WebRTC level so Azure receives zero audio data when muted

Android was unaffected. See `VOICE_AI_DEPLOYED.md` and `BUG_FIXES.md` (BUG-011) for details.

> **Follow-up (BUG-012):** The `getSenders()` audio sender capture used `firstWhere` with an `orElse` callback that triggered a Dart type inference error on iOS (`RTCRtpSender` vs `RTCRtpSenderNative`). Removed `orElse` — audio sender is guaranteed after `addTrack()`. See `BUG_FIXES.md` (BUG-012).

---

## Note: Background Noise Sensitivity Fix (December 2025 - January 2026)

### Problem

Users reported Voice AI was too sensitive to background noise (TV, other conversations, environmental sounds).

**January 2026 Update**: Even with server-side `semantic_vad` configuration, the AI would stop mid-sentence when TV dialogue was detected due to client-side state machine bugs.

### Solution: Two-Part Fix

#### Part 1: Server Configuration (December 2025)

```javascript
turn_detection: {
    type: 'semantic_vad',           // AI-powered speech intent detection
    eagerness: 'low',               // More tolerant of background noise
    create_response: true,
    interrupt_response: false       // Prevent background noise from interrupting
},
input_audio_noise_reduction: {
    type: 'far_field'               // Aggressive filtering for noisy environments
}
```

#### Part 2: Client-Side State Guards (January 2026)

Fixed multiple bugs in `voice_ai_service.dart`:

1. **Wrong event names**: Changed `response.audio.started` → `output_audio_buffer.started`
2. **Premature state change**: Removed `_setState(VoiceAIState.speaking)` from WebRTC `onTrack` handler (fires at connection, not playback)
3. **Added state guards**: `speech_started` events now ignored when AI is speaking

### Key Insight

The WebRTC `onTrack` event fires when the audio TRACK is added during connection setup, NOT when audio actually starts playing. Setting state to `speaking` at that point caused the state guards to incorrectly block user speech.

### Key Differences

| Aspect | server_vad (Before) | semantic_vad + guards (After) |
|--------|---------------------|-------------------------------|
| Detection | Audio energy threshold | AI understands speech intent |
| Background noise | Triggers false positives | Filtered out + client guards |
| Other voices | Cannot distinguish | Focuses on primary speaker |
| Latency | ~100ms | ~200ms (acceptable trade-off) |

### Files Modified

- `backend/functions/index.js` - voice-session function (eagerness: low, interrupt_response: false, far_field)
- `mobile/app/lib/src/services/voice_ai_service.dart` - Fixed event names, removed onTrack state change, added state guards

### Testing Results (January 7, 2026)

- ✅ AI completes full responses with TV dialogue in background
- ✅ User can still speak to AI and get responses
- ✅ State machine correctly transitions

See `VOICE_AI_DEPLOYED.md` for full implementation details.
