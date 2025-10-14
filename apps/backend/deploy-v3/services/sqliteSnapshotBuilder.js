"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.buildSqliteSnapshot = void 0;
const fs_1 = require("fs");
const os_1 = require("os");
const path_1 = __importDefault(require("path"));
const crypto_1 = __importDefault(require("crypto"));
const better_sqlite3_1 = __importDefault(require("better-sqlite3"));
const zstd_codec_1 = require("zstd-codec");
const postgresPool_js_1 = require("../shared/db/postgresPool.js");
const loadZstd = async () => new Promise((resolve) => {
    zstd_codec_1.ZstdCodec.run((zstd) => {
        resolve(new zstd.Simple());
    });
});
const createSqliteSchema = (db) => {
    db.exec(`
    CREATE TABLE IF NOT EXISTS drinks (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      category TEXT,
      alcoholic TEXT,
      glass TEXT,
      instructions TEXT,
      thumbnail TEXT
    );

    CREATE TABLE IF NOT EXISTS ingredients (
      drink_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      name TEXT NOT NULL,
      PRIMARY KEY (drink_id, position)
    );

    CREATE TABLE IF NOT EXISTS measures (
      drink_id TEXT NOT NULL,
      position INTEGER NOT NULL,
      measure TEXT,
      PRIMARY KEY (drink_id, position)
    );

    CREATE TABLE IF NOT EXISTS drink_tags (
      drink_id TEXT NOT NULL,
      tag TEXT NOT NULL,
      PRIMARY KEY (drink_id, tag)
    );
  `);
};
const buildSqliteSnapshot = async () => {
    const pool = (0, postgresPool_js_1.getPool)();
    const tmpDir = await fs_1.promises.mkdtemp(path_1.default.join((0, os_1.tmpdir)(), "cocktaildb-"));
    const sqlitePath = path_1.default.join(tmpDir, "snapshot.db");
    try {
        const [drinksRes, ingredientsRes, measuresRes, tagsRes] = await Promise.all([
            pool.query('SELECT id, name, category, alcoholic, glass, instructions, thumbnail FROM drinks'),
            pool.query('SELECT drink_id, position, name FROM ingredients'),
            pool.query('SELECT drink_id, position, measure FROM measures'),
            pool.query(`SELECT dt.drink_id, t.name AS tag
           FROM drink_tags dt
           INNER JOIN tags t ON t.id = dt.tag_id`),
        ]);
        const db = new better_sqlite3_1.default(sqlitePath);
        try {
            db.pragma("journal_mode = MEMORY");
            db.pragma("synchronous = OFF");
            createSqliteSchema(db);
            const insertDrink = db.prepare("INSERT INTO drinks (id, name, category, alcoholic, glass, instructions, thumbnail) VALUES (@id, @name, @category, @alcoholic, @glass, @instructions, @thumbnail)");
            const insertIngredient = db.prepare("INSERT INTO ingredients (drink_id, position, name) VALUES (@drink_id, @position, @name)");
            const insertMeasure = db.prepare("INSERT INTO measures (drink_id, position, measure) VALUES (@drink_id, @position, @measure)");
            const insertTag = db.prepare("INSERT INTO drink_tags (drink_id, tag) VALUES (@drink_id, @tag)");
            const transaction = db.transaction(() => {
                for (const row of drinksRes.rows) {
                    insertDrink.run(row);
                }
                for (const row of ingredientsRes.rows) {
                    insertIngredient.run(row);
                }
                for (const row of measuresRes.rows) {
                    insertMeasure.run(row);
                }
                for (const row of tagsRes.rows) {
                    insertTag.run(row);
                }
            });
            transaction();
            db.exec("VACUUM; ANALYZE;");
        }
        finally {
            db.close();
        }
        const sqliteBuffer = await fs_1.promises.readFile(sqlitePath);
        const zstd = await loadZstd();
        const compressedBuffer = Buffer.from(zstd.compress(sqliteBuffer));
        const sha256 = crypto_1.default.createHash("sha256").update(compressedBuffer).digest("hex");
        return {
            compressed: compressedBuffer,
            sha256,
            sizeBytes: compressedBuffer.byteLength,
        };
    }
    finally {
        await fs_1.promises.rm(tmpDir, { recursive: true, force: true });
    }
};
exports.buildSqliteSnapshot = buildSqliteSnapshot;
