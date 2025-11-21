const { CocktailDbClient } = require('../services/cocktailDbClient');
const { syncCocktailCatalog } = require('../services/cocktailDbSyncService');
const { buildJsonSnapshot } = require('../services/jsonSnapshotBuilder');
const { uploadSnapshotArtifacts } = require('../services/snapshotStorageServiceMI'); // Use MI version
const { recordSnapshotMetadata } = require('../services/snapshotMetadataService');

const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(
        date.getUTCHours()
    )}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};

const getCocktailApiKey = async (context, maxRetries = 5) => {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
        const value = process.env['COCKTAILDB-API-KEY'];
        if (value && !value.startsWith('@Microsoft.KeyVault')) {
            return value;
        }
        
        if (attempt < maxRetries) {
            context.log(`[sync-cocktaildb-mi] Waiting for Key Vault reference to resolve (attempt ${attempt}/${maxRetries})...`);
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    throw new Error('COCKTAILDB-API-KEY environment variable is required or Key Vault reference did not resolve.');
};

const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION || '1';

module.exports = async function (context, myTimer) {
    const start = Date.now();
    context.log(`[sync-cocktaildb-mi] Starting synchronization with Managed Identity at ${new Date().toISOString()}`);
    
    if (myTimer.isPastDue) {
        context.log('[sync-cocktaildb-mi] Timer trigger is past due!');
    }
    
    try {
        // Get API key with retry logic for Key Vault references
        const apiKey = await getCocktailApiKey(context);
        const client = new CocktailDbClient(apiKey);
        
        // Fetch cocktail catalog
        const drinks = await client.fetchCatalog();
        context.log(`[sync-cocktaildb-mi] Retrieved ${drinks.length} drinks.`);
        
        // Sync to PostgreSQL
        const counts = await syncCocktailCatalog(drinks);
        context.log('[sync-cocktaildb-mi] Normalized data into PostgreSQL tables.');
        
        // Build snapshot
        const snapshotVersion = formatSnapshotVersion(new Date());
        const snapshot = await buildJsonSnapshot();
        context.log('[sync-cocktaildb-mi] Built JSON snapshot.');
        
        // Upload to blob storage using Managed Identity
        context.log('[sync-cocktaildb-mi] Uploading snapshot using Managed Identity...');
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
        
        context.log(`[sync-cocktaildb-mi] Completed in ${Date.now() - start}ms; snapshot=${uploadResult.blobPath}`);
        context.log('[sync-cocktaildb-mi] Successfully used Managed Identity for blob storage operations.');
        
    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        context.log.error(`[sync-cocktaildb-mi] Sync failed: ${message}`);
        
        // Log specific MI-related errors
        if (message.includes('DefaultAzureCredential') || message.includes('ManagedIdentityCredential')) {
            context.log.error('[sync-cocktaildb-mi] Managed Identity authentication failed. Ensure the identity has proper roles assigned.');
        }
        
        throw error;
    }
};
