# Voice Bartender Implementation Plan

**Created**: November 6, 2025
**Purpose**: Step-by-step implementation guide for adding voice interaction to MyBartenderAI
**Target Developer**: Sonnet AI for code implementation

## Overview

The Voice Bartender feature enables users to interact with the AI bartender using voice commands, creating a hands-free, conversational experience for cocktail making. This implementation uses **Azure Speech Services** (NOT OpenAI voice) for speech-to-text and text-to-speech, integrated with GPT-4o-mini for cocktail recommendations.

## ⚠️ IMPORTANT: Voice Technology Choice

**We are using AZURE SPEECH SERVICES, not OpenAI Realtime API**

This is a deliberate cost-optimization decision:
- **Azure Speech Services**: ~$0.10 per 5-minute session
- **OpenAI Realtime API**: ~$1.50 per 5-minute session
- **Savings**: 93% cost reduction

## Architecture Summary

```
User speaks → Azure Speech-to-Text (NOT OpenAI) →
Flutter App → APIM → Azure Function → GPT-4o-mini (text only) →
Azure Function → Flutter App → Azure Neural TTS (NOT OpenAI) → User hears
```

### Cost Breakdown
- **Azure Speech-to-Text**: $1 per audio hour (~$0.017/minute)
- **GPT-4o-mini text processing**: ~$0.007 per conversation
- **Azure Neural Text-to-Speech**: $16 per 1M characters (~$0.00005 per response)
- **Total per 5-min session**: ~$0.10

## Prerequisites

### Azure Resources Required
- **Azure Speech Services** (needs to be provisioned in South Central US)
- Azure Functions (existing: `func-mba-fresh`)
- Azure OpenAI (existing: `mybartenderai-scus`) - for text processing only
- API Management (existing: `apim-mba-001`)

### Required API Keys (from Key Vault)
- `AZURE-SPEECH-API-KEY`: Azure Speech Services subscription key
- `AZURE-SPEECH-REGION`: "southcentralus"
- `AZURE-SPEECH-ENDPOINT`: Speech Services endpoint
- Azure OpenAI API key (existing) - for text processing only

## Implementation Steps

### Phase 1: Azure Speech Services Setup

#### Step 1.1: Provision Azure Speech Services
**Location**: Azure Portal → Create Resource → Speech Services

```
Resource Name: speech-mybartenderai
Region: South Central US (same as other resources)
Pricing Tier: Standard S0
Resource Group: rg-mba-prod
```

#### Step 1.2: Add Speech Service Keys to Key Vault
**Location**: Azure Portal → `kv-mybartenderai-prod`

Add these secrets:
```
AZURE-SPEECH-API-KEY: <subscription-key-from-speech-service>
AZURE-SPEECH-REGION: southcentralus
AZURE-SPEECH-ENDPOINT: https://southcentralus.api.cognitive.microsoft.com/
```

#### Step 1.3: Update Function App Configuration
**File**: Azure Portal → `func-mba-fresh` → Configuration

Add application settings:
```json
{
  "AZURE_SPEECH_KEY": "@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-SPEECH-API-KEY)",
  "AZURE_SPEECH_REGION": "@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-SPEECH-REGION)",
  "AZURE_SPEECH_ENDPOINT": "@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-SPEECH-ENDPOINT)"
}
```

### Phase 2: Backend Implementation

#### Step 2.1: Install Azure Speech SDK
**Location**: `backend/functions/`

```bash
npm install microsoft-cognitiveservices-speech-sdk
```

#### Step 2.2: Create Voice Interaction Azure Function
**New File**: `backend/functions/voice-bartender/index.js`

```javascript
const sdk = require("microsoft-cognitiveservices-speech-sdk");
const { OpenAIClient } = require("@azure/openai");

module.exports = async function (context, req) {
    // THIS USES AZURE SPEECH SERVICES, NOT OPENAI VOICE
    const speechKey = process.env.AZURE_SPEECH_KEY;
    const speechRegion = process.env.AZURE_SPEECH_REGION;

    // Step 1: Convert speech to text using Azure Speech-to-Text
    const audioData = req.body; // Audio blob from mobile app
    const transcript = await convertSpeechToText(audioData, speechKey, speechRegion);

    // Step 2: Process with GPT-4o-mini (text only, no voice)
    const response = await processWithGPT(transcript);

    // Step 3: Convert response to speech using Azure Neural TTS
    const audioResponse = await convertTextToSpeech(response, speechKey, speechRegion);

    return {
        body: {
            audioData: audioResponse,
            transcript: transcript,
            textResponse: response
        }
    };
};
```

