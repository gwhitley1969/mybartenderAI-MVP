"use strict";
const snapshotMetadataService_1 = require("../services/snapshotMetadataService");
const snapshotStorageService_1 = require("../services/snapshotStorageService");
module.exports = async function (context, req) {
    context.log('[snapshots-latest] Handling request.');

    try {
        const metadata = await (0, snapshotMetadataService_1.getLatestSnapshotMetadata)();
        if (!metadata) {
            return {
                status: 503,
                headers: {
                    'Content-Type': 'application/json',
                },
                jsonBody: {
                    code: 'snapshot_unavailable',
                    message: 'No snapshot available yet.',
                    traceId: context.invocationId,
                },
            };
        }
        const signedUrl = (0, snapshotStorageService_1.generateSnapshotSas)(metadata.blobPath);
        return {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
            },
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
    } catch (error) {
        context.log.error('[snapshots-latest] Error:', error);
        return {
            status: 500,
            headers: {
                'Content-Type': 'application/json',
            },
            jsonBody: {
                code: 'internal_error',
                message: 'Failed to retrieve snapshot metadata.',
                error: error.message,
                traceId: context.invocationId,
            },
        };
    }
};
