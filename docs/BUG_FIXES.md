# MyBartenderAI Bug Fixes Log

Chronological record of significant bug fixes applied to the project.

---

## BUG-008: Mobile API Providers Using Unauthenticated Dio (No JWT Token)

**Date Fixed**: February 11, 2026
**Severity**: High (Security / Functionality)
**Component**: Mobile App (API Layer)
**Files Modified**: `ask_bartender_api.dart`, `recommend_api.dart`, `create_studio_api.dart`, `vision_provider.dart`
**Backend Changes**: None (APIM policies were correct — the problem was client-side)

### Symptoms

1. **Chat broken**: AI Bartender chat returned "Sorry, I encountered an error" after APIM `validate-jwt` policies were deployed
2. **Subscription silently failed**: App defaulted to free tier because subscription-config returned 401
3. **All Batch 1+2 endpoints broken**: Every endpoint that received a new `validate-jwt` policy stopped working from the mobile app

### Root Cause

The mobile app had **two separate Dio instances** — one authenticated, one not — and 4 API providers were wired to the wrong one:

| Code Path | Dio Instance | Auth Token | Used By |
|-----------|-------------|------------|---------|
| `backendServiceProvider` → `BackendService` | Own Dio with `getIdToken` interceptor | ID token (correct) | `chatProvider`, subscription, recommendations |
| `dioProvider` from `bootstrap.dart` | Bare Dio, NO auth interceptor | **NONE** | `askBartenderApiProvider`, `recommendApiProvider`, `createStudioApiProvider`, `visionApiProvider` |

Before `validate-jwt` was deployed to APIM, tokenless requests passed through because APIM had no policy to reject them. The bug was latent — deploying APIM security correctly exposed it.

Voice worked because `voice_ai_service.dart` manages its own Dio instance with `getValidIdToken()`, completely independent of both code paths.

### Fix Applied (4 Files)

All 4 providers changed from using the bare `dioProvider` to using `backendServiceProvider.dio`, which has the JWT interceptor that calls `getValidIdToken()` on every request.

#### File 1: `ask_bartender_api.dart` (Chat)

```dart
// BEFORE — bare Dio, no auth:
final askBartenderApiProvider = Provider<AskBartenderApi>((ref) {
  final dio = ref.watch(dioProvider);  // from bootstrap.dart
  return AskBartenderApi(dio);
});

// AFTER — authenticated Dio:
final askBartenderApiProvider = Provider<AskBartenderApi>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  return AskBartenderApi(backendService.dio);
});
```

Import changed from `bootstrap.dart` to `backend_provider.dart`.

#### File 2: `recommend_api.dart` (Recommendations)

Same pattern — `dioProvider` → `backendServiceProvider.dio`.

#### File 3: `create_studio_api.dart` (Create Studio AI Refinement)

Same pattern — `dioProvider` → `backendServiceProvider.dio`.

#### File 4: `vision_provider.dart` (Smart Scanner)

This one was slightly different — it used `createBaseDio()` directly instead of `dioProvider`, but the effect was the same (no auth interceptor). Changed to `backendServiceProvider.dio`.

### Why `backendServiceProvider.dio` Works

`BackendService` (in `backend_service.dart`) creates its own Dio instance with an interceptor that:
1. Calls `getValidIdToken()` from `authServiceProvider` on every request
2. Adds `Authorization: Bearer <token>` header
3. Skips auth for public endpoints (`/v1/snapshots/latest`, `/health`)
4. Has a 10-second timeout to prevent hanging on token retrieval

The Dio instance is exposed via `Dio get dio => _dio;` (line 19), allowing other providers to share the authenticated instance.

### Verification

1. Chat works: Send message → AI responds (not error)
2. Recommendations work: Cocktail suggestions load
3. Create Studio AI refinement works
4. Smart Scanner works (after Batch 3 deployment)
5. No-token curl test returns 401: `curl -X POST https://apim-mba-002.azure-api.net/api/v1/ask-bartender-simple -H "Content-Type: application/json" -d '{"message":"test"}'`

### Design Lesson

This bug illustrates the "two instances" anti-pattern in dependency injection. Having two Dio providers (`dioProvider` for base config, `backendServiceProvider` for auth) created a trap where new API providers could be wired to the wrong one. The bare `dioProvider` should arguably be removed or marked as internal-only, since all APIM-routed endpoints now require JWT authentication.

