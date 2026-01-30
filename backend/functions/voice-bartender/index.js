// Voice Bartender Function - Uses AZURE SPEECH SERVICES (NOT OpenAI Realtime API)
// Cost-optimized implementation: ~$0.10 per 5-minute session vs $1.50 for OpenAI
// PRO TIER ONLY - Voice AI is a premium feature

const sdk = require('microsoft-cognitiveservices-speech-sdk');
const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');
const { authenticateRequest, AuthenticationError } = require('../shared/auth/jwtMiddleware');
const { getOrCreateUser, getTierQuotas, hasFeatureAccess } = require('../services/userService');

module.exports = async function (context, req) {
    context.log('Voice Bartender - Request received');
    context.log('IMPORTANT: Using Azure Speech Services (NOT OpenAI Realtime API)');

    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, Ocp-Apim-Subscription-Key',
    };

    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
        context.res = {
            status: 200,
            headers: headers,
            body: ''
        };
        return;
    }

    let userId = null;
    let userTier = 'free';

    try {
        // ========================================
        // STEP 1: JWT Authentication
        // ========================================
        context.log('[Auth] Validating JWT token...');

        let authResult;
        try {
            authResult = await authenticateRequest(req, context);
            userId = authResult.sub;
            context.log(`[Auth] Token validated. User: ${userId.substring(0, 8)}...`);
        } catch (authError) {
            if (authError instanceof AuthenticationError) {
                context.log.error(`[Auth] Authentication failed: ${authError.message}`);
                context.res = {
                    status: authError.status || 401,
                    headers: {
                        ...headers,
                        'WWW-Authenticate': 'Bearer realm="mybartenderai", error="invalid_token"'
                    },
                    body: {
                        error: 'Authentication required',
                        message: authError.message,
                        code: authError.code
                    }
                };
                return;
            }
            throw authError;
        }

        // ========================================
        // STEP 2: Get/Create User & Check Pro Tier
        // ========================================
        context.log('[User] Looking up user in database...');

        // Read APIM-forwarded profile headers from JWT claims
        const userEmail = req.headers?.['x-user-email'] || null;
        const userName = req.headers?.['x-user-name'] || null;

        const user = await getOrCreateUser(userId, context, {
            email: userEmail,
            displayName: userName
        });
        userTier = user.tier;
        context.log(`[User] User ID: ${user.id}, Tier: ${userTier}`);

        // Voice AI is PRO tier only
        if (!hasFeatureAccess(userTier, 'voice')) {
            context.log.warn(`[Auth] User tier ${userTier} does not have voice access`);
            context.res = {
                status: 403,
                headers,
                body: {
                    error: 'Pro subscription required',
                    message: 'Voice AI is available exclusively for Pro subscribers. Please upgrade your subscription to access this feature.',
                    tier: userTier,
                    requiredTier: 'pro'
                }
            };
            return;
        }

        context.log('[Auth] Pro tier verified - voice access granted');
        // Check for required Azure Speech Services configuration
        const speechKey = process.env.AZURE_SPEECH_KEY;
        const speechRegion = process.env.AZURE_SPEECH_REGION;
        const openaiKey = process.env.OPENAI_API_KEY;

        if (!speechKey || !speechRegion) {
            context.log.error('Azure Speech Services not configured');
            context.res = {
                status: 500,
                headers: headers,
                body: {
                    error: 'Azure Speech Services not configured',
                    message: 'The server is missing Azure Speech configuration. Please contact support.'
                }
            };
            return;
        }

        if (!openaiKey) {
            context.log.error('OpenAI API key not found');
            context.res = {
                status: 500,
                headers: headers,
                body: {
                    error: 'OpenAI API key not configured',
                    message: 'The server is not properly configured. Please contact support.'
                }
            };
            return;
        }

        // Parse request body
        const body = req.body || {};
        const audioBase64 = body.audioData; // Base64 encoded audio from mobile app
        const voicePreference = body.voicePreference || 'en-US-JennyNeural'; // Azure Neural voice
        const conversationContext = body.context || {};

        if (!audioBase64) {
            context.res = {
                status: 400,
                headers: headers,
                body: {
                    error: 'Missing audio data',
                    message: 'No audio data provided in request'
                }
            };
            return;
        }

        context.log('Processing voice request with Azure Speech Services');
        context.log('Selected Azure Neural voice:', voicePreference);

        // Step 1: Convert speech to text using Azure Speech-to-Text (NOT OpenAI)
        context.log('Step 1: Azure Speech-to-Text conversion');
        const audioBuffer = Buffer.from(audioBase64, 'base64');
        const transcript = await convertSpeechToText(context, audioBuffer, speechKey, speechRegion);
        context.log('Transcript:', transcript);

        // Step 2: Process with GPT-4o-mini (text only, no voice features)
        context.log('Step 2: GPT-4o-mini text processing (NOT voice processing)');
        const aiResponse = await processWithGPT(context, transcript, conversationContext, openaiKey);
        context.log('AI response generated');

        // Step 3: Convert response to speech using Azure Neural TTS (NOT OpenAI voice)
        context.log('Step 3: Azure Neural Text-to-Speech conversion');
        const audioResponse = await convertTextToSpeech(context, aiResponse.text, speechKey, speechRegion, voicePreference);
        context.log('Audio response generated');

        // Track usage for cost management
        const usage = {
            speechToTextDuration: audioBuffer.length / 32000, // Approximate duration in seconds (16kHz, 16-bit = 32000 bytes/sec)
            textToSpeechCharacters: aiResponse.text.length,
            gptTokens: aiResponse.usage.totalTokens,
            estimatedCost: calculateCost(audioBuffer.length, aiResponse.text.length, aiResponse.usage.totalTokens)
        };

        context.log('Usage stats:', usage);

        // Return response
        context.res = {
            status: 200,
            headers: headers,
            body: {
                audioData: audioResponse, // Base64 encoded audio
                transcript: transcript,
                textResponse: aiResponse.text,
                conversationId: aiResponse.conversationId,
                usage: usage,
                technology: 'Azure Speech Services', // Explicitly indicate NOT OpenAI
                voiceUsed: voicePreference,
                user: {
                    tier: userTier
                }
            }
        };

    } catch (error) {
        context.log.error('Error in voice-bartender:', error.message);
        context.log.error('Stack trace:', error.stack);

        context.res = {
            status: 500,
            headers: headers,
            body: {
                error: 'Internal server error',
                message: error.message,
                details: process.env.NODE_ENV === 'development' ? error.stack : undefined
            }
        };
    }
};

