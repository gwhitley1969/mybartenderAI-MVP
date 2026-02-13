# Voice Integration Plan with Azure Speech Services

> **Note (February 2026):** This document describes the original plan to use Azure Speech Services with a client-side SDK approach and the old Free/Premium/Pro tier model. The voice architecture has since been replaced with **GPT-realtime-mini** via Azure OpenAI Realtime API (server-side WebSocket), and the subscription model simplified to a binary `paid`/`none` entitlement managed via RevenueCat. See `VOICE_AI_IMPLEMENTATION.md` and `VOICE_AI_DEPLOYED.md` for the current architecture, and `SUBSCRIPTION_DEPLOYMENT.md` for the current subscription model.

## Overview

After cost analysis, we've decided to use **Azure Speech Services** instead of OpenAI's Realtime API. This approach provides **93% cost savings** while maintaining excellent voice interaction quality for cocktail-making guidance.

## Cost Comparison

### OpenAI Realtime API (Rejected)
- Audio Input: ~$0.06/minute
- Audio Output: ~$0.24/minute
- **5-minute session cost**: ~$1.50
- **1,000 Premium users (4 sessions/month)**: ~$6,000/month

### Azure Speech Services + GPT-4o-mini (Selected) ✅
- Speech-to-Text: $1/hour (~$0.017/minute)
- GPT-4o-mini text processing: ~$0.007/session
- Neural Text-to-Speech: $16/1M characters (~$0.00005/response)
- **5-minute session cost**: ~$0.10
- **1,000 Premium users (4 sessions/month)**: ~$400/month
- **Cost savings**: 93%

## Architecture Decision

### Selected: Client-Side Speech Processing ✅
```
User speaks → Azure Speech SDK (client) → Text →
Mobile App → APIM → Azure Function → GPT-4o-mini → Text response →
Mobile App → Azure Speech SDK (client) → Audio playback
```

**Advantages:**
- Lower latency (no server audio processing)
- Offline TTS capability (download neural voices)
- Reduced bandwidth (text vs audio streaming)
- Works on all Flutter platforms
- Better privacy (audio stays on device)

**Trade-offs:**
- Requires Azure Speech SDK integration in Flutter
- Client handles audio format conversion
- Larger app size (if bundling offline voices)

### Alternative: Server-Side Processing (Not Selected)
```
User speaks → Mobile (audio) → Azure Function → Speech-to-Text →
GPT-4o-mini → Text-to-Speech → Azure Function → Mobile (audio)
```

**Why Not Selected:**
- Higher latency (audio round-trip to server)
- More bandwidth usage
- Server processing costs
- No offline capability

## Implementation Plan

### Phase 1: Azure Speech Services Setup ✅

#### 1. Create Azure Speech Resource
```bash
# Create Speech Services resource
az cognitiveservices account create \
  --name speech-mba-prod \
  --resource-group rg-mba-prod \
  --kind SpeechServices \
  --sku F0 \  # Free tier for testing (5 hours/month)
  --location southcentralus

# Get API keys
az cognitiveservices account keys list \
  --name speech-mba-prod \
  --resource-group rg-mba-prod
```

#### 2. Add Speech Key to Key Vault
```bash
# Store in Key Vault
az keyvault secret set \
  --vault-name kv-mybartenderai-prod \
  --name AZURE-SPEECH-KEY \
  --value "<speech-api-key>"

az keyvault secret set \
  --vault-name kv-mybartenderai-prod \
  --name AZURE-SPEECH-REGION \
  --value "southcentralus"
```

#### 3. Create Token Endpoint (Function)
**New Function**: `GET /v1/speech/token`
- Returns short-lived Speech SDK token (10 minutes)
- No API key exposed to mobile app
- Rate limited by APIM per tier

