const { CocktailDbClient } = require('../services/cocktailDbClient');
const { syncCocktailCatalog } = require('../services/cocktailDbSyncService');
const { buildSqliteSnapshot } = require('../services/sqliteSnapshotBuilder');
const { uploadSnapshotArtifacts } = require('../services/snapshotStorageService');
const { recordSnapshotMetadata } = require('../services/snapshotMetadataService');

const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(
        date.getUTCHours()
    )}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};

const getCocktailApiKey = () => {
    const value = process.env['COCKTAILDB-API-KEY'];
    if (!value) {
        throw new Error('COCKTAILDB-API-KEY environment variable is required.');
    }
    return value;
};

const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION || '1';

module.exports = async function (context, myTimer) {
    const start = Date.now();
    context.log(`[sync-cocktaildb] Starting synchronization at ${new Date().toISOString()}`);

    if (myTimer.isPastDue) {
        context.log('[sync-cocktaildb] Timer trigger is past due!');
    }

    try {
        const apiKey = getCocktailApiKey();
        const client = new CocktailDbClient(apiKey);

        const drinks = await client.fetchCatalog();
        context.log(`[sync-cocktaildb] Retrieved ${drinks.length} drinks.`);

        const counts = await syncCocktailCatalog(drinks);
        context.log('[sync-cocktaildb] Normalized data into PostgreSQL tables.');

        const snapshotVersion = formatSnapshotVersion(new Date());
        const snapshot = await buildSqliteSnapshot(snapshotVersion);
        context.log('[sync-cocktaildb] Built SQLite snapshot.');

        const uploadResult = await uploadSnapshotArtifacts({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            compressed: snapshot.compressed,
            sha256: snapshot.sha256,
        });

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
