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
