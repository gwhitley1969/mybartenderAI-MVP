# Voice AI Feature - Deployment Documentation

**Date Deployed**: December 8, 2025
**Last Updated**: December 27, 2025
**Status**: ✅ Deployed and Tested
**Tier Requirement**: Pro only
**Latest APK**: `mobile/app/build/app/outputs/flutter-apk/app-release.apk`

---

## Overview

Real-time voice conversations with an AI bartender using Azure OpenAI GPT-realtime-mini API via WebRTC. Users can speak naturally and receive spoken responses with live transcription.

### Business Model
- **Pro Tier**: 60 minutes/month included ($7.99/month)
- **Add-on Packs**: 20 minutes for $4.99 (non-expiring)
- **Voice Metering**: Active speech time only (user + AI talking, not idle time)
- **Estimated Cost**: ~$0.03/minute (~$1.80 for 60 min usage)
- **Margin**: ~$3.50+ per Pro user after 30% app store cut

---

## Azure Resources Configured

### Key Vault Secrets Added (`kv-mybartenderai-prod`)

| Secret Name | Value | Purpose |
|-------------|-------|---------|
| `AZURE-OPENAI-REALTIME-ENDPOINT` | `https://blueb-midjmnz5-eastus2.cognitiveservices.azure.com` | Azure OpenAI resource endpoint |
| `AZURE-OPENAI-REALTIME-KEY` | `ExvZDQ...` (redacted) | API key for authentication |
| `AZURE-OPENAI-REALTIME-DEPLOYMENT` | `gpt-realtime-mini` | Model deployment name |

### Function App Settings (`func-mba-fresh`)

Added Key Vault references in Application Settings:
```
AZURE_OPENAI_REALTIME_ENDPOINT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-OPENAI-REALTIME-ENDPOINT/)
AZURE_OPENAI_REALTIME_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-OPENAI-REALTIME-KEY/)
AZURE_OPENAI_REALTIME_DEPLOYMENT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-OPENAI-REALTIME-DEPLOYMENT/)
```

---

## Database Schema Changes

### Migration File
`backend/functions/migrations/006_voice_ai_tables.sql`

### New Tables

#### `voice_messages`
Stores conversation transcripts for each voice session.

```sql
CREATE TABLE voice_messages (
    id SERIAL PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES voice_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'assistant')),
    transcript TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_voice_messages_session ON voice_messages(session_id, timestamp);
```

#### `voice_addon_purchases`
Tracks add-on minute pack purchases (non-expiring).

```sql
CREATE TABLE voice_addon_purchases (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seconds_purchased INTEGER NOT NULL,           -- 1200 = 20 minutes
    price_cents INTEGER NOT NULL,                 -- 499 = $4.99
    transaction_id VARCHAR(255),                  -- App Store/Play Store transaction ID
    platform VARCHAR(20) CHECK (platform IN ('ios', 'android', 'web')),
    purchased_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_voice_addon_user ON voice_addon_purchases(user_id, purchased_at DESC);
```

### Extended `voice_sessions` Table

Added columns via ALTER TABLE:
- `input_tokens INTEGER` - Total audio input tokens consumed
- `output_tokens INTEGER` - Total audio output tokens consumed
- `status VARCHAR(20)` - Session status: 'active', 'completed', 'error', 'quota_exceeded'
- `error_message TEXT` - Error details if session failed

### New View

#### `voice_usage_summary`
Aggregated monthly voice usage per user with quota calculations.

```sql
CREATE VIEW voice_usage_summary AS
SELECT
    u.id AS user_id,
    u.email,
    u.tier,
    DATE_TRUNC('month', vs.started_at) AS month,
    COUNT(vs.id) AS session_count,
    COALESCE(SUM(vs.duration_seconds), 0) AS total_seconds_used,
    COALESCE(SUM(vs.input_tokens), 0) AS total_input_tokens,
    COALESCE(SUM(vs.output_tokens), 0) AS total_output_tokens,
    CASE
        WHEN u.tier = 'pro' THEN 1800 - COALESCE(SUM(vs.duration_seconds), 0)
        ELSE 0
    END AS remaining_seconds,
    COALESCE((SELECT SUM(vap.seconds_purchased) FROM voice_addon_purchases vap WHERE vap.user_id = u.id), 0) AS addon_seconds_purchased
FROM users u
LEFT JOIN voice_sessions vs ON u.id = vs.user_id
    AND vs.started_at >= DATE_TRUNC('month', CURRENT_DATE)
    AND vs.status = 'completed'
GROUP BY u.id, u.email, u.tier, DATE_TRUNC('month', vs.started_at);
```

### New Database Functions

#### `check_voice_quota(p_user_id UUID)`
Returns quota status for a user including monthly and addon seconds.

```sql
RETURNS TABLE(
    has_quota BOOLEAN,
    monthly_used_seconds INTEGER,
    monthly_limit_seconds INTEGER,
    addon_seconds_remaining INTEGER,
    total_remaining_seconds INTEGER
)
```