// Azure Speech-to-Text (NOT OpenAI)
async function convertSpeechToText(context, audioBuffer, speechKey, speechRegion) {
    return new Promise((resolve, reject) => {
        try {
            const speechConfig = sdk.SpeechConfig.fromSubscription(speechKey, speechRegion);
            speechConfig.speechRecognitionLanguage = 'en-US';

            // Create audio config from buffer
            const pushStream = sdk.AudioInputStream.createPushStream();
            pushStream.write(audioBuffer);
            pushStream.close();

            const audioConfig = sdk.AudioConfig.fromStreamInput(pushStream);
            const recognizer = new sdk.SpeechRecognizer(speechConfig, audioConfig);

            // Add custom bartending vocabulary for better recognition
            const phraseList = sdk.PhraseListGrammar.fromRecognizer(recognizer);
            phraseList.addPhrase('Margarita');
            phraseList.addPhrase('Mojito');
            phraseList.addPhrase('Manhattan');
            phraseList.addPhrase('Old Fashioned');
            phraseList.addPhrase('Negroni');
            phraseList.addPhrase('Martini');
            phraseList.addPhrase('Daiquiri');
            phraseList.addPhrase('Whiskey Sour');
            phraseList.addPhrase('Angostura bitters');
            phraseList.addPhrase('muddle');
            phraseList.addPhrase('shake with ice');
            phraseList.addPhrase('strain into glass');

            recognizer.recognizeOnceAsync(
                result => {
                    if (result.reason === sdk.ResultReason.RecognizedSpeech) {
                        context.log('Azure STT Success:', result.text);
                        recognizer.close();
                        resolve(result.text);
                    } else {
                        const errorMessage = `Azure STT failed: ${sdk.ResultReason[result.reason]}`;
                        context.log.error(errorMessage);
                        recognizer.close();
                        reject(new Error(errorMessage));
                    }
                },
                error => {
                    context.log.error('Azure STT error:', error);
                    recognizer.close();
                    reject(error);
                }
            );
        } catch (error) {
            context.log.error('Exception in convertSpeechToText:', error);
            reject(error);
        }
    });
}