#### Step 2.3: Speech Services Integration Functions
**New File**: `backend/functions/voice-bartender/speech-service.js`

```javascript
const sdk = require("microsoft-cognitiveservices-speech-sdk");

// Azure Speech-to-Text (NOT OpenAI)
async function convertSpeechToText(audioBuffer, speechKey, speechRegion) {
    const speechConfig = sdk.SpeechConfig.fromSubscription(speechKey, speechRegion);

    // Add custom bartending vocabulary
    const phraseList = sdk.PhraseListGrammar.fromRecognizer(recognizer);
    phraseList.addPhrase("Margarita");
    phraseList.addPhrase("Mojito");
    phraseList.addPhrase("Manhattan");
    phraseList.addPhrase("Angostura bitters");
    phraseList.addPhrase("muddle");
    phraseList.addPhrase("shake with ice");

    // Configure for US English
    speechConfig.speechRecognitionLanguage = "en-US";

    // Process audio
    // ... implementation details
}

// Azure Neural Text-to-Speech (NOT OpenAI)
async function convertTextToSpeech(text, speechKey, speechRegion) {
    const speechConfig = sdk.SpeechConfig.fromSubscription(speechKey, speechRegion);

    // Use Azure Neural voice (NOT OpenAI voice)
    speechConfig.speechSynthesisVoiceName = "en-US-JennyNeural"; // Azure voice
    // Alternative: "en-US-GuyNeural" for male voice

    // Configure voice properties
    const synthesizer = new sdk.SpeechSynthesizer(speechConfig);

    // Generate speech
    // ... implementation details
}
```

#### Step 2.4: Voice Selection Configuration
**Important**: Available Azure Neural Voices (NOT OpenAI voices)

```javascript
const AZURE_VOICES = {
    female: {
        standard: "en-US-JennyNeural",     // Natural, conversational
        friendly: "en-US-AriaNeural",      // Friendly, warm
        professional: "en-US-AmberNeural"  // Clear, professional
    },
    male: {
        standard: "en-US-GuyNeural",       // Natural, conversational
        friendly: "en-US-DavisNeural",     // Warm, approachable
        professional: "en-US-TonyNeural"   // Clear, articulate
    }
};
```

#### Step 2.5: Update API Management
**Location**: Azure Portal → `apim-mba-001`

Add new API endpoint:
```
Path: /api/v1/voice-bartender
Method: POST
Description: Azure Speech Services voice interaction (NOT OpenAI)
Rate limits:
  - Free tier: 10 requests/day
  - Premium tier: 100 requests/day
  - Pro tier: unlimited
```

### Phase 3: Flutter Mobile Implementation

#### Step 3.1: Add Dependencies
**File**: `mobile/app/pubspec.yaml`

```yaml
dependencies:
  # Audio recording and playback
  record: ^5.0.0  # For recording user voice
  just_audio: ^0.9.35  # For playing Azure TTS response

  # Note: We are NOT using OpenAI voice SDKs
  # All voice processing happens via Azure Speech Services
```

#### Step 3.2: Create Voice Service
**New File**: `mobile/app/lib/src/services/voice_service.dart`

```dart
class VoiceService {
  // IMPORTANT: This service sends audio to Azure Speech Services
  // NOT to OpenAI Realtime API

  final String azureFunctionUrl = '/api/v1/voice-bartender';

  Future<VoiceResponse> processVoiceInput(Uint8List audioData) async {
    // Send to Azure Function which uses Azure Speech Services
    final response = await apiClient.post(
      azureFunctionUrl,
      body: audioData,
      headers: {'Content-Type': 'audio/wav'},
    );

    // Response contains:
    // - Azure TTS audio (not OpenAI)
    // - Transcript from Azure Speech-to-Text
    // - Text response from GPT-4o-mini
  }
}
```

#### Step 3.3: Voice Configuration Screen
**New File**: `mobile/app/lib/src/features/voice_bartender/voice_settings.dart`

