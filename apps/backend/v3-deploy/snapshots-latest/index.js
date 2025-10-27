"use strict";
const snapshotMetadataService_1 = require("../services/snapshotMetadataService");
const snapshotStorageService_1 = require("../services/snapshotStorageService");
module.exports = async function (context, req) {
    context.log('[snapshots-latest] Handling request.');
    const metadata = await (0, snapshotMetadataService_1.getLatestSnapshotMetadata)();
    if (!metadata) {
        context.res = {
            status: 503,
            headers: {
                'Content-Type': 'application/json',
            },
            body: {
                code: 'snapshot_unavailable',
                message: 'No snapshot available yet.',
                traceId: context.invocationId,
            },
        };
        return;
    }
    const signedUrl = (0, snapshotStorageService_1.generateSnapshotSas)(metadata.blobPath);
    context.res = {
        status: 200,
        headers: {
            'Content-Type': 'application/json',
        },
        body: {
            schemaVersion: metadata.schemaVersion,
            snapshotVersion: metadata.snapshotVersion,
            sizeBytes: metadata.sizeBytes,
            sha256: metadata.sha256,
            signedUrl,
            createdAtUtc: metadata.createdAtUtc,
            counts: metadata.counts,
        },
    };
};
