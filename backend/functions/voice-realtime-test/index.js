/**
 * Voice Realtime Test Function
 *
 * Tests connectivity to Azure OpenAI Realtime API and ephemeral token generation.
 * This is a validation function to ensure the Realtime API is properly configured
 * before building the full voice feature.
 */

module.exports = async function (context, req) {
    context.log('Voice Realtime Test - Request received');

    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    };

    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
        context.res = { status: 200, headers, body: '' };
        return;
    }

    try {
        // Get configuration from environment (populated from Key Vault)
        const realtimeEndpoint = process.env.AZURE_OPENAI_REALTIME_ENDPOINT;
        const realtimeKey = process.env.AZURE_OPENAI_REALTIME_KEY;
        const realtimeDeployment = process.env.AZURE_OPENAI_REALTIME_DEPLOYMENT;

        // Validate configuration
        const configCheck = {
            endpoint: !!realtimeEndpoint,
            key: !!realtimeKey,
            deployment: !!realtimeDeployment
        };

        if (!realtimeEndpoint || !realtimeKey || !realtimeDeployment) {
            context.log.error('Missing Realtime API configuration:', configCheck);
            context.res = {
                status: 500,
                headers,
                body: {
                    success: false,
                    error: 'Missing configuration',
                    configCheck,
                    message: 'One or more Realtime API settings are not configured. Check Key Vault references.'
                }
            };
            return;
        }

        context.log('Configuration validated. Attempting ephemeral token request...');
        context.log('Endpoint:', realtimeEndpoint);
        context.log('Deployment:', realtimeDeployment);

        // Build the sessions URL for ephemeral token
        // Format: POST https://{endpoint}/openai/realtimeapi/sessions?api-version=2025-04-01-preview
        const sessionsUrl = `${realtimeEndpoint}/openai/realtimeapi/sessions?api-version=2025-04-01-preview`;

        context.log('Sessions URL:', sessionsUrl);

        // Session configuration for the ephemeral token request
        const sessionConfig = {
            model: realtimeDeployment,
            voice: 'alloy',
            instructions: 'You are a helpful AI bartender assistant.',
            input_audio_transcription: {
                model: 'whisper-1'
            },
            turn_detection: {
                type: 'server_vad',
                threshold: 0.5,
                prefix_padding_ms: 300,
                silence_duration_ms: 500
            }
        };

        // Request ephemeral token
        const response = await fetch(sessionsUrl, {
            method: 'POST',
            headers: {
                'api-key': realtimeKey,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(sessionConfig)
        });

        const responseText = await response.text();
        context.log('Response status:', response.status);
        context.log('Response body:', responseText.substring(0, 500)); // Log first 500 chars

        if (!response.ok) {
            context.log.error('Ephemeral token request failed');
            context.res = {
                status: response.status,
                headers,
                body: {
                    success: false,
                    error: 'Ephemeral token request failed',
                    httpStatus: response.status,
                    details: responseText,
                    sessionsUrl: sessionsUrl.replace(realtimeKey, '***')
                }
            };
            return;
        }

        // Parse successful response
        const sessionData = JSON.parse(responseText);

        // The WebRTC URL for East US2
        const webrtcUrl = 'https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc';

        context.res = {
            status: 200,
            headers,
            body: {
                success: true,
                message: 'Realtime API connection validated successfully!',
                session: {
                    id: sessionData.id,
                    model: sessionData.model,
                    voice: sessionData.voice,
                    hasClientSecret: !!sessionData.client_secret,
                    expiresAt: sessionData.client_secret?.expires_at
                },
                webrtcUrl,
                note: 'Ephemeral token generated successfully. The token is valid for ~60 seconds and can be used for WebRTC connection.'
            }
        };

    } catch (error) {
        context.log.error('Exception in voice-realtime-test:', error.message);
        context.log.error('Stack:', error.stack);

        context.res = {
            status: 500,
            headers,
            body: {
                success: false,
                error: 'Exception occurred',
                message: error.message,
                stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
            }
        };
    }
};
