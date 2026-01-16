# Voice AI Feature Implementation Spec

> **For Claude Code** - This is the implementation guide for the "Talk" feature in My AI Bartender.

**Status**: ✅ IMPLEMENTED (December 9, 2025, updated January 16, 2026 - iOS speaker routing fix)

## Overview

Real-time voice conversations with an AI bartender using Azure OpenAI's GPT-4o-mini Realtime API via WebRTC. Pro tier only.

## UI Location

In the "AI Cocktail Concierge" section on the home screen, reorganize into 2x2 grid:
- Row 1: Chat | Scanner
- Row 2: Create | **Talk** (new - microphone icon, "Speak to your AI Bartender")

---

## Phase 1: Database Schema

Create migration file: `migrations/YYYYMMDD_voice_ai_tables.sql`

```sql
-- Voice usage tracking (monthly quotas)
CREATE TABLE voice_usage (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    period_start DATE NOT NULL,
    monthly_seconds_used INTEGER DEFAULT 0,
    addon_seconds_remaining INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, period_start)
);

CREATE INDEX idx_voice_usage_user_period ON voice_usage(user_id, period_start);

-- Voice sessions
CREATE TABLE voice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    input_tokens INTEGER,
    output_tokens INTEGER,
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'completed', 'error'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_voice_sessions_user ON voice_sessions(user_id, started_at DESC);

-- Conversation history (transcripts)
CREATE TABLE voice_messages (
    id SERIAL PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES voice_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL, -- 'user' or 'assistant'
    transcript TEXT NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_voice_messages_session ON voice_messages(session_id, timestamp);

-- Add-on purchases (non-expiring minutes)
CREATE TABLE voice_addon_purchases (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id),
    seconds_purchased INTEGER NOT NULL, -- 1200 = 20 minutes
    price_cents INTEGER NOT NULL, -- 499 = $4.99
    transaction_id VARCHAR(255),
    platform VARCHAR(20), -- 'ios', 'android'
    purchased_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Phase 2: Azure Functions

### 2.1 POST /api/v1/voice/session

Location: `apps/backend/v4-deploy/voice-session/index.js`

Purpose: Validate Pro tier, check quota, return ephemeral token for WebRTC connection.

```javascript
const { app } = require('@azure/functions');
const { DefaultAzureCredential } = require('@azure/identity');

app.http('voice-session', {
    methods: ['POST'],
    authLevel: 'anonymous',
    route: 'v1/voice/session',
    handler: async (request, context) => {
        // 1. Validate JWT from Authorization header
        // 2. Check user is Pro tier
        // 3. Check voice quota (monthly_seconds_used < 1800 OR addon_seconds_remaining > 0)
        // 4. Get user's inventory from request body
        // 5. Request ephemeral token from Azure OpenAI
        // 6. Create voice_sessions record
        // 7. Return token + session info

        const SESSIONS_URL = `https://${process.env.AZURE_OPENAI_RESOURCE}.openai.azure.com/openai/realtimeapi/sessions?api-version=2025-04-01-preview`;

        // Ephemeral token request body
        const sessionConfig = {
            model: process.env.AZURE_OPENAI_REALTIME_DEPLOYMENT, // 'gpt-4o-mini-realtime-preview'
            voice: 'alloy',
            instructions: getSystemPrompt(inventory), // See section 4
            input_audio_transcription: {
                model: 'whisper-1'
            },
            // UPDATED: Using semantic_vad for better background noise handling
            turn_detection: {
                type: 'semantic_vad',           // Changed from 'server_vad' - uses AI to understand speech intent
                eagerness: 'medium',            // Balance between responsiveness and not cutting off user
                create_response: true,
                interrupt_response: true        // Enable interruptions
            },
            // Noise reduction settings to filter background sounds
            input_audio_noise_reduction: {
                type: 'near_field'              // Optimized for close microphone (mobile devices)
            }
        };

        // Response shape
        return {
            status: 200,
            jsonBody: {
                ephemeralToken: tokenResponse.client_secret.value,
                endpoint: 'https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc',
                sessionId: newSession.id,
                remainingMinutes: calculateRemainingMinutes(usage),
                expiresAt: tokenResponse.client_secret.expires_at
            }
        };
    }
});
```

### 2.2 POST /api/v1/voice/usage

Location: `apps/backend/v4-deploy/voice-usage/index.js`

Purpose: Record session completion, update quotas, save transcripts.

```javascript
app.http('voice-usage', {
    methods: ['POST'],
    authLevel: 'anonymous',
    route: 'v1/voice/usage',
    handler: async (request, context) => {
        const body = await request.json();
        // {
        //   sessionId: 'uuid',
        //   durationSeconds: 185,
        //   inputTokens: 2450,
        //   outputTokens: 3200,
        //   transcripts: [
        //     { role: 'user', text: '...', timestamp: '...' },
        //     { role: 'assistant', text: '...', timestamp: '...' }
        //   ]
        // }

        // 1. Update voice_sessions with duration/tokens
        // 2. Update voice_usage: deduct from addon first, then monthly
        // 3. Insert voice_messages for each transcript
        // 4. Return updated quota info
    }
});
```

### 2.3 GET /api/v1/voice/quota

Location: `apps/backend/v4-deploy/voice-quota/index.js`

Purpose: Check remaining voice minutes (for UI display).

```javascript
app.http('voice-quota', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'v1/voice/quota',
    handler: async (request, context) => {
        // Return shape
        return {
            status: 200,
            jsonBody: {
                remainingMinutes: 24.5,
                monthlyAllocation: 30,
                addOnMinutes: 0,
                usedThisMonth: 5.5,
                resetDate: '2025-01-01T00:00:00Z'
            }
        };
    }
});
```

---

## Phase 3: Flutter Implementation

### 3.1 Add Dependencies

In `mobile/app/pubspec.yaml`:

```yaml
dependencies:
  flutter_webrtc: ^0.11.0
  permission_handler: ^11.0.0