```dart
// Allow users to choose Azure Neural voice
class VoiceSettings {
  static const Map<String, String> availableVoices = {
    'Jenny (Female, Natural)': 'en-US-JennyNeural',      // Azure voice
    'Guy (Male, Natural)': 'en-US-GuyNeural',            // Azure voice
    'Aria (Female, Friendly)': 'en-US-AriaNeural',      // Azure voice
    'Davis (Male, Friendly)': 'en-US-DavisNeural',      // Azure voice
    // Note: These are Azure voices, NOT OpenAI voices
  };
}
```

### Phase 4: Cost Management Implementation

#### Step 4.1: Usage Tracking
**File**: `backend/functions/voice-bartender/usage-tracker.js`

```javascript
// Track Azure Speech Services usage for cost management
class UsageTracker {
    // Azure Speech-to-Text: $1 per audio hour
    trackSpeechToText(durationSeconds) {
        const cost = (durationSeconds / 3600) * 1.00;
        // Log to Application Insights
    }

    // Azure Neural TTS: $16 per 1M characters
    trackTextToSpeech(characterCount) {
        const cost = (characterCount / 1000000) * 16.00;
        // Log to Application Insights
    }

    // NOT tracking OpenAI Realtime API (not used)
}
```

#### Step 4.2: Tier-based Limits
**File**: `backend/functions/voice-bartender/rate-limiter.js`

```javascript
const VOICE_LIMITS = {
    free: {
        dailyMinutes: 5,      // 5 minutes of Azure Speech per day
        message: "Free tier allows 5 minutes of voice interaction daily"
    },
    premium: {
        dailyMinutes: 60,     // 60 minutes of Azure Speech per day
        message: "Premium tier allows 60 minutes of voice interaction daily"
    },
    pro: {
        dailyMinutes: null,   // Unlimited Azure Speech usage
        message: "Pro tier includes unlimited voice interaction"
    }
};
```

### Phase 5: UI/UX Implementation

#### Step 5.1: Voice Technology Indicator
**File**: `mobile/app/lib/src/features/voice_bartender/voice_bartender_screen.dart`

Add indicator showing which service is being used:
```dart
Widget build(BuildContext context) {
  return Column(
    children: [
      // Technology indicator
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, size: 16),
            SizedBox(width: 4),
            Text(
              'Powered by Azure Speech Services',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      // Rest of UI...
    ],
  );
}
```

### Phase 6: Testing Voice Services

#### Step 6.1: Test Azure Speech Services
**File**: `backend/functions/test/test-azure-speech.js`

```javascript
// Test Azure Speech Services (NOT OpenAI)
const sdk = require("microsoft-cognitiveservices-speech-sdk");

async function testAzureSpeech() {
    console.log("Testing Azure Speech Services...");
    console.log("NOT testing OpenAI Realtime API (not used)");

    // Test Speech-to-Text
    const sttResult = await testSpeechToText();
    console.log("Azure STT Result:", sttResult);

    // Test Text-to-Speech
    const ttsResult = await testTextToSpeech("Testing Azure Neural voice");
    console.log("Azure TTS Result:", ttsResult);
}
```

### Phase 7: Documentation Updates

#### Step 7.1: Update CLAUDE.md
Add clarification about voice services:

```markdown
## Voice Interaction Architecture

**IMPORTANT**: This app uses Azure Speech Services, NOT OpenAI Realtime API

### Services Used:
- **Speech-to-Text**: Azure Cognitive Services Speech-to-Text
- **Text-to-Speech**: Azure Neural Text-to-Speech
- **AI Processing**: GPT-4o-mini (text only, no voice features)

### Why Azure Speech Services?
- Cost: 93% cheaper than OpenAI Realtime API
- Reliability: Microsoft Azure infrastructure
- Customization: Bartending vocabulary support
- Integration: Native Azure ecosystem
```

### Phase 8: Migration Considerations

#### Step 8.1: Future OpenAI Migration Path (Optional)
**File**: `OPENAI_VOICE_MIGRATION.md`