---

## BUG-007: Server-Side Authoritative Voice Metering (Trust Boundary Violation)

**Date Fixed**: February 11, 2026
**Severity**: High (Security)
**Component**: Voice AI (Backend + Database + Mobile Client)
**CWE**: CWE-602 (Client-Side Enforcement of Server-Side Security)
**Files Modified**: `backend/functions/migrations/010_voice_metering_server_auth.sql` (NEW), `backend/functions/index.js`, `mobile/app/lib/src/services/voice_ai_service.dart`
**Backend Changes**: Yes (SQL migration + JS function updates + new timer function)

### Threat Model

The client-side voice minutes fix (BUG-006, commit `5eec6de`) solved the immediate usability bug, but the backend **trusted the client-reported `durationSeconds` without validation**. A modified client could:

| Attack | Before | After |
|--------|--------|-------|
| Report `durationSeconds: 0` every time | 0 billed, free minutes | Server bills 30% of wall-clock |
| Report inflated duration | Overcharged (self-harm) | Capped at wall-clock |
| Never call `/v1/voice/usage` | `active` forever, 0 billed | Timer expires after 2h, bills 30% |
| Multiple concurrent sessions | Unlimited | 409 Conflict; stale auto-expired |
| Session > 60 minutes | No cap | Capped at 3600s |

### Root Cause

The server already had `started_at = NOW()` set at session creation. When the session ends, `NOW() - started_at` gives server-controlled wall-clock time that no client can forge. But the old `record_voice_session()` SQL function blindly stored whatever `p_duration_seconds` the client sent.

### Fix Applied (3 Files, 5 Components)

#### Component 1: SQL Migration `010_voice_metering_server_auth.sql`

**1a. Status constraint** — Added `'expired'` to `voice_sessions.status` CHECK constraint for auto-closed stale sessions.

**1b. Server-authoritative `record_voice_session()`** — Same parameter signature (backward-compatible). Return type changed from `VOID` to `TABLE(billed_seconds, wall_clock_seconds, client_reported_seconds, billing_method)`.

Billing logic:
```
wall_clock = EXTRACT(EPOCH FROM (NOW() - started_at))   -- server-controlled
wall_clock = LEAST(wall_clock, 3600)                      -- 60-min hard cap
IF already completed/expired → return previous values     -- idempotency
IF client > 0  → billed = LEAST(client, wall_clock)       -- client discount, capped by server
IF client <= 0 AND wall_clock > 10 → billed = wall_clock * 0.3  -- conservative fallback
IF client <= 0 AND wall_clock <= 10 → billed = 0          -- short session, benefit of doubt
```

**1c. `expire_stale_voice_sessions()`** — Finds `active` sessions older than N hours, marks them `expired`, bills 30% of capped wall-clock. Called by hourly timer.

**1d. `close_user_stale_sessions()`** — Per-user version called during session creation. Auto-closes stale sessions before allowing a new one.

**1e. Updated `check_voice_quota()`** — Now counts both `'completed'` AND `'expired'` sessions so stale-session billing affects quota.

**1f. Updated `voice_usage_summary` view** — Also includes `'expired'` sessions.

#### Component 2: Concurrent Session Enforcement (`index.js`)

Before inserting a new `voice_sessions` row in the `voice-session` function:
1. Auto-expire stale sessions (>2h) via `close_user_stale_sessions()`
2. Check for remaining active sessions
3. If found: return **409 Conflict** with `concurrent_session` error

#### Component 3: Billing Result Capture (`index.js`)

The `voice-usage` endpoint now captures and returns the SQL function's billing breakdown. Removed the redundant session ownership check (the SQL function validates this internally). Response now includes:
```json
{
  "billing": {
    "billedSeconds": 120,
    "wallClockSeconds": 180,
    "clientReportedSeconds": 120,
    "method": "client_capped_by_wallclock"
  }
}
```

#### Component 4: Hourly Cleanup Timer (`index.js`)

New `voice-session-cleanup` timer runs every hour. Calls `expire_stale_voice_sessions(2)` to catch sessions where the client never called back. Logs each expired session with age and billed seconds.

#### Component 5: Flutter Client Updates (`voice_ai_service.dart`)

