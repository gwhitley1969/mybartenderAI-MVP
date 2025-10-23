# Flutter Mobile App Integration Plan

**Created**: October 22, 2025  
**Backend Status**: ✅ Fully operational at `https://apim-mba-001.azure-api.net/api`

## Overview

This plan outlines the integration of the Flutter mobile app with Azure Functions via Azure API Management, including text-based AI recommendations and voice interaction using Azure Speech Services.

## Current Backend Architecture

### API Gateway
- **APIM Instance**: `apim-mba-001`
- **Gateway URL**: https://apim-mba-001.azure-api.net
- **Function Backend**: `func-mba-fresh.azurewebsites.net`
- **Region**: South Central US

### ✅ Operational Endpoints

1. **Health Check**
   - `GET /api/health` - Anonymous access
   - Returns: `{ "status": "ok", "message": "...", "timestamp": "..." }`

2. **Snapshots**
   - `GET /api/v1/snapshots/latest` - Get latest cocktail database snapshot
   - Returns: Metadata with SAS URL for downloading

3. **AI Features** (Requires Premium/Pro tier)
   - `POST /api/v1/ask-bartender` - GPT-4o-mini conversational endpoint
   - `POST /api/v1/recommend` - Get cocktail recommendations
   - `POST /api/v1/ask-bartender-simple` - Simplified version

4. **Voice Features** (Future - Azure Speech Services)
   - `GET /api/v1/speech/token` - Get Azure Speech SDK token

5. **Admin**
   - `POST /api/v1/admin/sync` - Trigger CocktailDB sync (function key required)

## Phase 1: Basic Integration (Text-Based)

### 1.1 Environment Configuration
```dart
// lib/src/config/env_config.dart
class EnvConfig {
  // APIM Gateway (not direct Function URL)
  static const String apiBaseUrl = 'https://apim-mba-001.azure-api.net/api';
  
  // Subscription key per tier (provisioned during signup)
  // DO NOT hardcode - retrieve from secure storage
  static String? _subscriptionKey;
  
  static Future<String?> getSubscriptionKey() async {
    if (_subscriptionKey == null) {
      final storage = FlutterSecureStorage();
      _subscriptionKey = await storage.read(key: 'apim_subscription_key');
    }
    return _subscriptionKey;
  }
  
  static Future<void> setSubscriptionKey(String key) async {
    _subscriptionKey = key;
    final storage = FlutterSecureStorage();
    await storage.write(key: 'apim_subscription_key', value: key);
  }
}
```

### 1.2 API Client Setup
```dart
// lib/src/api/api_client.dart
class ApiClient {
  final Dio _dio;
  
  ApiClient() : _dio = Dio(
    BaseOptions(
      baseUrl: EnvConfig.apiBaseUrl,
      connectTimeout: Duration(seconds: 30),
      receiveTimeout: Duration(seconds: 30),
    ),
  ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // CRITICAL: Add APIM subscription key
        final subKey = await EnvConfig.getSubscriptionKey();
        if (subKey != null) {
          options.headers['Ocp-Apim-Subscription-Key'] = subKey;
        }
        
        // Add JWT for user identity
        final authService = getIt<AuthService>();
        final idToken = await authService.getIdToken();
        if (idToken != null) {
          options.headers['Authorization'] = 'Bearer $idToken';
        }
        
        // Correlation ID for tracing
        options.headers['X-Correlation-Id'] = Uuid().v4();
        
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 429) {
          // Rate limit exceeded
          _showUpgradeDialog();
        }
        handler.next(error);
      },
    ));
  }
}
```

