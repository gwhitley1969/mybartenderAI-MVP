const { DefaultAzureCredential } = require("@azure/identity");
const { BlobServiceClient } = require("@azure/storage-blob");

module.exports = async function (context, req) {
    context.log('[test-mi-access] Testing Managed Identity access to storage');
    
    const results = {
        timestamp: new Date().toISOString(),
        storageAccount: process.env.STORAGE_ACCOUNT_NAME,
        clientId: process.env.AZURE_CLIENT_ID,
        tests: {}
    };
    
    try {
        // Test 1: Can we create the credential?
        context.log('[test-mi-access] Creating DefaultAzureCredential...');
        const credential = new DefaultAzureCredential({
            managedIdentityClientId: process.env.AZURE_CLIENT_ID || undefined
        });
        results.tests.credentialCreated = true;
        
        // Test 2: Can we create BlobServiceClient?
        context.log('[test-mi-access] Creating BlobServiceClient...');
        const accountName = process.env.STORAGE_ACCOUNT_NAME || 'cocktaildbfun';
        const blobServiceClient = new BlobServiceClient(
            `https://${accountName}.blob.core.windows.net`,
            credential
        );
        results.tests.blobServiceClientCreated = true;
        
        // Test 3: Can we list containers?
        context.log('[test-mi-access] Attempting to list containers...');
        const containers = [];
        try {
            for await (const container of blobServiceClient.listContainers()) {
                containers.push(container.name);
                if (containers.length >= 5) break; // Limit to first 5
            }
            results.tests.listContainers = {
                success: true,
                containers: containers
            };
        } catch (listError) {
            results.tests.listContainers = {
                success: false,
                error: listError.message,
                code: listError.code
            };
        }
        
        // Test 4: Can we access the snapshots container?
        context.log('[test-mi-access] Accessing snapshots container...');
        const containerName = process.env.SNAPSHOT_CONTAINER_NAME || 'snapshots';
        const containerClient = blobServiceClient.getContainerClient(containerName);
        
        try {
            const exists = await containerClient.exists();
            results.tests.snapshotsContainer = {
                success: true,
                exists: exists
            };
            
            // Test 5: Can we list blobs in the container?
            if (exists) {
                context.log('[test-mi-access] Listing blobs in snapshots container...');
                const blobs = [];
                for await (const blob of containerClient.listBlobsFlat({ maxPageSize: 5 })) {
                    blobs.push(blob.name);
                    if (blobs.length >= 5) break;
                }
                results.tests.listBlobs = {
                    success: true,
                    blobCount: blobs.length,
                    sampleBlobs: blobs
                };
            }
        } catch (containerError) {
            results.tests.snapshotsContainer = {
                success: false,
                error: containerError.message,
                code: containerError.code
            };
        }
        
        // Test 6: Can we get a User Delegation Key?
        context.log('[test-mi-access] Attempting to get User Delegation Key...');
        try {
            const now = new Date();
            const startsOn = new Date(now.getTime() - 5 * 60 * 1000);
            const expiresOn = new Date(now.getTime() + 60 * 60 * 1000);
            
            const userDelegationKey = await blobServiceClient.getUserDelegationKey(
                startsOn,
                expiresOn
            );
            
            results.tests.userDelegationKey = {
                success: true,
                keyId: userDelegationKey.signedObjectId,
                signedTenantId: userDelegationKey.signedTenantId,
                signedService: userDelegationKey.signedService,
                signedVersion: userDelegationKey.signedVersion
            };
        } catch (keyError) {
            results.tests.userDelegationKey = {
                success: false,
                error: keyError.message,
                code: keyError.code,
                statusCode: keyError.statusCode
            };
        }
        
        context.res = {
            status: 200,
            body: results
        };
        
    } catch (error) {
        context.log.error('[test-mi-access] Error:', error);
        
        results.error = {
            message: error.message,
            code: error.code,
            stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
        };
        
        context.res = {
            status: 500,
            body: results
        };
    }
};