- **409 handler** in `startSession()` DioException handler — surfaces "active session" message
- **Billing logging** in `endSession()` — logs server billing details for debugging

### Verification Tests

| Test | Expected Result |
|------|----------------|
| Normal: client 120s, wall-clock 180s | billed 120, method `client_capped_by_wallclock` |
| Inflation: client 500s, wall-clock 120s | billed 120 (capped) |
| Zero: client 0, wall-clock 300s | billed 90 (30%) |
| Short: client 0, wall-clock 5s | billed 0, method `short_session_free` |
| Idempotency: call twice | second returns `already_recorded` |
| Concurrent: Start A, then B | 409 Conflict for B |
| Stale cleanup: 3h old active session | `expire_stale_voice_sessions(2)` → expired with billing |

### Deployment

1. Migration applied to `pg-mybartenderdb` (Feb 11, 2026)
2. `func-mba-fresh` redeployed with 35 functions (33 HTTP + 2 timer triggers)
3. Release APK built with 409 handling

---

## BUG-006: Voice Minutes Counter Not Decrementing (0 Usage Recorded)

**Date Fixed**: February 9, 2026
**Severity**: High
**Component**: Voice AI (Mobile Client)
**Files Modified**: `voice_ai_screen.dart`, `voice_ai_service.dart`, `voice_ai_provider.dart`
**Backend Changes**: None

### Symptoms

1. **Quota never decreases**: The voice minutes chip always showed "60 min" regardless of usage
2. **Database confirms zero usage**: `monthly_used_seconds = 0` in `voice_usage` table
3. **Stale sessions**: 8/10 sessions stuck at `active` status with NULL `duration_seconds`
4. **Zero-duration completions**: 2/10 sessions marked `completed` but with `duration_seconds = 0`

### Root Cause (Two Bugs)

**Bug 1 (PRIMARY): No cleanup when user navigates away**

`VoiceAIScreen` is a `ConsumerStatefulWidget` but had **no `dispose()` method** and **no `PopScope` navigation guard**. When the user pressed the back arrow (the most natural way to leave), Flutter unmounted the widget silently:
- `endSession()` was never called
- The `/v1/voice/usage` POST never fired
- The WebRTC connection died silently
- The database session stayed `active` forever with NULL duration

The only path to `endSession()` was the toggle button — but users naturally press back to leave.

**Bug 2 (SECONDARY): Duration reports 0 for edge-case sessions**

Even the 2 sessions where `endSession()` WAS called recorded 0 seconds. Cause: Azure VAD `speech_started` events have ~200-500ms latency. For very short interactions or certain push-to-talk timing patterns, the events may not fire before the session ends, leaving `_userSpeechStartTime` as null and `_userSpeakingSeconds` at 0.

### Fix Applied (4 Changes across 3 Files)

#### Change 1: `dispose()` method (`voice_ai_screen.dart`)

Ends active session when widget is unmounted — the last-resort safety net.

```dart
@override
void dispose() {
  final state = ref.read(voiceAINotifierProvider);
  if (state.isConnected) {
    ref.read(voiceAINotifierProvider.notifier).endSession();
  }
  super.dispose();
}
```

#### Change 2: `PopScope` navigation guard (`voice_ai_screen.dart`)

Intercepts back navigation during active sessions with a confirmation dialog. UX-friendly path that awaits `endSession()` before popping.

```dart
PopScope(
  canPop: !voiceState.isConnected,
  onPopInvokedWithResult: (didPop, result) async {
    if (didPop) return;
    final shouldLeave = await showDialog<bool>(...);
    if (shouldLeave == true && context.mounted) {
      await ref.read(voiceAINotifierProvider.notifier).endSession();
      if (context.mounted) Navigator.pop(context);
    }
  },
  child: Scaffold(...),
)
```

#### Change 3: Wall-clock duration fallback (`voice_ai_service.dart`)

After computing `_durationSeconds` from speech metering, if the result is 0 but the session lasted >10 seconds, falls back to 30% of wall-clock time.

```dart
if (_durationSeconds == 0 && connectedTime > 10) {
  _durationSeconds = (connectedTime * 0.3).round();
}
```

The 30% factor is conservative — in typical voice sessions, active speech accounts for 30-50% of wall time.

#### Change 4: Quota state nulling (`voice_ai_provider.dart`)

