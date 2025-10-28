"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildSqliteSnapshot = void 0;
const crypto_1 = __importDefault(require("crypto"));
const { ZstdCodec } = require("zstd-codec");
const initSqlJs = require("sql.js");
const postgresPool_js_1 = require("../shared/db/postgresPool.js");

const loadZstd = async () => new Promise((resolve) => {
    ZstdCodec.run((zstd) => {
        resolve(new zstd.Simple());
    });
});

const buildSqliteSnapshot = async (snapshotVersion) => {
    const pool = (0, postgresPool_js_1.getPool)();

    try {
        // Initialize sql.js
        const SQL = await initSqlJs();
        const db = new SQL.Database();

        // Create schema
        db.run(`
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

            CREATE INDEX idx_drinks_name ON drinks(name);
            CREATE INDEX idx_drinks_category ON drinks(category);
            CREATE INDEX idx_drinks_alcoholic ON drinks(alcoholic);
            CREATE INDEX idx_drink_ingredients_drink ON drink_ingredients(drink_id);
            CREATE INDEX idx_drink_ingredients_name ON drink_ingredients(ingredient_name);

            CREATE TABLE metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );`);

        // Fetch all data from PostgreSQL
        const [drinksRes, ingredientsRes, measuresRes, tagsRes] = await Promise.all([
            pool.query(`
                SELECT
                    id, name, category, alcoholic, glass,
                    instructions, thumbnail
                FROM drinks
            `),
            pool.query(`
                SELECT drink_id, position, name
                FROM ingredients
                ORDER BY drink_id, position
            `),
            pool.query(`
                SELECT drink_id, position, measure
                FROM measures
                ORDER BY drink_id, position
            `),
            pool.query(`
                SELECT dt.drink_id, t.name AS tag
                FROM drink_tags dt
                INNER JOIN tags t ON t.id = dt.tag_id
                ORDER BY dt.drink_id, t.name
            `),
        ]);

        // Build ingredient map with measures
        const ingredientsByDrink = new Map();
        for (const row of ingredientsRes.rows) {
            if (!ingredientsByDrink.has(row.drink_id)) {
                ingredientsByDrink.set(row.drink_id, []);
            }
            ingredientsByDrink.get(row.drink_id).push({
                position: row.position,
                name: row.name,
                measure: null,
            });
        }

        // Add measures to ingredients
        for (const row of measuresRes.rows) {
            const ingredients = ingredientsByDrink.get(row.drink_id);
            if (ingredients) {
                const ingredient = ingredients.find(i => i.position === row.position);
                if (ingredient) {
                    ingredient.measure = row.measure;
                }
            }
        }

        // Build tags map
        const tagsByDrink = new Map();
        for (const row of tagsRes.rows) {
            if (!tagsByDrink.has(row.drink_id)) {
                tagsByDrink.set(row.drink_id, []);
            }
            tagsByDrink.get(row.drink_id).push(row.tag);
        }

        // Insert data
        const now = new Date().toISOString();

        for (const row of drinksRes.rows) {
            const tags = tagsByDrink.get(row.id) || [];
            const tagsStr = tags.join(',');

            db.run(
                `INSERT INTO drinks (id, name, category, alcoholic, glass, instructions, image_url, tags, created_at, updated_at, source, is_custom)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [row.id, row.name, row.category, row.alcoholic, row.glass, row.instructions, row.thumbnail, tagsStr, now, now, 'thecocktaildb', 0]
            );

            const ingredients = ingredientsByDrink.get(row.id) || [];
            for (const ingredient of ingredients) {
                db.run(
                    `INSERT INTO drink_ingredients (drink_id, ingredient_name, measure, ingredient_order)
                     VALUES (?, ?, ?, ?)`,
                    [row.id, ingredient.name, ingredient.measure, ingredient.position]
                );
            }
        }

        // Calculate statistics for metadata
        const totalCocktails = drinksRes.rows.length;
        const categoriesSet = new Set();
        for (const row of drinksRes.rows) {
            if (row.category) {
                categoriesSet.add(row.category);
            }
        }
        const totalCategories = categoriesSet.size;

        // Insert metadata
        db.run(
            `INSERT INTO metadata (key, value, updated_at) VALUES (?, ?, ?)`,
            ['snapshot_version', snapshotVersion, now]
        );
        db.run(
            `INSERT INTO metadata (key, value, updated_at) VALUES (?, ?, ?)`,
            ['total_cocktails', totalCocktails.toString(), now]
        );
        db.run(
            `INSERT INTO metadata (key, value, updated_at) VALUES (?, ?, ?)`,
            ['total_categories', totalCategories.toString(), now]
        );

        // Set database version to 1 for sqflite compatibility
        // This tells sqflite the database is already initialized
        // Note: sql.js requires exec() for PRAGMA statements to take effect before export
        db.exec('PRAGMA user_version = 1');

        // Export database to buffer
        const sqliteBuffer = Buffer.from(db.export());

        // Compress with Zstandard
        const zstd = await loadZstd();
        const compressedBuffer = Buffer.from(zstd.compress(sqliteBuffer));

        // Calculate SHA256
        const sha256 = crypto_1.default.createHash("sha256").update(compressedBuffer).digest("hex");

        return {
            compressed: compressedBuffer,
            sha256,
            sizeBytes: compressedBuffer.byteLength,
        };
    } catch (error) {
        console.error("Error building SQLite snapshot:", error);
        throw error;
    }
};

exports.buildSqliteSnapshot = buildSqliteSnapshot;
