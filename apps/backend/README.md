# MyBartenderAI Backend

Azure Functions backend for the MyBartenderAI application.

## Status: OPERATIONAL ✅

All functions are deployed and working on Azure Functions (Windows Consumption Plan).

## Functions

### 1. `snapshots-latest` (HTTP Trigger)
- **Endpoint**: GET `/api/v1/snapshots/latest`
- **Purpose**: Returns metadata and signed URL for the latest cocktail database snapshot
- **Response**: JSON with snapshot version, size, hash, and download URL

### 2. `sync-cocktaildb` (Timer Trigger)
- **Schedule**: Daily at 3:30 AM UTC
- **Purpose**: Syncs cocktail data from TheCocktailDB API to PostgreSQL and creates snapshots
- **Process**:
  1. Fetches all cocktails from TheCocktailDB V2 API
  2. Normalizes and stores in PostgreSQL
  3. Builds compressed JSON snapshot
  4. Uploads to Azure Blob Storage
  5. Records metadata for retrieval

### 3. `recommend` (HTTP Trigger) [Coming Soon]
- **Endpoint**: POST `/api/v1/cocktails/recommend`
- **Purpose**: AI-powered cocktail recommendations

## Architecture Decisions

### JSON Snapshots (ADR-0014)
- Replaced SQLite with JSON snapshots to avoid native module dependencies
- Uses built-in gzip compression (no native modules)
- Mobile app imports JSON into local SQLite
- Reliable cross-platform deployment

### Technology Stack
- **Runtime**: Node.js 20 LTS
- **Azure Functions**: v3 SDK (CommonJS)
- **Database**: PostgreSQL (Azure Database for PostgreSQL)
- **Storage**: Azure Blob Storage
- **Compression**: gzip (built-in Node.js)

## Development

### Prerequisites
- Node.js 20+
- Azure Functions Core Tools v4
- Azure CLI

### Local Development
```bash
# Install dependencies
npm install

# Build TypeScript (Note: Will show errors due to v4 imports in source)
npm run build

# Run locally (requires local.settings.json)
func start
```

### Environment Variables
Create `local.settings.json` (not committed):
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "...",
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "PG_CONNECTION_STRING": "postgresql://...",
    "BLOB_STORAGE_CONNECTION_STRING": "...",
    "COCKTAILDB-API-KEY": "...",
    "OPENAI_API_KEY": "..."
  }
}
```

## Deployment

### Manual Deployment
```bash
# From apps/backend directory
cd deploy
Compress-Archive -Path * -DestinationPath ../deploy.zip -Force
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src ../deploy.zip
```

### CI/CD
GitHub Actions workflows are configured but not yet enabled:
- `.github/workflows/backend-test.yml` - Runs tests on PR
- `.github/workflows/backend-deploy.yml` - Deploys on push to main

## Monitoring

- **Application Insights**: Available in Azure Portal
- **Function Logs**: Use KQL queries in Log Analytics
- **Smoke Test**: Run `.\smoke-check.ps1` from repo root

## Known Issues

None - all systems operational ✅

## Future Enhancements

1. Move API key to Key Vault reference
2. Enable GitHub Actions CI/CD
3. Add comprehensive test coverage
4. Implement recommend endpoint
5. Configure Azure Front Door for image CDN