### 1.3 Offline Database
```dart
// lib/src/services/snapshot_service.dart
class SnapshotService {
  Future<void> downloadLatestSnapshot() async {
    try {
      // 1. Get metadata from APIM endpoint
      final response = await _apiClient.get('/v1/snapshots/latest');
      final metadata = SnapshotMetadata.fromJson(response.data);
      
      // 2. Check if we need to download (compare versions)
      final currentVersion = await _getLocalVersion();
      if (metadata.version == currentVersion) {
        print('Snapshot up to date');
        return;
      }
      
      // 3. Download snapshot using SAS URL
      final snapshotData = await _downloadFile(metadata.blobUrl);
      
      // 4. Verify SHA256
      final actualHash = sha256.convert(snapshotData).toString();
      if (actualHash != metadata.sha256) {
        throw Exception('Snapshot hash mismatch');
      }
      
      // 5. Decompress and store locally
      final decompressed = GZipDecoder().decodeBytes(snapshotData);
      await _importToSqlite(decompressed);
      
      // 6. Update local version
      await _setLocalVersion(metadata.version);
      
    } catch (e) {
      print('Error downloading snapshot: $e');
      rethrow;
    }
  }
  
  Future<void> _importToSqlite(Uint8List jsonData) async {
    final db = await database;
    final json = jsonDecode(utf8.decode(jsonData));
    
    await db.transaction((txn) async {
      // Import drinks
      for (var drink in json['drinks']) {
        await txn.insert('drinks', drink, 
          conflictAlgorithm: ConflictAlgorithm.replace);
      }
      
      // Import ingredients
      for (var ingredient in json['ingredients']) {
        await txn.insert('ingredients', ingredient,
          conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
```

### 1.4 Core Features Implementation
- [x] **Ask the Bartender** - Text chat with GPT-4o-mini
- [ ] **Find Cocktails** - Search and filter from local DB
- [ ] **Home Screen** - Match the provided mockup
- [ ] **Offline Mode** - Indicator and functionality
- [ ] **Tier Management** - Handle Free/Premium/Pro features

## Phase 2: Voice Integration with Azure Speech Services

### 2.1 Cost-Optimized Voice Architecture
**Why Azure Speech Services instead of OpenAI Realtime API:**
- OpenAI Realtime: ~$1.50 per 5-minute session
- Azure Speech + GPT-4o-mini: ~$0.10 per 5-minute session
- **93% cost savings**

### 2.2 Client-Side Speech Processing
```dart
// lib/src/services/speech_service.dart
class SpeechService {
  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  Future<void> initialize() async {
    // Initialize Speech-to-Text
    await _stt.initialize(
      onStatus: (status) => print('STT Status: $status'),
      onError: (error) => print('STT Error: $error'),
    );
    
    // Initialize Text-to-Speech
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); // Slower for instructions
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // Optional: Use Azure Neural voices
    // await _tts.setVoice('en-US-JennyNeural');
  }
  
  Future<String> listenForSpeech() async {
    if (!_stt.isAvailable) {
      throw Exception('Speech recognition not available');
    }
    
    String recognizedText = '';
    
    await _stt.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
      },
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
    );
    
    // Wait for speech to complete
    while (_stt.isListening) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    return recognizedText;
  }
  
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
  
  Future<void> stop() async {
    await _stt.stop();
    await _tts.stop();
  }
}
```

### 2.3 Voice Controller Integration
```dart
// lib/src/features/voice_assistant/voice_controller.dart
class VoiceAssistantController extends StateNotifier<VoiceState> {
  final SpeechService _speechService;
  final ApiClient _apiClient;
  
  VoiceAssistantController(this._speechService, this._apiClient) 
    : super(VoiceState.idle());
  
  Future<void> startVoiceSession() async {
    try {
      // 1. Start listening
      state = VoiceState.listening();
      final userText = await _speechService.listenForSpeech();
      
      if (userText.isEmpty) {
        state = VoiceState.idle();
        return;
      }
      
      // 2. Show transcription
      state = VoiceState.processing(userTranscript: userText);
      
      // 3. Send to backend via APIM
      final response = await _apiClient.post(
        '/v1/ask-bartender',
        data: {
          'query': userText,
          'context': 'voice',
        },
      );
      
      final aiResponse = response.data['text'];
      
      // 4. Speak response
      state = VoiceState.speaking(
        userTranscript: userText,
        aiResponse: aiResponse,
      );
      
      await _speechService.speak(aiResponse);
      
      // 5. Ready for next input
      state = VoiceState.idle();
      
    } catch (e) {
      state = VoiceState.error(e.toString());
    }
  }
  
  void stop() {
    _speechService.stop();
    state = VoiceState.idle();
  }
}
```

