// Handler-level tests for the Voice AI realtime endpoints (GA Realtime API).
// Only the external edges are stubbed: Azure OpenAI (fetch), PostgreSQL and the user lookup.

const mockHandlers = {};
jest.mock('@azure/functions', () => ({
    app: {
        http: (name, options) => { mockHandlers[name] = options.handler; },
        timer: () => {}
    }
}));
jest.mock('./services/userService', () => ({ getOrCreateUser: jest.fn() }));
jest.mock('./shared/database', () => ({ query: jest.fn() }));

const db = require('./shared/database');
const { getOrCreateUser } = require('./services/userService');
const { FAKE_CLIENT_SECRET, gaClientSecretResponse } = require('./test/fixtures/realtime-ga');
require('./index');

const ENDPOINT = 'https://res-eastus2.cognitiveservices.azure.com';
const originalEnv = { ...process.env };
const originalFetch = global.fetch;

function mockAzure(responseBody, { ok = true, status = 200 } = {}) {
    global.fetch = jest.fn(async () => ({
        ok,
        status,
        json: async () => responseBody,
        text: async () => JSON.stringify(responseBody)
    }));
}

function sentClientSecretRequest() {
    return JSON.parse(global.fetch.mock.calls[0][1].body);
}

function voiceSessionInserts() {
    return db.query.mock.calls.filter(([sql]) => sql.includes('INSERT INTO voice_sessions'));
}

function sessionRequest(body) {
    return {
        method: 'POST',
        headers: new Headers({ 'x-user-id': 'entra-sub-123' }),
        json: async () => body
    };
}

function invocationContext() {
    return { log: jest.fn(), error: jest.fn(), warn: jest.fn() };
}

const startSession = (body, context = invocationContext()) =>
    mockHandlers['voice-session'](sessionRequest(body), context);

beforeEach(() => {
    process.env = {
        ...originalEnv,
        AZURE_OPENAI_REALTIME_ENDPOINT: ENDPOINT,
        AZURE_OPENAI_REALTIME_KEY: 'test-realtime-key',
        AZURE_OPENAI_REALTIME_DEPLOYMENT: 'gpt-realtime-mini'
    };
    delete process.env.VOICE_LEGACY_CLIENT_MODE;
    delete process.env.AZURE_OPENAI_REALTIME_TRANSCRIPTION_MODEL;

    getOrCreateUser.mockReset().mockResolvedValue({ id: 'user-1', entitlement: 'paid', tier: 'pro' });
    db.query.mockReset().mockImplementation(async (sql) => {
        if (sql.includes('get_remaining_voice_minutes')) {
            return { rows: [{ total_remaining: '42.5', included_remaining: '40', purchased_remaining: '2.5', monthly_included: 60, used_this_cycle: '17.5' }] };
        }
        if (sql.includes('close_user_stale_sessions')) return { rows: [{ close_user_stale_sessions: 0 }] };
        if (sql.includes('INSERT INTO voice_sessions')) return { rows: [{ id: 'db-session-1' }] };
        if (sql.includes('FROM voice_sessions')) return { rows: [] }; // no other active session
        throw new Error(`Unexpected query: ${sql}`);
    });
});

afterAll(() => {
    process.env = originalEnv;
    global.fetch = originalFetch;
});