```

### 3.2 Platform Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>My AI Bartender needs microphone access to have voice conversations with your AI bartender.</string>
```

### 3.3 New Files to Create

```
mobile/app/lib/src/
├── api/
│   └── voice_api_client.dart          # HTTP calls to voice endpoints
├── services/
│   └── voice_realtime_service.dart    # WebRTC connection management
├── providers/
│   └── voice_ai_provider.dart         # Riverpod state management
└── features/
    └── voice_ai/
        ├── voice_ai_screen.dart       # Main conversation screen
        └── widgets/
            ├── voice_button.dart      # Animated mic button
            ├── waveform_widget.dart   # Audio visualization
            └── transcript_view.dart   # Scrollable conversation
```

### 3.4 State Machine

```dart
// lib/src/providers/voice_ai_provider.dart

enum VoiceAIState {
  idle,           // Initial - show "Talk" button
  connecting,     // Fetching token, establishing WebRTC
  listening,      // User speaking (mic active)
  processing,     // VAD detected silence, AI processing
  speaking,       // AI audio playing
  error,          // Connection/API error
  quotaExhausted, // Minutes depleted
}

@riverpod
class VoiceAI extends _$VoiceAI {
  VoiceAIState _state = VoiceAIState.idle;
  String? _sessionId;
  double _remainingMinutes = 0;
  List<VoiceMessage> _messages = [];
  
  // State transitions triggered by WebRTC events
}
```

### 3.5 WebRTC Service Skeleton

```dart
// lib/src/services/voice_realtime_service.dart

import 'package:flutter_webrtc/flutter_webrtc.dart';

class VoiceRealtimeService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  
  Future<void> connect({
    required String ephemeralToken,
    required String endpoint,
    required Function(String) onTranscript,
    required Function(VoiceAIState) onStateChange,
  }) async {
    // 1. Get local audio stream
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    
    // 2. Create peer connection
    _peerConnection = await createPeerConnection({
      'iceServers': [], // Azure handles ICE
    });
    
    // 3. Add local audio track
    _localStream!.getAudioTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });
    
    // 4. Create data channel for events
    _dataChannel = await _peerConnection!.createDataChannel(
      'oai-events',
      RTCDataChannelInit(),
    );
    
    // 5. Handle incoming events
    _dataChannel!.onMessage = (RTCDataChannelMessage message) {
      final event = jsonDecode(message.text);
      _handleRealtimeEvent(event, onTranscript, onStateChange);
    };
    
    // 6. Create offer and connect to Azure
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    
    // 7. Send offer to Azure WebRTC endpoint
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $ephemeralToken',
        'Content-Type': 'application/sdp',
      },
      body: offer.sdp,
    );
    
    // 8. Set remote description from Azure's answer
    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(response.body, 'answer'),
    );
  }
  
  void _handleRealtimeEvent(Map event, Function onTranscript, Function onStateChange) {
    switch (event['type']) {
      case 'conversation.item.input_audio_transcription.completed':
        onTranscript(event['transcript']); // User's speech
        break;
      case 'response.audio_transcript.done':
        onTranscript(event['transcript']); // AI's response
        break;
      case 'input_audio_buffer.speech_started':
        onStateChange(VoiceAIState.listening);
        break;
      case 'input_audio_buffer.speech_stopped':
        onStateChange(VoiceAIState.processing);
        break;
      case 'response.audio.delta':
        onStateChange(VoiceAIState.speaking);
        break;
      case 'response.done':
        onStateChange(VoiceAIState.idle);
        break;
    }
  }
  
  Future<void> disconnect() async {
    await _localStream?.dispose();
    await _dataChannel?.close();
    await _peerConnection?.close();
  }
}
```