```javascript
// functions/speech-token.js
module.exports = async function (context, req) {
  const speechKey = process.env.AZURE_SPEECH_KEY;
  const region = process.env.AZURE_SPEECH_REGION;
  
  // Exchange key for token
  const tokenResponse = await fetch(
    `https://${region}.api.cognitive.microsoft.com/sts/v1.0/issueToken`,
    {
      method: 'POST',
      headers: {
        'Ocp-Apim-Subscription-Key': speechKey,
        'Content-Length': '0'
      }
    }
  );
  
  const token = await tokenResponse.text();
  
  context.res = {
    status: 200,
    body: {
      token,
      region,
      expiresIn: 600 // 10 minutes
    }
  };
};
```

### Phase 2: Flutter Integration

#### 1. Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  speech_to_text: ^6.3.0  # For Speech-to-Text
  flutter_tts: ^3.7.0      # For Text-to-Speech
  http: ^1.1.0
  
  # Alternative: Use Azure Speech SDK directly
  # azure_speech_recognition: ^1.0.0  # If available
```

#### 2. Speech-to-Text Service

```dart
// lib/services/speech_service.dart
import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  
  Future<void> initialize() async {
    // Option 1: Use device STT (works offline, free)
    await _speech.initialize();
    
    // Option 2: Use Azure STT (better accuracy, requires token)
    // Fetch token from /v1/speech/token endpoint
    // Configure with Azure credentials
  }
  
  Future<String> listen() async {
    if (!_isListening) {
      _isListening = true;
      
      String recognizedText = '';
      
      await _speech.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords;
        },
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        // For Azure: configure custom vocabulary
        // vocabulary: ['muddler', 'jigger', 'Aperol', 'Negroni', ...]
      );
      
      // Wait for speech to complete
      while (_speech.isListening) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      _isListening = false;
      return recognizedText;
    }
    return '';
  }
  
  void stop() {
    _speech.stop();
    _isListening = false;
  }
}
```

#### 3. Text-to-Speech Service

```dart
// lib/services/tts_service.dart
import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts _tts = FlutterTts();
  
  Future<void> initialize() async {
    // Configure voice
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5); // Slower for instructions
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // For Azure Neural voices (if using azure_tts package):
    // await _tts.setVoice('en-US-JennyNeural'); // Friendly female voice
    // or 'en-US-GuyNeural' for male
  }
  
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }
  
  Future<void> stop() async {
    await _tts.stop();
  }
  
  // Add SSML support for better control
  Future<void> speakWithEmphasis(String text, List<String> emphasize) async {
    // Example: Emphasize measurements
    // "Add <emphasis>two ounces</emphasis> of gin"
    String ssml = generateSSML(text, emphasize);
    await _tts.speak(ssml);
  }
}
```

#### 4. Voice Bartender Controller

```dart
// lib/features/voice_assistant/voice_controller.dart
class VoiceAssistantController extends StateNotifier<VoiceState> {
  final SpeechService _speechService;
  final TTSService _ttsService;
  final BartenderApiService _apiService;
  
  VoiceAssistantController(
    this._speechService,
    this._ttsService,
    this._apiService,
  ) : super(VoiceState.idle());
  
  Future<void> startConversation() async {
    // 1. Start listening
    state = VoiceState.listening();
    final userText = await _speechService.listen();
    
    if (userText.isEmpty) {
      state = VoiceState.idle();
      return;
    }
    
    // 2. Show transcription
    state = VoiceState.processing(userTranscript: userText);
    
    // 3. Send to backend (via APIM)
    final response = await _apiService.askBartender(userText);
    
    // 4. Speak response
    state = VoiceState.speaking(
      userTranscript: userText,
      aiResponse: response.text,
    );
    
    await _ttsService.speak(response.text);
    
    // 5. Ready for next input
    state = VoiceState.idle();
  }
  
  void stop() {
    _speechService.stop();
    _ttsService.stop();
    state = VoiceState.idle();
  }
}
```

### Phase 3: Backend Updates

