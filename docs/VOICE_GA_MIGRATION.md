# Voice AI Outage: Move to the GA Realtime API (v1.2.2 hotfix)

Handoff brief for Claude Code working in this repo (`mybartenderAI-MVP`).
Prepared 2026-10-17 by Claude (claude.ai) with Gene, from a read-only pass over this code and Microsoft's documentation.
**Priority: urgent.** Ship this before `docs/CONVERSION_PLAN.md`; its demo video needs working voice.

> **Outcome (2026-10-18).** Steps 1-3 are done, Step 4's code is done, and the app release is pending. Code: PR #2 (`fix/voice-ga-realtime-api`). Details: `docs/DEPLOYMENT_STATUS.md` (October 2026) and `docs/VOICE_AI_DEPLOYED.md` → GA Realtime API Migration.
> - **Step 1:** confirmed. `400 realtime_beta_access_required` from the Preview sessions endpoint; 14 failures from 2 users on Oct 17; last success Sep 23.
> - **Stage A deviated from this brief.** As written, store builds would get an `error` event for their Preview `session.update` (confirmed with a WebRTC probe), which their error handler turns into a stuck "Error occurred" state, with abandoned sessions billed by the server fallback. Instead the backend serves store builds a **compat mode** (`?webrtcfilter=on`, server-created replies); `VOICE_LEGACY_CLIENT_MODE=update_required` switches them to a "please update" message. Inventory awareness turned out to work in Stage A, because the backend already puts the inventory in the token-time instructions. Deployed Oct 17, 23:46 UTC; verified on iPhone and Android on Oct 18.
> - **Stage B (v1.2.2+36):** the app sends `realtimeProtocol: 'ga'` and **no** `session.update` (GA applies the token-time config to WebRTC calls, and the update replaced the persona with inventory-only text), handles the GA event names, treats data-channel errors as non-fatal, and no longer shows "Error occurred" after a stop on iPhone. The signed Android bundle is built (Flutter 3.35.5 + JDK 21); the iOS build and store submission are pending.
> - **Still to check on v1.2.2 (Step 5):** user transcripts with `whisper-1`, inventory awareness, and push-to-talk replies on both platforms.

> **Gene: paste this into Claude Code to start**
>
> `Read docs/VOICE_GA_MIGRATION.md end to end. Do Steps 1 and 2 only, then stop and show me what you found and your plan.`

---

## Symptom

- On iPhone and Android, starting the Voice AI Bartender shows "Error occurred" and "Failed to initialize voice session". The text AI chat still works. Reported 2026-10-17.
- That message comes from the backend: `voice-session` in `backend/functions/index.js` (about line 3003, error `token_error`). It returns it when the ephemeral-token request to Azure OpenAI fails.

## Most likely cause (not yet confirmed; Step 1 confirms)

- **The backend still uses the Preview Realtime API.**
    - Token request: `${AZURE_OPENAI_REALTIME_ENDPOINT}/openai/realtimeapi/sessions?api-version=2025-04-01-preview` (index.js about line 2963, and a second copy about line 2701).
    - WebRTC URL handed to the app: `https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc` (about line 3074, and about line 2755).
- **Microsoft deprecated the Preview Realtime API on April 30, 2026.** The GA API uses different endpoints:
    - `POST {endpoint}/openai/v1/realtime/client_secrets` for the ephemeral key (no `api-version`);
    - `{endpoint}/openai/v1/realtime/calls` for the WebRTC offer/answer.

    Microsoft's guidance: [Migration from Preview to GA version of Realtime API](https://learn.microsoft.com/azure/foundry/openai/how-to/realtime-audio-preview-api-migration-guide); [Use the GPT Realtime API via WebRTC](https://learn.microsoft.com/azure/foundry/openai/how-to/realtime-audio-webrtc).
- **The model is already fine.** The deployment was moved to GA `gpt-realtime-mini` on resource `blueb-midjmnz5-eastus2` in January 2026. Only the protocol and endpoints are still on the Preview.

## Ground rules

- **Investigate and propose first.** Stop for Gene's approval after Step 2.
- **No deploys or releases without Gene's OK.** That covers deploying to `func-mba-fresh` and releasing either app. It is urgent, but still gated.
- **Use the Microsoft Learn MCP server** for the GA Realtime API reference: session schema, `client_secrets` response, event names. Don't rely on memory.
- **Out of scope:** the model deployment, quotas, entitlement checks, pricing, and the auth method to Azure OpenAI (keep the `api-key` header for this fix).
- **Builds:** clean Flutter builds (`flutter clean`), both platforms.

## Step 1: Confirm the cause (read-only)

Query the function app's Application Insights:

```kusto
traces
| where timestamp > ago(60d)
| where message has "Ephemeral token request failed"
| project timestamp, message
| order by timestamp asc
```

- Record the HTTP status and error body, the **first** failure date, and how many failures there have been. Check `exceptions` around the same time.
- Confirm the deployment exists and note its model version (for example `az cognitiveservices account deployment list` on `blueb-midjmnz5-eastus2`).
- **If the error is not an endpoint or API-version problem** (for example 401 key, 429 quota, or a missing deployment), stop and report: the fix is different.