// Process with GPT-4o-mini (text only, NOT voice)
async function processWithGPT(context, message, conversationContext, openaiKey) {
    const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
    const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

    const client = new OpenAIClient(
        azureEndpoint,
        new AzureKeyCredential(openaiKey)
    );

    // Build system prompt
    let systemPrompt = 'You are a sophisticated AI bartender for MyBartenderAI voice interaction. ' +
                      'Be helpful, friendly, conversational, and knowledgeable about cocktails. ' +
                      'Keep responses concise and natural for voice conversation (2-3 sentences max unless recipe details requested).';

    if (conversationContext.inventory) {
        const spirits = conversationContext.inventory.spirits || [];
        const mixers = conversationContext.inventory.mixers || [];
        const allIngredients = [...spirits, ...mixers];

        if (allIngredients.length > 0) {
            systemPrompt += '\n\nThe user has these ingredients: ';
            if (spirits.length > 0) {
                systemPrompt += 'Spirits: ' + spirits.join(', ') + '. ';
            }
            if (mixers.length > 0) {
                systemPrompt += 'Mixers: ' + mixers.join(', ') + '. ';
            }
            systemPrompt += 'Suggest cocktails using their available ingredients.';
        }
    }

    const messages = [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: message }
    ];

    const result = await client.getChatCompletions(deployment, messages, {
        temperature: 0.7,
        maxTokens: 300
    });

    const responseText = result.choices[0]?.message?.content || 'I apologize, but I could not process your request.';
    const conversationId = conversationContext.conversationId || `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    return {
        text: responseText,
        conversationId: conversationId,
        usage: {
            promptTokens: result.usage?.promptTokens || 0,
            completionTokens: result.usage?.completionTokens || 0,
            totalTokens: result.usage?.totalTokens || 0,
        }
    };
}

// Azure Neural Text-to-Speech (NOT OpenAI voice)
async function convertTextToSpeech(context, text, speechKey, speechRegion, voiceName) {
    return new Promise((resolve, reject) => {
        try {
            const speechConfig = sdk.SpeechConfig.fromSubscription(speechKey, speechRegion);

            // Use Azure Neural voice (NOT OpenAI voice)
            speechConfig.speechSynthesisVoiceName = voiceName;
            speechConfig.speechSynthesisOutputFormat = sdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoMp3;

            const synthesizer = new sdk.SpeechSynthesizer(speechConfig, null);

            synthesizer.speakTextAsync(
                text,
                result => {
                    if (result.reason === sdk.ResultReason.SynthesizingAudioCompleted) {
                        context.log('Azure TTS Success');
                        const audioBase64 = Buffer.from(result.audioData).toString('base64');
                        synthesizer.close();
                        resolve(audioBase64);
                    } else {
                        const errorMessage = `Azure TTS failed: ${sdk.ResultReason[result.reason]}`;
                        context.log.error(errorMessage);
                        synthesizer.close();
                        reject(new Error(errorMessage));
                    }
                },
                error => {
                    context.log.error('Azure TTS error:', error);
                    synthesizer.close();
                    reject(error);
                }
            );
        } catch (error) {
            context.log.error('Exception in convertTextToSpeech:', error);
            reject(error);
        }
    });
}

// Calculate estimated cost for Azure Speech Services
function calculateCost(audioBytes, textChars, gptTokens) {
    // Azure Speech-to-Text: $1 per audio hour
    const audioDurationSeconds = audioBytes / 32000; // 16kHz, 16-bit = 32000 bytes/sec
    const sttCost = (audioDurationSeconds / 3600) * 1.00;

    // Azure Neural TTS: $16 per 1M characters
    const ttsCost = (textChars / 1000000) * 16.00;

    // GPT-4o-mini: $0.15 per 1M input tokens, $0.60 per 1M output tokens (approximation)
    const gptCost = (gptTokens / 1000000) * 0.30; // Average cost

    const totalCost = sttCost + ttsCost + gptCost;

    return {
        speechToText: sttCost,
        textToSpeech: ttsCost,
        gptProcessing: gptCost,
        total: totalCost,
        currency: 'USD'
    };
}
