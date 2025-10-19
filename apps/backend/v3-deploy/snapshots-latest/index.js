const { getLatestSnapshotMetadata } = require('../services/snapshotMetadataService');
const { generateSnapshotSas } = require('../services/snapshotStorageService');

module.exports = async function (context, req) {
    context.log('[snapshots/latest] Handling request.');
    
    try {
        const metadata = await getLatestSnapshotMetadata();
        
        if (!metadata) {
            context.res = {
                status: 503,
                body: {
                    code: 'snapshot_unavailable',
                    message: 'No snapshot available yet.',
                    traceId: context.invocationId,
                }
            };
            return;
        }
        
        const signedUrl = generateSnapshotSas(metadata.blobPath);
        
        context.res = {
            status: 200,
            body: {
                schemaVersion: metadata.schemaVersion,
                snapshotVersion: metadata.snapshotVersion,
                sizeBytes: metadata.sizeBytes,
                sha256: metadata.sha256,
                signedUrl,
                createdAtUtc: metadata.createdAtUtc,
                counts: metadata.counts,
            }
        };
    } catch (error) {
        context.log.error('[snapshots/latest] Error:', error);
        context.res = {
            status: 500,
            body: {
                code: 'internal_error',
                message: 'An unexpected error occurred.',
                traceId: context.invocationId,
            }
        };
    }
};
