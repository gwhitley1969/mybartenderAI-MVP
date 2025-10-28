# Azure Functions v3 Deployment

This directory contains Azure Functions using v3 SDK patterns for deployment to Windows Consumption plan.

## Functions

### 1. snapshots-latest
- **Type**: HTTP Trigger
- **Route**: GET /api/v1/snapshots/latest
- **Auth**: Anonymous
- **Description**: Returns the latest cocktail database snapshot metadata with a signed URL for downloading

### 2. recommend
- **Type**: HTTP Trigger
- **Route**: POST /api/v1/recommend
- **Auth**: Function + JWT
- **Description**: AI-powered cocktail recommendations based on inventory and taste profile
- **Features**:
  - JWT authentication for user identification
  - Rate limiting per user/IP
  - Token quota enforcement
  - OpenAI integration with lazy initialization

### 3. download-images
- **Type**: HTTP Trigger
- **Route**: POST /api/v1/admin/download-images
- **Auth**: Admin
- **Description**: Downloads cocktail images from TheCocktailDB and stores them in Azure Blob Storage
- **Features**:
  - Downloads images only if not already present
  - Updates database with new blob URLs
  - Returns summary of operations

### 4. sync-cocktaildb
- **Type**: Timer Trigger
- **Schedule**: Daily at 3:30 AM UTC (0 30 3 * * *)
- **Description**: Syncs cocktail data from TheCocktailDB API and creates snapshots
- **Features**:
  - Fetches complete cocktail catalog
  - Syncs to PostgreSQL database
  - Builds SQLite snapshot using sql.js (pure JavaScript, no native deps)
  - Compresses with Zstandard (.zst)
  - Sets `user_version = 1` pragma for sqflite compatibility
  - Uploads to blob storage with SHA256 hash
  - Records metadata with snapshot version

### 5. health
- **Type**: HTTP Trigger
- **Route**: GET /api/health
- **Auth**: Anonymous
- **Description**: Simple health check endpoint

## Deployment

```bash
# From this directory
func azure functionapp publish func-mba-fresh --javascript

# Or using zip deployment
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src deployment.zip
```

## Environment Variables Required

- `BLOB_STORAGE_CONNECTION_STRING`
- `PG_CONNECTION_STRING` or `POSTGRES_CONNECTION_STRING`
- `SNAPSHOT_CONTAINER_NAME`
- `OPENAI_API_KEY`
- `COCKTAILDB-API-KEY`
- `APPINSIGHTS_INSTRUMENTATIONKEY`
- `APPLICATIONINSIGHTS_CONNECTION_STRING`

## Key Differences from v4

1. Each function has a `function.json` file defining bindings
2. Functions use `module.exports = async function(context, req/timer)`
3. HTTP responses use `context.res = { status, body }`
4. Timer functions receive `myTimer` parameter
5. All imports use CommonJS `require()` syntax

## Important Notes

### SQLite Snapshot Generation

The snapshot builder uses **sql.js** (pure JavaScript SQLite) instead of native libraries like better-sqlite3. This is required for Azure Functions Windows Consumption plan compatibility.

**Critical**: When setting PRAGMA statements in sql.js, use `db.exec()` instead of `db.run()`:

```javascript
// ✅ CORRECT - Pragma persists to exported binary
db.exec('PRAGMA user_version = 1');

// ❌ WRONG - Pragma does not persist
db.run('PRAGMA user_version = 1');
```

The `user_version` pragma is essential for Flutter's sqflite to recognize the database as initialized. Without it, sqflite will attempt to recreate tables that already exist in the snapshot, causing errors.

See [SQLITE_SNAPSHOT_FIX.md](../../../SQLITE_SNAPSHOT_FIX.md) for details about this fix.