Replaced `state.copyWith()` with direct `VoiceAISessionState()` construction so the stale `quota` field becomes null. This forces the UI to fall through to the freshly-fetched `voiceQuotaProvider` value.

```dart
// copyWith uses ?? so it can't null out existing non-null fields
state = VoiceAISessionState(
  voiceState: VoiceAIState.idle,
  transcripts: state.transcripts,
);
```

### Verification Tests

| Test | Expected Result |
|------|----------------|
| Back-arrow exit during session | Confirmation dialog appears; on "Leave", session ends and usage is recorded |
| Stop-button exit | Session ends, quota chip refreshes (e.g., 60 → 59 min after ~1 min) |
| Short session (<10s) | Duration recorded as 0 (below fallback threshold, acceptable) |
| Medium session (>10s, no speech events) | Fallback: 30% of wall-clock time recorded |
| Normal session with speech | Active metering reports actual user + AI speech time |
| DB verification | `SELECT duration_seconds, status FROM voice_sessions ORDER BY started_at DESC LIMIT 3;` shows `completed` with non-zero duration |
| Quota verification | `SELECT * FROM check_voice_quota('<user_id>');` shows `monthly_used_seconds > 0` |

### Design Note: Defense in Depth

`PopScope` and `dispose()` serve complementary purposes:
- **PopScope**: UX-friendly confirmation dialog, awaits `endSession()` properly
- **dispose()**: Last-resort safety net that fires regardless of how the screen exits (system back, app lifecycle, etc.)

Together they cover every navigation path out of the Voice AI screen.

### Related Previous Fixes

- **BUG-005** (Jan 31, 2026): Phantom "Thinking..." from muted-mic VAD events
- **BUG-003** (Jan 7, 2026): Background noise state machine corruption
- Push-to-talk implementation (Jan 16, 2026): Added `create_response: false`

---

## BUG-005: Voice AI Phantom "Thinking..." and Muted-Mic State Leakage

**Date Fixed**: January 31, 2026
**Severity**: High
**Component**: Voice AI (Mobile Client)
**File Modified**: `mobile/app/lib/src/services/voice_ai_service.dart`
**Backend Changes**: None

### Symptoms

1. **Phantom "Thinking..."**: The blue hourglass/processing indicator appeared on its own without the user pressing the push-to-talk button, and stayed stuck indefinitely
2. **Unrelated AI responses**: Occasionally the AI responded with content unrelated to the current conversation (e.g., "Salty Dog" when discussing bourbon)

### Root Cause

The `speech_started` and `speech_stopped` VAD (Voice Activity Detection) event handlers did not check `_isMuted` when the state was NOT `speaking`. Even though the mic audio track was disabled via WebRTC, Azure's server-side Semantic VAD could still fire events from residual noise or buffered audio. Background noise triggered these events while the mic was muted, causing false state transitions:

```
AI finishes speaking → state = listening
Background noise (mic MUTED) → speech_started → sets _userSpeechStartTime (BUG: no _isMuted check)
Background noise stops → speech_stopped → transitions to PROCESSING (BUG: no _isMuted check)
With create_response: false → no response created → STUCK AT "Thinking..." indefinitely
```

The combination of `create_response: false` (set in the January push-to-talk implementation) and the missing mute guards created this deadlock: VAD events could push the state into `processing`, but only an explicit `response.create` (sent on button release) could resolve it.

### Fix Applied (4 Changes)

#### Change 1: Guard `speech_started` with `_isMuted` check
Added `_isMuted` as the **first** guard in the `speech_started` handler. When muted, ALL speech detections are background noise in push-to-talk mode.

```dart
case 'input_audio_buffer.speech_started':
  if (_isMuted) {
    debugPrint('[VOICE-AI] IGNORED speech_started - mic is MUTED (background noise)');
    _ignoringBackgroundNoise = true;
    break;
  }
  // ... rest of handler for unmuted state
```

#### Change 2: Guard `speech_stopped` with `_isMuted` check
Added `_isMuted` as the **first** guard in the `speech_stopped` handler. This is THE fix that prevents the phantom "Thinking..." — it blocks the `listening -> processing` transition from background noise.

```dart
case 'input_audio_buffer.speech_stopped':
  if (_isMuted) {
    debugPrint('[VOICE-AI] IGNORED speech_stopped - mic is MUTED (background noise ended)');
    _ignoringBackgroundNoise = false;
    break;
  }
  // ... rest of handler for unmuted state
```

