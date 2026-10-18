// =============================================================================
// Azure OpenAI Realtime API (GA) helpers for Voice AI
//
// Azure retired the Preview protocol (/openai/realtimeapi/sessions and the
// regional realtimeapi-preview WebRTC host) in 2026; requests now fail with
// 400 realtime_beta_access_required. GA uses:
//   POST {endpoint}/openai/v1/realtime/client_secrets  -> ephemeral key
//   POST {endpoint}/openai/v1/realtime/calls           -> WebRTC SDP offer/answer
// =============================================================================
const crypto = require('crypto');

// App versions that speak the GA protocol send { realtimeProtocol: 'ga' } in the
// POST /v1/voice/session body (v1.2.2+). Store builds <= v1.2.1 send nothing.
const GA_PROTOCOL = 'ga';

// Push-to-talk: the app commits audio and sends response.create itself when the
// user releases the button, so the server must not create replies on its own.
const PUSH_TO_TALK_TURN_DETECTION = {
    type: 'semantic_vad',
    eagerness: 'low',
    create_response: false,
    interrupt_response: false
};

// Store builds <= v1.2.1 send a Preview-shaped session.update that GA rejects with
// an error event, which puts the app into its error state. Their WebRTC URL gets
// ?webrtcfilter=on to hide that error, but the filter also hides response.done,
// which those builds need before they send the next response.create. So the
// server creates each reply when the user stops talking.
const LEGACY_COMPAT_TURN_DETECTION = {
    type: 'server_vad',
    threshold: 0.5,
    prefix_padding_ms: 300,
    silence_duration_ms: 700,
    create_response: true,
    interrupt_response: false
};

/**
 * Decide how to serve this client:
 *  'ga'              - v1.2.2+ app (push-to-talk, full event stream)
 *  'compat'          - store build <= v1.2.1, best-effort GA compatibility (default)
 *  'update_required' - store build <= v1.2.1, VOICE_LEGACY_CLIENT_MODE=update_required
 */
function resolveClientMode(body, legacyModeSetting) {
    if (body?.realtimeProtocol === GA_PROTOCOL) {
        return 'ga';
    }
    const legacyMode = (legacyModeSetting || '').trim().toLowerCase();
    return legacyMode === 'update_required' ? 'update_required' : 'compat';
}

function realtimeBaseUrl(endpoint) {
    return `${endpoint.replace(/\/+$/, '')}/openai/v1/realtime`;
}

function clientSecretsUrl(endpoint) {
    return `${realtimeBaseUrl(endpoint)}/client_secrets`;
}

function webrtcCallsUrl(endpoint, clientMode) {
    const url = `${realtimeBaseUrl(endpoint)}/calls`;
    return clientMode === 'ga' ? url : `${url}?webrtcfilter=on`;
}

function buildClientSecretRequest({ deployment, instructions, clientMode, transcriptionModel }) {
    const turnDetection = clientMode === 'ga' ? PUSH_TO_TALK_TURN_DETECTION : LEGACY_COMPAT_TURN_DETECTION;

    return {
        // Ephemeral keys only need to live long enough to start the WebRTC call
        // (Preview keys lasted ~60s; the GA default is 600s).
        expires_after: { anchor: 'created_at', seconds: 60 },
        session: {
            type: 'realtime',
            model: deployment,
            instructions,
            audio: {
                input: {
                    // Azure accepts any name here at token time; whether transcription
                    // works only shows at runtime (user transcript events).
                    transcription: { model: transcriptionModel || 'whisper-1' },
                    turn_detection: { ...turnDetection },
                    noise_reduction: { type: 'far_field' } // Phone speaker/mic
                },
                output: { voice: 'alloy' }
            }
        }
    };
}

/**
 * Map a GA client_secrets response onto the fields the app reads. Returns null
 * when there is no usable ephemeral key. The app force-unwraps the session id and
 * expects non-null model/voice, and voice_sessions.session_id is NOT NULL, so the
 * optional session fields always get a value.
 */
function mapClientSecretResponse(data, { deployment, generateId = () => `rt_${crypto.randomUUID()}` }) {
    if (!data?.value) {
        return null;
    }
    return {
        realtimeSessionId: data.session?.id || generateId(),
        model: data.session?.model || deployment,
        voice: data.session?.audio?.output?.voice || 'alloy',
        token: { value: data.value, expiresAt: data.expires_at }
    };
}

module.exports = {
    resolveClientMode,
    clientSecretsUrl,
    webrtcCallsUrl,
    buildClientSecretRequest,
    mapClientSecretResponse
};
