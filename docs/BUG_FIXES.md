# MyBartenderAI Bug Fixes Log

Chronological record of significant bug fixes applied to the project.

---

## BUG-012: WebRTC Connection Failed — Dart Type Error on iOS (`RTCRtpSender` vs `RTCRtpSenderNative`)

**Date Fixed**: February 15, 2026
**Severity**: Critical (Feature-breaking on iOS)
**Component**: Voice AI (Mobile Client)
**Files Modified**: `mobile/app/lib/src/services/voice_ai_service.dart`
**Backend Changes**: None

### Symptoms

After deploying the BUG-011 fix (iOS background audio capture), Voice AI fails to connect on iOS with:

```
WebRTC connection failed: type '() => RTCRtpSender' is not a subtype of type '(() => RTCRtpSenderNative)?' of 'orElse'
```

The error occurs before any WebRTC handshake completes — the session never establishes.

### Root Cause

The `_audioSender` capture code introduced in BUG-011 (Change 3) used `firstWhere` with an `orElse` callback:

```dart
final senders = await _peerConnection!.getSenders();
_audioSender = senders.firstWhere(
    (s) => s.track?.kind == 'audio',
    orElse: () => senders.first,  // <-- TYPE ERROR HERE
);
```

On iOS, `flutter_webrtc`'s `getSenders()` returns `List<RTCRtpSenderNative>` (a concrete platform subclass), not `List<RTCRtpSender>` (the abstract supertype). Dart's `firstWhere` method on this list expects `orElse` to return `RTCRtpSenderNative`, but Dart infers the closure return type as `() => RTCRtpSender`. This runtime type mismatch crashes immediately.

Android is unaffected because its `getSenders()` returns the abstract `List<RTCRtpSender>` type.

### Fix Applied (1 Change in 1 File)

Removed the `orElse` callback entirely:

**Before:**
```dart
_audioSender = senders.firstWhere(
    (s) => s.track?.kind == 'audio',
    orElse: () => senders.first,
);
```

**After:**
```dart
_audioSender = senders.firstWhere(
    (s) => s.track?.kind == 'audio',
);
```

**Why it's safe:** `addTrack(audioTrack, _localStream!)` is called on the line immediately before this code. The audio sender is guaranteed to exist in the senders list. The `orElse` was unnecessary defensive code.

