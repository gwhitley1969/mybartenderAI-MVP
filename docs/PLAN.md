# PLAN — Acceptance Criteria & Test Ideas

## Feature: Inventory → Recommendations (MVP)
- Given on-device inventory exists, when user taps "Get ideas", app returns ≥3 recommendations within p95 600ms (cache hit).
- 4xx/5xx paths show standard error shape and retry CTA.
- Offline: show local-only suggestions from SQLite.
- Tests:
  - Contract tests: recommend request/response matches `/spec`
  - Mobile: golden tests for cards; integration test that injects fake repo returns fixed list


### Cost & Caching Acceptance
- Given an identical system prompt + schema hash, when 20 consecutive premium requests run within 5 minutes,
  server metrics show ≥40% reduction in OpenAI input cost vs. uncached baseline (sample window).
- Server logs include `cacheKeyHash`, `cacheHit:boolean` per call (PII-free).
- Quota tests: when a user exceeds server-side monthly token allotment, Functions returns 429 with standard Error schema.

### Realtime seam (deferred)
- Documented but disabled. Toggle guarded by `ENABLE_REALTIME=false`.
- If enabled in a future slice, E2E test: mobile streams audio → websocket proxy → interim tokens → final instructions.
### Feature: CocktailDB Mirror & SQLite Snapshot

**Acceptance criteria**
- AC1: Nightly timer run produces a new snapshot when upstream data changed; otherwise reuses last `snapshotVersion`.
- AC2: `GET /v1/snapshots/latest` returns 200 with valid `signedUrl` (SAS ≤ 15 min expiry) and correct `sha256`.
- AC3: A clean mobile install downloads snapshot, verifies `sha256`, stores DB to app documents, and queries locally with <100ms p95 for lookups.
- AC4: Sync handles partial upstream failures with retry/backoff and leaves last good snapshot intact.
- AC5: Logs contain `runId`, counts, and durations; **no secrets or PII**.
- AC6: Manual `POST /v1/admin/sync` (with function key) enqueues/starts a run and returns 202.

**Test ideas**
- Unit: upsert mappers (CDB → PG rows), idempotent measures join, tag parsing, ETag handling.
- Integration: run sync against a recorded fixture; verify PG counts and a generated SQLite’s foreign keys.
- Contract: `SnapshotInfo` schema; NDJSON change feed framing.
- Perf: Snapshot build ≤ 3 min on B2ms; mobile cold start download ≤ 10s on 10 Mbps.
- Chaos: simulate CDB 429/5xx; ensure exponential backoff with jitter; run resumes next cycle.

### Feature: CocktailDB V2 Mirror & SQLite Snapshot

**Acceptance criteria**
- AC1: Nightly timer run detects upstream changes and produces a **new `snapshotVersion`**; otherwise reuses last good snapshot.
- AC2: `GET /v1/snapshots/latest` returns 200 with valid **SAS URL** expiring ≤ 15 minutes and a **sha256** that matches the uploaded artifact.
- AC3: Clean app install downloads, verifies sha256, and opens SQLite with **sqflite**; local search (by name/ingredient) p95 < 100 ms.
- AC4: If CocktailDB returns 429/5xx, the run retries with **exponential backoff + jitter** and preserves last good snapshot.
- AC5: Logs include `runId`, counts, durations; **no secrets** (key/URLs) anywhere.
- AC6: `POST /v1/admin/sync` with a valid function key responds 202 and enqueues/starts sync.

**Test ideas**
- Unit: JSON → normalized rows; idempotent UPSERTs; measure ordering; tag parsing.
- Integration: replay fixtures for A..Z + `latest.php`; verify PG counts and generated SQLite FKs/indices.
- Contract: `SnapshotInfo` validation; 503 when no snapshot yet.
- Perf: Build time on B2ms; app download time on 10 Mbps link.
- Chaos: Inject partial network failures; verify resumable ingestion; verify snapshot stays consistent.

# PLAN — Hardening & MVP Delivery

## Acceptance Criteria (global)
- All mobile/network types generated from `/spec/openapi.yaml` (no hand-written DTOs).
- App compiles with **Riverpod** state and **GoRouter** navigation; no Provider usages remain.
- All endpoints behind APIM require Entra External ID JWT; **no PII** in DB/logs.
- p95 ≤ 600ms for `GET /v1/recipes` and `GET /v1/inventory` measured at APIM edge under baseline load.
- Logs in Functions and client telemetry **redact** Authorization headers and any candidate PII fields.

## Feature: Inventory (MVP)
**Happy path**
- User authenticates; `GET /v1/inventory` returns their items.
- User adds items; `POST /v1/inventory` merges and returns 200.

**Errors**
- 401 without valid token.
- 400 when payload invalid (e.g., missing category/name).

**Tests**
- API contract tests (Dredd/Prism/owasp zap for security).
- Mobile repo tests: provider wiring, cache TTL, optimistic updates.

