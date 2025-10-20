const { BlobServiceClient } = require('@azure/storage-blob');
const { DefaultAzureCredential } = require('@azure/identity');

module.exports = async function (context, req) {
    context.log('[test-write] Testing blob write with Managed Identity');

    // Diagnostic information
    const diagnostics = {
        envVars: {
            STORAGE_ACCOUNT_NAME: process.env.STORAGE_ACCOUNT_NAME || 'NOT SET',
            AZURE_CLIENT_ID: process.env.AZURE_CLIENT_ID || 'NOT SET',
            SNAPSHOT_CONTAINER_NAME: process.env.SNAPSHOT_CONTAINER_NAME || 'NOT SET'
        },
        timestamp: new Date().toISOString()
    };

    context.log('[test-write] Environment check:', diagnostics.envVars);

    try {
        // Validate required environment variables
        const accountName = process.env.STORAGE_ACCOUNT_NAME;
        if (!accountName) {
            throw new Error('STORAGE_ACCOUNT_NAME environment variable is required but not set. Please configure it in Function App settings.');
        }

        const containerName = 'test-writes';

        // Log credential configuration
        const clientId = process.env.AZURE_CLIENT_ID;
        context.log(`[test-write] Using Managed Identity${clientId ? ` with Client ID: ${clientId}` : ' (system-assigned)'}`);

        // Create BlobServiceClient with Managed Identity
        const credential = new DefaultAzureCredential({
            managedIdentityClientId: clientId || undefined
        });

        const blobServiceClient = new BlobServiceClient(
            `https://${accountName}.blob.core.windows.net`,
            credential
        );

        // Get container client
        const containerClient = blobServiceClient.getContainerClient(containerName);

        // Create container if it doesn't exist
        context.log(`[test-write] Creating container if needed: ${containerName}`);
        const createResult = await containerClient.createIfNotExists();
        context.log(`[test-write] Container status: ${createResult.succeeded ? 'created' : 'already exists'}`);

        // Write a test blob
        const testContent = JSON.stringify({
            timestamp: new Date().toISOString(),
            message: 'Test write from Managed Identity',
            functionName: 'test-write',
            storageAccount: accountName,
            clientId: clientId || 'system-assigned',
            diagnostics: diagnostics
        }, null, 2);

        const blobName = `test-${Date.now()}.json`;
        const blockBlobClient = containerClient.getBlockBlobClient(blobName);

        context.log(`[test-write] Writing blob: ${blobName}`);
        const uploadResult = await blockBlobClient.upload(testContent, testContent.length, {
            blobHTTPHeaders: {
                blobContentType: 'application/json'
            }
        });

        context.log(`[test-write] Upload successful! ETag: ${uploadResult.etag}`);

        context.res = {
            status: 200,
            body: {
                success: true,
                message: 'Successfully wrote to blob storage using Managed Identity',
                storageAccount: accountName,
                container: containerName,
                blob: blobName,
                url: blockBlobClient.url,
                authMethod: 'managed-identity',
                clientId: clientId || 'system-assigned',
                uploadETag: uploadResult.etag,
                diagnostics: diagnostics
            }
        };

    } catch (error) {
        context.log.error('[test-write] Error:', error);
        context.log.error('[test-write] Error stack:', error.stack);

        let errorMessage = 'Failed to write to blob storage';
        let errorCode = 'write_failed';
        let suggestions = [];

        if (error.message?.includes('STORAGE_ACCOUNT_NAME')) {
            errorMessage = 'Missing STORAGE_ACCOUNT_NAME environment variable';
            errorCode = 'missing_config';
            suggestions.push('Set STORAGE_ACCOUNT_NAME=mbacocktaildb3 in Function App settings');
        } else if (error.message?.includes('DefaultAzureCredential') || error.message?.includes('ManagedIdentityCredential')) {
            errorMessage = 'Managed Identity authentication failed';
            errorCode = 'auth_failed';
            suggestions.push('Ensure the managed identity is assigned to the Function App');
            suggestions.push('Check that AZURE_CLIENT_ID is set to: 94d9cf74-99a3-49d5-9be4-98ce2eae1d33');
        } else if (error.message?.includes('403') || error.statusCode === 403) {
            errorMessage = 'Access denied - Managed Identity lacks required permissions';
            errorCode = 'access_denied';
            suggestions.push('Assign "Storage Blob Data Contributor" role to the managed identity');
            suggestions.push('Run: az role assignment create --assignee 94d9cf74-99a3-49d5-9be4-98ce2eae1d33 --role "Storage Blob Data Contributor" --scope /subscriptions/YOUR_SUB/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/mbacocktaildb3');
        } else if (error.message?.includes('404')) {
            errorMessage = 'Storage account not found';
            errorCode = 'not_found';
            suggestions.push('Verify storage account name is correct: mbacocktaildb3');
            suggestions.push('Check that the storage account exists in the same subscription');
        }

        context.res = {
            status: 500,
            body: {
                error: errorCode,
                message: errorMessage,
                details: error.message,
                statusCode: error.statusCode,
                storageAccount: process.env.STORAGE_ACCOUNT_NAME || 'NOT SET',
                clientId: process.env.AZURE_CLIENT_ID || 'NOT SET',
                suggestions: suggestions,
                diagnostics: diagnostics
            }
        };
    }
};