#### Change 3: Finalize speech time tracking on button release
Added user speech time finalization in `setMicrophoneMuted()` when muting. Since `speech_stopped` events are now ignored while muted, but the event may arrive after the mic is already muted, we capture the user's real speech duration at mute time.

```dart
if (muted && _userSpeechStartTime != null) {
  final speechDuration = DateTime.now().difference(_userSpeechStartTime!).inSeconds;
  _userSpeakingSeconds += speechDuration;
  debugPrint('[VOICE-AI] User speech finalized on mute: +${speechDuration}s (total: ${_userSpeakingSeconds}s)');
  _userSpeechStartTime = null;
}
```

#### Change 4: Processing state safety timeout (defensive)
Added a 15-second `Timer` in `_setState()` that catches any future edge case where `processing` gets stuck (network issues, Azure hiccups, race conditions). On timeout, falls back to `listening` state. Timer is cancelled when leaving `processing` state and in `_cleanup()`.

### Verification Tests

| Test | Expected Result |
|------|----------------|
| No Phantom "Thinking..." | Let 60+ seconds pass without pressing button -- status stays "Hold to speak" |
| Noisy Environment | TV/music playing for 30+ seconds without pressing button -- no state changes |
| Normal Push-to-Talk | Hold -> ask question -> release -> AI responds correctly |
| Interruption | Hold button while AI is speaking -> AI stops, listens, responds to new question |
| Speech Metering | Debug logs show user speech seconds only during button presses, finalized with "User speech finalized on mute" messages |

### Related Previous Fixes

- **BUG-003** (Jan 7, 2026): Client-side state guard fix (wrong event names, premature onTrack state change)
- **BUG-002** (Dec 2025 - Jan 2026): Background noise sensitivity (server_vad -> semantic_vad + far_field)
- Push-to-talk implementation (Jan 16, 2026): Added `create_response: false` and explicit `response.create` on button release

---

## BUG-004: Suggestive Cocktail Name Content Filter Rejection

**Date Fixed**: January 30, 2026
**Severity**: Medium
**Component**: AI Bartender Chat (Backend)

Asking about cocktails with suggestive names (e.g., "Sex on the Beach") returned "Sorry, I encountered an error" instead of the recipe. Three-layer fix: custom Azure RAI policy, system prompt upgrades with cocktail name context, and content filter error handling returning helpful 200 responses.

See `DEPLOYMENT_STATUS.md` "Suggestive Cocktail Name Fix" entry for full details.

---

## BUG-003: Voice AI Background Noise State Machine Corruption

**Date Fixed**: January 7, 2026
**Severity**: High
**Component**: Voice AI (Mobile Client)

AI would stop mid-sentence when TV dialogue or background conversations were detected. Root causes: wrong WebRTC event names (`response.audio.started` doesn't exist), premature state change in `onTrack` handler, no state guards on `speech_started`/`speech_stopped`.

See `VOICE_AI_DEPLOYED.md` "Client-Side State Guard Fix" section for full details.

---

## BUG-002: Voice AI Background Noise Sensitivity

**Date Fixed**: December 2025 - January 2026 (iterative)
**Severity**: High
**Component**: Voice AI (Backend + Mobile Client)

TV/music/conversations triggered false speech detections. Migrated from `server_vad` to `semantic_vad` with `eagerness: low`, added `far_field` noise reduction, enhanced WebRTC audio constraints.

See `VOICE_AI_DEPLOYED.md` "Background Noise Sensitivity Fix" section for full details.

---

## BUG-001: Create Studio SQLite Type-Casting Crash

**Date Fixed**: January 30, 2026
**Severity**: Critical
**Component**: Mobile App (SQLite Database Layer)

Saving a second custom cocktail crashed with "type '_UnmodifiableUint8ArrayView' is not a subtype of type 'String' in type cast". Flutter's `sqflite` package returned TEXT columns as `Uint8List` instead of `String`. Fixed with safe conversion helpers across 39 unsafe casts in 4 files.

See `DEPLOYMENT_STATUS.md` "Create Studio SQLite Type-Casting Bug Fix" entry for full details.

---

**Last Updated**: February 11, 2026