---

## Phase 4: System Prompt

```javascript
// Used in voice-session/index.js

function getSystemPrompt(inventory) {
  const inventoryContext = inventory ? `
USER'S BAR INVENTORY:
Spirits: ${inventory.spirits?.join(', ') || 'None specified'}
Mixers: ${inventory.mixers?.join(', ') || 'None specified'}
Bitters: ${inventory.bitters?.join(', ') || 'None specified'}
Garnishes: ${inventory.garnishes?.join(', ') || 'None specified'}

Prioritize suggesting drinks the user can make with these ingredients.
` : '';

  return `You are an expert bartender and mixologist with decades of experience. Your name is "My AI Bartender" and you work exclusively within the My AI Bartender mobile app.

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

${inventoryContext}

VOICE INTERACTION STYLE:
- Speak naturally and conversationally, as if talking across a bar
- Keep responses concise for voice (aim for under 30 seconds of speech)
- Use clear step-by-step instructions for recipes
- Offer follow-up suggestions ("Would you like to know about a variation?")

STRICT BOUNDARIES:
If asked about topics outside bartending/mixology (politics, news, technology, health advice, etc.), respond warmly but redirect:
"I'm your bartender - my expertise is cocktails and drinks! I'd be happy to help with anything drink-related. Is there a cocktail I can help you make?"

Never provide:
- Medical or health advice beyond general responsible drinking
- Political opinions or commentary
- Information unrelated to beverages and bar culture`;
}
```

---

## Key Configuration Values

Add to Key Vault / environment:

```
AZURE_OPENAI_REALTIME_RESOURCE=<your-aoai-resource-name>
AZURE_OPENAI_REALTIME_DEPLOYMENT=gpt-4o-mini-realtime-preview
AZURE_OPENAI_REALTIME_REGION=eastus2
```

Pro tier quota constants:
```javascript
const MONTHLY_VOICE_SECONDS = 1800;  // 30 minutes
const ADDON_VOICE_SECONDS = 1200;    // 20 minutes
const WARNING_THRESHOLD = 0.80;      // Warn at 80% used (6 min remaining)
```

---

## Testing Checklist

- [x] Non-Pro user sees upgrade prompt when tapping "Talk"
- [x] Pro user can start voice session
- [x] Microphone permission flow works (Android tested, iOS tested January 2026)
- [x] Real-time transcription displays correctly
- [x] AI responds audibly
- [x] ~~User can interrupt AI mid-response~~ (Replaced by push-to-talk)
- [x] Push-to-talk: Hold button to speak, release for AI response ✅ January 16, 2026
- [x] Push-to-talk: Quick tap ends session ✅ January 16, 2026
- [x] Push-to-talk: Background noise ignored when not holding ✅ January 16, 2026
- [x] "How to use" instructions updated for push-to-talk ✅ January 16, 2026
- [x] Bar inventory context passed to AI (via session.update) ✅ December 27, 2025
- [ ] "Minutes remaining" updates after each session
- [ ] 80% warning toast appears at 6 minutes remaining
- [ ] Quota exhaustion shows purchase option (after AI finishes response)
- [ ] Conversation history saved to database
- [ ] Session survives brief network interruption
- [x] Out-of-scope questions get polite redirect

---

## Implementation Notes (December 9, 2025, updated January 16, 2026)

### User Interface
- Voice AI screen accessible from home screen via "Voice" button in AI Cocktail Concierge section
- Status indicator shows current state: "Tap to start", "Hold to speak", "Listening...", "Thinking...", "AI Speaking..."
- **Push-to-talk mode**: Hold button to speak, release to hear AI respond
- Transcripts displayed in chat bubble format (user on right, AI on left)