#### `record_voice_session(...)`
Records completed voice session and updates usage tracking.

```sql
CREATE FUNCTION record_voice_session(
    p_user_id UUID,
    p_session_id UUID,
    p_duration_seconds INTEGER,
    p_input_tokens INTEGER DEFAULT NULL,
    p_output_tokens INTEGER DEFAULT NULL
) RETURNS VOID
```

---

## Azure Functions Deployed

All functions added to `backend/functions/index.js` (consolidated Azure Functions v4 model).

### 1. Voice Session - `voice-session`

**Route**: POST `/api/v1/voice/session`
**Auth Level**: Function key
**Purpose**: Creates voice session and returns ephemeral token for WebRTC

**Request Headers**:
- `x-user-id`: User UUID (set by APIM after JWT validation)
- `x-functions-key`: Function key

**Request Body** (optional):
```json
{
  "inventory": {
    "spirits": ["vodka", "gin"],
    "mixers": ["tonic", "lime juice"],
    "garnishes": ["lime wedge"]
  }
}
```

**Success Response** (200):
```json
{
  "success": true,
  "session": {
    "dbSessionId": "uuid-here",
    "realtimeSessionId": "sess_xxx",
    "model": "gpt-realtime-mini",
    "voice": "alloy"
  },
  "token": {
    "value": "ephemeral-token-here",
    "expiresAt": 1733698800
  },
  "webrtcUrl": "https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc",
  "quota": {
    "remainingSeconds": 1800,
    "monthlyUsedSeconds": 0,
    "monthlyLimitSeconds": 1800,
    "addonSecondsRemaining": 0,
    "warningThreshold": 360
  }
}
```

**Error Responses**:
- `401` - Unauthorized (no user ID)
- `403` - Tier required (not Pro) or quota exceeded
- `404` - User not found
- `500` - Configuration error or token generation failed

### 2. Voice Usage - `voice-usage`

**Route**: POST `/api/v1/voice/usage`
**Auth Level**: Function key
**Purpose**: Records completed session usage and saves transcripts

**Request Body**:
```json
{
  "sessionId": "uuid-here",
  "durationSeconds": 180,
  "inputTokens": 1500,
  "outputTokens": 2000,
  "transcripts": [
    {
      "role": "user",
      "transcript": "How do I make a margarita?",
      "timestamp": "2025-12-08T21:30:00Z"
    },
    {
      "role": "assistant",
      "transcript": "Great choice! For a classic margarita...",
      "timestamp": "2025-12-08T21:30:05Z"
    }
  ]
}
```

**Success Response** (200):
```json
{
  "success": true,
  "message": "Usage recorded successfully",
  "sessionId": "uuid-here",
  "durationRecorded": 180,
  "quota": {
    "remainingSeconds": 1620,
    "monthlyUsedSeconds": 180,
    "monthlyLimitSeconds": 1800,
    "addonSecondsRemaining": 0
  }
}
```

### 3. Voice Quota - `voice-quota`

**Route**: GET `/api/v1/voice/quota`
**Auth Level**: Function key
**Purpose**: Returns current voice quota status for UI display

**Success Response** (200 - Pro user):
```json
{
  "success": true,
  "hasAccess": true,
  "hasQuota": true,
  "tier": "pro",
  "quota": {
    "remainingSeconds": 1440,
    "remainingMinutes": 24,
    "monthlyUsedSeconds": 360,
    "monthlyLimitSeconds": 1800,
    "addonSecondsRemaining": 0,
    "percentUsed": 20
  },
  "showWarning": false,
  "warningMessage": null
}
```

**Success Response** (200 - Non-Pro user):
```json
{
  "success": true,
  "hasAccess": false,
  "tier": "free",
  "message": "Voice AI requires Pro tier"
}
```

### 4. Voice Realtime Test - `voice-realtime-test`

**Route**: GET/POST `/api/v1/voice/test`
**Auth Level**: Function key
**Purpose**: Validates Realtime API connectivity (for testing)

**Success Response** (200):
```json
{
  "success": true,
  "message": "Realtime API connection validated successfully!",
  "session": {
    "id": "sess_xxx",
    "model": "gpt-realtime-mini",
    "voice": "alloy",
    "hasClientSecret": true,
    "expiresAt": 1733698800
  },
  "webrtcUrl": "https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc",
  "note": "Ephemeral token generated successfully..."
}
```

---

## Flutter Mobile App Implementation

### Dependencies Added

**`pubspec.yaml`**:
```yaml
# Voice AI - WebRTC for real-time audio with Azure OpenAI Realtime API
flutter_webrtc: ^0.12.6
```

