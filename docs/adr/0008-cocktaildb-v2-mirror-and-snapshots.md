
---

### 2) ADR — `/docs/adr/0008-cocktaildb-v2-mirror-and-snapshots.md`
```md
# 0008 — CocktailDB V2 Mirror & On‑Device SQLite
Status: Proposed
Date: 2025-10-08

## Context
The mobile app needs a fast, offline cocktail catalog. Direct device calls to TheCocktailDB would leak the API key and harm UX offline. Premium adds endpoints (e.g., latest, multi‑ingredient) but still expects server-side usage. :contentReference[oaicite:4]{index=4}

## Decision
Mirror CocktailDB (server-side) into **Azure PostgreSQL**, then publish a **versioned, read‑only SQLite snapshot** to Blob. App downloads the latest snapshot on first run and when `snapshotVersion` changes via `GET /v1/snapshots/latest`.

## Data Model (canonical in PostgreSQL)
Tables:
- `drinks(id int primary key, name text, instructions text, image_url text, category_id int, glass_id int, is_alcoholic boolean, tags text[], iba text, updated_at timestamptz)`
- `ingredients(id int primary key, name text, description text, type text, abv numeric, is_alcohol boolean)`
- `measures(drink_id int, ingredient_id int, measure_text text, ordinal int, primary key(drink_id, ingredient_id, ordinal))`
- `categories(id int primary key, name text)`
- `glasses(id int primary key, name text)`

Indexes:
- `drinks(name)`, `drinks(category_id)`, `measures(drink_id)`, `measures(ingredient_id)`, GIN on `tags`.

Migration:
- Create all tables + FKs; no TTL (catalog). Keep `updated_at` from source if present, else import time.

## Snapshot format (SQLite)
- File: `snapshots/sqlite/{schemaVersion}/{snapshotVersion}.db.zst` with `.sha256`.
- `schemaVersion`: string (start `"1"`). Bump on breaking changes.
- `snapshotVersion`: `yyyymmdd.N` (e.g., `20251008.1`).
- SQLite DDL mirrors PG (FKs on; indices; `WITHOUT ROWID` where helpful).

## Security & Privacy
- Key in **Key Vault** (`COCKTAILDB_API_KEY`), accessed via managed identity.
- No API keys or URLs logged. Redact querystrings.
- `/v1/snapshots/latest` is anonymous but returns **short‑lived SAS**.

## Performance/SLO
- Snapshot build ≤ 3 min on B2ms PG baseline; app local lookups p95 < 100 ms.
- Read endpoints p95 ≤ 600 ms from APIM.

## Cost (initial)
- PG Flexible B2ms ~$30–60/mo.
- Blob for ~100–200 MB snapshot negligible; egress pennies/user/month.
- Functions negligible at MVP scale.

## Risks/Unknowns
- CocktailDB doesn’t publish a single “dump” endpoint; initial full import uses `search.php?f=a..z` + detail lookups; Premium `latest.php` assists with recent deltas. :contentReference[oaicite:5]{index=5}
- ETag/If‑Modified‑Since support not documented—implement optimistic caching and idempotent upserts.