If the sender were somehow missing (shouldn't happen), `firstWhere` throws a `StateError` which is caught by the existing try/catch block at line 625 — producing a clear diagnostic message instead of the confusing type error.

### Verification Tests

| Test | Expected Result |
|------|----------------|
| iOS: Voice AI → Talk | Session connects without "WebRTC connection failed" error |
| iOS: Push-to-talk works | Hold button to speak, release to hear AI respond |
| iOS: Muting works | No background audio leaks when mic is muted (BUG-011 fix still functions) |
| Android: Same tests | Behavior unchanged (was never affected by this bug) |

### Design Lesson

When using `firstWhere` on platform-specific list types in Flutter plugins, avoid `orElse` callbacks — Dart's type inference uses the abstract supertype for the closure return type, which may not match the list's runtime element type on specific platforms (iOS native vs Android). Either omit `orElse` (if the element is guaranteed to exist) or use a try/catch on `StateError` instead.

### Related Fixes

- **BUG-011** (Feb 15, 2026): iOS background audio capture — introduced the `_audioSender` capture code with the type-incompatible `orElse`

---

## BUG-011: Voice AI Captures Background Audio When Muted (iOS Only)

**Date Fixed**: February 15, 2026
**Severity**: Medium (UX confusion, wasted Azure compute)
**Component**: Voice AI (Mobile Client)
**Files Modified**: `mobile/app/lib/src/services/voice_ai_service.dart`
**Backend Changes**: None

### Symptoms

1. **Background speech bubbles**: On iOS (TestFlight), user transcript bubbles appear for ambient audio (TV dialogue, nearby conversations) even when the push-to-talk button is **not** held down
2. **Mic shows muted state**: The mic icon correctly shows muted with "Hold to speak," yet transcripts appear
3. **Android unaffected**: The same build works correctly on Android — no background transcripts when muted

### Root Cause (Two Layers)

**Layer 1 — iOS platform behavior**: `track.enabled = false` on a WebRTC audio track does not fully silence the audio stream on iOS. With `AVAudioSession` configured as `playAndRecord` + `voiceChat`, the microphone hardware stays active and audio data continues flowing through the WebRTC connection to Azure OpenAI. Android's audio HAL properly silences the track when `track.enabled = false`.

**Layer 2 — Missing mute guard on transcript handler**: The `conversation.item.input_audio_transcription.completed` event handler had **no `_isMuted` check**. It added every user transcript to the UI regardless of mute state. The existing `_isMuted` guards on `speech_started`/`speech_stopped` only prevented state transitions — they didn't stop Azure from receiving and transcribing the leaked audio.

### Fix Applied (5 Changes in 1 File)

#### Change 1: Guard transcript handler with `_isMuted` check (CRITICAL)

```dart
case 'conversation.item.input_audio_transcription.completed':
  if (_isMuted) {
    debugPrint('[VOICE-AI] IGNORED user transcript - mic is MUTED (background audio on iOS)');
    break;
  }
  // ... existing transcript processing unchanged ...
```

This is the immediate fix — even if audio leaks through the WebRTC connection, the transcript is silently discarded before reaching the UI.

#### Change 2: Add `_audioSender` field

```dart
RTCRtpSender? _audioSender; // Stored for iOS replaceTrack muting
```

#### Change 3: Store audio sender after `addTrack()`

```dart
final senders = await _peerConnection!.getSenders();
_audioSender = senders.firstWhere(
  (s) => s.track?.kind == 'audio',
);
```

> **Note:** The original code included `orElse: () => senders.first` but this caused a Dart type inference crash on iOS — see BUG-012. The `orElse` was removed since the audio sender is guaranteed to exist after `addTrack()`.

#### Change 4: iOS-specific `replaceTrack(null)` in `setMicrophoneMuted()`

```dart
// iOS-specific: track.enabled = false doesn't fully silence audio on iOS.
// Use replaceTrack(null) to ensure zero audio data reaches Azure.
if (Platform.isIOS && _audioSender != null) {
  if (muted) {
    _audioSender!.replaceTrack(null).then((_) {
      debugPrint('[VOICE-AI] iOS: Audio sender track replaced with null (silence)');
    }).catchError((e) {
      debugPrint('[VOICE-AI] iOS: replaceTrack(null) failed: $e');
    });
  } else {
    // Restore audio track when unmuting
    _audioSender!.replaceTrack(audioTrack).then((_) { ... });
  }
}
```

**Why fire-and-forget (no await)?** `setMicrophoneMuted` is called synchronously from the button handler. The critical flag `_isMuted = true` is already set before this code runs, so the transcript guard (Change 1) is active immediately. The `replaceTrack` call completes ~5ms later.

#### Change 5: Reset `_audioSender` in `_cleanup()`

```dart
_audioSender = null;
```

### Defense-in-Depth Strategy

| Layer | What It Does | Protects Against |
|-------|-------------|-----------------|
| `_isMuted` guard on transcript handler | Drops background transcripts at event level | Audio leaking through on iOS (or any future platform bug) |
| `replaceTrack(null)` on iOS | Swaps audio track to silence at WebRTC level | Azure processing leaked audio (saves tokens, prevents AI confusion) |
| `track.enabled = false` (existing) | Standard WebRTC mute | Works correctly on Android; belt-and-suspenders on iOS |

### Verification Tests

| Test | Expected Result |
|------|----------------|
| iOS: Don't hold button, have TV playing | No user transcript bubbles; logs show `IGNORED user transcript - mic is MUTED` |
| iOS: Hold button, speak, release | Speech transcribed, AI responds; logs show `Audio sender track restored` |
| iOS: Check logs on mute | `iOS: Audio sender track replaced with null (silence)` appears |
| Android: Same tests | Behavior unchanged (no background capture, push-to-talk works) |
| Static analysis | Zero new warnings in `voice_ai_service.dart` |

### Related Previous Fixes

- **BUG-010** (Feb 15, 2026): Push-to-talk interruption transcript fix
- **BUG-005** (Jan 31, 2026): Phantom "Thinking..." from muted-mic VAD events
- **BUG-003** (Jan 7, 2026): Background noise state machine corruption

---

## BUG-010: Voice AI "Repeating Itself" During Push-to-Talk Interruption

**Date Fixed**: February 15, 2026
**Severity**: Medium (UX confusion)
**Component**: Voice AI (Mobile Client)
**Files Modified**: `mobile/app/lib/src/services/voice_ai_service.dart`, `mobile/app/lib/src/providers/voice_ai_provider.dart`
**Backend Changes**: None

### Symptoms

1. **Duplicate messages**: User interrupts AI mid-sentence via push-to-talk, then the AI's next response begins with the same words — appearing to "repeat itself"
2. **Truncated messages**: Partial AI responses persist in the transcript even after cancellation
3. **Potential duplicate `response.create`**: Rapid push-to-talk cycles could produce overlapping response requests

### Root Cause

When the user presses the push-to-talk button while the AI is speaking, `_prepareForNewUtterance()` sends `response.cancel` to Azure but does **not** clean up the partial transcript that was already streaming. Azure's Realtime API fires events asynchronously — `response.audio_transcript.done` still arrives for the cancelled response, permanently adding truncated text to the conversation. The new response then naturally starts with similar context, creating the "repeating" illusion.

**The broken flow:**
```
AI speaking: "Alright, let's break it down. First you need..."
  → response.audio_transcript.delta streaming into StringBuffer

User presses push-to-talk button:
  → _prepareForNewUtterance() sends response.cancel
  → BUT StringBuffer still contains "Alright, let's break it down. First you need..."
  → AND response.audio_transcript.done fires for cancelled response
  → Truncated text permanently added to _transcripts list

User releases button, AI generates new response:
  → AI naturally starts: "Alright, let's break it down..."
  → User sees what looks like a duplicate message
```

**Secondary risk**: `_commitAudioBuffer()` had no guard against being called while a response was already in progress, which could produce duplicate `response.create` events in rapid push-to-talk edge cases.

### Fix Applied (9 Changes across 2 Files + Build Bump)

#### Changes 1-2: State-tracking flags + cancellation cleanup (`voice_ai_service.dart`)

Added `_responseInProgress` and `_responseCancelled` boolean flags after `_currentAssistantResponse`. In `_prepareForNewUtterance()`, after sending `response.cancel`:

```dart
// Mark the current response as cancelled so its transcript.done is discarded
_responseCancelled = true;

// Clear the partial transcript buffer — this text is now stale
_currentAssistantResponse = StringBuffer();

// Remove the partial assistant message from the UI
_onTranscript?.call('assistant', '', true);
```

#### Change 3: Guard on `_commitAudioBuffer()` (`voice_ai_service.dart`)

```dart
if (_responseInProgress) {
  debugPrint('[VOICE-AI] Skipping commit — response already in progress');
  return;
}
// Before response.create:
_responseInProgress = true;
_responseCancelled = false;
```

#### Changes 4-5: Cancelled transcript filtering (`voice_ai_service.dart`)

```dart
case 'response.audio_transcript.delta':
  if (_responseCancelled) break; // Ignore deltas from cancelled response
  // ... existing code ...

case 'response.audio_transcript.done':
  if (_responseCancelled) {
    debugPrint('[VOICE-AI] Discarding transcript.done for cancelled response');
    _currentAssistantResponse = StringBuffer();
    break;
  }
  // ... existing code ...
```

#### Changes 6-7: Event handler cleanup (`voice_ai_service.dart`)

- `response.done` / `response.audio.done`: Sets `_responseInProgress = false`
- `response.cancelled`: Sets `_responseInProgress = false`, `_responseCancelled = true` (defensive), clears StringBuffer

#### Change 8: `_cleanup()` resets (`voice_ai_service.dart`)

Both flags and StringBuffer cleared during session teardown.

#### Change 9: Provider cancellation signal (`voice_ai_provider.dart`)

```dart
if (role == 'assistant') {
  // Empty final text = cancellation signal: remove the partial assistant message
  if (text.isEmpty && isFinal) {
    if (transcripts.isNotEmpty &&
        transcripts.last.role == 'assistant' &&
        !transcripts.last.isFinal) {
      transcripts.removeAt(lastIndex);
    }
    state = state.copyWith(transcripts: transcripts);
    return;
  }
  // ... existing partial/final logic unchanged ...
```

### Verification Tests

| Test | Expected Result |
|------|----------------|
| Interrupt AI mid-sentence | No truncated/duplicate messages in transcript |
| Normal conversation (no interruption) | Conversation flows naturally, no missing messages |
| Rapid push-to-talk cycles | No duplicate response.create, clean transcript |
| Debug logs during interruption | `[VOICE-AI] Discarding transcript.done for cancelled response` appears |
| Session cleanup | Both flags reset, no stale state carries to next session |

### Design Notes

**Empty-text signal pattern**: Rather than adding a new callback or making the provider aware of cancellation semantics, we reuse the existing `_onTranscript` channel with a sentinel value (empty text + `isFinal=true`). The provider recognizes this as "drop the in-progress bubble" — maintaining clean separation between the service and UI layers.

**Defensive redundancy**: The `response.cancelled` handler sets `_responseCancelled = true` even though `_prepareForNewUtterance()` already set it. This handles the rare case where Azure processes the cancellation before the client-side flag is set.

### Related Previous Fixes

- **BUG-005** (Jan 31, 2026): Phantom "Thinking..." from muted-mic VAD events
- **BUG-003** (Jan 7, 2026): Background noise state machine corruption
- Push-to-talk implementation (Jan 16, 2026): Added `create_response: false` and explicit `response.create`

---

## BUG-009: Voice Session Auto-Close "Last Session Wins" — PostgreSQL Parameter Type Error

**Date Fixed**: February 13, 2026
**Severity**: High (Feature-breaking)
**Component**: Voice AI (Backend)
**Files Modified**: `backend/functions/index.js`
**Backend Changes**: Yes (single-line fix in voice-session function)

### Context

After deploying the "last session wins" fix (replacing the 409 Conflict block with auto-close logic in the `voice-session` function), tapping "Talk" on the Voice AI screen returned:

> "could not determine data type of parameter $3"

### Root Cause

The `usage_tracking` INSERT added as part of the auto-close logic passes `$3` and `$4` inside `jsonb_build_object()`. PostgreSQL's `jsonb_build_object()` has the signature `VARIADIC "any"` — unlike an `INSERT ... VALUES ($1, $2)` where column types provide inference context, PostgreSQL has no way to determine the types of parameterized placeholders inside a variadic function.

```javascript
// BROKEN — PostgreSQL can't infer types of $3 and $4 inside jsonb_build_object()
jsonb_build_object('session_id', $3, 'wall_clock_seconds', $4, 'billing_method', 'last_session_wins')
```

The existing SQL migrations (006, 010) don't have this problem because they use typed PL/pgSQL variables, not parameterized placeholders from `node-postgres`.

### Fix Applied

Added explicit type casts to resolve the ambiguity:

```javascript
// FIXED — explicit casts tell PostgreSQL what types to expect
jsonb_build_object('session_id', $3::text, 'wall_clock_seconds', $4::integer, 'billing_method', 'last_session_wins')
```

- `$3::text` — session IDs become JSON strings in JSONB regardless; `::text` is idiomatic
- `$4::integer` — `wallClock` is an integer (seconds); explicit cast resolves the ambiguity

### Verification

1. Deployed to `func-mba-fresh` (Feb 13, 2026)
2. Device test: Voice AI → Talk → session starts cleanly
3. If a stale session existed, `Auto-closing orphaned session:` appears in Azure logs
4. DB verification: `SELECT * FROM usage_tracking WHERE metadata->>'billing_method' = 'last_session_wins' ORDER BY created_at DESC LIMIT 5;`

### Design Lesson

When using `node-postgres` parameterized queries with PostgreSQL functions that accept `VARIADIC "any"` (like `jsonb_build_object`, `json_build_object`, `COALESCE` in some contexts), always add explicit type casts (`::text`, `::integer`, etc.) to the placeholders. This is only needed when parameters appear inside such functions — column-context queries (`INSERT INTO ... VALUES ($1, $2)`) infer types automatically.

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

> **Update (Feb 13, 2026):** The 409 Conflict concurrent session enforcement described below was replaced with "last session wins" auto-close logic. See BUG-009 for details. The server-authoritative billing, stale session expiry, and hourly cleanup timer remain unchanged.

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
| Concurrent: Start A, then B | A auto-closed and billed, B starts (last-session-wins) |
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

**Last Updated**: February 16, 2026