Document how to migrate to OpenAI Realtime API if needed in future:
```markdown
# Currently Using: Azure Speech Services
- Cost: ~$0.10 per 5-minute session
- Latency: ~500ms round trip
- Quality: High (Azure Neural voices)

# If Migrating to OpenAI Realtime API:
- Cost: ~$1.50 per 5-minute session (15x more expensive)
- Latency: ~200ms round trip (faster)
- Quality: Highest (OpenAI advanced voices)

# Migration would require:
1. Replace Azure Speech SDK with OpenAI SDK
2. Update backend functions
3. Modify cost tracking
4. Update tier limits (due to higher cost)
```

## Implementation Order

1. **Azure Speech Services Setup** (Phase 1)
   - Provision Speech Services resource
   - Configure Key Vault secrets
   - Test credentials

2. **Backend Implementation** (Phase 2)
   - Install Azure Speech SDK (NOT OpenAI SDK)
   - Create voice processing functions
   - Test with Azure Speech Services

3. **Flutter Integration** (Phase 3)
   - Add audio dependencies
   - Create voice service
   - Connect to Azure-powered backend

4. **Cost Management** (Phase 4)
   - Implement usage tracking
   - Set up tier limits
   - Monitor Azure Speech costs

5. **UI/UX Polish** (Phase 5)
   - Add voice selection
   - Show Azure Speech branding
   - Implement animations

## Configuration Values

### Required Azure Speech Services Configuration
```bash
# Azure Speech Services (NOT OpenAI)
AZURE_SPEECH_KEY=<from-key-vault>
AZURE_SPEECH_REGION=southcentralus
AZURE_SPEECH_ENDPOINT=https://southcentralus.api.cognitive.microsoft.com/

# GPT-4o-mini for text processing only
AZURE_OPENAI_API_KEY=<existing>
AZURE_OPENAI_ENDPOINT=<existing>
DEPLOYMENT_NAME=gpt-4o-mini

# NOT NEEDED (not using OpenAI voice):
# OPENAI_REALTIME_KEY=<not-used>
# OPENAI_VOICE_MODEL=<not-used>
```

### Audio Settings for Azure Speech Services
```
# Input (to Azure Speech-to-Text)
Recording format: WAV (16kHz, 16-bit, mono)
Max duration: 30 seconds
Chunk size: 4096 bytes

# Output (from Azure Neural TTS)
Playback format: MP3 or WAV
Voice: en-US-JennyNeural (default)
Speed: 1.0x
Pitch: 0 (normal)
```

## Cost Comparison Table

| Service | Component | Cost | 5-min Session |
|---------|-----------|------|---------------|
| **Azure Speech (USED)** | Speech-to-Text | $1/hour | $0.083 |
| | Neural TTS | $16/1M chars | $0.016 |
| | GPT-4o-mini | $0.15/1M tokens | $0.007 |
| | **Total** | | **$0.106** |
| **OpenAI Realtime (NOT USED)** | All-in-one | $0.06/min audio | **$1.50** |

## Success Criteria

1. ✅ Voice interaction uses Azure Speech Services (NOT OpenAI)
2. ✅ Cost per session < $0.15 (Azure pricing)
3. ✅ Custom bartending vocabulary works
4. ✅ Response time < 2 seconds
5. ✅ Clear indication that Azure Speech is being used
6. ✅ Usage tracking for cost management
7. ✅ Tier-based limits implemented
8. ✅ Works on Samsung Flip 6

## Important Notes for Sonnet

### ⚠️ CRITICAL: Voice Service Choice
- **USE**: Azure Speech Services (Speech-to-Text + Neural TTS)
- **DO NOT USE**: OpenAI Realtime API
- **WHY**: Cost optimization (93% savings)

### Implementation Guidelines
1. All voice processing goes through Azure Speech Services
2. GPT-4o-mini is used for text processing only (no voice features)
3. Show "Powered by Azure Speech Services" in UI
4. Track usage for cost management
5. Document that this is NOT using OpenAI voice

### Testing Focus
- Test with Azure Speech Services endpoints
- Verify custom vocabulary for bartending terms
- Monitor costs via Application Insights
- Ensure clear audio quality with Azure Neural voices

---

**Ready for Implementation**: This plan clearly specifies the use of Azure Speech Services (NOT OpenAI Realtime API) for all voice features. Cost optimization is the primary driver for this architectural decision.