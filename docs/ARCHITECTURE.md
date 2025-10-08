# Architecture — MyBartenderAI (MVP)

## System overview
- Flutter app (feature-first clean architecture; Riverpod state; GoRouter)
- Azure Functions (HTTP) behind simple HTTPS (no APIM for MVP)
- Azure PostgreSQL for mirrored recipe corpus; SQLite on-device cache
- Azure Blob for user images; Key Vault for secrets; App Insights for telemetry

## Data flow (Mermaid)
```mermaid
sequenceDiagram
  participant App as Flutter (Mobile)
  participant Func as Azure Function (HTTP)
  participant PG as Azure PostgreSQL
  participant Blob as Azure Blob
  App->>App: Query local SQLite (recipes, indexes)
  App->>Func: POST /v1/recommend (inventory,tasteProfile)
  Func->>PG: SELECT candidate recipes
  Func-->>App: 200 application/json (Recommendation[])

## AI Model & Cost Strategy
- Models: use OpenAI GPT-4.1 family via backend-only calls (never from the device).
+ Models: use OpenAI GPT-4.1 family via backend-only calls (never from the device).
  - Default: gpt-4.1-mini for recommendations (cost/latency sweet spot).
  - Long-context or complex chains: gpt-4.1.
+ - Future on-device experiments: gpt-4.1-nano when supported via vetted SDKs.

+## Prompt Caching (OpenAI)
+We enable OpenAI Prompt Caching for stable, repeated system/tool prompts. The Azure Function computes a cache key
+from: model + promptTemplateVersion + normalized tools list + schema hash. Requests include cache hints and reuse keys
+across users (no PII in keys). This yields substantial savings for identical prompts during traffic bursts. 
+Telemetry logs only the cache-key hash, never raw prompts.

## Realtime (deferred)
- Voice guidance may be added later.
+ If/when we add "hands-free bartender", use OpenAI Realtime API via the backend as a websocket proxy. The mobile app
+ streams mic audio to Functions, which relays to OpenAI Realtime and streams transcripts/instructions back. Not part of MVP.

## Pricing guardrails
- Token caps enforced in app.
+ Token caps enforced in app + server. Server rejects over-quota calls early. Prompt Caching reduces marginal cost for
+ premium tiers; see PLAN for tests.