#### Update `ask-bartender` Function for Voice
```javascript
// functions/ask-bartender.js
module.exports = async function (context, req) {
  const userText = req.body.query;
  const conversationHistory = req.body.history || [];
  
  // Optimized system prompt for voice interaction
  const systemPrompt = `You are an expert bartender assistant providing voice-guided instructions.

Guidelines:
- Be conversational and friendly
- Use clear, step-by-step instructions
- Specify exact measurements (e.g., "two ounces" not "2 oz")
- Describe actions clearly (e.g., "gently muddle" not just "muddle")
- Mention glassware and garnishes
- Keep responses under 100 words for natural speech
- Use pauses for clarity (use periods, not commas for long pauses)

Example: "First, fill your shaker with ice. Then add two ounces of vodka. Next, add one ounce of lime juice. Now shake vigorously for ten seconds. Finally, strain into a chilled martini glass."`;

  // Call GPT-4o-mini
  const completion = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: systemPrompt },
      ...conversationHistory,
      { role: 'user', content: userText }
    ],
    temperature: 0.7,
    max_tokens: 200, // Shorter for voice
  });
  
  const aiResponse = completion.choices[0].message.content;
  
  context.res = {
    status: 200,
    body: {
      text: aiResponse,
      conversationId: req.body.conversationId,
      tokensUsed: completion.usage.total_tokens
    }
  };
};
```

### Phase 4: APIM Configuration

#### Add Voice Endpoints to APIM
1. **Speech Token Endpoint**: `GET /v1/speech/token`
   - Rate limit: 60 calls/hour (token valid for 10 min)
   - Available to: Premium, Pro tiers only

2. **Ask Bartender (Voice)**: `POST /v1/ask-bartender`
   - Rate limit per tier (tracked in Function/DB)
   - Caching: Disabled (each conversation is unique)

3. **Voice Session Tracking**: `POST /v1/voice/session`
   - Track voice usage minutes per user
   - Enforce tier limits (Premium: 30 min/month, Pro: 5 hours/month)

#### APIM Policy Example
```xml
<policies>
  <inbound>
    <!-- Validate subscription key -->
    <validate-jwt header-name="Authorization">
      <openid-config url="https://login.microsoftonline.com/{tenant-id}/v2.0/.well-known/openid-configuration" />
    </validate-jwt>
    
    <!-- Rate limiting by tier -->
    <choose>
      <when condition="@(context.Subscription.Name == 'Premium')">
        <rate-limit calls="1000" renewal-period="86400" /> <!-- 1000/day -->
      </when>
      <when condition="@(context.Subscription.Name == 'Pro')">
        <rate-limit calls="10000" renewal-period="86400" /> <!-- 10000/day -->
      </when>
      <otherwise>
        <return-response>
          <set-status code="403" reason="Forbidden" />
          <set-body>Voice features require Premium or Pro subscription</set-body>
        </return-response>
      </otherwise>
    </choose>
    
    <!-- Forward to backend -->
    <set-backend-service base-url="https://func-mba-fresh.azurewebsites.net" />
  </inbound>
</policies>
```

## Testing Strategy

### 1. Unit Tests
- Speech-to-Text accuracy with bartending vocabulary
- TTS naturalness and clarity
- GPT-4o-mini response quality for voice format

### 2. Integration Tests
```dart
// test/voice_integration_test.dart
testWidgets('Voice assistant completes cocktail instruction', (tester) async {
  // Mock services
  final mockSpeech = MockSpeechService();
  final mockTTS = MockTTSService();
  final mockAPI = MockBartenderAPI();
  
  when(mockSpeech.listen()).thenAnswer((_) async => 'How do I make a Negroni?');
  when(mockAPI.askBartender(any)).thenAnswer((_) async => 
    BartenderResponse(text: 'First, fill a rocks glass with ice...')
  );
  
  // Build widget
  await tester.pumpWidget(VoiceAssistantScreen(
    speechService: mockSpeech,
    ttsService: mockTTS,
    apiService: mockAPI,
  ));
  
  // Tap voice button
  await tester.tap(find.byIcon(Icons.mic));
  await tester.pumpAndSettle();
  
  // Verify flow
  verify(mockSpeech.listen()).called(1);
  verify(mockAPI.askBartender('How do I make a Negroni?')).called(1);
  verify(mockTTS.speak(contains('First, fill a rocks glass'))).called(1);
});
```

