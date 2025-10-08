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
