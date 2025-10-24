# PLAN — Acceptance Criteria & Test Ideas

API Layer: Azure API Management (APIM) gateway to Azure Functions (HTTP triggers)
Gateway: `apim-mba-001` (Developer tier for MVP, Consumption tier for production)
Base URL:

- Local: http://localhost:7073
- Dev/Prod: https://apim-mba-001.azure-api.net

Security & AuthN/AuthZ

- JWT validation via Microsoft Entra External ID at APIM layer
- APIM subscription keys (API keys) per mobile app installation
- Claims-based authZ per feature/endpoint
- Tier-based access control via APIM Products (Free/Premium/Pro)

Rate limiting & Abuse Mitigation

- APIM policies for rate limiting per product/subscription
- Per-IP rate limiting at APIM edge
- Backend PostgreSQL counters for feature quota tracking (AI calls, voice minutes)
- Optional Azure Front Door WAF if needed post-MVP
- Structured logging in Functions with PII redaction before emit

Observability

- Application Insights (Functions + APIM) with custom events
- APIM Analytics for API usage per tier
- Correlation IDs propagated from mobile client headers
- Voice usage tracking (minutes per user/tier)

Deployment

- APIM manually configured via Azure Portal (Developer tier)
- CI/CD deploys Function App
- OpenAPI remains single source of truth for contracts
- APIM imports OpenAPI spec for automatic endpoint configuration

## Feature: Inventory → Recommendations (MVP)

- Given on-device inventory exists, when user taps "Get ideas", app returns ≥3 recommendations within p95 600ms (cache hit).
- APIM validates subscription tier before forwarding to backend
- 4xx/5xx paths show standard error shape and retry CTA.
- Offline: show local-only suggestions from SQLite.
- Tests:
  - Contract tests: recommend request/response matches `/spec`
  - Mobile: golden tests for cards; integration test that injects fake repo returns fixed list
  - APIM: Verify rate limiting policies per tier

### Cost & Caching Acceptance

- Given an identical system prompt + schema hash, when 20 consecutive premium requests run within 5 minutes,
  server metrics show ≥40% reduction in OpenAI input cost vs. uncached baseline (sample window).
- Server logs include `cacheKeyHash`, `cacheHit:boolean` per call (PII-free).
- Quota tests: when a user exceeds server-side monthly token allotment, Functions returns 429 with standard Error schema.
- APIM enforces daily/monthly rate limits at API gateway layer

### Voice Assistant Feature (Premium/Pro)

**Architecture: Azure Speech Services + GPT-4o-mini**

- Mobile client uses Azure Speech SDK for Speech-to-Text (local processing)
- Text query sent via APIM to `POST /v1/ask-bartender`
- GPT-4o-mini processes query and returns conversational text response
- Mobile client uses Azure Speech SDK for Text-to-Speech (local playback)
- No OpenAI Realtime API (cost prohibitive)

**Acceptance Criteria:**

- AC1: `GET /v1/speech/token` returns valid 10-minute Azure Speech token (Premium/Pro only)
- AC2: End-to-end voice session latency < 2 seconds p95 (STT → API → TTS start)
- AC3: Voice sessions tracked in PostgreSQL; enforces tier limits:
  - Premium: 30 minutes/month
  - Pro: 5 hours/month
- AC4: When voice quota exceeded, 429 response with upgrade CTA
- AC5: Speech recognition accuracy > 95% with bartending vocabulary
- AC6: GPT-4o-mini responses optimized for voice (conversational, < 100 words)
- AC7: All voice transcripts ephemeral unless user opts in to save
- AC8: APIM rate limits for speech token endpoint: 60 calls/hour

**Test Ideas:**

- Unit: GPT-4o-mini prompt quality for voice instructions
- Integration: Full voice flow (mock STT/TTS, real API calls)
- Performance: Measure latency at each step (STT, API, TTS)
- Cost: Verify session cost < $0.12 per 5-minute interaction
- UX: Test interruption handling, background noise tolerance
- Security: Verify tokens expire, no API keys exposed to client

### CocktailDB Mirror & JSON Snapshot

**Status:** ✅ **OPERATIONAL** (as of 2025-10-23)

**Acceptance criteria**

- ✅ AC1: Nightly timer run produces a new snapshot when upstream data changed; otherwise reuses last `snapshotVersion`.
  - Timer: Daily at 03:30 UTC
  - Current version: 20251023.033020 (71KB compressed)
  - Sync duration: ~16 seconds
