# ADR-0014: Replace SQLite Generation with JSON Snapshots

**Date:** 2025-10-14  
**Status:** Accepted  
**Deciders:** Development team

## Context

During deployment to Azure Functions (Windows Consumption plan), we encountered persistent issues with `better-sqlite3`, a native Node.js module that requires platform-specific binaries. The error "better_sqlite3.node is not a valid Win32 application" blocked our deployment pipeline.

Additionally, we discovered:
- TheCocktailDB already provides data in JSON format
- Mobile app can import JSON to local SQLite
- Native dependencies complicate CI/CD pipelines
- Windows Functions are more stable than Linux Consumption (which is being retired)

## Decision

We will:
1. **Remove all native dependencies** (better-sqlite3)
2. **Generate JSON snapshots** instead of SQLite files
3. **Use gzip compression** (built-in) instead of zstd
4. **Keep PostgreSQL** as authoritative store for AI enhancements
5. **Re-host cocktail images** in Azure Blob + Front Door

## Consequences

### Positive
- ✅ No platform-specific build issues
- ✅ Simpler deployment pipeline
- ✅ Works on any Azure Functions OS
- ✅ Easier debugging (JSON is readable)
- ✅ Smaller codebase
- ✅ CI/CD friendly

### Negative
- ❌ Slightly larger snapshots (~2MB JSON vs ~1MB SQLite)
- ❌ Mobile app needs JSON import logic
- ❌ Initial parse is slower than SQLite

### Neutral
- Mobile app still uses SQLite locally (no change to offline experience)
- Compression ratio: gzip (70%) vs zstd (80%) - acceptable tradeoff

## Implementation

1. Created `jsonSnapshotBuilder.ts` to replace `sqliteSnapshotBuilder.ts`
2. Updated `sync-cocktaildb` function to use JSON builder
3. Removed better-sqlite3 from package.json
4. Mobile app will parse JSON and import to local SQLite

## Alternatives Considered

1. **Linux App Service Plan**: More expensive, Linux Consumption being retired
2. **Docker containers**: Overkill for simple functions
3. **Different SQLite library**: All have native dependencies
4. **Direct CocktailDB access**: No offline support, UK-based latency

## Related

- ADR-0013: Drop APIM, use direct Functions
- ADR-0008: CocktailDB V2 mirror strategy