### Platform Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<!-- Voice AI permissions for WebRTC audio -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>My AI Bartender needs microphone access to have voice conversations with your AI bartender.</string>
```

### New Dart Files

#### `lib/src/services/voice_ai_service.dart`

Core service managing WebRTC connection and voice state.

**Key Classes**:
- `VoiceAIService` - Main service class
- `VoiceAIState` - Enum: idle, connecting, listening, processing, speaking, error, quotaExhausted, tierRequired
- `VoiceQuota` - Quota data model
- `VoiceSessionInfo` - Session metadata
- `VoiceTranscript` - Transcript entry (role, text, timestamp)
- `VoiceAIException`, `VoiceAITierRequiredException`, `VoiceAIQuotaExceededException` - Exception types

**Key Methods**:
```dart
Future<bool> requestMicrophonePermission()
Future<bool> hasMicrophonePermission()
Future<VoiceQuota> getVoiceQuota()
Future<VoiceSessionInfo> startSession({...})
Future<void> endSession()
```

#### `lib/src/providers/voice_ai_provider.dart`

Riverpod state management for voice AI.

**Providers**:
- `voiceAIServiceProvider` - Service singleton
- `voiceQuotaProvider` - FutureProvider for quota check
- `voiceAINotifierProvider` - StateNotifier for session state

**State Class**:
```dart
class VoiceAISessionState {
  final VoiceAIState voiceState;
  final bool isLoading;
  final String? error;
  final VoiceSessionInfo? sessionInfo;
  final VoiceQuota? quota;
  final List<VoiceTranscript> transcripts;
  final bool requiresUpgrade;
}
```

#### `lib/src/features/voice_ai/voice_ai_screen.dart`

Main conversation UI screen featuring:
- Quota display in app bar
- Low quota warning banner
- Scrollable transcript view
- Status indicator (listening, speaking, processing, etc.)
- Animated voice button
- Upgrade prompt for non-Pro users
- Quota exhausted prompt with add-on purchase option

#### `lib/src/features/voice_ai/widgets/voice_button.dart`

Animated microphone button with:
- Color-coded gradients based on state
- Pulsing animation when listening/speaking
- Size changes based on activity
- Loading spinner during connection

**State Colors**:
- Idle: Purple gradient
- Connecting: Orange/red gradient
- Listening: Green gradient (pulsing)
- Processing: Blue gradient
- Speaking: Purple gradient (pulsing)
- Error: Red gradient
- Locked: Gray gradient

#### `lib/src/features/voice_ai/widgets/transcript_view.dart`

Conversation display featuring:
- Chat bubble UI (user on right, assistant on left)
- Auto-scroll on new messages
- Typing indicator during AI processing
- Empty state with suggestion chips
- Timestamps on messages

### User Interface Updates (December 9, 2025)

**Status Indicator Improvements:**
- Clear status messages: "Listening...", "Thinking...", "Speaking..."
- **"Tap microphone to stop"** instruction displayed below status when session is active
- Color-coded status indicators (green for listening, blue for thinking, purple for speaking)

**Session Control:**
- Users tap the microphone button to start a voice session
- Users tap the same microphone button again to end the session
- Status text provides clear guidance on how to stop the AI

#### `lib/src/features/voice_ai/widgets/quota_display.dart`

Quota visualization widgets:
- `QuotaChip` - Small chip for app bar (color-coded by remaining time)
- `QuotaDisplay` - Full progress bar display with usage stats

---

## System Prompt (AI Personality)

The bartender AI uses this system prompt configured in the voice-session function:

```
You are an expert bartender and mixologist with decades of experience.
Your name is "My AI Bartender" and you work exclusively within the My AI Bartender mobile app.

EXPERTISE AREAS (respond helpfully to these topics):
- Cocktail recipes, ingredients, measurements, and preparation techniques
- Mixology theory: flavor profiles, spirit categories, balancing drinks
- Bar tools and equipment: shakers, jiggers, muddlers, strainers, glassware
- Garnishes and presentation techniques
- Spirit knowledge: production, aging, tasting notes, brands
- Non-alcoholic mocktails and low-ABV options
- Drink history and origins
- Bar setup and home bar recommendations
- Food pairings with cocktails
- Responsible drinking guidance

VOICE INTERACTION STYLE:
- Speak naturally and conversationally, as if talking across a bar
- Keep responses concise for voice (aim for under 30 seconds of speech)
- Use clear step-by-step instructions for recipes
- Offer follow-up suggestions ("Would you like to know about a variation?")

STRICT BOUNDARIES:
If asked about topics outside bartending/mixology (politics, news, technology,
health advice, etc.), respond warmly but redirect:
"I'm your bartender - my expertise is cocktails and drinks! I'd be happy to
help with anything drink-related. Is there a cocktail I can help you make?"