### 3. User Experience Tests
- Measure latency: Target < 2 seconds (STT → API → TTS start)
- Test interruption handling
- Verify natural conversation flow
- Background noise tolerance

### 4. Cost Monitoring
- Track speech usage per user/tier
- Alert when approaching quota limits
- Monitor GPT-4o-mini token consumption

## Custom Vocabulary for Bartending

### Azure Speech Custom Models
Create custom speech model with bartending terms:

```json
{
  "vocabulary": [
    "muddler", "jigger", "shaker", "strainer",
    "Aperol", "Campari", "Negroni", "Manhattan",
    "Old Fashioned", "Boulevardier", "Sazerac",
    "Angostura", "Peychaud's", "orange bitters",
    "expressed", "flamed", "garnish", "zest",
    "ounce", "ounces", "dash", "dashes", "barspoon"
  ]
}
```

## Error Handling

### Common Scenarios
1. **Speech Recognition Fails**
   - Show "Didn't catch that, try again" UI
   - Fall back to text input option

2. **Network Error During API Call**
   - Cache user's question
   - Show offline message
   - Retry when connection restored

3. **Quota Exceeded**
   - Graceful message: "You've used your voice minutes for this month. Upgrade to Pro for more!"
   - Offer text-based chat as alternative

4. **TTS Playback Fails**
   - Show response as text
   - Log error for debugging

## Privacy & Security

### Voice Data Handling
- **Transcripts**: Not stored by default
- **Opt-in Recording**: Allow users to save conversations for learning
- **Retention**: 90 days for opted-in data only
- **PII**: Never log user-identifying information with transcripts

### Azure Speech Privacy
- All audio processing happens in Azure US datacenters
- No audio recordings stored by Microsoft (ephemeral processing)
- HTTPS for all API calls
- Tokens expire in 10 minutes

## Rollout Plan

### Beta Testing (Week 1-2)
- Internal testing with development team
- 10 external beta users (Premium tier)
- Collect feedback on naturalness and accuracy

### Limited Release (Week 3-4)
- Open to all Premium users
- Monitor costs and usage patterns
- Iterate on prompts and voice parameters

### General Availability (Week 5+)
- Enable for all Premium/Pro users
- Add advanced features (custom voices, SSML)
- Marketing push for voice capabilities

## Future Enhancements

### Phase 2
- **Multi-language Support**: Azure Speech Translation
- **Conversation Memory**: Remember user preferences across sessions
- **Emotion Detection**: Adjust AI tone based on user sentiment
- **Custom Voices**: Let users choose from multiple AI bartender personalities

### Phase 3
- **Offline Mode**: Download neural voices for offline TTS
- **Real-time Corrections**: Interrupt and correct AI mid-instruction
- **Visual Aids**: Show images/videos synchronized with voice instructions

## Success Metrics

### Technical Metrics
- Voice session latency: < 2 seconds p95
- Speech recognition accuracy: > 95%
- User retention: Track voice feature usage vs text

### Business Metrics
- Premium conversion rate increase
- Voice feature adoption: Target 40% of Premium users
- Cost per voice session: Maintain < $0.12

## Resources

- [Azure Speech Services Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/speech-service/)
- [Flutter Speech-to-Text Package](https://pub.dev/packages/speech_to_text)
- [Flutter TTS Package](https://pub.dev/packages/flutter_tts)
- [GPT-4o-mini Documentation](https://platform.openai.com/docs/models/gpt-4o-mini)