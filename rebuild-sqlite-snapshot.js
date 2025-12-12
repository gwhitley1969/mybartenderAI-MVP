/**
 * Rebuild SQLite snapshot from PostgreSQL
 * Creates an actual SQLite database file (not JSON!) for the mobile app
 *
 * Credentials are fetched from Azure Key Vault (no hardcoded secrets)
 */
const { Pool } = require('pg');
const { DefaultAzureCredential } = require('@azure/identity');
const { SecretClient } = require('@azure/keyvault-secrets');
const { BlobServiceClient } = require('@azure/storage-blob');
const Database = require('better-sqlite3');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { ZstdCodec } = require('zstd-codec');

const STORAGE_ACCOUNT = 'mbacocktaildb3';
const CONTAINER_NAME = 'snapshots';
const KEY_VAULT_NAME = 'kv-mybartenderai-prod';

/**
 * Fetch PostgreSQL connection string from Azure Key Vault
 */
async function getPostgresConnectionString() {
    console.log('Fetching PostgreSQL connection string from Key Vault...');
    const credential = new DefaultAzureCredential();
    const vaultUrl = `https://${KEY_VAULT_NAME}.vault.azure.net`;
    const client = new SecretClient(vaultUrl, credential);

    const secret = await client.getSecret('POSTGRES-CONNECTION-STRING');
    console.log('Connection string retrieved from Key Vault');
    return secret.value;
}

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

