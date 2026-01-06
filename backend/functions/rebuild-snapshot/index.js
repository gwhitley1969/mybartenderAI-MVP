/**
 * rebuild-snapshot - Rebuild SQLite snapshot from PostgreSQL without syncing from TheCocktailDB
 *
 * This function builds a new mobile app snapshot from the current PostgreSQL database
 * without fetching/syncing from TheCocktailDB. Use this when:
 * - You've made manual changes to the PostgreSQL database (removed bad tags, etc.)
 * - You want to generate a new snapshot without overwriting your curated data
 *
 * HTTP POST /api/admin/rebuild-snapshot
 * Requires function key authentication
 */

const { buildSqliteSnapshot } = require('../services/sqliteSnapshotBuilder');
const { uploadSnapshotArtifacts } = require('../services/snapshotStorageServiceMI');
const { recordSnapshotMetadata } = require('../services/snapshotMetadataService');
const { getPool } = require('../shared/db/postgresPool');

const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(
        date.getUTCHours()
    )}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};

const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION || '1';

module.exports = async function (context, req) {
    const start = Date.now();
    context.log('[rebuild-snapshot] Starting snapshot rebuild (PostgreSQL only, no TheCocktailDB sync)');

    try {
        // Step 1: Get current counts from PostgreSQL for metadata
        const pool = getPool();
        const countsResult = await pool.query(`
            SELECT
                (SELECT COUNT(*) FROM drinks) as drinks,
                (SELECT COUNT(*) FROM ingredients) as ingredients,
                (SELECT COUNT(DISTINCT category) FROM drinks WHERE category IS NOT NULL) as categories,
                (SELECT COUNT(*) FROM tags) as tags
        `);
        const counts = countsResult.rows[0];
        context.log(`[rebuild-snapshot] PostgreSQL stats: ${counts.drinks} drinks, ${counts.categories} categories, ${counts.tags} tags`);

        // Step 2: Build SQLite snapshot from current PostgreSQL data
        const snapshotVersion = formatSnapshotVersion(new Date());
        context.log(`[rebuild-snapshot] Building SQLite snapshot version: ${snapshotVersion}`);

        const snapshot = await buildSqliteSnapshot(snapshotVersion);
        context.log(`[rebuild-snapshot] Built SQLite snapshot: ${snapshot.sizeBytes} bytes, SHA256: ${snapshot.sha256.substring(0, 16)}...`);

        // Step 3: Upload to blob storage using Managed Identity
        context.log('[rebuild-snapshot] Uploading snapshot to blob storage...');
        const uploadResult = await uploadSnapshotArtifacts({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            compressed: snapshot.compressed,
            sha256: snapshot.sha256,
        });
        context.log(`[rebuild-snapshot] Uploaded to: ${uploadResult.blobPath}`);

        // Step 4: Record metadata in PostgreSQL
        await recordSnapshotMetadata({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            blobPath: uploadResult.blobPath,
            sizeBytes: uploadResult.sizeBytes,
            sha256: snapshot.sha256,
            counts: {
                drinks: parseInt(counts.drinks),
                ingredients: parseInt(counts.ingredients),
                categories: parseInt(counts.categories),
                tags: parseInt(counts.tags),
            },
            createdAtUtc: new Date().toISOString(),
        });

        const duration = Date.now() - start;
        context.log(`[rebuild-snapshot] Completed in ${duration}ms`);

        context.res = {
            status: 200,
            body: {
                success: true,
                message: 'Snapshot rebuilt successfully from PostgreSQL',
                snapshotVersion,
                blobPath: uploadResult.blobPath,
                sizeBytes: uploadResult.sizeBytes,
                sha256: snapshot.sha256,
                counts: {
                    drinks: parseInt(counts.drinks),
                    ingredients: parseInt(counts.ingredients),
                    categories: parseInt(counts.categories),
                    tags: parseInt(counts.tags),
                },
                durationMs: duration,
            }
        };

    } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        context.log.error(`[rebuild-snapshot] Failed: ${message}`);
        context.log.error(`[rebuild-snapshot] Stack: ${error.stack}`);

        context.res = {
            status: 500,
            body: {
                success: false,
                error: message,
                traceId: context.invocationId,
            }
        };
    }
};
