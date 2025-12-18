# Recipe Vault Architecture

## Overview

The Recipe Vault is the cocktail database system that powers MyBartenderAI. It provides offline-first access to 621+ cocktail recipes on mobile devices by maintaining a master database in PostgreSQL and distributing compressed SQLite snapshots to mobile clients.

```
┌─────────────────────┐     ┌─────────────────────┐     ┌─────────────────────┐
│   TheCocktailDB     │     │     PostgreSQL      │     │   Azure Blob        │
│   (External API)    │────▶│   (Master Database) │────▶│   Storage           │
│   [DISABLED]        │     │   pg-mybartenderdb  │     │   mbacocktaildb3    │
└─────────────────────┘     └─────────────────────┘     └─────────────────────┘
                                                                  │
                                                                  │ SQLite Snapshot
                                                                  │ (.db.zst)
                                                                  ▼
                                                        ┌─────────────────────┐
                                                        │   Mobile App        │
                                                        │   (SQLite Local)    │
                                                        └─────────────────────┘
```

## Data Flow

### 1. Source Data (Historical)

Originally, cocktail data was fetched from [TheCocktailDB API](https://www.thecocktaildb.com/api.php). This external sync has been **disabled** as of December 2025. The PostgreSQL database now serves as the authoritative master source.

### 2. Master Database (PostgreSQL)

**Server**: `pg-mybartenderdb.postgres.database.azure.com`
**Database**: `mybartender`

The PostgreSQL database stores normalized cocktail data across multiple tables:

#### Core Tables

| Table | Description | Row Count |
|-------|-------------|-----------|
| `drinks` | Main cocktail records (id, name, category, glass, instructions, thumbnail) | 621 |
| `ingredients` | Ingredient names for each drink (drink_id, position, name) | 2,491 |
| `measures` | Measurements for each ingredient (drink_id, position, measure) | 2,491 |
| `tags` | Tag definitions (id, name) | 67 |
| `drink_tags` | Many-to-many relationship between drinks and tags | varies |
| `glasses` | Glass types | ~40 |
| `categories` | Drink categories (Cocktail, Shot, etc.) | ~11 |

#### Drinks Table Schema

```sql
CREATE TABLE drinks (
    id           TEXT PRIMARY KEY,      -- TheCocktailDB ID (e.g., "11007")
    name         TEXT NOT NULL,         -- Cocktail name
    category     TEXT,                  -- "Cocktail", "Shot", etc.
    alcoholic    TEXT,                  -- "Alcoholic", "Non alcoholic"
    glass        TEXT,                  -- Glass type
    instructions TEXT,                  -- Preparation instructions
    thumbnail    TEXT,                  -- Image URL
    raw          JSONB,                 -- Original API response (historical)
    updated_at   TIMESTAMP WITH TIME ZONE
);
```

#### Metadata Tables

| Table | Description |
|-------|-------------|
| `snapshot_metadata` | Records of generated snapshots (version, blob_path, size, sha256) |
| `snapshots` | Legacy table (empty, not used) |

### 3. Snapshot Generation

Snapshots convert PostgreSQL data into a compressed SQLite database for mobile distribution.

#### Snapshot Builder Script

**Location**: `/rebuild-sqlite-snapshot.js`

This Node.js script:
1. Connects to PostgreSQL via Key Vault credentials
2. Queries all drinks, ingredients, measures, and tags
3. Creates an in-memory SQLite database using `better-sqlite3`
4. Compresses with Zstandard (zstd)
5. Uploads to Azure Blob Storage
6. Records metadata in PostgreSQL

```bash
# Run manually to generate a new snapshot
node rebuild-sqlite-snapshot.js
```

#### SQLite Schema (Mobile App)

The SQLite database created for mobile devices has this schema:

```sql
CREATE TABLE drinks (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    alternate_name TEXT,
    category TEXT,
    glass TEXT,
    instructions TEXT,
    instructions_es TEXT,
    instructions_de TEXT,
    instructions_fr TEXT,
    instructions_it TEXT,
    image_url TEXT,
    image_attribution TEXT,
    tags TEXT,                    -- Comma-separated tag names
    video_url TEXT,
    iba TEXT,
    alcoholic TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    source TEXT DEFAULT 'thecocktaildb',
    is_custom INTEGER DEFAULT 0
);

CREATE TABLE drink_ingredients (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drink_id TEXT NOT NULL,
    ingredient_name TEXT NOT NULL,
    measure TEXT,
    ingredient_order INTEGER NOT NULL,
    FOREIGN KEY (drink_id) REFERENCES drinks (id) ON DELETE CASCADE,
    UNIQUE (drink_id, ingredient_order)
);

CREATE TABLE metadata (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

#### Compression

- **Format**: Zstandard (.zst)
- **Uncompressed Size**: ~553 KB
- **Compressed Size**: ~173 KB
- **Compression Ratio**: ~3:1

### 4. Azure Blob Storage

**Storage Account**: `mbacocktaildb3`
**Container**: `snapshots`

#### Blob Structure

```
snapshots/
└── snapshots/
    └── sqlite/
        └── 1/                              # Schema version
            ├── 20251217.210721.db.zst      # Compressed SQLite
            └── 20251217.210721.db.zst.sha256  # Checksum
```

#### Naming Convention

Snapshot versions follow the format: `YYYYMMDD.HHMMSS`

Example: `20251217.210721` = December 17, 2025 at 21:07:21 UTC

### 5. API Endpoint

**Endpoint**: `GET /api/v1/snapshots/latest`

Returns metadata about the latest snapshot:

```json
{
    "schemaVersion": "1",
    "snapshotVersion": "20251217.210721",
    "sizeBytes": 172894,
    "sha256": "21c3d1a6310257f02ca5533abde45e75f408d1216f11d46a1734ba55a0697471",
    "signedUrl": "https://mbacocktaildb3.blob.core.windows.net/snapshots/...",
    "createdAtUtc": "2025-12-17T21:07:21.000Z",
    "counts": {
        "drinks": 621,
        "ingredients": 392,
        "categories": 11,
        "glasses": 40,
        "tags": 67
    }
}
```

The `signedUrl` is a time-limited SAS token URL (15 minutes default) for downloading the blob.

**Backend Code**: `/backend/functions/snapshots-latest/index.js`

### 6. Mobile App Sync

**Service**: `/mobile/app/lib/src/services/snapshot_service.dart`

#### Sync Process

1. **Check for Updates**: Compare local snapshot version with server
2. **Download Metadata**: Fetch `/v1/snapshots/latest`
3. **Download Blob**: GET the signed URL to download compressed SQLite
4. **Verify Size**: Ensure downloaded bytes match expected size
5. **Decompress**: Use Zstandard to decompress the .zst file
6. **Atomic Swap**:
   - Write to temporary file first
   - Close existing database connection
   - Delete old database files (.db, .db-wal, .db-shm)
   - Rename temp file to final location
7. **Initialize**: Add user-specific tables (favorites, inventory, etc.)

#### Local Database Location

```
/data/user/0/ai.mybartender.mybartenderai/app_flutter/mybartenderai.db
```

#### User Tables (Added Locally)

The mobile app adds these tables to the downloaded snapshot:

- `favorites` - User's bookmarked cocktails
- `inventory` - User's bar inventory
- `custom_cocktails` - User-created recipes
- `taste_profile` - User preferences

## Component Reference

### Backend Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `snapshots-latest` | `/backend/functions/snapshots-latest/` | API endpoint for snapshot metadata |
| `snapshotMetadataService.js` | `/backend/functions/services/` | Read/write snapshot metadata in PostgreSQL |
| `snapshotStorageService.js` | `/backend/functions/services/` | Upload blobs, generate SAS URLs |
| `rebuild-sqlite-snapshot.js` | `/` (root) | Manual script to generate SQLite snapshots |

### Mobile Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `snapshot_service.dart` | `/mobile/app/lib/src/services/` | Download and sync snapshots |
| `database_service.dart` | `/mobile/app/lib/src/services/` | SQLite operations, schema management |
| `backend_service.dart` | `/mobile/app/lib/src/services/` | API client for backend calls |

### Disabled Components

| Component | Location | Status |
|-----------|----------|--------|
| `sync-cocktaildb` | `/backend/functions/sync-cocktaildb/` | **DISABLED** - Was timer-triggered sync with TheCocktailDB API |
| `sync-cocktaildb-mi` | `/backend/functions/sync-cocktaildb-mi/` | **DISABLED** - Managed Identity version |

## Historical Issues

### JSON vs SQLite Snapshot Bug (Dec 17, 2025)

**Problem**: The timer-triggered `sync-cocktaildb` Azure Function was producing JSON snapshots instead of SQLite databases, causing mobile app sync failures.

**Symptoms**:
- Snapshot size: 71KB (JSON) instead of ~173KB (SQLite)
- Mobile app reports "database corruption"
- SQLite header check fails (finds `{"version":1,...}` instead of `SQLite format 3`)

**Root Cause**: The Azure Function uses `sql.js` (pure JavaScript SQLite) which has different behavior than `better-sqlite3` (native). The function was inadvertently producing JSON output.

**Initial Solution** (Dec 17):
1. Changed `function.json` schedule to Feb 31 (impossible date)
2. Use `rebuild-sqlite-snapshot.js` for manual snapshot generation
3. PostgreSQL is now the master database (no external API sync)

### Timer Function Recurrence (Dec 18, 2025)

**Problem**: The broken timer function ran again at 03:30 UTC on Dec 18, overwriting the good SQLite snapshot with broken JSON.

**Root Cause**: The timer was registered in **two places**:
1. `sync-cocktaildb/function.json` - schedule was changed but timer still active
2. `backend/functions/index.js` line 2269 - **`app.timer()` call was still active** with `schedule: '0 30 3 * * *'`

The `app.timer()` registration in `index.js` **overrides** the `function.json` settings in the Azure Functions v4 programming model.

**Permanent Solution** (Dec 18):
1. **Commented out** both timer registrations in `index.js` (lines 2266-2292)
2. Added `"disabled": true` to both `function.json` files
3. Changed schedules to Feb 31 as backup safety
4. Added explicit "DO NOT RE-ENABLE" comments in the code

**Lesson Learned**: When disabling Azure Functions v4 timer triggers, you must disable them in **both**:
- The `function.json` file (add `"disabled": true`)
- The `index.js` registration (comment out or remove the `app.timer()` call)

### Snapshot Size Reference

| Size | Format | Status |
|------|--------|--------|
| ~71 KB | JSON | **BROKEN** - Not a valid SQLite database |
| ~152-173 KB | SQLite | **CORRECT** - Valid SQLite database |

## Operations

### Generate New Snapshot

When cocktail data changes in PostgreSQL, generate a new snapshot:

```bash
cd /path/to/mybartenderAI-MVP
node rebuild-sqlite-snapshot.js
```

This will:
1. Create a new SQLite snapshot from PostgreSQL
2. Upload to Azure Blob Storage
3. Record metadata (the API will automatically serve the new version)

### Verify Current Snapshot

```bash
# Check what the API is serving
curl https://share.mybartenderai.com/api/v1/snapshots/latest | jq '{version: .snapshotVersion, size: .sizeBytes}'

# Expected output for valid SQLite:
# { "version": "20251217.210721", "size": 172894 }
```

### Force Mobile App Re-sync

```bash
# Clear app data to force fresh download
adb shell pm clear ai.mybartender.mybartenderai
```

### Check PostgreSQL Data

```bash
# Connect to PostgreSQL
PGPASSWORD='<password>' psql -h pg-mybartenderdb.postgres.database.azure.com -U pgadmin -d mybartender

# Check drink count
SELECT COUNT(*) FROM drinks;

# Check recent snapshots
SELECT snapshot_version, size_bytes, created_at
FROM snapshot_metadata
ORDER BY created_at DESC
LIMIT 5;
```

## Future Considerations

1. **Automated Snapshot Builds**: Set up a GitHub Action or Azure DevOps pipeline to run `rebuild-sqlite-snapshot.js` when PostgreSQL data changes

2. **Snapshot Validation**: Add pre-upload validation to verify the blob is valid SQLite before recording metadata

3. **Delta Updates**: For large databases, consider incremental updates instead of full snapshots

4. **CDN Caching**: Snapshots could be cached at Azure Front Door for faster global distribution

---

**Last Updated**: December 18, 2025
**Author**: Claude Code
**Related Docs**:
- `SQLITE_SNAPSHOT_FIX.md` - Historical fix documentation
- `AUTO_SYNC_FIRST_LAUNCH.md` - Mobile app initial sync flow