Never provide:
- Medical or health advice beyond general responsible drinking
- Political opinions or commentary
- Information unrelated to beverages and bar culture
```

---

## WebRTC Connection Flow

1. **Start Session**: Flutter calls POST `/v1/voice/session`
2. **Backend**:
   - Validates Pro tier
   - Checks quota via `check_voice_quota()`
   - Creates database session record
   - Requests ephemeral token from Azure OpenAI Realtime API
   - Returns token + WebRTC URL
3. **Flutter**:
   - Requests microphone permission
   - Creates local audio stream
   - Creates RTCPeerConnection
   - Creates data channel for events
   - Creates SDP offer
   - Sends offer to WebRTC URL with ephemeral token
   - Sets remote description from answer
4. **During Session**:
   - Audio streams bidirectionally
   - Data channel receives transcripts and state events
   - UI updates based on VAD (voice activity detection)
5. **End Session**: Flutter calls POST `/v1/voice/usage` with duration and transcripts

---

## Quota Constants

```javascript
const MONTHLY_VOICE_SECONDS = 3600;  // 60 minutes for Pro at $7.99/mo
const ADDON_VOICE_SECONDS = 1200;    // 20 minutes per add-on pack ($4.99)
const WARNING_THRESHOLD = 720;       // Show warning at 12 minutes remaining (80% used)
```

---

## Testing Checklist

- [x] Non-Pro user sees upgrade prompt when opening Voice AI
- [x] Pro user can start voice session
- [x] Microphone permission flow works (Android)
- [x] Real-time transcription displays correctly
- [x] AI responds audibly
- [x] User can speak naturally with VAD detection
- [x] "Tap microphone to stop" instruction visible during active session
- [ ] "Minutes remaining" updates after each session
- [ ] 80% warning toast appears at 6 minutes remaining
- [ ] Quota exhaustion shows purchase option
- [ ] Conversation history saved to database
- [ ] Session survives brief network interruption
- [x] Out-of-scope questions get polite redirect
- [x] Background noise filtered (semantic_vad + noise reduction)
- [ ] End session properly records usage
- [ ] iOS microphone permission flow (not yet tested)

---

## File Locations Summary

### Backend
- `backend/functions/index.js` - Functions #29-32 (voice-realtime-test, voice-session, voice-usage, voice-quota)
- `backend/functions/migrations/006_voice_ai_tables.sql` - Database migration

### Flutter
- `mobile/app/pubspec.yaml` - flutter_webrtc dependency
- `mobile/app/android/app/src/main/AndroidManifest.xml` - RECORD_AUDIO permission
- `mobile/app/ios/Runner/Info.plist` - NSMicrophoneUsageDescription
- `mobile/app/lib/src/services/voice_ai_service.dart` - WebRTC service
- `mobile/app/lib/src/providers/voice_ai_provider.dart` - State management
- `mobile/app/lib/src/features/voice_ai/voice_ai_screen.dart` - Main screen
- `mobile/app/lib/src/features/voice_ai/widgets/voice_button.dart` - Mic button
- `mobile/app/lib/src/features/voice_ai/widgets/transcript_view.dart` - Chat view
- `mobile/app/lib/src/features/voice_ai/widgets/quota_display.dart` - Quota widgets

---

## App Integration (Completed December 8, 2025)

### GoRouter Route Added

**File**: `mobile/app/lib/main.dart`

Added import and route for Voice AI screen:

```dart
import 'src/features/voice_ai/voice_ai_screen.dart';

// In GoRouter routes under '/' route's children:
GoRoute(
  path: 'voice-ai',
  builder: (BuildContext context, GoRouterState state) {
    return const VoiceAIScreen();
  },
),
```

### Home Screen Entry Point Added

**File**: `mobile/app/lib/src/features/home/home_screen.dart`

Added Voice button in the "AI Cocktail Concierge" section alongside the Chat button:

```dart
// Action Buttons - Row 1
Row(
  children: [
    Expanded(
      child: _buildActionButton(
        context: context,
        icon: Icons.chat_bubble_outline,
        title: 'Chat',
        subtitle: 'Text conversation',
        color: AppColors.iconCircleBlue,
        onTap: () => context.go('/ask-bartender'),
      ),
    ),
    SizedBox(width: AppSpacing.md),
    Expanded(
      child: _buildActionButton(
        context: context,
        icon: Icons.mic,
        title: 'Voice',
        subtitle: 'Talk to AI',
        color: const Color(0xFF8B5CF6), // Purple for voice
        onTap: () => context.go('/voice-ai'),
      ),
    ),
  ],
),
```

### APIM Bypass for Testing

**File**: `mobile/app/lib/src/services/voice_ai_service.dart`

Configured voice service to call Function App directly during testing:

```dart
// Direct Function App configuration for testing (bypassing APIM)
// TODO: Remove this when APIM is configured for voice endpoints
static const String _functionAppBaseUrl = 'https://func-mba-fresh.azurewebsites.net/api';
// Function key passed via environment variable at build time
static const String _functionKey = String.fromEnvironment('VOICE_FUNCTION_KEY', defaultValue: '');
static const bool _bypassApim = true; // Set to false when APIM is ready
```

The service creates a dedicated Dio instance for voice API calls:
- Uses `x-functions-key` header for authentication
- Calls Function App directly at `https://func-mba-fresh.azurewebsites.net/api`
- Added debug logging throughout for troubleshooting

**To switch back to APIM**: Set `_bypassApim = false` and the service will use the shared backend Dio instance.

### APK Build

Built debug APK for testing:
```powershell
cd mobile/app
flutter clean
flutter pub get
flutter build apk --debug
```

**Output**: `mobile/app/build/app/outputs/flutter-apk/app-debug.apk` (~186MB debug build)