## Step 2: Inventory everything on the Preview protocol (read-only)

**Backend:** search for `realtimeapi`, `realtimertc`, `2025-04-01-preview` and `OpenAI-Beta` (at least the two handlers above). Say which handler each belongs to and which one the app actually calls. The app's config also mentions `/v1/realtime/token-simple`.

**Client:** `mobile/app/lib/src/services/voice_ai_service.dart`.
- **`session.update`** (about lines 1040 to 1080) uses the Preview shape:
    - top-level `turn_detection` (semantic VAD, `create_response: false`, `interrupt_response: false` for push-to-talk);
    - `input_audio_noise_reduction: far_field`;
    - `instructions` carrying the user's My Bar inventory.

    GA requires `type: "realtime"` and moves the audio settings under `session.audio.input` and `session.audio.output`.
- **Event names** (about lines 640 to 860). GA renames:
    - `response.audio_transcript.*` → `response.output_audio_transcript.*`
    - `response.audio.*` → `response.output_audio.*`
    - `response.text.*` → `response.output_text.*`

    GA also adds `conversation.item.added` and `conversation.item.done`, and assistant content types change from `text`/`audio` to `output_text`/`output_audio`.
- **SDP exchange** (about line 570): it posts the offer to the backend-supplied `webrtcUrl` with `Authorization: Bearer <ephemeral>` and `Content-Type: application/sdp`. GA keeps this shape; only the URL changes.
- **Error events:** does an `error` event on the data channel end the session?
- **Usage:** which events drive voice-minute usage reporting (`voice-usage`)?

**Then report the two-stage plan below with exact changes, and stop.**

## Step 3: Stage A, backend hotfix (restores voice for installed apps, no app review)

Goal: the app versions already in the stores work again, even if slightly degraded, while Stage B goes through review.

1. **Get the ephemeral key from the GA endpoint.** In `voice-session`, request it from `POST {AZURE_OPENAI_REALTIME_ENDPOINT}/openai/v1/realtime/client_secrets` with the existing `api-key` header. Build the GA session server-side (verify the field names against the API reference):
    - `type: "realtime"`;
    - `model`: the `AZURE_OPENAI_REALTIME_DEPLOYMENT` value;
    - the existing system `instructions`;
    - `audio.output.voice: "alloy"`, as today;
    - `audio.input.transcription`: same intent as today's `whisper-1` (confirm the GA-supported model);
    - `audio.input.turn_detection`: matching the app's push-to-talk design (semantic VAD, no auto-response, no interruption);
    - `audio.input.noise_reduction: far_field`.
2. **Keep the response shape the app expects.** Parse the GA response (ephemeral key value and expiry) and return it with the **same field names** the current app reads. Set `webrtcUrl` to `{endpoint}/openai/v1/realtime/calls`, derived from `AZURE_OPENAI_REALTIME_ENDPOINT` with no hardcoded region.
3. **Change nothing else in the handler:** DB session creation, quota checks and logging stay as they are. Fix the second handler the same way if anything uses it.
4. **Expected gaps until Stage B ships.** The app's own Preview-shaped `session.update` will probably be rejected, so My Bar inventory awareness may be missing, and the AI's reply text may not show (renamed events). Audio, push-to-talk and the user's transcript should work. Confirm all of this on real iPhone and Android devices running the **store** build before calling it fixed.

## Step 4: Stage B, app update v1.2.2 (full fix)

1. **`session.update` in GA format** (`type: "realtime"`, audio settings nested), still carrying the My Bar inventory instructions. Settings the backend already applied can be omitted if Step 2 shows they're redundant.
2. **Handle the GA event names.** Keep the old names as well for one release; it's harmless.
3. **Remove any `OpenAI-Beta` header.**
4. **Version:** bump to `1.2.2+36` (`CONVERSION_PLAN.md`'s v1.3.0 then takes the next build number).
5. **Docs:** update `.claude/CLAUDE.md` (Voice AI line), `docs/DEPLOYMENT_STATUS.md` (incident note and changelog), `docs/ARCHITECTURE.md` (voice flow), and any voice-specific doc that names the Preview endpoints.
6. **Release:** Gene builds iOS in Xcode and submits to both stores. On iOS, request an expedited review because a paid feature is broken.

## Step 5: Verify

- **Sessions start** on iOS and Android with the store build (after Stage A) and with the new build (after Stage B).
- **Push-to-talk:** hold to speak, release, and get exactly one reply.
- **Transcripts:** both the user's and the AI's text appear (Stage B).
- **Inventory awareness:** "What can I make with what I have?" uses My Bar (Stage B).
- **Minutes:** voice minutes decrement correctly, and the `quota_exceeded` path still works.
- **Logs:** Application Insights shows no new `token_error` after the fix.

## Afterward (Gene)

- Turn on an Azure Service Health alert for Azure OpenAI retirement and deprecation notices so the next change doesn't arrive silently.
- Optional: an Application Insights alert when `voice-session` returns errors several times in an hour.