### Session Control (Push-to-Talk - January 2026)
- Tap microphone button to **start** voice session
- **Hold** button to speak (microphone active only while holding)
- **Release** button to trigger AI response (immediate, no VAD delay)
- **Quick tap** (<250ms) to end session
- Session automatically records usage when ended

### Known Limitations
- Quota tracking not fully verified
- Add-on purchase flow not implemented

### iOS Testing (January 2026)
- ✅ Microphone permission works (requires Podfile GCC_PREPROCESSOR_DEFINITIONS)
- ✅ Voice AI audio plays through speaker (not earpiece)
- ✅ Real-time transcription displays correctly
- ✅ AI responds audibly at normal volume

See `docs/VOICE_AI_DEPLOYED.md` for complete deployment documentation.

---

## Bar Inventory Integration (December 27, 2025)

### Implementation Change

The original plan called for passing inventory context to the backend `voice-session` function, which would include it in the system instructions during session creation. However, this approach did not work for WebRTC sessions - the `instructions` field was not being applied.

### New Approach: session.update via WebRTC Data Channel

Instead of backend instruction injection, the mobile app now:
1. Loads user's bar inventory when starting a voice session
2. Builds inventory instructions locally
3. Sends a `session.update` event via the WebRTC data channel after connection
4. Azure OpenAI applies the instructions to the active session

**Key Code** (`voice_ai_service.dart`):
```dart
// When data channel opens, send inventory instructions
_dataChannel!.onDataChannelState = (RTCDataChannelState state) {
  if (state == RTCDataChannelState.RTCDataChannelOpen) {
    _sendSessionUpdate(); // Sends session.update with inventory
  }
};
```

This approach is more reliable because:
- Bypasses backend body parsing issues
- Instructions go directly to the active AI session
- Confirmed working by `session.updated` response from Azure

See `docs/VOICE_AI_DEPLOYED.md` for full implementation details.

---

## Background Noise Sensitivity Fix (December 2025 - January 2026)

### Problem

Users reported the Voice AI was too sensitive to background noise:
- TV/music in the background would trigger false "speech detected" events
- Other people talking nearby would interrupt the AI's responses
- Environmental sounds (air conditioning, traffic) caused erratic behavior
- **January 2026**: Even with `semantic_vad`, AI would stop mid-sentence when TV dialogue was detected

### Root Cause (Multi-Part)

1. **Original Issue**: `server_vad` uses simple audio energy thresholds - cannot distinguish intentional speech from background noise

