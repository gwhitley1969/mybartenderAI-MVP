# MyBartenderAI Backend

Azure Functions backend for MyBartenderAI, providing cocktail data synchronization and AI-powered recommendations.

## Current Status

⚠️ **Migration in Progress**: Migrating from v3 to v4 SDK for Flex Consumption plan compatibility. See [DEPLOYMENT_STATUS.md](../../docs/DEPLOYMENT_STATUS.md) for details.

## Architecture

- **Runtime**: Node.js 18 LTS
- **Framework**: Azure Functions v4 SDK
- **Language**: TypeScript
- **Database**: Azure PostgreSQL
- **Storage**: Azure Blob Storage
- **AI**: OpenAI GPT-4

## Functions

### HTTP Triggers

1. **snapshots-latest** (`GET /api/v1/snapshots/latest`)
   - Returns latest cocktail database snapshot metadata
   - Public endpoint (anonymous auth)

2. **recommend** (`POST /api/v1/recommend`)
   - AI-powered cocktail recommendations
   - Requires function key authentication

3. **download-images** (`POST /api/admin/download-images`)
   - Downloads cocktail images to Azure Blob Storage
   - Admin authentication required

### Timer Triggers

1. **sync-cocktaildb** (`0 30 3 * * *` - Daily at 3:30 AM)
   - Fetches cocktail data from TheCocktailDB API
   - Builds compressed JSON snapshot
   - Uploads to Azure Blob Storage

## Local Development

```bash
# Install dependencies
npm install

# Set up local.settings.json (copy from template)
cp local.settings.template.json local.settings.json

# Build TypeScript
npm run build

# Start Functions locally
npm start
```

## Environment Variables

Required settings in Azure:
- `PG_CONNECTION_STRING`: PostgreSQL connection
- `BLOB_STORAGE_CONNECTION_STRING`: Azure Storage connection
- `COCKTAILDB-API-KEY`: TheCocktailDB API key
- `OPENAI_API_KEY`: OpenAI API key (in Key Vault)

## Deployment

### Current Deployment Target
- **Function App**: func-cocktaildb2
- **Plan**: Flex Consumption (Linux)
- **Region**: South Central US

### Deploy Command
```bash
cd apps/backend/v4-deploy
func azure functionapp publish func-cocktaildb2 --javascript --nozip
```

## Known Issues

1. **Functions Not Loading**: Despite clean v4 structure, Azure Functions host reports "0 functions loaded"
2. **Module Resolution**: Had to fix import paths from `../../../` to `../`
3. **v3/v4 Conflicts**: Removed all function.json files and export statements

## Directory Structure

```
v4-deploy/                    # Clean v4 deployment folder
├── index.js                 # Main entry point
├── package.json            # With "main": "index.js"
├── host.json              # Azure Functions host config
├── [function-name]/       # Each function in its folder
│   └── index.js          # Function implementation
├── services/             # Business logic
├── shared/              # Shared utilities
└── config/             # Configuration
```

## Troubleshooting

### Check Function Status
```bash
func azure functionapp list-functions func-cocktaildb2
```

### View Logs
```bash
az webapp log tail --name func-cocktaildb2 --resource-group rg-mba-prod
```

### Application Insights Queries
```kql
// Check if functions are loading
traces
| where timestamp > ago(5m)
| where message contains "functions loaded"
| project timestamp, message

// View exceptions
exceptions
| where timestamp > ago(10m)
| project timestamp, outerMessage, details
```

## Next Steps

1. Get external review of v4 migration
2. Resolve function discovery issue
3. Test all endpoints once functions load
4. Implement image sync in sync-cocktaildb