## Feature: Assistant Generate
**Happy path**
- Given profile + inventory, `POST /v1/assistant/generate` returns a structured **GeneratedRecipe** with ABV, steps, and reasoning text.

**Errors**
- 429 on per-user rate limit (free tier).
- 400 when prompt empty.

**Tests**
- JSON schema compliance; max tokens; prompt-injection hardening.
- Latency budget < 2.5s end-to-end for first token, < 600ms for subsequent renders via streaming (if enabled later).

## Feature: Vision Scan
**Happy path**
- App obtains SAS (`GET /v1/uploads/images/sas`), uploads to Blob, calls `POST /v1/vision/scan-bottle` with blobUrl, polls `GET /v1/vision/scan-bottle?requestId=…` until status=done and gets detected items.

**Errors**
- 400 for invalid blob URL or expired SAS.
- 413 for oversized images (enforced at APIM).

---

## Implementation Tasks (hand-off to Codex)

### Sprint 0 — Repo & Tooling
- [x] Add directories: `/spec`, `/docs`, `/apps/backend`, `/scripts`, `/mobile/app`.
- [ ] Configure **melos** or mono-repo tooling if desired.
- [ ] Add lint/format (flutter_lints), commit hooks (pre-commit), Conventional Commits.
- [ ] Add codegen: **build_runner**, **freezed**, **json_serializable**; `scripts/codegen.sh`.

### Sprint 1 — OpenAPI & Clients
- [x] Create `/spec/openapi.yaml` (from this file).
- [ ] Generate Dart client/models (e.g., `openapi-generator-cli` → `dart-dio-next`) into `/mobile/app/lib/api`.
- [ ] Wire **dio** interceptors: request ID (UUID), auth header injection, retry/backoff (idempotent reads only).

### Sprint 2 — Identity & Privacy
- [ ] Add **Entra External ID** sign-in flows to Flutter (MSAL) with secure token storage.
- [ ] Add `AuthRepository` (Riverpod) to fetch/refresh tokens; unit tests.
- [ ] Backend: JWT validation middleware in Functions; map `sub` → `user_id`.

### Sprint 3 — State & Navigation Migration
- [ ] Introduce **Riverpod** providers for `Inventory`, `Profile`, `Recipes`, `Assistant`.
- [ ] Replace string-based navigation with **GoRouter**; define typed routes per feature.
- [ ] Remove Provider/ChangeNotifier; delete legacy state once parity achieved. :contentReference[oaicite:8]{index=8}

### Sprint 4 — Backend MVP (Functions)
- [ ] Scaffold Functions in `/apps/backend` with handlers for all `/v1` paths.
- [ ] Add data layer for **Azure PostgreSQL** (pooled connections; SQL migrations with Flyway/Liquibase).
- [ ] Add **Blob SAS** generation function and storage bindings.
- [ ] Integrate **Azure OpenAI** in `/v1/assistant/generate` with output schema guard.
- [ ] Add **Application Insights**; correlation of `traceId` from header.

### Sprint 5 — Vision
- [ ] Queue-triggered function to process `inventoryScan` images; **Azure AI Vision** OCR/classify; persist normalized items.
- [ ] Polling endpoint or SignalR callback; enforce Blob lifecycle rules (7‑day TTL).

### Sprint 6 — CI/CD & Quality
- [ ] GitHub Actions: verify OpenAPI → regenerate → compile app; fail on drift.
- [ ] Unit/integration tests; API smoke tests against dev environment.
- [ ] Security: Secrets via **Key Vault**; no secrets in repo; dependabot enabled.

### Tester Checklist
- [ ] Validate rate limits (free vs pro claim).
- [ ] Verify no PII persisted (DB schema, logs samples).
- [ ] Offline mode: SQLite cache used; reconciling on re-connect.
- [ ] Regression: legacy screens replaced; no Provider references remain.

---

## Why these changes (grounded in your repo + product goals)

- The codebase currently exposes **Provider + manual screen switching** instead of **Riverpod + GoRouter**, increasing coupling and making runtime navigation brittle—migrating reduces tech debt and aligns with constraints. :contentReference[oaicite:9]{index=9}  
- **AI Assistant** and **Smart Scanner** exist in UI but lack service contracts and backend—moving to **contracts-first** OpenAPI with Functions unblocks these flagship features (AI recipe generation, voice assistant, personalization).   
- The product vision emphasizes **personalized AI mixology**, **voice guidance**, and **inventory scanning**—formalizing endpoints + schemas ensures Implementers can deliver those capabilities without ambiguity, while meeting the **no‑PII** policy. :contentReference[oaicite:11]{index=11}

---

### Hand-off note
If you want, I can also provide a **one‑time “issues list”** for GitHub (labels, short titles, and descriptions) based exactly on the Sprint tasks above—ready to bulk‑import.