### 2.4 Voice Chat UI
```dart
// lib/src/features/voice_assistant/voice_assistant_screen.dart
class VoiceAssistantScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceAssistantProvider);
    final controller = ref.read(voiceAssistantProvider.notifier);
    
    return Scaffold(
      body: Column(
        children: [
          // Transcription display
          if (voiceState.userTranscript != null)
            TranscriptBubble(
              text: voiceState.userTranscript!,
              isUser: true,
            ),
          
          // AI response
          if (voiceState.aiResponse != null)
            TranscriptBubble(
              text: voiceState.aiResponse!,
              isUser: false,
            ),
          
          Spacer(),
          
          // Animated microphone button
          VoiceMicrophoneButton(
            isListening: voiceState is VoiceListening,
            isSpeaking: voiceState is VoiceSpeaking,
            onPressed: () {
              if (voiceState is VoiceIdle) {
                controller.startVoiceSession();
              } else {
                controller.stop();
              }
            },
          ),
        ],
      ),
    );
  }
}
```

## Phase 3: Authentication (Azure AD B2C)

### 3.1 Configuration
```dart
// lib/src/config/auth_config.dart
class AuthConfig {
  static const String b2cTenant = 'mybartenderai';
  static const String clientId = '<your-b2c-app-client-id>';
  static const String redirectUri = 'com.mybartenderai.app://auth';
  static const String signInPolicy = 'B2C_1_signupsignin';
  
  static String get authority =>
      'https://$b2cTenant.b2clogin.com/$b2cTenant.onmicrosoft.com/$signInPolicy';
  
  static String get discoveryUrl =>
      '$authority/v2.0/.well-known/openid-configuration';
}
```

### 3.2 Auth Flow
```dart
// lib/src/services/auth_service.dart
class AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  Future<bool> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AuthConfig.clientId,
          AuthConfig.redirectUri,
          discoveryUrl: AuthConfig.discoveryUrl,
          scopes: ['openid', 'profile', 'offline_access'],
        ),
      );
      
      if (result != null) {
        await _storeTokens(result);
        
        // Register/login with backend to get APIM subscription key
        await _registerWithBackend(result.idToken!);
        
        return true;
      }
      return false;
    } catch (e) {
      print('Sign in error: $e');
      return false;
    }
  }
  
  Future<void> _registerWithBackend(String idToken) async {
    // Call backend to get/create user and APIM subscription
    final response = await _apiClient.post(
      '/v1/auth/register',
      options: Options(headers: {'Authorization': 'Bearer $idToken'}),
    );
    
    final subscriptionKey = response.data['subscriptionKey'];
    await EnvConfig.setSubscriptionKey(subscriptionKey);
  }
  
  Future<void> signOut() async {
    await _storage.deleteAll();
    await EnvConfig.setSubscriptionKey('');
  }
}
```

## Phase 4: Tier Management

### 4.1 Feature Gating
```dart
// lib/src/services/tier_service.dart
class TierService {
  final ApiClient _apiClient;
  
  // Track usage against quotas
  int _aiRecommendationsUsed = 0;
  int _voiceMinutesUsed = 0;
  
  Future<bool> canUseFeature(Feature feature) async {
    final tier = await _getCurrentTier();
    
    switch (feature) {
      case Feature.aiRecommendations:
        if (tier == Tier.free && _aiRecommendationsUsed >= 10) {
          return false;
        }
        if (tier == Tier.premium && _aiRecommendationsUsed >= 100) {
          return false;
        }
        return true;
        
      case Feature.voiceAssistant:
        if (tier == Tier.free) return false;
        if (tier == Tier.premium && _voiceMinutesUsed >= 30) {
          return false;
        }
        return true;
        
      case Feature.visionScanning:
        return tier != Tier.free;
        
      default:
        return true;
    }
  }
  
  Future<void> showUpgradeDialog() async {
    // Show dialog prompting upgrade to Premium/Pro
  }
}
```

