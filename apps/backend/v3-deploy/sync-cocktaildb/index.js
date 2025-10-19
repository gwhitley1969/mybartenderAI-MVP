const { CocktailDbClient } = require('../services/cocktailDbClient');
const { syncCocktailCatalog } = require('../services/cocktailDbSyncService');
const { buildJsonSnapshot } = require('../services/jsonSnapshotBuilder');
const { uploadSnapshotArtifacts } = require('../services/snapshotStorageService');
const { recordSnapshotMetadata } = require('../services/snapshotMetadataService');

const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(
        date.getUTCHours()
    )}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};

const getCocktailApiKey = async (context, maxRetries = 5) => {
    for (let i = 0; i < maxRetries; i++) {
        const value = process.env['COCKTAILDB-API-KEY'];
        if (value) {
            return value;
        }
        
        if (i < maxRetries - 1) {
            context.log(`[sync-cocktaildb] Waiting for COCKTAILDB-API-KEY to be available from Key Vault (attempt ${i + 1}/${maxRetries})...`);
            await new Promise(resolve => setTimeout(resolve, 2000)); // Wait 2 seconds
        }
    }
    
    throw new Error('COCKTAILDB-API-KEY environment variable is required but not available after retries.');
};

const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION || '1';

module.exports = async function (context, myTimer) {
    const start = Date.now();
    context.log(`[sync-cocktaildb] Starting synchronization at ${new Date().toISOString()}`);
    
    if (myTimer.isPastDue) {
        context.log('[sync-cocktaildb] Timer trigger is past due!');
    }
    
    try {
        // Get API key with retry logic for Key Vault references
        const apiKey = await getCocktailApiKey(context);
        const client = new CocktailDbClient(apiKey);
        
        // Fetch cocktail catalog
        const drinks = await client.fetchCatalog();
        context.log(`[sync-cocktaildb] Retrieved ${drinks.length} drinks.`);
        
        // Sync to PostgreSQL
        const counts = await syncCocktailCatalog(drinks);
        context.log('[sync-cocktaildb] Normalized data into PostgreSQL tables.');
        
        // Build snapshot
        const snapshotVersion = formatSnapshotVersion(new Date());
        const snapshot = await buildJsonSnapshot();
        context.log('[sync-cocktaildb] Built JSON snapshot.');
        
        // Upload to blob storage
        const uploadResult = await uploadSnapshotArtifacts({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            compressed: snapshot.compressed,
            sha256: snapshot.sha256,
        });
        
        // Record metadata
        await recordSnapshotMetadata({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            blobPath: uploadResult.blobPath,
            sizeBytes: uploadResult.sizeBytes,
            sha256: snapshot.sha256,
            counts,
            createdAtUtc: new Date().toISOString(),
        });
        
        context.log(`[sync-cocktaildb] Completed in ${Date.now() - start}ms; snapshot=${uploadResult.blobPath}`);
        
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        context.log.error(`[sync-cocktaildb] Failed: ${message}`);
        throw error;
    }
};
