const { getLatestSnapshotMetadata } = require('../services/snapshotMetadataService');
const { generateSnapshotSas } = require('../services/snapshotStorageServiceMI');

module.exports = async function (context, req) {
    context.log('[snapshots/latest-mi] Handling request using Managed Identity.');
    
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
        
        // Generate SAS using Managed Identity (User Delegation SAS)
        const signedUrl = await generateSnapshotSas(metadata.blobPath);
        
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
                // Include a flag to indicate this is using MI
                authMethod: 'managed-identity'
            }
        };
    } catch (error) {
        context.log.error('[snapshots/latest-mi] Error:', error);
        context.log.error('[snapshots/latest-mi] Error stack:', error.stack);
        context.log.error('[snapshots/latest-mi] Error details:', {
            message: error.message,
            code: error.code,
            statusCode: error.statusCode,
            details: error.details
        });
        
        // More detailed error for troubleshooting MI issues
        let errorMessage = 'An unexpected error occurred.';
        let errorCode = 'internal_error';
        
        if (error.message?.includes('Delegator')) {
            errorMessage = 'Managed Identity needs Storage Blob Delegator role for SAS generation.';
            errorCode = 'missing_delegator_role';
        } else if (error.message?.includes('STORAGE_ACCOUNT_NAME')) {
            errorMessage = 'Storage account name not configured.';
            errorCode = 'missing_configuration';
        } else if (error.message?.includes('DefaultAzureCredential') || error.message?.includes('authentication')) {
            errorMessage = 'Managed Identity authentication failed. Ensure identity is assigned to Function App.';
            errorCode = 'auth_failed';
        }
        
        context.res = {
            status: 500,
            body: {
                code: errorCode,
                message: errorMessage,
                details: error.message, // Always show details for debugging MI issues
                traceId: context.invocationId,
                storageAccount: process.env.STORAGE_ACCOUNT_NAME,
                clientId: process.env.AZURE_CLIENT_ID
            }
        };
    }
};