async function buildSqliteSnapshot(pool) {
    console.log('Building SQLite snapshot from PostgreSQL...');

    // Fetch all data from PostgreSQL
    const [drinksRes, ingredientsRes, measuresRes, tagsRes, glassesRes, categoriesRes] = await Promise.all([
        pool.query('SELECT id, name, category, alcoholic, glass, instructions, thumbnail FROM drinks'),
        pool.query('SELECT drink_id, position, name FROM ingredients ORDER BY drink_id, position'),
        pool.query('SELECT drink_id, position, measure FROM measures ORDER BY drink_id, position'),
        pool.query(`SELECT dt.drink_id, t.name AS tag
            FROM drink_tags dt
            INNER JOIN tags t ON t.id = dt.tag_id
            ORDER BY dt.drink_id, t.name`),
        pool.query('SELECT DISTINCT glass FROM drinks WHERE glass IS NOT NULL ORDER BY glass'),
        pool.query('SELECT DISTINCT category FROM drinks WHERE category IS NOT NULL ORDER BY category'),
    ]);

    console.log(`Found ${drinksRes.rows.length} drinks`);

    // Create temporary SQLite database
    const tempDbPath = path.join(process.cwd(), 'temp_snapshot.db');
    if (fs.existsSync(tempDbPath)) {
        fs.unlinkSync(tempDbPath);
    }

    const db = new Database(tempDbPath);

    // Create schema matching mobile app expectations EXACTLY
    // Must match database_service.dart schema
    db.exec(`
        CREATE TABLE drinks (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            alternate_name TEXT,
            category TEXT,
            glass TEXT,
            instructions TEXT,
            instructions_es TEXT,
            instructions_de TEXT,
            instructions_fr TEXT,
            instructions_it TEXT,
            image_url TEXT,
            image_attribution TEXT,
            tags TEXT,
            video_url TEXT,
            iba TEXT,
            alcoholic TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            source TEXT DEFAULT 'thecocktaildb',
            is_custom INTEGER DEFAULT 0
        );

        CREATE TABLE drink_ingredients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            drink_id TEXT NOT NULL,
            ingredient_name TEXT NOT NULL,
            measure TEXT,
            ingredient_order INTEGER NOT NULL,
            FOREIGN KEY (drink_id) REFERENCES drinks (id) ON DELETE CASCADE,
            UNIQUE (drink_id, ingredient_order)
        );

        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );

        CREATE INDEX idx_drinks_name ON drinks(name);
        CREATE INDEX idx_drinks_category ON drinks(category);
        CREATE INDEX idx_drinks_alcoholic ON drinks(alcoholic);
        CREATE INDEX idx_drink_ingredients_drink ON drink_ingredients(drink_id);
        CREATE INDEX idx_drink_ingredients_name ON drink_ingredients(ingredient_name);
    `);

    // Build ingredient and measure maps
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

    // Build tags map
    const tagsByDrink = new Map();
    for (const row of tagsRes.rows) {
        if (!tagsByDrink.has(row.drink_id)) {
            tagsByDrink.set(row.drink_id, []);
        }
        tagsByDrink.get(row.drink_id).push(row.tag);
    }

    // Insert drinks with all required columns
    const now = new Date().toISOString();

    const insertDrink = db.prepare(`
        INSERT INTO drinks (id, name, alternate_name, category, glass, instructions,
            instructions_es, instructions_de, instructions_fr, instructions_it,
            image_url, image_attribution, tags, video_url, iba, alcoholic,
            created_at, updated_at, source, is_custom)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const insertIngredient = db.prepare(`
        INSERT INTO drink_ingredients (drink_id, ingredient_name, measure, ingredient_order)
        VALUES (?, ?, ?, ?)
    `);

    const insertMany = db.transaction((drinks) => {
        for (const drink of drinks) {
            const tags = tagsByDrink.get(drink.id) || [];
            insertDrink.run(
                drink.id,                    // id
                drink.name,                  // name
                null,                        // alternate_name
                drink.category,              // category
                drink.glass,                 // glass
                drink.instructions,          // instructions
                null,                        // instructions_es
                null,                        // instructions_de
                null,                        // instructions_fr
                null,                        // instructions_it
                drink.thumbnail,             // image_url
                null,                        // image_attribution
                tags.join(','),              // tags
                null,                        // video_url
                null,                        // iba
                drink.alcoholic,             // alcoholic
                now,                         // created_at
                now,                         // updated_at
                'thecocktaildb',             // source
                0                            // is_custom
            );

            // Insert ingredients with measures
            const ingredients = ingredientsByDrink.get(drink.id) || [];
            const measures = measuresByDrink.get(drink.id) || new Map();
            for (const ing of ingredients) {
                insertIngredient.run(
                    drink.id,
                    ing.name,
                    measures.get(ing.position) || null,
                    ing.position               // ingredient_order (using position value)
                );
            }
        }
    });

    insertMany(drinksRes.rows);

    // Get counts
    const drinkCount = db.prepare('SELECT COUNT(*) as count FROM drinks').get().count;
    const ingredientCount = db.prepare('SELECT COUNT(DISTINCT ingredient_name) as count FROM drink_ingredients').get().count;
    const categoryCount = categoriesRes.rows.length;
    const glassCount = glassesRes.rows.length;
    const tagCount = new Set([...tagsByDrink.values()].flat()).size;

    console.log(`SQLite database created with ${drinkCount} drinks, ${ingredientCount} ingredients`);

    // Close database
    db.close();

    // Read the database file
    const dbBuffer = fs.readFileSync(tempDbPath);
    console.log(`Uncompressed SQLite size: ${dbBuffer.length} bytes`);

    // Compress with Zstandard
    const zstd = await loadZstd();
    const compressedBuffer = Buffer.from(zstd.compress(dbBuffer));
    const sha256 = crypto.createHash("sha256").update(compressedBuffer).digest("hex");

    console.log(`Compressed size: ${compressedBuffer.length} bytes`);
    console.log(`SHA256: ${sha256}`);

    // Clean up temp file
    fs.unlinkSync(tempDbPath);

    return {
        compressed: compressedBuffer,
        sha256,
        sizeBytes: compressedBuffer.length,
        counts: {
            drinks: drinkCount,
            ingredients: ingredientCount,
            categories: categoryCount,
            glasses: glassCount,
            tags: tagCount,
            measures: ingredientCount, // Same as ingredients for compatibility
        }
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
    const blobPath = `snapshots/sqlite/1/${snapshotVersion}.db.zst`;
    const blockBlobClient = containerClient.getBlockBlobClient(blobPath);

    await blockBlobClient.upload(snapshot.compressed, snapshot.sizeBytes, {
        blobHTTPHeaders: {
            blobContentType: 'application/octet-stream',
        },
    });

    console.log(`Uploaded: ${blobPath}`);

    // Upload SHA256 checksum
    const shaPath = `${blobPath}.sha256`;
    const shaBlobClient = containerClient.getBlockBlobClient(shaPath);
    await shaBlobClient.upload(Buffer.from(snapshot.sha256), snapshot.sha256.length, {
        blobHTTPHeaders: {
            blobContentType: 'text/plain',
        },
    });

    console.log(`Uploaded: ${shaPath}`);

    return { blobPath };
}

async function recordMetadata(pool, snapshotVersion, blobPath, snapshot) {
    console.log('Recording snapshot metadata in PostgreSQL...');

    // Simple INSERT - no upsert needed for new snapshots
    await pool.query(`
        INSERT INTO snapshot_metadata (schema_version, snapshot_version, blob_path, size_bytes, sha256, counts, created_at)
        VALUES ($1, $2, $3, $4, $5, $6, NOW())
    `, ['1', snapshotVersion, blobPath, snapshot.sizeBytes, snapshot.sha256, JSON.stringify(snapshot.counts)]);

    console.log('Metadata recorded');
}

async function main() {
    console.log('=== Rebuild SQLite Snapshot Script ===');
    console.log(`Started at: ${new Date().toISOString()}`);

    // Fetch connection string from Key Vault (no hardcoded secrets)
    const connectionString = await getPostgresConnectionString();
    const pool = new Pool({ connectionString });

    try {
        // Test connection
        const testResult = await pool.query('SELECT COUNT(*) as count FROM drinks');
        console.log(`PostgreSQL connection OK - ${testResult.rows[0].count} drinks in database`);

        const snapshotVersion = formatSnapshotVersion(new Date());
        console.log(`Snapshot version: ${snapshotVersion}`);

        // Build SQLite snapshot from PostgreSQL data
        const snapshot = await buildSqliteSnapshot(pool);

        // Upload to blob storage
        const { blobPath } = await uploadSnapshot(snapshot, snapshotVersion);

        // Record metadata
        await recordMetadata(pool, snapshotVersion, blobPath, snapshot);

        console.log('\n=== SUCCESS ===');
        console.log(`New SQLite snapshot available at: ${blobPath}`);
        console.log(`Drinks: ${snapshot.counts.drinks}`);
        console.log(`Size: ${snapshot.sizeBytes} bytes compressed`);

    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    } finally {
        await pool.end();
    }
}

main();