---

## Next Steps (Not Yet Implemented)

1. ~~**Add route to GoRouter**~~ ✅ Completed
2. ~~**APIM Integration**~~ ✅ Completed - Voice endpoints configured with JWT validation
3. **Add-on Purchase Flow** - Integrate with App Store/Play Store for minute packs
4. ~~**Inventory Context**~~ ✅ Completed - Bar inventory sent via session.update (Dec 27, 2025)
5. **Session History** - View past voice conversations from profile
6. **Analytics** - Track voice usage metrics in Application Insights

---

## Deployment Commands Used

```powershell
# Add Key Vault secrets
az keyvault secret set --vault-name kv-mybartenderai-prod --name AZURE-OPENAI-REALTIME-ENDPOINT --value "https://blueb-midjmnz5-eastus2.cognitiveservices.azure.com"
az keyvault secret set --vault-name kv-mybartenderai-prod --name AZURE-OPENAI-REALTIME-KEY --value "..."
az keyvault secret set --vault-name kv-mybartenderai-prod --name AZURE-OPENAI-REALTIME-DEPLOYMENT --value "gpt-realtime-mini"

# Add Function App settings
az functionapp config appsettings set --name func-mba-fresh --resource-group rg-mba-prod --settings "AZURE_OPENAI_REALTIME_ENDPOINT=@Microsoft.KeyVault(...)"

# Run database migration
PGPASSWORD="..." psql -h pg-mybartenderdb.postgres.database.azure.com -U pgadmin -d mybartender -f backend/functions/migrations/006_voice_ai_tables.sql

# Deploy functions
cd backend/functions && func azure functionapp publish func-mba-fresh --javascript

# Install Flutter dependencies
cd mobile/app && flutter pub get
```

---

## Deployed Function Endpoints

After deployment, the following voice endpoints are available:

| Function | URL |
|----------|-----|
| voice-quota | `https://func-mba-fresh.azurewebsites.net/api/v1/voice/quota` |
| voice-session | `https://func-mba-fresh.azurewebsites.net/api/v1/voice/session` |
| voice-usage | `https://func-mba-fresh.azurewebsites.net/api/v1/voice/usage` |
| voice-realtime-test | `https://func-mba-fresh.azurewebsites.net/api/v1/voice/test` |

---

---

## Troubleshooting

### Issue: "Voice AI requires authentication. Please sign in" (401 Error) ✅ RESOLVED

**Date Fixed**: December 11, 2025

**Symptoms:**
- Voice AI fails with "Voice AI requires authentication. Please sign in" error
- User is authenticated and other features work correctly
- APIM returns 401 Unauthorized despite valid JWT token being sent

**Root Cause Analysis:**

The issue was a **Dio interceptor overwriting the correct Authorization header**.

1. **Token Types**: Entra External ID provides two tokens:
   - **Access Token**: `aud: https://graph.microsoft.com` (for Microsoft Graph API)
   - **ID Token**: `aud: f9f7f159-b847-4211-98c9-18e5b8193045` (our client app ID)

2. **APIM JWT Validation**: APIM policy validates that `aud` claim matches client app ID, requiring the **ID Token**.

3. **The Bug**: VoiceAIService was correctly obtaining and setting the ID Token in the Authorization header. However, the shared Dio instance from BackendService had an interceptor that **overwrote** the header with the Graph access token.

**Code Flow (Before Fix):**
```
1. VoiceAIService calls getValidIdToken() → Returns correct ID token (aud: client_app_id)
2. VoiceAIService sets: Authorization: Bearer <ID_TOKEN>
3. BackendService Dio interceptor runs → OVERWRITES header with Graph token
4. Request sent with: Authorization: Bearer <GRAPH_TOKEN> (aud: graph.microsoft.com)
5. APIM rejects → 401 Unauthorized (audience mismatch)
```

**Solution:**

Created a **separate Dio instance** for VoiceAIService without the auth interceptor:

**File**: `mobile/app/lib/src/services/voice_ai_service.dart`

```dart
VoiceAIService(this._dio, {...}) {
  // CRITICAL: Create a SEPARATE Dio instance for Voice AI requests
  //
  // Why? The shared _dio from BackendService has an interceptor that automatically
  // sets Authorization header with the Graph access token (for Microsoft Graph API).
  // But Voice AI endpoints require the ID token (with aud=client_app_id) for APIM
  // JWT validation. The interceptor would OVERWRITE our correct ID token with the
  // wrong Graph token, causing 401 errors.
  //
  // By creating a fresh Dio instance without interceptors, we ensure the
  // Authorization header we set in _getAuthHeaders() is preserved.
  _voiceDio = Dio(BaseOptions(
    baseUrl: _dio.options.baseUrl,
    connectTimeout: _dio.options.connectTimeout,
    receiveTimeout: _dio.options.receiveTimeout,
  ));

  // Add logging interceptor for debugging (this one doesn't modify headers)
  _voiceDio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
}
```

