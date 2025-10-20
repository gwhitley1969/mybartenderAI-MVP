const { BlobServiceClient } = require('@azure/storage-blob');
const { DefaultAzureCredential } = require('@azure/identity');

module.exports = async function (context, req) {
    context.log('[test-write] Testing blob write with Managed Identity');
    
    try {
        // Get storage account name
        const accountName = process.env.STORAGE_ACCOUNT_NAME || 'mbacocktaildb3';
        const containerName = 'test-writes';
        
        // Create BlobServiceClient with Managed Identity
        const credential = new DefaultAzureCredential({
            managedIdentityClientId: process.env.AZURE_CLIENT_ID || undefined
        });
        
        const blobServiceClient = new BlobServiceClient(
            `https://${accountName}.blob.core.windows.net`,
            credential
        );
        
        // Get container client
        const containerClient = blobServiceClient.getContainerClient(containerName);
        
        // Create container if it doesn't exist
        context.log(`[test-write] Creating container if needed: ${containerName}`);
        await containerClient.createIfNotExists();
        
        // Write a test blob
        const testContent = JSON.stringify({
            timestamp: new Date().toISOString(),
            message: 'Test write from Managed Identity',
            functionName: 'test-write',
            storageAccount: accountName,
            clientId: process.env.AZURE_CLIENT_ID
        });
        
        const blobName = `test-${Date.now()}.json`;
        const blockBlobClient = containerClient.getBlockBlobClient(blobName);
        
        context.log(`[test-write] Writing blob: ${blobName}`);
        await blockBlobClient.upload(testContent, testContent.length, {
            blobHTTPHeaders: {
                blobContentType: 'application/json'
            }
        });
        
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
                clientId: process.env.AZURE_CLIENT_ID
            }
        };
        
    } catch (error) {
        context.log.error('[test-write] Error:', error);
        
        let errorMessage = 'Failed to write to blob storage';
        let errorCode = 'write_failed';
        
        if (error.message?.includes('DefaultAzureCredential') || error.message?.includes('ManagedIdentityCredential')) {
            errorMessage = 'Managed Identity authentication failed';
            errorCode = 'auth_failed';
        } else if (error.message?.includes('403')) {
            errorMessage = 'Access denied - Managed Identity needs Storage Blob Data Contributor role';
            errorCode = 'access_denied';
        }
        
        context.res = {
            status: 500,
            body: {
                error: errorCode,
                message: errorMessage,
                details: error.message,
                storageAccount: accountName,
                clientId: process.env.AZURE_CLIENT_ID
            }
        };
    }
};
