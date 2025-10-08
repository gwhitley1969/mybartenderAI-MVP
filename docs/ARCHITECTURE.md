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
  participant Func as Azure Functions (HTTP)
  participant PG as Azure PostgreSQL
  participant Blob as Azure Blob
  App->>App: Query local SQLite (recipes, indexes)
  App->>Func: POST /v1/recommend (inventory, tasteProfile)
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

## Feature: CocktailDB Mirror & SQLite Snapshot Service

**Goal:** Pull premium TheCocktailDB data on a schedule into Azure Database for PostgreSQL (normalized), then publish a versioned, read-only SQLite snapshot to Azure Blob for the mobile app to download and cache locally. Optionally publish deltas for smaller updates.

### Components
- **Timer Function** `sync-cocktaildb` (nightly @ 03:30 UTC; manual HTTP trigger available for admins)
- **HTTP Function** `GET /v1/snapshots/latest` → returns snapshot metadata + signed URL
- **HTTP Function** `GET /v1/changes?since={version}` → NDJSON of upserts/deletes (optional for MVP)
- **PostgreSQL**: canonical schema (drinks, ingredients, measures, categories, glasses, tags)
- **Blob Storage**: `/snapshots/sqlite/{schemaVersion}/{snapshotVersion}.db.zst` (and `.sha256`)
- **Key Vault**: `COCKTAILDB_API_KEY` (premium), DB creds via MI + KV references
- **App**: On first run (or when `snapshotVersion` changes), download+decompress SQLite, hydrate local cache

### Sequence (Mermaid)
```mermaid
sequenceDiagram
  autonumber
  participant T as Timer Function (sync-cocktaildb)
  participant CDB as TheCocktailDB (premium)
  participant PG as Azure DB for PostgreSQL
  participant BL as Azure Blob Storage
  participant H as HTTP Function (/v1/snapshots/latest)
  participant M as Mobile App (Flutter)

  T->>CDB: Fetch drinks/ingredients/categories (paged, with ETags)
  CDB-->>T: 200 OK (JSON batches)
  T->>PG: Upsert normalized rows (COPY/UPSERT)
  T->>T: Build SQLite from PG (read-only; VACUUM; ANALYZE)
  T->>BL: Upload snapshot .db.zst + .sha256 (versioned)
  Note over T: Write metadata: {schemaVersion, snapshotVersion, counts, createdAt}
  M->>H: GET /v1/snapshots/latest
  H-->>M: { snapshotVersion, signedUrl, size, sha256 }
  M->>BL: Download snapshot
  M->>M: Verify sha256 → replace local DB atomically

- No PII persisted; only public catalog data.
- Secrets: `COCKTAILDB_API_KEY` and DB creds in Key Vault; app settings use `@Microsoft.KeyVault(SecretUri=...)`.
- Redaction: remove querystrings from logs; never log upstream response bodies; log only counts/hashes.
- Authorization:
  - `/v1/snapshots/latest`: anonymous OK (returns **signed URL** with short expiry).
  - `/v1/changes`: same as above (or gated later).
  - `/v1/admin/sync`: requires `x-functions-key` (function auth) or Entra claim `role=admin` if you enable Easy Auth later.
- Rate limiting upstream calls (respect TheCocktailDB ToS): page-size throttle, If-Modified-Since/ETag, 429 retry with backoff.