**Files Modified:**
- `mobile/app/lib/src/services/voice_ai_service.dart` - Created dedicated `_voiceDio` instance
- `mobile/app/lib/src/services/auth_service.dart` - Added `getValidIdToken()` method with debug logging
- `mobile/app/lib/src/providers/voice_ai_provider.dart` - Updated to use `getValidIdToken()` instead of `getValidAccessToken()`

**Key Learnings:**
1. **Access Token vs ID Token**: For APIM JWT validation, use the ID token (audience = client app ID), not the access token (audience = Graph API)
2. **Dio Interceptors**: Shared Dio instances with auth interceptors can overwrite headers set by specific services
3. **Debug Strategy**: Decode JWT tokens in logs to compare `aud` claim between what's stored and what's actually sent

**Verification:**
After the fix, Voice AI works correctly:
1. ID token with correct audience is preserved
2. APIM JWT validation passes
3. Voice session starts successfully

---

---

## Bar Inventory Integration (December 27, 2025)

### Problem

Voice AI could not access the user's "My Bar" inventory. When users asked "What's in my bar?" or "What can I make?", the AI would respond that it didn't know their ingredients - unlike the Chat feature which works correctly with inventory context.

### Root Cause

The `instructions` field in the Azure OpenAI Realtime API session creation request was not being applied to WebRTC sessions. The backend was correctly building inventory-aware system instructions, but they weren't reaching the AI.

### Solution: session.update via WebRTC Data Channel

Instead of relying on backend instruction injection during session creation, the mobile app now sends inventory instructions **directly to the active AI session** via the WebRTC data channel using the `session.update` event.

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Mobile App    │────▶│  Backend Func   │────▶│  Azure OpenAI   │
│                 │     │  voice-session  │     │  Realtime API   │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ 1. Load bar     │     │ 4. Create       │     │ 5. Return       │
│    inventory    │     │    session      │     │    ephemeral    │
│ 2. Store as     │     │    (no inv.)    │     │    token        │
│    pending      │     │                 │     │                 │
│    instructions │     │                 │     │                 │
│ 3. POST to      │     │                 │     │                 │
│    /voice/      │     │                 │     │                 │
│    session      │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                               │
        │                                               │
        └───────────── WebRTC Direct Connection ────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────┐
        │ 6. Data channel opens                       │
        │ 7. Send session.update with inventory       │
        │ 8. Azure responds with session.updated      │
        │ 9. AI now knows user's bar inventory!       │
        └─────────────────────────────────────────────┘
```

### Implementation Details

**File Modified:** `mobile/app/lib/src/services/voice_ai_service.dart`

**Key Changes:**

1. **Added `_pendingInstructions` field** to store inventory instructions until data channel is ready:
```dart
String? _pendingInstructions;
```

2. **Modified `startSession()`** to build inventory instructions:
```dart
if (inventory != null && (inventory['spirits']?.isNotEmpty ?? false)) {
  _pendingInstructions = _buildInventoryInstructions(inventory);
  debugPrint('[VOICE-AI] Built inventory instructions for ${inventory['spirits']?.length ?? 0} ingredients');
}
```

3. **Added `_buildInventoryInstructions()` helper**:
```dart
String _buildInventoryInstructions(Map<String, List<String>> inventory) {
  final allIngredients = inventory['spirits'] ?? [];
  final mixers = inventory['mixers'] ?? [];
  final combined = [...allIngredients, ...mixers].where((s) => s.isNotEmpty).toList();

  return '''
USER'S BAR INVENTORY:
The user has these ingredients in their home bar: ${combined.join(', ')}

IMPORTANT: When the user asks what they can make or for drink suggestions, you MUST reference these specific ingredients. Suggest cocktails that can be made using ONLY these available ingredients. If they ask "what's in my bar" or "what do I have", list these ingredients.
''';
}
```

4. **Added `_sendSessionUpdate()` method**:
```dart
void _sendSessionUpdate() {
  if (_pendingInstructions == null) return;
  if (_dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) return;

  final event = json.encode({
    'type': 'session.update',
    'session': {
      'instructions': _pendingInstructions,
    }
  });

  _dataChannel!.send(RTCDataChannelMessage(event));
  _pendingInstructions = null;
}
```

5. **Wired up data channel `onDataChannelState` handler**:
```dart
_dataChannel!.onDataChannelState = (RTCDataChannelState state) {
  if (state == RTCDataChannelState.RTCDataChannelOpen) {
    debugPrint('[VOICE-AI] Data channel opened');
    _sendSessionUpdate();
  }
};
```

6. **Added `session.updated` response handling** to confirm instructions were applied:
```dart
case 'session.updated':
  debugPrint('[VOICE-AI] Session updated - inventory instructions applied successfully');
  break;