describe('voice-session (POST /v1/voice/session)', () => {
    test('v1.2.2+ app: asks the GA endpoint for a push-to-talk client secret carrying the bar inventory', async () => {
        mockAzure(gaClientSecretResponse());

        await startSession({ realtimeProtocol: 'ga', inventory: { spirits: ['Gin', 'Campari'], mixers: [] } });

        expect(global.fetch).toHaveBeenCalledTimes(1);
        const [url, init] = global.fetch.mock.calls[0];
        expect(url).toBe(`${ENDPOINT}/openai/v1/realtime/client_secrets`);
        expect(init.headers['api-key']).toBe('test-realtime-key');
        const sent = sentClientSecretRequest();
        expect(sent.session.type).toBe('realtime');
        expect(sent.session.model).toBe('gpt-realtime-mini');
        expect(sent.session.audio.input.turn_detection.create_response).toBe(false);
        expect(sent.session.instructions).toContain('Spirits: Gin, Campari');
    });

    test('v1.2.2+ app: returns the response contract the app reads and stores the GA session id', async () => {
        mockAzure(gaClientSecretResponse());

        const response = await startSession({ realtimeProtocol: 'ga' });

        expect(response.status).toBe(200);
        expect(response.jsonBody).toEqual({
            success: true,
            session: {
                dbSessionId: 'db-session-1',
                realtimeSessionId: 'sess_Ea7u3srFAV3GIGvZXM42D',
                model: 'gpt-realtime-mini',
                voice: 'alloy'
            },
            token: { value: FAKE_CLIENT_SECRET, expiresAt: 1792280000 },
            webrtcUrl: `${ENDPOINT}/openai/v1/realtime/calls`,
            quota: {
                remainingMinutes: 42.5,
                includedRemaining: 40,
                purchasedRemaining: 2.5,
                monthlyIncluded: 60,
                usedThisCycle: 17.5,
                warningThresholdMinutes: 6
            }
        });
        expect(voiceSessionInserts().map(([, params]) => params)).toEqual([['user-1', 'sess_Ea7u3srFAV3GIGvZXM42D']]);
    });

    test('store build: compat session with server-created replies on the filtered WebRTC channel', async () => {
        mockAzure(gaClientSecretResponse());

        const response = await startSession({ inventory: { spirits: ['Gin'], mixers: [] } });

        expect(sentClientSecretRequest().session.audio.input.turn_detection)
            .toMatchObject({ type: 'server_vad', create_response: true, interrupt_response: false });
        expect(response.jsonBody.webrtcUrl).toBe(`${ENDPOINT}/openai/v1/realtime/calls?webrtcfilter=on`);
    });

    test('store build with VOICE_LEGACY_CLIENT_MODE=update_required: update message, no Azure call, no session row', async () => {
        process.env.VOICE_LEGACY_CLIENT_MODE = 'update_required';
        mockAzure(gaClientSecretResponse());

        const response = await startSession({ inventory: { spirits: ['Gin'], mixers: [] } });

        expect(response.status).toBe(426);
        expect(response.jsonBody).toMatchObject({ success: false, error: 'update_required' });
        expect(response.jsonBody.message).toEqual(expect.stringMatching(/update/i)); // shown verbatim by store builds
        expect(global.fetch).not.toHaveBeenCalled();
        expect(voiceSessionInserts()).toEqual([]);
    });

    test('GA response without a client secret: token_error and no session row', async () => {
        mockAzure({ expires_at: 1792280000, session: { type: 'realtime', id: 'sess_no_secret' } });

        const response = await startSession({ realtimeProtocol: 'ga' });

        expect(response.status).toBe(500);
        expect(response.jsonBody).toMatchObject({ success: false, error: 'token_error' });
        expect(voiceSessionInserts()).toEqual([]);
    });

    test('transcription model comes from AZURE_OPENAI_REALTIME_TRANSCRIPTION_MODEL when set', async () => {
        process.env.AZURE_OPENAI_REALTIME_TRANSCRIPTION_MODEL = 'gpt-4o-mini-transcribe';
        mockAzure(gaClientSecretResponse());

        await startSession({ realtimeProtocol: 'ga' });

        expect(sentClientSecretRequest().session.audio.input.transcription).toEqual({ model: 'gpt-4o-mini-transcribe' });
    });
});

describe('voice-realtime-test (GET /v1/voice/test, function key)', () => {
    const runDiagnostic = (query, context) => mockHandlers['voice-realtime-test'](
        { method: 'GET', headers: new Headers(), query: new URLSearchParams(query) },
        context
    );

    test('mints a GA client secret and never writes it to the logs', async () => {
        mockAzure(gaClientSecretResponse());
        const context = invocationContext();

        const response = await runDiagnostic('', context);

        expect(global.fetch.mock.calls[0][0]).toBe(`${ENDPOINT}/openai/v1/realtime/client_secrets`);
        expect(response.status).toBe(200);
        expect(response.jsonBody).toMatchObject({
            success: true,
            session: { id: 'sess_Ea7u3srFAV3GIGvZXM42D', hasClientSecret: true, expiresAt: 1792280000 },
            webrtcUrl: `${ENDPOINT}/openai/v1/realtime/calls`
        });
        const everythingLogged = JSON.stringify([...context.log.mock.calls, ...context.error.mock.calls]);
        expect(everythingLogged).not.toContain(FAKE_CLIENT_SECRET);
    });

    test('?mode=compat exercises the store-build configuration', async () => {
        mockAzure(gaClientSecretResponse());

        const response = await runDiagnostic('mode=compat', invocationContext());

        expect(sentClientSecretRequest().session.audio.input.turn_detection.type).toBe('server_vad');
        expect(response.jsonBody.webrtcUrl).toBe(`${ENDPOINT}/openai/v1/realtime/calls?webrtcfilter=on`);
    });
});
