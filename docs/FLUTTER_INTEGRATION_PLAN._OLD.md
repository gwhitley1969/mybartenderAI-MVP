# Flutter Mobile App Integration Plan

**Created**: October 20, 2025  
**Backend Status**: ✅ Fully operational at `https://func-mba-fresh.azurewebsites.net`

## Overview

This plan outlines the integration of the Flutter mobile app with the Azure Functions backend, including both text-based and voice-enabled features using OpenAI's Realtime API.

## Current Backend Endpoints

### ✅ Operational Endpoints

1. **Health Check**
   - `GET /api/health` - Anonymous access
   - Returns: `{ "status": "ok", "message": "...", "timestamp": "..." }`

2. **Snapshots**
   - `GET /api/v1/snapshots/latest` - Get latest cocktail database snapshot
   - `GET /api/v1/snapshots/latest-mi` - MI version (currently using)
   - Returns: Metadata with User Delegation SAS URL for downloading

3. **AI Features**
   - `POST /api/v1/recommend` - Get cocktail recommendations (requires function key)
   - `POST /api/v1/ask-bartender-simple` - Natural language queries (requires function key)

4. **Voice Features**
   - `POST /api/v1/realtime/token-simple` - Get ephemeral token for OpenAI Realtime API

5. **Admin**
   - `POST /api/v1/admin/download-images-mi` - Download cocktail images (admin key)

## Phase 1: Basic Integration (Text-Based)

### 1.1 Environment Configuration
```dart
// lib/src/config/env_config.dart
class EnvConfig {
  static const String apiBaseUrl = 'https://func-mba-fresh.azurewebsites.net/api';
  static const String functionKey = ''; // Store securely, not in code
}
```

### 1.2 API Client Setup
- [x] Configure Dio HTTP client with interceptors
- [x] Add function key header injection
- [ ] Implement retry logic and error handling
- [ ] Add request/response logging for debugging

### 1.3 Offline Database
```dart
// Download and cache cocktail snapshot
class SnapshotService {
  Future<void> downloadLatestSnapshot() async {
    // 1. Get metadata from /v1/snapshots/latest-mi
    // 2. Download snapshot using signed URL
    // 3. Verify SHA256
    // 4. Decompress and store locally
  }
}
```

### 1.4 Core Features Implementation
- [ ] **Home Screen** - Match the provided mockup
- [x] **Ask the Bartender** - Text chat interface
- [ ] **Find Cocktails** - Search and filter from local DB
- [ ] **Offline Mode** - Indicator and functionality

## Phase 2: Voice Integration with OpenAI Realtime API

### 2.1 Authentication Flow
```dart
class RealtimeAuthService {
  Future<RealtimeToken> getEphemeralToken() async {
    // POST /v1/realtime/token-simple
    // Returns temporary credentials for WebSocket
  }
}
```

### 2.2 WebSocket Implementation
```dart
class RealtimeWebSocketService {
  WebSocketChannel? _channel;
  
  Future<void> connect(String token) async {
    final url = 'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01';
    _channel = WebSocketChannel.connect(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'OpenAI-Beta': 'realtime=v1',
      },
    );
  }
}
```

### 2.3 Audio Handling
```dart
// Using 'record' package for audio capture
class AudioRecorderService {
  final Record _recorder = Record();
  
  Stream<Uint8List> startRecording() async* {
    await _recorder.start(
      encoder: AudioEncoder.pcm16,
      samplingRate: 24000, // OpenAI Realtime requirement
      numChannels: 1,
    );
    // Stream PCM16 audio chunks
  }
}
```

### 2.4 Voice Chat UI
- [x] Animated microphone button with pulse effect
- [x] Real-time transcription display
- [x] AI response text and audio playback
- [ ] Voice activity detection (VAD)
- [ ] Interruption handling

## Phase 3: Authentication (Azure AD B2C)

### 3.1 Configuration
```dart
// Using flutter_appauth package
final AuthorizationService _authService = AuthorizationService();

final AuthorizationServiceConfiguration _serviceConfig = 
  AuthorizationServiceConfiguration(
    authorizationEndpoint: 'https://yourtenant.b2clogin.com/...',
    tokenEndpoint: 'https://yourtenant.b2clogin.com/...',
  );
```

### 3.2 Auth Flow
1. **Login** - Redirect to B2C login page
2. **Token Storage** - Secure storage using flutter_secure_storage
3. **Token Refresh** - Automatic refresh before expiry
4. **Logout** - Clear tokens and redirect

### 3.3 Protected Endpoints
- Inject JWT token in Authorization header
- Handle 401 responses with token refresh
- Implement logout on refresh failure

## Implementation Timeline

### Week 1: Core Integration
- [x] Day 1-2: Environment setup and API client
- [x] Day 3-4: Ask the Bartender text chat
- [ ] Day 5-7: Offline database and cocktail search

### Week 2: Voice Features
- [ ] Day 1-2: WebSocket connection setup
- [ ] Day 3-4: Audio recording and streaming
- [ ] Day 5-7: Voice UI and playback

### Week 3: Authentication & Polish
- [ ] Day 1-3: Azure AD B2C integration
- [ ] Day 4-5: Error handling and edge cases
- [ ] Day 6-7: Testing and bug fixes

## Testing Strategy

### Unit Tests
- API client methods
- Data models and serialization
- Offline database operations

### Integration Tests
- Backend API calls with mock server
- WebSocket connection handling
- Audio streaming pipeline

### E2E Tests
- Complete user flows
- Offline/online transitions
- Voice interaction scenarios

## Security Considerations

1. **API Keys**
   - Never hardcode function keys
   - Use environment variables or secure storage
   - Implement key rotation strategy

2. **Token Management**
   - Store tokens securely
   - Implement proper expiry handling
   - Clear tokens on logout

3. **Network Security**
   - Certificate pinning for API calls
   - Validate SSL certificates
   - Implement request signing if needed

## Error Handling

### Network Errors
- Retry with exponential backoff
- Queue requests when offline
- Show appropriate user messages

### Audio Errors
- Microphone permission handling
- Audio device failures
- Network interruptions during streaming

### API Errors
- Rate limiting (429 responses)
- Token expiry (401 responses)
- Server errors (500+ responses)

## Performance Optimization

1. **Caching Strategy**
   - Cache cocktail images locally
   - Store user preferences
   - Cache AI responses when appropriate

2. **Database Optimization**
   - Index frequently queried fields
   - Implement pagination for large results
   - Use SQLite FTS for text search

3. **Network Optimization**
   - Compress request/response payloads
   - Batch API calls where possible
   - Implement request debouncing

## Monitoring & Analytics

1. **Crash Reporting** - Firebase Crashlytics
2. **Analytics** - Track feature usage
3. **Performance** - Monitor API latency
4. **User Feedback** - In-app feedback mechanism

## Next Steps

1. **Immediate Actions**
   - [ ] Configure Flutter app with backend URL
   - [ ] Test basic API connectivity
   - [ ] Implement offline snapshot download

2. **Short Term** (1-2 weeks)
   - [ ] Complete text-based features
   - [ ] Begin voice integration
   - [ ] Set up CI/CD pipeline

3. **Long Term** (3-4 weeks)
   - [ ] Full authentication flow
   - [ ] App store submission prep
   - [ ] Performance optimization

## Success Metrics

- **API Integration**: All endpoints working with <500ms latency
- **Offline Mode**: Full functionality without network
- **Voice**: <200ms latency for voice interactions
- **Auth**: Seamless login/logout with token refresh
- **User Experience**: 4.5+ star rating target
