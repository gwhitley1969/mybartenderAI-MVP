const {
    resolveClientMode,
    clientSecretsUrl,
    webrtcCallsUrl,
    buildClientSecretRequest,
    mapClientSecretResponse
} = require('./realtime-ga');
const { FAKE_CLIENT_SECRET, gaClientSecretResponse } = require('../test/fixtures/realtime-ga');

describe('resolveClientMode', () => {
    test.each([
        ['v1.2.2+ app', { realtimeProtocol: 'ga' }, undefined, 'ga'],
        ['v1.2.2+ app ignores the legacy switch', { realtimeProtocol: 'ga' }, 'update_required', 'ga'],
        ['store build, switch unset', { inventory: { spirits: ['Gin'] } }, undefined, 'compat'],
        ['store build, no body', null, '', 'compat'],
        ['store build, unknown protocol value', { realtimeProtocol: 'preview' }, 'compat', 'compat'],
        ['store build, switch set to update_required', {}, 'update_required', 'update_required'],
        ['store build, switch with stray case/spaces', {}, ' Update_Required ', 'update_required'],
        ['store build, unrecognised switch value', {}, 'off', 'compat']
    ])('%s', (_label, body, legacySetting, expected) => {
        expect(resolveClientMode(body, legacySetting)).toBe(expected);
    });
});

describe('clientSecretsUrl', () => {
    test.each([
        ['https://res.cognitiveservices.azure.com', 'https://res.cognitiveservices.azure.com/openai/v1/realtime/client_secrets'],
        ['https://res.openai.azure.com/', 'https://res.openai.azure.com/openai/v1/realtime/client_secrets']
    ])('%s', (endpoint, expected) => {
        expect(clientSecretsUrl(endpoint)).toBe(expected);
    });
});

describe('webrtcCallsUrl', () => {
    test.each([
        ['GA app gets every event', 'https://res.cognitiveservices.azure.com', 'ga',
            'https://res.cognitiveservices.azure.com/openai/v1/realtime/calls'],
        ['store build gets the filtered channel', 'https://res.cognitiveservices.azure.com/', 'compat',
            'https://res.cognitiveservices.azure.com/openai/v1/realtime/calls?webrtcfilter=on']
    ])('%s', (_label, endpoint, clientMode, expected) => {
        expect(webrtcCallsUrl(endpoint, clientMode)).toBe(expected);
    });
});

describe('buildClientSecretRequest', () => {
    test('GA app: push-to-talk session (no server-created replies)', () => {
        expect(buildClientSecretRequest({
            deployment: 'gpt-realtime-mini',
            instructions: 'You are a bartender.',
            clientMode: 'ga'
        })).toEqual({
            expires_after: { anchor: 'created_at', seconds: 60 },
            session: {
                type: 'realtime',
                model: 'gpt-realtime-mini',
                instructions: 'You are a bartender.',
                audio: {
                    input: {
                        transcription: { model: 'whisper-1' },
                        turn_detection: {
                            type: 'semantic_vad',
                            eagerness: 'low',
                            create_response: false,
                            interrupt_response: false
                        },
                        noise_reduction: { type: 'far_field' }
                    },
                    output: { voice: 'alloy' }
                }
            }
        });
    });

    test('store build: server creates each reply when the user stops talking', () => {
        const request = buildClientSecretRequest({
            deployment: 'gpt-realtime-mini',
            instructions: 'You are a bartender.',
            clientMode: 'compat'
        });

        expect(request.session.audio.input.turn_detection).toEqual({
            type: 'server_vad',
            threshold: 0.5,
            prefix_padding_ms: 300,
            silence_duration_ms: 700,
            create_response: true,
            interrupt_response: false
        });
        expect(request.session.instructions).toBe('You are a bartender.');
        expect(request.session.audio.output).toEqual({ voice: 'alloy' });
        expect(request.session.audio.input.noise_reduction).toEqual({ type: 'far_field' });
    });

    test.each([
        ['defaults to whisper-1', undefined, 'whisper-1'],
        ['blank app setting falls back to whisper-1', '', 'whisper-1'],
        ['uses the configured deployment', 'gpt-4o-mini-transcribe', 'gpt-4o-mini-transcribe']
    ])('transcription model: %s', (_label, transcriptionModel, expected) => {
        const request = buildClientSecretRequest({
            deployment: 'gpt-realtime-mini',
            instructions: 'x',
            clientMode: 'ga',
            transcriptionModel
        });
        expect(request.session.audio.input.transcription).toEqual({ model: expected });
    });
});

describe('mapClientSecretResponse', () => {
    const generateId = () => 'rt_generated';

    test('maps the GA response onto the fields the app reads', () => {
        expect(mapClientSecretResponse(gaClientSecretResponse(), { deployment: 'gpt-realtime-mini', generateId }))
            .toEqual({
                realtimeSessionId: 'sess_Ea7u3srFAV3GIGvZXM42D',
                model: 'gpt-realtime-mini',
                voice: 'alloy',
                token: { value: FAKE_CLIENT_SECRET, expiresAt: 1792280000 }
            });
    });

    test('fills optional session fields so the app and voice_sessions never get null', () => {
        const sparse = { value: 'ek_test_sparse', expires_at: 1792280000, session: { type: 'realtime' } };

        expect(mapClientSecretResponse(sparse, { deployment: 'gpt-realtime-mini', generateId }))
            .toEqual({
                realtimeSessionId: 'rt_generated',
                model: 'gpt-realtime-mini',
                voice: 'alloy',
                token: { value: 'ek_test_sparse', expiresAt: 1792280000 }
            });
    });

    test('generates a session id that fits voice_sessions.session_id by default', () => {
        const sparse = { value: 'ek_test_sparse', expires_at: 1792280000, session: { type: 'realtime' } };

        const { realtimeSessionId } = mapClientSecretResponse(sparse, { deployment: 'gpt-realtime-mini' });

        expect(realtimeSessionId).toMatch(/^rt_[0-9a-f-]{36}$/);
    });

    test.each([
        ['no client secret value', { expires_at: 1792280000, session: { id: 'sess_x', type: 'realtime' } }],
        ['Preview-shaped response', { id: 'sess_x', client_secret: { value: 'ek_old', expires_at: 1792280000 } }],
        ['empty body', null]
    ])('returns null when there is no usable token: %s', (_label, data) => {
        expect(mapClientSecretResponse(data, { deployment: 'gpt-realtime-mini', generateId })).toBeNull();
    });
});
