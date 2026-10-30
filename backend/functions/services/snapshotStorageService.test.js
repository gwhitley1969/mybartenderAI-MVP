const { createSnapshotSasGenerator } = require('./snapshotStorageService');

// Shape of a user delegation key as returned by getUserDelegationKey; the value is fake.
const fakeUserDelegationKey = (startsOn, expiresOn) => ({
    signedObjectId: '00000000-0000-0000-0000-000000000001',
    signedTenantId: '00000000-0000-0000-0000-000000000002',
    signedStartsOn: startsOn,
    signedExpiresOn: expiresOn,
    signedService: 'b',
    signedVersion: '2025-01-05',
    value: Buffer.from('not-a-real-key').toString('base64')
});

const fakeBlobServiceClient = () => {
    const client = {
        getUserDelegationKey: jest.fn(async (startsOn, expiresOn) => fakeUserDelegationKey(startsOn, expiresOn)),
        getContainerClient: (container) => ({
            getBlockBlobClient: (blob) => ({
                url: `https://mbacocktaildb3.blob.core.windows.net/${container}/${blob}`
            })
        })
    };
    return client;
};

const T0 = Date.parse('2026-10-30T12:00:00Z');

describe('createSnapshotSasGenerator', () => {
    test('signs a read-only HTTPS user delegation SAS for the blob', async () => {
        const blobServiceClient = fakeBlobServiceClient();
        const sign = createSnapshotSasGenerator({
            blobServiceClient,
            accountName: 'mbacocktaildb3',
            containerName: 'snapshots',
            now: () => T0
        });

        const url = new URL(await sign('snapshots/sqlite/1/20261030.db.zst', 15));

        expect(url.origin + url.pathname).toBe(
            'https://mbacocktaildb3.blob.core.windows.net/snapshots/snapshots/sqlite/1/20261030.db.zst'
        );
        expect(url.searchParams.get('sp')).toBe('r');
        expect(url.searchParams.get('spr')).toBe('https');
        expect(url.searchParams.get('sr')).toBe('b');
        // skoid is only present on user delegation SAS, never on account-key SAS.
        expect(url.searchParams.get('skoid')).toBe('00000000-0000-0000-0000-000000000001');
        expect(url.searchParams.get('se')).toBe('2026-10-30T12:15:00Z');
        expect(url.searchParams.get('sig')).toBeTruthy();
    });

    test('reuses the user delegation key while it outlives the link', async () => {
        let now = T0;
        const blobServiceClient = fakeBlobServiceClient();
        const sign = createSnapshotSasGenerator({
            blobServiceClient,
            accountName: 'mbacocktaildb3',
            containerName: 'snapshots',
            now: () => now
        });

        await sign('a.db.zst', 15);
        now = T0 + 5 * 60 * 60 * 1000;
        await sign('a.db.zst', 15);
        expect(blobServiceClient.getUserDelegationKey).toHaveBeenCalledTimes(1);

        // 5h50m in, a 15-minute link would outlive the 6-hour key.
        now = T0 + (5 * 60 + 50) * 60 * 1000;
        await sign('a.db.zst', 15);
        expect(blobServiceClient.getUserDelegationKey).toHaveBeenCalledTimes(2);
    });

    test('does not cache a failed key request', async () => {
        const blobServiceClient = fakeBlobServiceClient();
        blobServiceClient.getUserDelegationKey.mockRejectedValueOnce(
            Object.assign(new Error('This request is not authorized to perform this operation.'), { statusCode: 403 })
        );
        const sign = createSnapshotSasGenerator({
            blobServiceClient,
            accountName: 'mbacocktaildb3',
            containerName: 'snapshots',
            now: () => T0
        });

        await expect(sign('a.db.zst', 15)).rejects.toThrow('not authorized');
        await expect(sign('a.db.zst', 15)).resolves.toContain('sig=');
        expect(blobServiceClient.getUserDelegationKey).toHaveBeenCalledTimes(2);
    });
});