## Implementation Timeline

### Week 1: Core Integration
- [x] Day 1-2: APIM integration and API client
- [x] Day 3-4: Ask the Bartender text chat with GPT-4o-mini
- [ ] Day 5-7: Offline database and cocktail search

### Week 2: Voice Features
- [ ] Day 1-2: Azure Speech Services setup
- [ ] Day 3-4: Voice UI and client-side STT/TTS
- [ ] Day 5-7: Voice session management and error handling

### Week 3: Authentication & Tiers
- [ ] Day 1-3: Azure AD B2C integration
- [ ] Day 4-5: APIM subscription provisioning
- [ ] Day 6-7: Feature gating and tier management

### Week 4: Polish & Testing
- [ ] Day 1-2: Error handling and edge cases
- [ ] Day 3-4: Offline/online transitions
- [ ] Day 5-7: End-to-end testing and bug fixes

## Testing Strategy

### Unit Tests
- API client methods with APIM headers
- Data models and serialization
- Offline database operations
- Speech service mocking

### Integration Tests
- APIM authentication flow
- GPT-4o-mini responses via APIM
- Voice session end-to-end
- Tier-based feature access

### E2E Tests
- Complete user flows (signup → AI chat → voice)
- Offline/online transitions
- Upgrade flow (Free → Premium)
- Voice interaction scenarios

## Security Considerations

1. **APIM Subscription Keys**
   - Never hardcode subscription keys
   - Store in Flutter Secure Storage
   - Implement key refresh if compromised

2. **JWT Token Management**
   - Store tokens securely
   - Implement proper expiry handling
   - Refresh tokens before expiry
   - Clear tokens on logout

3. **Network Security**
   - All communication over HTTPS
   - Validate SSL certificates
   - Consider certificate pinning for production

## Performance Optimization

1. **API Calls**
   - Cache responses where appropriate
   - Implement request debouncing
   - Batch operations when possible

2. **Database**
   - Index frequently queried fields
   - Use SQLite FTS for text search
   - Implement pagination for large results

3. **Voice**
   - Stream audio for lower latency
   - Use lower quality audio for STT (24kHz)
   - Prefetch TTS voices for offline use

## Monitoring & Analytics

1. **Crash Reporting**: Firebase Crashlytics
2. **Analytics**: Track feature usage per tier
3. **Performance**: Monitor API latency via APIM
4. **Voice Metrics**: Track session duration and success rate

## Next Steps

1. **Immediate Actions**
   - [ ] Configure Flutter app with APIM URL
   - [ ] Test basic API connectivity with subscription key
   - [ ] Implement offline snapshot download

2. **Short Term** (1-2 weeks)
   - [ ] Complete text-based AI features
   - [ ] Begin voice integration with Azure Speech
   - [ ] Set up CI/CD pipeline

3. **Long Term** (3-4 weeks)
   - [ ] Full authentication flow with B2C
   - [ ] Tier management and upgrade flow
   - [ ] App store submission prep

## Success Metrics

- **API Integration**: All endpoints working with <500ms latency via APIM
- **Offline Mode**: Full Free tier functionality without network
- **Voice**: <2 seconds end-to-end latency (STT → API → TTS)
- **Auth**: Seamless login/logout with automatic token refresh
- **Tier Enforcement**: Proper gating of Premium/Pro features at APIM layer
- **Cost**: Stay within $0.50/user/month for AI+Voice services
- **User Experience**: 4.5+ star rating target