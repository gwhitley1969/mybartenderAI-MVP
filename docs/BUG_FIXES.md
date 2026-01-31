# MyBartenderAI Bug Fixes Log

Chronological record of significant bug fixes applied to the project.

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

**Last Updated**: January 31, 2026
