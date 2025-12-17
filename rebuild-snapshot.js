/**
 * One-off script to rebuild the cocktail snapshot from PostgreSQL
 * without re-syncing from TheCocktailDB API
 */
const { Pool } = require('pg');
const { DefaultAzureCredential } = require('@azure/identity');
const { BlobServiceClient } = require('@azure/storage-blob');
const crypto = require('crypto');
const { ZstdCodec } = require('zstd-codec');

const STORAGE_ACCOUNT = 'mbacocktaildb3';
const CONTAINER_NAME = 'snapshots';
const POSTGRES_CONNECTION = 'postgresql://pgadmin:Advocate2!@pg-mybartenderdb.postgres.database.azure.com/mybartender?sslmode=require';

const loadZstd = async () => new Promise((resolve) => {
    ZstdCodec.run((zstd) => {
        resolve(new zstd.Simple());
    });
});

const formatSnapshotVersion = (date) => {
    const pad = (value) => value.toString().padStart(2, '0');
    return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(
        date.getUTCHours()
    )}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};

async function buildSnapshot(pool) {
    console.log('Building snapshot from PostgreSQL...');

    const [drinksRes, ingredientsRes, measuresRes, tagsRes] = await Promise.all([
        pool.query('SELECT id, name, category, alcoholic, glass, instructions, thumbnail FROM drinks'),
        pool.query('SELECT drink_id, position, name FROM ingredients ORDER BY drink_id, position'),
        pool.query('SELECT drink_id, position, measure FROM measures ORDER BY drink_id, position'),
        pool.query(`SELECT dt.drink_id, t.name AS tag
            FROM drink_tags dt
            INNER JOIN tags t ON t.id = dt.tag_id
            ORDER BY dt.drink_id, t.name`),
    ]);

    console.log(`Found ${drinksRes.rows.length} drinks`);

    // Build drink map
    const drinkMap = new Map();
    for (const row of drinksRes.rows) {
        drinkMap.set(row.id, {
            id: row.id,
            name: row.name,
            category: row.category,
            alcoholic: row.alcoholic,
            glass: row.glass,
            instructions: row.instructions,
            thumbnail: row.thumbnail,
            ingredients: [],
            tags: [],
        });
    }

    // Add ingredients with measures
    const ingredientsByDrink = new Map();
    for (const row of ingredientsRes.rows) {
        if (!ingredientsByDrink.has(row.drink_id)) {
            ingredientsByDrink.set(row.drink_id, []);
        }
        ingredientsByDrink.get(row.drink_id).push(row);
    }

    const measuresByDrink = new Map();
    for (const row of measuresRes.rows) {
        if (!measuresByDrink.has(row.drink_id)) {
            measuresByDrink.set(row.drink_id, new Map());
        }
        measuresByDrink.get(row.drink_id).set(row.position, row.measure);
    }

    // Combine ingredients with measures
    for (const [drinkId, ingredients] of ingredientsByDrink) {
        const drink = drinkMap.get(drinkId);
        if (!drink) continue;
        const measures = measuresByDrink.get(drinkId) || new Map();
        for (const ingredient of ingredients) {
            drink.ingredients.push({
                position: ingredient.position,
                name: ingredient.name,
                measure: measures.get(ingredient.position) || null,
            });
        }
    }

    // Add tags
    for (const row of tagsRes.rows) {
        const drink = drinkMap.get(row.drink_id);
        if (drink) {
            drink.tags.push(row.tag);
        }
    }

    // Build final snapshot
    const snapshot = {
        version: 1,
        generatedAt: new Date().toISOString(),
        drinks: Array.from(drinkMap.values()),
    };

    // Convert to JSON and compress
    const jsonString = JSON.stringify(snapshot);
    const jsonBuffer = Buffer.from(jsonString, 'utf-8');
    const zstd = await loadZstd();
    const compressedBuffer = Buffer.from(zstd.compress(jsonBuffer));
    const sha256 = crypto.createHash("sha256").update(compressedBuffer).digest("hex");

    console.log(`Snapshot built: ${compressedBuffer.byteLength} bytes compressed, SHA256: ${sha256.substring(0, 16)}...`);

    return {
        compressed: compressedBuffer,
        sha256,
        sizeBytes: compressedBuffer.byteLength,
    };
}

async function uploadSnapshot(snapshot, snapshotVersion) {
    console.log('Uploading snapshot to Azure Blob Storage using Managed Identity...');

    const credential = new DefaultAzureCredential();
    const blobServiceClient = new BlobServiceClient(
        `https://${STORAGE_ACCOUNT}.blob.core.windows.net`,
        credential
    );

    const containerClient = blobServiceClient.getContainerClient(CONTAINER_NAME);

    // Upload compressed snapshot
    const blobPath = `v1/${snapshotVersion}/cocktails.json.zst`;
    const blockBlobClient = containerClient.getBlockBlobClient(blobPath);

    await blockBlobClient.upload(snapshot.compressed, snapshot.sizeBytes, {
        blobHTTPHeaders: {
            blobContentType: 'application/zstd',
            blobContentEncoding: 'zstd',
        },
        metadata: {
            sha256: snapshot.sha256,
            snapshotVersion: snapshotVersion,
        },
    });

    console.log(`Uploaded: ${blobPath}`);

    // Update latest pointer
    const latestBlobClient = containerClient.getBlockBlobClient('v1/latest.json');
    const latestContent = JSON.stringify({
        snapshotVersion,
        blobPath,
        sha256: snapshot.sha256,
        sizeBytes: snapshot.sizeBytes,
        updatedAt: new Date().toISOString(),
    });

    await latestBlobClient.upload(latestContent, latestContent.length, {
        blobHTTPHeaders: {
            blobContentType: 'application/json',
        },
    });

    console.log('Updated latest.json pointer');

    return { blobPath };
}

async function recordMetadata(pool, snapshotVersion, blobPath, snapshot) {
    console.log('Recording snapshot metadata...');

    await pool.query(`
        INSERT INTO snapshot_metadata (schema_version, snapshot_version, blob_path, size_bytes, sha256, created_at)
        VALUES ($1, $2, $3, $4, $5, NOW())
        ON CONFLICT (schema_version, snapshot_version) DO UPDATE SET
            blob_path = EXCLUDED.blob_path,
            size_bytes = EXCLUDED.size_bytes,
            sha256 = EXCLUDED.sha256,
            created_at = NOW()
    `, [1, snapshotVersion, blobPath, snapshot.sizeBytes, snapshot.sha256]);

    console.log('Metadata recorded');
}

async function main() {
    console.log('=== Rebuild Snapshot Script ===');
    console.log(`Started at: ${new Date().toISOString()}`);

    const pool = new Pool({ connectionString: POSTGRES_CONNECTION });

    try {
        const snapshotVersion = formatSnapshotVersion(new Date());
        console.log(`Snapshot version: ${snapshotVersion}`);

        // Build snapshot from current PostgreSQL data
        const snapshot = await buildSnapshot(pool);

        // Upload to blob storage
        const { blobPath } = await uploadSnapshot(snapshot, snapshotVersion);

        // Record metadata
        await recordMetadata(pool, snapshotVersion, blobPath, snapshot);

        console.log('\n=== SUCCESS ===');
        console.log(`New snapshot available at: ${blobPath}`);

    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

main();