- ✅ AC2: `GET /v1/snapshots/latest` returns 200 with valid `signedUrl` (SAS ≤ 15 min expiry) and correct `sha256`.
  - Direct endpoint: https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest
  - APIM endpoint: TBD (will enforce tier access when APIM configured)
  - Response includes: schemaVersion, snapshotVersion, sizeBytes, sha256, signedUrl, createdAtUtc, counts
  - Rate limiting: TBD (via APIM policies)
- 📋 AC3: A clean mobile install downloads snapshot, verifies `sha256`, stores DB to app documents, and queries locally with <100ms p95 for lookups.
  - Mobile app integration pending
- ✅ AC4: Sync handles partial upstream failures with retry/backoff and leaves last good snapshot intact.
  - Sync implemented with error handling
  - Last good snapshot preserved on failure
- ✅ AC5: Logs contain `runId`, counts, and durations; **no secrets or PII**.
  - Application Insights configured
  - Structured logging in place
- AC6: Manual `POST /v1/admin/sync` (with function key, bypasses APIM) enqueues/starts a run and returns 202.

**Test ideas**

- Unit: upsert mappers (CDB → PG rows), idempotent measures join, tag parsing, ETag handling.
- Integration: run sync against a recorded fixture; verify PG counts and a generated JSON's structure.
- Contract: `SnapshotInfo` schema; NDJSON change feed framing.
- Perf: Snapshot build ≤ 3 min; mobile cold start download ≤ 10s on 10 Mbps.
- Chaos: simulate CDB 429/5xx; ensure exponential backoff with jitter; run resumes next cycle.
- APIM: Test rate limiting on snapshot endpoint

## APIM Configuration & Testing

### Products (Subscription Tiers)

**Free Tier:**

- Rate limit: 100 API calls/day
- Features: Snapshot downloads only
- No AI features (blocked at APIM)

**Premium Tier ($4.99/month):**

- Rate limit: 1,000 API calls/day
- Features: AI recommendations (100/month), Voice (30 min/month), Vision (5 scans/month)
- Cost coverage: ~$0.50/user/month for AI services

**Pro Tier ($9.99/month):**

- Rate limit: Unlimited API calls
- Features: Unlimited AI recommendations, Voice (5 hours/month), Vision (50 scans/month)
- Priority support

### Acceptance Criteria for APIM

- AC1: Mobile app obtains APIM subscription key during signup
- AC2: All API requests include `Ocp-Apim-Subscription-Key` header
- AC3: APIM validates subscription and enforces rate limits before forwarding to Functions
- AC4: Free tier blocked from `/v1/ask-bartender`, `/v1/speech/token`, `/v1/vision/*`
- AC5: Premium/Pro tiers can access all endpoints within quota
- AC6: 429 response when rate limit exceeded with `Retry-After` header
- AC7: APIM logs requests with correlation IDs for debugging
- AC8: Backend Functions do NOT see subscription keys (APIM strips/replaces with internal auth)

### Test Ideas for APIM

- Contract: OpenAPI import creates correct APIM operations
- Security: Verify Function URLs not exposed to clients
- Rate limiting: Test 100 requests/day for Free tier returns 429
- Tier enforcement: Free tier cannot call Premium endpoints (403)
- Token forwarding: Verify JWT passes through APIM to Functions
- Caching: Test APIM caching for `/v1/snapshots/latest` (5-minute cache)
- Failover: Verify APIM retries on Function 5xx errors

# PLAN — Hardening & MVP Delivery

## Acceptance Criteria (global)

- All mobile/network types generated from `/spec/openapi.yaml` (no hand-written DTOs).
- App compiles with **Riverpod** state and **GoRouter** navigation; no Provider usages remain.
- All endpoints behind APIM with JWT validation; **no PII** in DB/logs.
- p95 ≤ 600ms for `GET /v1/recipes` and `GET /v1/inventory` measured at APIM edge under baseline load.
- Logs in Functions and client telemetry **redact** Authorization headers and any candidate PII fields.
- APIM Developer Portal configured for API key management

## Feature: Inventory (MVP)

**Happy path**

- User authenticates; APIM forwards to `GET /v1/inventory` with validated JWT.
- User adds items; `POST /v1/inventory` merges and returns 200.
- APIM rate limiting enforced per tier.

**Errors**

- 401 without valid JWT (APIM rejects before backend).
- 403 when Free tier tries Premium feature.
- 429 when rate limit exceeded.
- 400 when payload invalid (e.g., missing category/name).

**Tests**

- API contract tests (Dredd/Prism/owasp zap for security).
- APIM policy tests (rate limiting, JWT validation).
- Mobile repo tests: provider wiring, cache TTL, optimistic updates.

## Feature: AI Recommendations (GPT-4o-mini)

**Happy path**