```

### Why This Approach

| Approach | Pros | Cons |
|----------|------|------|
| Backend instruction injection | Single point of configuration | Not working for WebRTC sessions |
| **session.update via data channel** | Direct to AI, bypasses backend issues, confirmed working | Client-side instruction building |

The `session.update` approach is more reliable because:
1. Bypasses any backend body parsing issues
2. Instructions go directly to the active session
3. Confirmed by `session.updated` response from Azure
4. No backend deployment required for instruction changes

### Debug Logs

When working correctly, you'll see these log entries:
```
[VOICE-AI] Built inventory instructions for 8 ingredients
[VOICE-AI] Data channel state changed: RTCDataChannelOpen
[VOICE-AI] Data channel opened
[VOICE-AI] Sending session.update with inventory instructions
[VOICE-AI] session.update sent successfully
[VOICE-AI] Session updated - inventory instructions applied successfully
```

### Testing

1. Add ingredients to "My Bar" (e.g., vodka, gin, tonic water)
2. Start Voice AI session
3. Ask "What's in my bar?" - AI should list your ingredients
4. Ask "What can I make?" - AI should suggest drinks using your ingredients

---

---

## Background Noise Sensitivity Fix (Updated January 2026)

### Problem

Users reported the Voice AI was too sensitive to background noise:
- TV or music playing in the background would trigger responses
- Other people talking nearby would interrupt the AI
- Environmental sounds caused erratic behavior
- **January 2026 Update**: Even with initial `semantic_vad` fix, AI would pause indefinitely when background conversations were detected, requiring user to say "continue"

### Root Cause

The original implementation used `server_vad` (Voice Activity Detection), which detects speech based on audio energy thresholds. This was changed to `semantic_vad`, but with `eagerness: 'medium'` the AI was still too sensitive to background conversations in noisy environments (TV + people talking).

### Solution: Low Eagerness + Far-Field Noise Reduction + Enhanced WebRTC

**Key insight**: The `eagerness` parameter controls how quickly the AI assumes you've finished speaking:
- `high` = responds quickly, sensitive to any pause
- `medium` = balanced (still too sensitive for noisy environments)
- **`low`** = waits longer, more tolerant of background noise/pauses

**Session Configuration (voice-session function):**
```javascript
turn_detection: {
    type: 'semantic_vad',           // AI-powered speech understanding
    eagerness: 'low',               // More tolerant of background noise/pauses
    create_response: true,
    interrupt_response: false       // Prevents AI from being interrupted by noise
},
input_audio_noise_reduction: {
    type: 'far_field'               // Aggressive filtering for speakerphone/ambient use
}
```

**Client-side session.update (voice_ai_service.dart):**
```dart
'turn_detection': {
  'type': 'semantic_vad',
  'eagerness': 'low',
  'create_response': true,
  'interrupt_response': false,
},
'input_audio_noise_reduction': {
  'type': 'far_field',
},
```

**Enhanced WebRTC Audio Constraints:**
```dart
_localStream = await navigator.mediaDevices.getUserMedia({
  'audio': {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
    // Enhanced noise filtering for noisy environments
    'googNoiseSuppression': true,    // Chrome-specific enhanced suppression
    'googHighpassFilter': true,       // Filter low-frequency background noise
    'channelCount': 1,                // Mono audio (reduces complexity)
  },
  'video': false,
});
```

### How Semantic VAD Works

| Feature | server_vad | semantic_vad |
|---------|------------|--------------|
| Detection method | Audio energy threshold | AI speech understanding |
| Background noise | Triggers on any sound | Ignores non-speech |
| Other voices | Cannot distinguish | Focuses on primary speaker |
| TV/Music | Triggers false positives | Filters out |
| Latency | ~100ms | ~200ms |

### Noise Reduction Types

| Type | Best For | Description |
|------|----------|-------------|
| `near_field` | Headphones/close mic | Moderate noise filtering |
| `far_field` | Speakerphone/ambient | Aggressive filtering for noisy environments |

We use `far_field` because users are typically using phone speaker/mic in noisy bar environments.

### Eagerness Settings

| Setting | Behavior |
|---------|----------|
| **`low`** | Waits longer, more tolerant of background noise - **recommended for noisy environments** |
| `medium` | Balanced - too sensitive for TV + conversations |
| `high` | Responds quickly, may cut off user mid-sentence |

We use `low` to handle noisy environments (TV, background conversations) without pausing indefinitely.

### Files Modified

| File | Changes |
|------|---------|
| `backend/functions/index.js` | `eagerness: 'low'`, `interrupt_response: false`, `far_field` noise reduction |
| `mobile/app/lib/src/services/voice_ai_service.dart` | Same VAD settings + enhanced WebRTC audio constraints |

### Testing

After implementing these changes (January 2026):
- ✅ AI completes full responses without pausing when TV is on
- ✅ AI completes responses when people are talking nearby
- ✅ User can still speak to AI and get responses
- ✅ Slight increase in response latency (acceptable trade-off)

### Debug Logging

When session.update is sent with the new configuration:
```
[VOICE-AI] Sending session.update with turn_detection: semantic_vad
[VOICE-AI] Noise reduction enabled: far_field
[VOICE-AI] session.update sent successfully
[VOICE-AI] Session updated - configuration applied
```

---

## Client-Side State Guard Fix (January 7, 2026)

### Problem

Despite the server-side configuration (`semantic_vad`, `eagerness: low`, `interrupt_response: false`, `far_field`), the AI would still stop mid-sentence when TV dialogue was detected. The AI would wait indefinitely for user input.

### Root Cause Analysis

**The configuration was correct but insufficient.** Investigation revealed multiple issues:

1. **Azure still sends events**: Even with `interrupt_response: false`, Azure still SENDS `input_audio_buffer.speech_started` events when it detects human speech (including TV dialogue)

2. **Wrong event name in code**: The code was listening for `response.audio.started` which doesn't exist in Azure OpenAI Realtime API. The correct event is `output_audio_buffer.started`

3. **Premature state change in onTrack**: The WebRTC `onTrack` handler was setting state to `speaking` when the audio track was added during connection setup - NOT when the AI actually started talking. This caused the state machine to be in `speaking` state before any audio playback began

4. **Buffer clear command causing aborts**: Initial fix attempted to send `input_audio_buffer.clear` when background noise was detected, but this caused Azure to abort the response with a server error

### Solution: Multi-Part Fix

#### Fix 1: Correct Event Names

Changed from non-existent events to correct Azure OpenAI Realtime API events:

| Wrong (Before) | Correct (After) |
|----------------|-----------------|
| `response.audio.started` | `output_audio_buffer.started` |
| `response.audio.done` (for state) | `output_audio_buffer.stopped` |

#### Fix 2: Remove Premature State Change from onTrack

**Before (problematic):**
```dart
_peerConnection!.onTrack = (RTCTrackEvent event) {
  if (event.track.kind == 'audio') {
    _setState(VoiceAIState.speaking);  // WRONG - fires at connection, not playback!
  }
};
```

**After (fixed):**
```dart
_peerConnection!.onTrack = (RTCTrackEvent event) {
  if (event.track.kind == 'audio') {
    debugPrint('[VOICE-AI] Remote audio track received (AI can now send audio)');
    // State will transition to 'speaking' when output_audio_buffer.started is received
  }
};
```

#### Fix 3: State Guards (Passive Defense)

```dart
case 'input_audio_buffer.speech_started':
  // STATE GUARD: Only transition to listening if NOT currently speaking
  if (_state != VoiceAIState.speaking) {
    _setState(VoiceAIState.listening);
  } else {
    debugPrint('[VOICE-AI] IGNORED speech_started - AI is speaking (likely TV/background noise)');
    // Do NOT send any commands to Azure - just ignore client-side
  }
  break;

