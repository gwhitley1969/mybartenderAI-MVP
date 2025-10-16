"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildJsonSnapshot = void 0;
const crypto_1 = __importDefault(require("crypto"));
const zstd_codec_1 = require("zstd-codec");
const postgresPool_js_1 = require("../shared/db/postgresPool.js");
const loadZstd = async () => new Promise((resolve) => {
    zstd_codec_1.ZstdCodec.run((zstd) => {
        resolve(new zstd.Simple());
    });
});
const buildJsonSnapshot = async () => {
    const pool = (0, postgresPool_js_1.getPool)();
    try {
        // Fetch all data from PostgreSQL
        const [drinksRes, ingredientsRes, measuresRes, tagsRes] = await Promise.all([
            pool.query('SELECT id, name, category, alcoholic, glass, instructions, thumbnail FROM drinks'),
            pool.query('SELECT drink_id, position, name FROM ingredients ORDER BY drink_id, position'),
            pool.query('SELECT drink_id, position, measure FROM measures ORDER BY drink_id, position'),
            pool.query(`SELECT dt.drink_id, t.name AS tag
         FROM drink_tags dt
         INNER JOIN tags t ON t.id = dt.tag_id
         ORDER BY dt.drink_id, t.name`),
        ]);
        // Build drink map
        const drinkMap = new Map();
        // Initialize drinks
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
            if (!drink)
                continue;
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
            version: parseInt(process.env.SNAPSHOT_SCHEMA_VERSION || "1", 10),
            generatedAt: new Date().toISOString(),
            drinks: Array.from(drinkMap.values()),
        };
        // Convert to JSON and compress
        const jsonString = JSON.stringify(snapshot);
        const jsonBuffer = Buffer.from(jsonString, 'utf-8');
        const zstd = await loadZstd();
        const compressedBuffer = Buffer.from(zstd.compress(jsonBuffer));
        const sha256 = crypto_1.default.createHash("sha256").update(compressedBuffer).digest("hex");
        return {
            compressed: compressedBuffer,
            sha256,
            sizeBytes: compressedBuffer.byteLength,
        };
    }
    catch (error) {
        console.error("Error building JSON snapshot:", error);
        throw error;
    }
};
exports.buildJsonSnapshot = buildJsonSnapshot;