2. **Deeper Issue (January 2026)**: Even with `semantic_vad` + `interrupt_response: false`, client-side state machine bugs caused failures:
   - **Wrong event names**: Code used `response.audio.started` (doesn't exist), should be `output_audio_buffer.started`
   - **Premature state change**: WebRTC `onTrack` handler set state to `speaking` at connection time, not when AI actually spoke
   - **No state guards**: `speech_started` events always transitioned to `listening`, even during AI playback

### Solution: Server + Client-Side Fixes

#### Part 1: Server Configuration (December 2025)

```javascript
turn_detection: {
    type: 'semantic_vad',           // AI-powered speech understanding
    eagerness: 'low',               // More tolerant of background noise
    create_response: true,
    interrupt_response: false       // Prevent interruption from background noise
},
input_audio_noise_reduction: {
    type: 'far_field'               // Aggressive filtering for noisy environments
}
```

#### Part 2: Client-Side State Guards (January 2026)

Fixed WebRTC event handling in `voice_ai_service.dart`:

1. **Correct event names**:
   - `output_audio_buffer.started` → state = speaking
   - `output_audio_buffer.stopped` → state = listening

2. **Removed premature state change from `onTrack`**:
   ```dart
   // Before: _setState(VoiceAIState.speaking); // WRONG!
   // After: Just log - state changes on output_audio_buffer.started
   ```

3. **Added state guards**:
   ```dart
   case 'input_audio_buffer.speech_started':
     if (_state != VoiceAIState.speaking) {
       _setState(VoiceAIState.listening);
     } else {
       debugPrint('[VOICE-AI] IGNORED - AI is speaking');
     }
     break;
   ```

### How Semantic VAD Works

| Feature | server_vad | semantic_vad |
|---------|------------|--------------|
| Detection method | Audio energy threshold | AI speech understanding |
| Background noise | Triggers on any sound | Ignores non-speech sounds |
| Other voices | Cannot distinguish | Focuses on primary speaker |
| TV/Music | Triggers false positives | Filters out as non-speech |
| Latency | Lower (~100ms) | Slightly higher (~200ms) |

### Files Modified

| File | Change |
|------|--------|
| `backend/functions/index.js` | semantic_vad, eagerness: low, interrupt_response: false, far_field |
| `mobile/app/lib/src/services/voice_ai_service.dart` | Fixed event names, removed onTrack state change, added state guards |

### Testing Results (January 7, 2026)

- ✅ AI completes full responses with TV dialogue in background
- ✅ User can still speak to AI and get responses
- ✅ State machine correctly transitions: listening → processing → speaking → listening
- ✅ Background noise during AI speech is properly ignored

See `docs/VOICE_AI_DEPLOYED.md` for complete implementation details.

---

## iOS Speaker Routing Fix (January 2026)

### Problem

On iOS, Voice AI audio played through the **earpiece** (receiver) instead of the **speaker**, making AI responses whisper-quiet even at maximum volume.

### Root Cause

Three issues combined to cause this problem:

1. **Timing Issue**: The original code called `Helper.ensureAudioSession()` and `Helper.setSpeakerphoneOn(true)` **BEFORE** the WebRTC peer connection was established. When WebRTC created the connection, iOS automatically switched to earpiece mode for "voice call" behavior, overriding our settings.

2. **Guard Check Bug**: In flutter_webrtc v0.12.12's `AudioUtils.m`, the `setSpeakerphoneOn()` method has a guard check that silently returns without doing anything if the audio session category isn't `PlayAndRecord`:
   ```objc
   if(enable && config.category != AVAudioSessionCategoryPlayAndRecord) {
       NSLog(@"setSpeakerphoneOn: ... ignore.");
       return;  // Does nothing!
   }
   ```

3. **Missing Option**: `Helper.ensureAudioSession()` sets up the `PlayAndRecord` category but does NOT include the `defaultToSpeaker` category option that actually forces speaker routing.

### Solution

Move iOS audio configuration to **AFTER** the peer connection is established, and use `setAppleAudioConfiguration()` with explicit `defaultToSpeaker` option.

**File Modified**: `lib/src/services/voice_ai_service.dart`

**New Imports Added**:
```dart
import 'dart:io' show Platform;
import 'package:flutter_webrtc/src/native/ios/audio_configuration.dart';
```

**Code Added** (after `onConnectionState` handler, around line 416):
```dart
// iOS-specific: Force speaker output AFTER peer connection is established
// This must happen AFTER WebRTC setup to override iOS's default earpiece routing
if (Platform.isIOS) {
  await Helper.setAppleAudioConfiguration(AppleAudioConfiguration(
    appleAudioCategory: AppleAudioCategory.playAndRecord,
    appleAudioCategoryOptions: {
      AppleAudioCategoryOption.defaultToSpeaker,  // KEY: Forces speaker!
      AppleAudioCategoryOption.allowBluetooth,
      AppleAudioCategoryOption.allowBluetoothA2DP,
      AppleAudioCategoryOption.allowAirPlay,
    },
    appleAudioMode: AppleAudioMode.voiceChat,
  ));

  await Helper.setSpeakerphoneOn(true);
  debugPrint('[VOICE-AI] iOS audio configured for speaker output');
}
```

### Why This Works

| Factor | Explanation |
|--------|-------------|
| **Timing** | Calling after peer connection ensures iOS doesn't override our settings |
| **Explicit Configuration** | `setAppleAudioConfiguration()` bypasses the guard check in `setSpeakerphoneOn()` |
| **defaultToSpeaker** | This iOS AVAudioSession category option explicitly routes audio to the speaker |
| **voiceChat Mode** | Optimized audio mode for two-way voice communication |

### Testing Results (January 16, 2026)

- ✅ AI voice responses play through iPhone speaker at normal volume
- ✅ User can still speak to AI via microphone
- ✅ Bluetooth audio routing still works when headphones connected
- ✅ Volume control works as expected

### iOS User Settings to Check

If audio still routes to earpiece, verify these iPhone settings:
- **Settings > Accessibility > Touch > Call Audio Routing**: Should be "Automatic"
- **Settings > Accessibility > Audio & Visual > Mono Audio**: Should be OFF

See `docs/iOS_IMPLEMENTATION.md` for complete iOS configuration documentation.

---

## Push-to-Talk Implementation (January 2026)

### Overview

Changed Voice AI from auto-detect mode to push-to-talk mode. Users must hold the microphone button to speak - when not pressed, the AI ignores audio input.

### User Experience

| Action | Result |
|--------|--------|
| **Tap button** (when idle) | Starts voice session, AI greets user |
| **Hold button** | Microphone unmuted, user can speak |
| **Release button** | Audio committed, AI responds immediately |
| **Quick tap** (during session) | Ends the voice session |

### Why Push-to-Talk?

1. **Eliminates false triggers** - Background noise, TV, other people talking won't accidentally trigger the AI
2. **User control** - User decides exactly when to speak and when to listen
3. **Faster responses** - No VAD delay; AI responds instantly when button released
4. **Better for noisy environments** - Works reliably in bars, parties, living rooms with TV

### Technical Implementation

#### Client-Side Only (No Azure Function Changes)

The implementation uses WebRTC audio track muting - completely client-side with no backend changes required.

#### Key Components

**1. Audio Track Muting** (`voice_ai_service.dart`):
```dart
void setMicrophoneMuted(bool muted) {
  _isMuted = muted;
  if (_localStream != null) {
    final audioTracks = _localStream!.getAudioTracks();
    for (final track in audioTracks) {
      track.enabled = !muted;  // Mute/unmute the WebRTC audio track
    }
  }

  // When muting (user released button), commit buffer and request response
  if (muted && _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen) {
    _commitAudioBuffer();
  }
}
```

**2. Immediate Response Trigger** (`voice_ai_service.dart`):
```dart
void _commitAudioBuffer() {
  // Step 1: Commit the audio buffer
  _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
    'type': 'input_audio_buffer.commit',
  })));

  // Step 2: Explicitly request response (bypasses VAD delay)
  _dataChannel!.send(RTCDataChannelMessage(jsonEncode({
    'type': 'response.create',
  })));

  _setState(VoiceAIState.processing);
}
```

**3. Gesture Detection** (`voice_button.dart`):

Uses `Listener` widget for raw pointer events instead of `GestureDetector` to avoid gesture recognition conflicts:

```dart
Listener(
  onPointerDown: _handlePointerDown,   // Start listening (unmute)
  onPointerUp: _handlePointerUp,       // Stop listening (mute + commit)
  onPointerCancel: _handlePointerCancel,
  child: /* button widget */,
)
```

Quick tap (<250ms) ends session; longer hold triggers push-to-talk.

**4. State Management** (`voice_ai_provider.dart`):
```dart
class VoiceAISessionState {
  final bool isMicMuted;  // true = not listening (default)
  // ... other fields
}
```

#### Session Flow

```
1. User taps button
   └─> startSession() called
   └─> WebRTC connection established
   └─> Microphone starts MUTED (push-to-talk default)
   └─> AI greets user

2. User holds button
   └─> onPointerDown fires
   └─> setMicrophoneMuted(false) called
   └─> Audio track enabled, user speaks

3. User releases button
   └─> onPointerUp fires
   └─> setMicrophoneMuted(true) called
   └─> Audio track disabled
   └─> input_audio_buffer.commit sent
   └─> response.create sent
   └─> AI responds immediately

4. Repeat steps 2-3 for conversation

5. User quick-taps button
   └─> endSession() called
   └─> Usage recorded, connection closed
```

### Files Modified

| File | Changes |
|------|---------|
| `voice_ai_service.dart` | Added `setMicrophoneMuted()`, `_commitAudioBuffer()`, mic starts muted |
| `voice_ai_provider.dart` | Added `isMicMuted` state field and `setMicrophoneMuted()` method |
| `voice_button.dart` | Replaced GestureDetector with Listener, added press-and-hold logic |
| `voice_ai_screen.dart` | Wired up `onMuteChanged` callback, updated status indicator |
| `transcript_view.dart` | Updated "How to use" instructions for push-to-talk |

### UI Instructions Updated

**Before (auto-detect):**
- "Tap the microphone and start talking"
- "Tap button to start talking"
- "Tap button again to stop"

**After (push-to-talk):**
- "Have a natural conversation about cocktails, recipes, and bar techniques!"
- "Tap to start a session"
- "Hold button to speak"
- "Release to hear AI respond"
- "Quick tap to end session"

### Testing Results (January 16, 2026)

- ✅ Hold button to speak works reliably
- ✅ Release triggers immediate AI response (no VAD delay)
- ✅ Quick tap correctly ends session
- ✅ Background noise completely ignored when not holding button
- ✅ Visual feedback (green ring) shows when listening
- ✅ Haptic feedback on press/release
