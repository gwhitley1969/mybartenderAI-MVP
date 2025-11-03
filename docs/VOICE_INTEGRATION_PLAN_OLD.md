# Voice Integration Plan with OpenAI Realtime API

## Overview

OpenAI's Realtime API enables low-latency, multimodal voice conversations. Based on the documentation provided, here's our implementation plan for MyBartenderAI.

## Architecture Decision

### Option 1: WebRTC (Direct Browser Connection) ✅ RECOMMENDED
- **Pros**: 
  - Lower latency (direct peer-to-peer)
  - No server-side audio processing needed
  - Better for real-time voice interaction
- **Cons**: 
  - More complex client implementation
  - Limited to browser/WebView environments

### Option 2: WebSocket (Server Relay)
- **Pros**: 
  - Works on any platform
  - Server can moderate/process audio
- **Cons**: 
  - Higher latency (audio travels through server)
  - Server costs for audio relay

## Implementation Steps

### Phase 1: Backend Setup ✅
1. **Create token endpoint** (`/v1/realtime/token`)
   - Generates ephemeral tokens for client authentication
   - Configures session with voice selection
   - Sets bartender-specific instructions

### Phase 2: Flutter WebSocket Implementation
1. **WebSocket Connection**
   ```dart
   // Connect to OpenAI Realtime API
   final wsUrl = 'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01';
   final ws = WebSocketChannel.connect(
     Uri.parse(wsUrl),
     headers: {
       'Authorization': 'Bearer $ephemeralToken',
       'OpenAI-Beta': 'realtime=v1',
     },
   );
   ```

2. **Audio Streaming**
   - Capture microphone audio
   - Convert to base64
   - Send via `input_audio_buffer.append` events

3. **Event Handling**
   - `conversation.item.created`: New message/transcription
   - `response.audio.delta`: Incoming audio chunks
   - `response.audio_transcript.delta`: Real-time transcription
   - `error`: Handle API errors

### Phase 3: Flutter UI Updates
1. **Voice Button States**
   - Idle (tap to start)
   - Listening (pulsing animation)
   - AI Speaking (waveform visualization)
   - Error state

2. **Real-time Feedback**
   - Show user transcription as they speak
   - Display AI response transcription
   - Visual indicators for connection status

## Key Features to Implement

### 1. Voice Activity Detection (VAD)
- Server-side VAD enabled by default
- Automatic turn detection

### 2. Interruption Handling
- User can interrupt AI mid-response
- Smooth conversation flow

### 3. Context Management
- Maintain conversation history
- Include user's bar inventory/preferences

### 4. Voice Selection
- Offer different AI voice options
- Remember user's preference

## Testing Strategy

### 1. Test Endpoints (No Auth) ✅
- `/v1/ask-bartender-test`
- `/v1/realtime/token-test`

### 2. Integration Tests
- Audio capture/playback
- WebSocket connection stability
- Token refresh mechanism

### 3. User Experience Tests
- Latency measurements
- Voice recognition accuracy
- Natural conversation flow

## Security Considerations

1. **Ephemeral Tokens**
   - Short-lived (1 hour)
   - Generated server-side only
   - Never expose main API key

2. **Rate Limiting**
   - Implement per-user limits
   - Monitor token usage

3. **Content Moderation**
   - Consider adding profanity filter
   - Log conversations for safety

## Next Steps

1. Fix current 500 errors in test endpoints
2. Implement WebSocket client in Flutter
3. Add audio recording/playback
4. Create voice UI components
5. Test end-to-end voice flow

## Resources

- [OpenAI Realtime API Guide](https://platform.openai.com/docs/guides/realtime)
- [Flutter WebSocket Package](https://pub.dev/packages/web_socket_channel)
- [Flutter Audio Recording](https://pub.dev/packages/record)
