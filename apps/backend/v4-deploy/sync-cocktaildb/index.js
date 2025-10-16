"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions_1 = require("@azure/functions");
const cocktailDbClient_js_1 = require("../../services/cocktailDbClient.js");
const cocktailDbSyncService_js_1 = require("../../services/cocktailDbSyncService.js");
const jsonSnapshotBuilder_js_1 = require("../../services/jsonSnapshotBuilder.js");
const snapshotStorageService_js_1 = require("../../services/snapshotStorageService.js");
const snapshotMetadataService_js_1 = require("../../services/snapshotMetadataService.js");
const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, "0");
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
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
const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION ?? '1';
const syncCocktailDb = async (timer, context) => {
    const start = Date.now();
    context.log(`[sync-cocktaildb] Starting synchronization at ${new Date().toISOString()}`);
    try {
        const apiKey = await getCocktailApiKey(context);
        const client = new cocktailDbClient_js_1.CocktailDbClient(apiKey);
        const drinks = await client.fetchCatalog();
        context.log(`[sync-cocktaildb] Retrieved ${drinks.length} drinks.`);
        const counts = await (0, cocktailDbSyncService_js_1.syncCocktailCatalog)(drinks);
        context.log('[sync-cocktaildb] Normalized data into PostgreSQL tables.');
        const snapshotVersion = formatSnapshotVersion(new Date());
        const snapshot = await (0, jsonSnapshotBuilder_js_1.buildJsonSnapshot)();
        context.log('[sync-cocktaildb] Built JSON snapshot.');
        const uploadResult = await (0, snapshotStorageService_js_1.uploadSnapshotArtifacts)({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            compressed: snapshot.compressed,
            sha256: snapshot.sha256,
        });
        await (0, snapshotMetadataService_js_1.recordSnapshotMetadata)({
            schemaVersion: SCHEMA_VERSION,
            snapshotVersion,
            blobPath: uploadResult.blobPath,
            sizeBytes: uploadResult.sizeBytes,
            sha256: snapshot.sha256,
            counts,
            createdAtUtc: new Date().toISOString(),
        });
        context.log(`[sync-cocktaildb] Completed in ${Date.now() - start}ms; snapshot=${uploadResult.blobPath}`);
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        context.log(`[sync-cocktaildb] Failed: ${message}`);
        throw error;
    }
};
functions_1.app.timer('sync-cocktaildb', {
    schedule: '0 30 3 * * *',
    handler: syncCocktailDb,
});