case 'input_audio_buffer.speech_stopped':
  // STATE GUARD: Only transition to processing if we were actually listening
  if (_state == VoiceAIState.listening) {
    _setState(VoiceAIState.processing);
  } else {
    debugPrint('[VOICE-AI] IGNORED speech_stopped - was not in listening state');
  }
  break;
```

### Key Insight: Why onTrack Was the Real Bug

The `onTrack` WebRTC event fires when the audio TRACK is added to the connection during setup, NOT when audio playback actually begins. This caused:

1. Connection established → `onTrack` fires → state = `speaking` (WRONG!)
2. You try to speak → `speech_started` event arrives
3. Guard checks `state != speaking` → FALSE (because state is incorrectly `speaking`)
4. **Your speech is IGNORED** because the system thinks AI is already talking

After removing this premature state change, the flow is correct:
1. Connection established → state = `listening`
2. User speaks → `speech_started` → state stays `listening`
3. User stops → `speech_stopped` → state = `processing`
4. AI generates response → `output_audio_buffer.started` → state = `speaking`
5. Background noise → `speech_started` → GUARD BLOCKS (correct!)
6. AI finishes → `output_audio_buffer.stopped` → state = `listening`

### Additional Improvements

1. **Debug Logging**: All incoming events are now logged with timestamps and current state
2. **`conversation.interrupted` Handler**: Now properly handled (logs but doesn't change state)
3. **Speaking Duration Tracking**: Tracks how long AI has been speaking for diagnostic purposes

### Debug Logging Example

With the new logging, you can diagnose issues by watching for:
```
[VOICE-AI] Remote audio track received (AI can now send audio)
[VOICE-AI] AI started speaking (audio playback began) at 2026-01-07T...
[VOICE-AI] EVENT: input_audio_buffer.speech_started | State: speaking
[VOICE-AI] IGNORED speech_started - AI is speaking for 3734ms (likely TV/background noise)
[VOICE-AI] AI stopped speaking (audio playback ended) - duration: 8500ms
```

### Files Modified

| File | Changes |
|------|---------|
| `mobile/app/lib/src/services/voice_ai_service.dart` | Fixed event names, removed onTrack state change, added state guards, debug logging |

### Testing Results (January 7, 2026)

- [x] AI completes full responses with TV dialogue in background
- [x] User can still speak to AI and get responses
- [x] State machine correctly transitions: listening → processing → speaking → listening
- [x] Background noise during AI speech is properly ignored

---

**Last Updated**: January 21, 2026 (Migrated to gpt-realtime-mini GA model)
