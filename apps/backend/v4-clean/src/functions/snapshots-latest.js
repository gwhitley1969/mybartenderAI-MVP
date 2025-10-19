"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const functions_1 = require("@azure/functions");
const snapshotMetadataService_js_1 = require("../../services/snapshotMetadataService.js");
const snapshotStorageService_js_1 = require("../../services/snapshotStorageService.js");
async function snapshotsLatest(request, context) {
    context.log('[snapshots/latest] Handling request.');
    const metadata = await (0, snapshotMetadataService_js_1.getLatestSnapshotMetadata)();
    if (!metadata) {
        return {
            status: 503,
            jsonBody: {
                code: 'snapshot_unavailable',
                message: 'No snapshot available yet.',
                traceId: context.invocationId,
            },
        };
    }
    const signedUrl = (0, snapshotStorageService_js_1.generateSnapshotSas)(metadata.blobPath);
    return {
        status: 200,
        jsonBody: {
            schemaVersion: metadata.schemaVersion,
            snapshotVersion: metadata.snapshotVersion,
            sizeBytes: metadata.sizeBytes,
            sha256: metadata.sha256,
            signedUrl,
            createdAtUtc: metadata.createdAtUtc,
            counts: metadata.counts,
        },
    };
}
functions_1.app.http('snapshots-latest', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'v1/snapshots/latest',
    handler: snapshotsLatest,
});


