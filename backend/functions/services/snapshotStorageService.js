// Signs read-only download links for snapshot blobs in mbacocktaildb3.
//
// Uses the Function App's managed identity (no account key): the link is a
// user delegation SAS. The identity needs a data role on the storage account
// that grants blob read and generateUserDelegationKey; Storage Blob Data
// Contributor covers both. See docs/STORAGE_MANAGED_IDENTITY.md.
//
// Snapshots are written by rebuild-sqlite-snapshot.js from a developer
// machine, not by the Function App.
const { DefaultAzureCredential } = require('@azure/identity');
const {
    BlobServiceClient,
    BlobSASPermissions,
    SASProtocol,
    generateBlobSASQueryParameters
} = require('@azure/storage-blob');

const DEFAULT_ACCOUNT_NAME = 'mbacocktaildb3';
const DEFAULT_CONTAINER_NAME = 'snapshots';
const CLOCK_SKEW_MS = 5 * 60 * 1000;
// One key signs many links; fetch a new one well before it runs out.
const KEY_LIFETIME_MS = 6 * 60 * 60 * 1000;

const createSnapshotSasGenerator = ({
    blobServiceClient,
    accountName,
    containerName,
    now = () => Date.now()
}) => {
    let cachedKey = null;

    const getKey = async (neededUntil) => {
        if (cachedKey && cachedKey.expiresOn.getTime() >= neededUntil) {
            return cachedKey.promise;
        }
        const startsOn = new Date(now() - CLOCK_SKEW_MS);
        const expiresOn = new Date(now() + KEY_LIFETIME_MS);
        const promise = blobServiceClient.getUserDelegationKey(startsOn, expiresOn);
        cachedKey = { expiresOn, promise };
        try {
            return await promise;
        } catch (error) {
            cachedKey = null;
            throw error;
        }
    };

    return async (blobPath, expiresInMinutes = Number(process.env.SNAPSHOT_SAS_TTL_MINUTES ?? '15')) => {
        const startsOn = new Date(now() - CLOCK_SKEW_MS);
        const expiresOn = new Date(now() + expiresInMinutes * 60 * 1000);
        const userDelegationKey = await getKey(expiresOn.getTime());

        const sas = generateBlobSASQueryParameters({
            containerName,
            blobName: blobPath,
            permissions: BlobSASPermissions.parse('r'),
            protocol: SASProtocol.Https,
            startsOn,
            expiresOn
        }, userDelegationKey, accountName);

        const blobUrl = blobServiceClient
            .getContainerClient(containerName)
            .getBlockBlobClient(blobPath)
            .url;
        return `${blobUrl}?${sas.toString()}`;
    };
};

let defaultGenerator = null;

const generateSnapshotSas = (blobPath, expiresInMinutes) => {
    if (!defaultGenerator) {
        const accountName = process.env.STORAGE_ACCOUNT_NAME || DEFAULT_ACCOUNT_NAME;
        const credential = new DefaultAzureCredential({
            // Set only when the app uses a user-assigned identity.
            managedIdentityClientId: process.env.AZURE_CLIENT_ID || undefined
        });
        defaultGenerator = createSnapshotSasGenerator({
            blobServiceClient: new BlobServiceClient(`https://${accountName}.blob.core.windows.net`, credential),
            accountName,
            containerName: process.env.SNAPSHOT_CONTAINER_NAME || DEFAULT_CONTAINER_NAME
        });
    }
    return defaultGenerator(blobPath, expiresInMinutes);
};

module.exports = { generateSnapshotSas, createSnapshotSasGenerator };
