"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions_1 = require("@azure/functions");
const cocktailDbClient_js_1 = require("../services/cocktailDbClient.js");
const cocktailDbSyncService_js_1 = require("../services/cocktailDbSyncService.js");
const jsonSnapshotBuilder_js_1 = require("../services/jsonSnapshotBuilder.js");
const snapshotStorageService_js_1 = require("../services/snapshotStorageService.js");
const snapshotMetadataService_js_1 = require("../services/snapshotMetadataService.js");
const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, "0");
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(date.getUTCHours())}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};
const getCocktailApiKey = () => {
    const value = process.env['COCKTAILDB-API-KEY'];
    if (!value) {
        throw new Error('COCKTAILDB-API-KEY environment variable is required.');
    }
    return value;
};
const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION ?? '1';
const syncCocktailDb = async (timer, context) => {
    const start = Date.now();
    context.log(`[sync-cocktaildb] Starting synchronization at ${new Date().toISOString()}`);
    try {
        const client = new cocktailDbClient_js_1.CocktailDbClient(getCocktailApiKey());
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