- Given profile + inventory, `POST /v1/assistant/generate` (via APIM) returns a structured **GeneratedRecipe** with ABV, steps, and reasoning text.
- GPT-4o-mini processes request (~$0.007 per session).
- APIM tracks usage against user's monthly quota.

**Errors**

- 429 on per-user quota limit (Premium: 100/month).
- 403 when Free tier attempts access.
- 400 when prompt empty.
- 503 when OpenAI service unavailable (APIM retries once).

**Tests**

- JSON schema compliance; max tokens; prompt-injection hardening.
- Latency budget < 2.5s end-to-end for first token.
- Cost tracking: Verify token usage logged correctly.
- Quota enforcement: Test 100th Premium request succeeds, 101st returns 429.

## Feature: Voice Assistant (Azure Speech Services)

**Happy path**

- App obtains Azure Speech token via `GET /v1/speech/token` (APIM validates Premium/Pro tier).
- User speaks → Azure Speech SDK (client-side STT) → text query.
- App calls `POST /v1/ask-bartender` via APIM → GPT-4o-mini → conversational text response.
- App uses Azure Speech SDK (client-side TTS) → audio playback.
- Usage tracked in minutes; enforced at Function/DB level.

**Errors**

- 403 when Free tier tries to access speech features.
- 429 when voice minutes quota exceeded (Premium: 30 min/month).
- 400 for invalid or expired speech token.
- Network error: Gracefully fall back to text chat.

**Tests**

- End-to-end latency: < 2 seconds p95.
- Speech recognition accuracy: > 95% with bartending vocabulary.
- Cost monitoring: Verify cost < $0.12 per 5-minute session.
- Quota enforcement: Test 30-minute limit for Premium users.
- Privacy: Verify transcripts not logged by default.

## Feature: Vision Scan (Future)

**Happy path**

- App obtains SAS token via `GET /v1/uploads/images/sas` (Premium/Pro only).
- Upload image to Blob Storage.
- Call `POST /v1/vision/scan-bottle` with blobUrl.
- Poll `GET /v1/vision/scan-bottle?requestId=…` until status=done.
- Returns detected bottles with confidence scores.

**Errors**

- 403 when Free tier attempts access.
- 400 for invalid blob URL or expired SAS.
- 413 for oversized images (>10MB).
- 429 when monthly scan quota exceeded.

## Cost Management

### MVP Budget (~$60-70/month)

- APIM Developer tier: $50/month (fixed)
- Functions (Consumption): ~$0.20/million executions (minimal)
- PostgreSQL Basic: ~$12-30/month
- Storage: ~$1/month
- AI services: Pay-per-use (~$0.50/user/month for Premium)

### Production Target (~$20-30/month base + usage)

- APIM Consumption: ~$5-15/month (based on usage)
- Functions: Same (~$0.20/million)
- PostgreSQL: Optimized tier ~$12-20/month
- Storage: ~$1/month
- AI services: Covered by Premium/Pro revenue

### Revenue Model

- Premium users cover their AI costs ($0.50) + margin
- Target: 1,000 Premium users = $5,000 revenue, ~$500 AI costs = 90% margin

---

## Implementation Tasks

### Sprint 0 — Repo & Tooling

- [x] Add directories: `/spec`, `/docs`, `/apps/backend`, `/scripts`, `/mobile/app`.
- [ ] Configure **melos** or mono-repo tooling if desired.
- [ ] Add lint/format (flutter_lints), commit hooks (pre-commit), Conventional Commits.
- [ ] Add codegen: **build_runner**, **freezed**, **json_serializable**; `scripts/codegen.sh`.

### Sprint 1 — OpenAPI & Clients

- [x] Create `/spec/openapi.yaml` (from this file).
- [ ] Generate Dart client/models (e.g., `openapi-generator-cli` → `dart-dio-next`) into `/mobile/app/lib/api`.
- [ ] Wire **dio** interceptors: request ID (UUID), APIM subscription key injection, retry/backoff.
- [ ] Import OpenAPI spec into APIM for automatic operation creation.

### Sprint 2 — APIM Configuration

- [x] Create APIM instance: `apim-mba-001` (Developer tier).
- [x] Configure three Products: Free, Premium, Pro with rate limit policies.
- [x] Import Function App as backend API in APIM.
- [x] Configure JWT validation policy (Entra External ID).
- [ ] Set up APIM Developer Portal for API key management.
- [ ] Test rate limiting and tier enforcement.

### Sprint 3 — Identity & Privacy

