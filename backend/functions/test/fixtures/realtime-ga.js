// Test fixtures for the Azure OpenAI Realtime API (GA).

// The value is fake; real client secrets never belong in source.
const FAKE_CLIENT_SECRET = 'ek_test_0123456789abcdef012345678';

// Mirrors a real POST /openai/v1/realtime/client_secrets response (smoke test, 2026-10-17).
function gaClientSecretResponse() {
    return {
        value: FAKE_CLIENT_SECRET,
        expires_at: 1792280000,
        session: {
            type: 'realtime',
            object: 'realtime.session',
            id: 'sess_Ea7u3srFAV3GIGvZXM42D',
            model: 'gpt-realtime-mini',
            output_modalities: ['audio'],
            instructions: 'You are a bartender.',
            tools: [],
            tool_choice: 'auto',
            max_output_tokens: 'inf',
            tracing: null,
            truncation: 'auto',
            prompt: null,
            expires_at: 0,
            audio: {
                input: {
                    format: { type: 'audio/pcm', rate: 24000 },
                    transcription: { model: 'whisper-1', language: null, prompt: null },
                    noise_reduction: { type: 'far_field' },
                    turn_detection: { type: 'semantic_vad', eagerness: 'low', create_response: false, interrupt_response: false }
                },
                output: { format: { type: 'audio/pcm', rate: 24000 }, voice: 'alloy', speed: 1 }
            },
            include: null
        }
    };
}

module.exports = { FAKE_CLIENT_SECRET, gaClientSecretResponse };
