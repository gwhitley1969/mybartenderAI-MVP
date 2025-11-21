const { DefaultAzureCredential } = require("@azure/identity");
const { 
    BlobServiceClient, 
    BlobSASPermissions, 
    generateBlobSASQueryParameters,
    SASProtocol
} = require("@azure/storage-blob");
const path = require("path");

// Environment variables
const getRequiredEnv = (key) => {
    const value = process.env[key];
    if (!value) {
        throw new Error(`${key} environment variable is required.`);
    }
    return value;
};

// Get storage account name from environment or extract from old connection string
const getStorageAccountName = () => {
    if (!process.env.STORAGE_ACCOUNT_NAME) {
        throw new Error('STORAGE_ACCOUNT_NAME environment variable is required when using Managed Identity.');
    }
    return process.env.STORAGE_ACCOUNT_NAME;
};

// Lazy initialization of BlobServiceClient with Managed Identity
let blobServiceClient = null;
const getBlobServiceClient = () => {
    if (!blobServiceClient) {
        const accountName = getStorageAccountName();
        const credential = new DefaultAzureCredential({
            // Use the specific managed identity if AZURE_CLIENT_ID is set
            managedIdentityClientId: process.env.AZURE_CLIENT_ID || undefined
        });
        
        blobServiceClient = new BlobServiceClient(
            `https://${accountName}.blob.core.windows.net`,
            credential
        );
    }
    return blobServiceClient;
};

const getContainerClient = () => {
    const containerName = getRequiredEnv("SNAPSHOT_CONTAINER_NAME");
    return getBlobServiceClient().getContainerClient(containerName);
};

// Upload snapshot artifacts using Managed Identity
const uploadSnapshotArtifacts = async (args) => {
    const containerClient = getContainerClient();
    
    // Create container if it doesn't exist
    await containerClient.createIfNotExists();
    
    // Upload compressed snapshot
    const blobPath = path.posix.join('snapshots', 'sqlite', args.schemaVersion, `${args.snapshotVersion}.db.zst`);
    const blobClient = containerClient.getBlockBlobClient(blobPath);
    await blobClient.uploadData(args.compressed, {
        blobHTTPHeaders: {
            blobContentType: 'application/octet-stream',
        },
    });
    
    // Upload SHA256 checksum
    const shaPath = `${blobPath}.sha256`;
    const shaBlobClient = containerClient.getBlockBlobClient(shaPath);
    await shaBlobClient.uploadData(Buffer.from(args.sha256, 'utf-8'), {
        blobHTTPHeaders: {
            blobContentType: 'text/plain',
        },
    });
    
    return {
        blobPath,
        sizeBytes: args.compressed.byteLength,
    };
};

// Generate User Delegation SAS using Managed Identity
const generateSnapshotSas = async (blobPath, expiresInMinutes = Number(process.env.SNAPSHOT_SAS_TTL_MINUTES ?? '15')) => {
    const containerClient = getContainerClient();
    const blobClient = containerClient.getBlockBlobClient(blobPath);
    
    // Get user delegation key (valid for up to 7 days)
    const now = new Date();
    const startsOn = new Date(now.getTime() - 5 * 60 * 1000); // 5 minutes ago to handle clock skew
    const expiresOn = new Date(now.getTime() + expiresInMinutes * 60 * 1000);
    
    try {
        // Get user delegation key from Azure AD
        const userDelegationKey = await getBlobServiceClient().getUserDelegationKey(
            startsOn,
            expiresOn
        );
        
        // Generate SAS token using user delegation key
        const sasToken = generateBlobSASQueryParameters({
            containerName: containerClient.containerName,
            blobName: blobPath,
            permissions: BlobSASPermissions.parse('r'), // read-only
            startsOn,
            expiresOn,
            protocol: SASProtocol.Https,
        }, userDelegationKey, getStorageAccountName());
        
        return `${blobClient.url}?${sasToken.toString()}`;
    } catch (error) {
        console.error('Error generating user delegation SAS:', error);
        throw new Error('Failed to generate SAS token. Ensure the managed identity has the "Storage Blob Delegator" role.');
    }
};

module.exports = {
    uploadSnapshotArtifacts,
    generateSnapshotSas
};