- [ ] Add **Entra External ID** sign-in flows to Flutter (MSAL) with secure token storage.
- [ ] Add `AuthRepository` (Riverpod) to fetch/refresh tokens; unit tests.
- [ ] Backend: JWT validation at APIM; map `sub` → `user_id` in Functions.
- [ ] Implement subscription key provisioning during user signup.
- [ ] **Age Verification (21+ requirement)**:
  - [ ] Deploy `validate-age` Azure Function for Entra External ID API connector
  - [ ] Configure Entra External ID custom attributes (`birthdate`, `age_verified`)
  - [ ] Add API connector to user flow for signup validation
  - [ ] Update JWT token configuration to include `age_verified` claim
  - [ ] Update APIM policies with age verification validation
  - [ ] Implement mobile app age gate screen (first launch)
  - [ ] Test complete age verification flow (app → signup → API)

### Sprint 4 — State & Navigation Migration

- [ ] Introduce **Riverpod** providers for `Inventory`, `Profile`, `Recipes`, `Assistant`.
- [ ] Replace string-based navigation with **GoRouter**; define typed routes per feature.
- [ ] Remove Provider/ChangeNotifier; delete legacy state once parity achieved.

### Sprint 5 — Backend MVP (Functions)

- [ ] Scaffold Functions in `/apps/backend` with handlers for all `/v1` paths.
- [ ] Add data layer for **Azure PostgreSQL** (pooled connections; SQL migrations).
- [ ] Add **SAS token** generation for Blob storage access (MVP approach).
- [ ] Integrate **GPT-4o-mini** in `/v1/assistant/generate` with output schema guard.
- [ ] Add **Application Insights**; correlation of `traceId` from header.
- [ ] Implement quota tracking in PostgreSQL (AI calls, voice minutes per user).

### Sprint 6 — Voice Assistant (Azure Speech)

- [ ] Create Azure Speech Services resource: `speech-mba-prod`.
- [ ] Add speech API key to Key Vault.
- [ ] Implement `GET /v1/speech/token` function (returns 10-min tokens).
- [ ] Flutter: Integrate `speech_to_text` and `flutter_tts` packages.
- [ ] Optimize `ask-bartender` function prompts for voice interaction.
- [ ] Add voice usage tracking to PostgreSQL.
- [ ] Configure APIM policies for speech token endpoint (60 calls/hour).
- [ ] End-to-end testing: STT → API → TTS flow.

### Sprint 7 — Vision (Future)

- [ ] Queue-triggered function to process `inventoryScan` images.
- [ ] **Azure AI Vision** OCR/classify; persist normalized items.
- [ ] Polling endpoint or SignalR callback.
- [ ] Enforce Blob lifecycle rules (7-day TTL).
- [ ] Configure APIM policies for vision endpoints (Premium/Pro only).

### Sprint 8 — CI/CD & Quality

- [ ] GitHub Actions: verify OpenAPI → regenerate → compile app; fail on drift.
- [ ] Unit/integration tests; API smoke tests against dev environment.
- [ ] Security: Secrets via **Key Vault**; no secrets in repo; dependabot enabled.
- [ ] APIM automated testing (Postman collections).
- [ ] Load testing: Verify APIM + Functions scale under load.

### Tester Checklist

- [ ] Validate rate limits (Free vs Premium vs Pro).
- [ ] Verify no PII persisted (DB schema, logs samples).
- [ ] Offline mode: SQLite cache used; reconciling on re-connect.
- [ ] Age verification: Test under-21 blocked, 21+ allowed.
- [ ] Age verification: Test JWT tokens include age_verified claim.
- [ ] Age verification: Test APIM rejects requests without age_verified.
- [ ] Voice feature: Test latency, accuracy, quota enforcement.
- [ ] APIM: Test all tier restrictions and rate limits.
- [ ] Regression: legacy screens replaced; no Provider references remain.
- [ ] Cost monitoring: Verify AI usage tracked correctly.

---

## Why these changes (grounded in product goals)

- **APIM Integration**: Provides tier-based access control, rate limiting, and API key management without custom code.
- **Azure Speech Services**: 93% cost savings vs OpenAI Realtime API while maintaining quality voice interaction.
- **GPT-4o-mini**: Cost-optimized AI model perfect for cocktail domain (~$0.007 per session vs ~$0.10 with GPT-4).
- **SAS Tokens (MVP)**: Pragmatic approach due to Windows Consumption Plan limitations; MI migration planned post-MVP.
- **Client-side Speech Processing**: Lower latency, offline capability, reduced bandwidth, better privacy.

---

### Hand-off note

This plan reflects the current architecture decisions:

- APIM for API gateway (tier management, rate limiting)
- Azure Speech Services for voice (cost-optimized)
- GPT-4o-mini for AI recommendations (cost-optimized)
- SAS tokens for blob access (MVP pragmatic choice)
- Three-tier subscription model (Free/Premium/Pro)

Ready for implementation with clear acceptance criteria and test strategies for each feature.
