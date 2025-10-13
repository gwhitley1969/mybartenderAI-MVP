import { promises as fs } from "fs";
import { tmpdir } from "os";
import path from "path";
import crypto from "crypto";
import Database from "better-sqlite3";
import { ZstdCodec } from "zstd-codec";

import { getPool } from "../shared/db/postgresPool.js";

interface SnapshotBuildResult {
  compressed: Buffer;
  sha256: string;
  sizeBytes: number;
}

const loadZstd = async (): Promise<any> =>
  new Promise((resolve) => {
    ZstdCodec.run((zstd: any) => {
      resolve(new zstd.Simple());
    });
  });

const createSqliteSchema = (db: Database.Database): void => {
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

export const buildSqliteSnapshot = async (): Promise<SnapshotBuildResult> => {
  const pool = getPool();
  const tmpDir = await fs.mkdtemp(path.join(tmpdir(), "cocktaildb-"));
  const sqlitePath = path.join(tmpDir, "snapshot.db");

  try {
    const [drinksRes, ingredientsRes, measuresRes, tagsRes] = await Promise.all([
      pool.query('SELECT id, name, category, alcoholic, glass, instructions, thumbnail FROM drinks'),
      pool.query('SELECT drink_id, position, name FROM ingredients'),
      pool.query('SELECT drink_id, position, measure FROM measures'),
      pool.query(
        `SELECT dt.drink_id, t.name AS tag
           FROM drink_tags dt
           INNER JOIN tags t ON t.id = dt.tag_id`,
      ),
    ]);

    const db = new Database(sqlitePath);
    try {
      db.pragma("journal_mode = MEMORY");
      db.pragma("synchronous = OFF");
      createSqliteSchema(db);

      const insertDrink = db.prepare(
        "INSERT INTO drinks (id, name, category, alcoholic, glass, instructions, thumbnail) VALUES (@id, @name, @category, @alcoholic, @glass, @instructions, @thumbnail)",
      );
      const insertIngredient = db.prepare(
        "INSERT INTO ingredients (drink_id, position, name) VALUES (@drink_id, @position, @name)",
      );
      const insertMeasure = db.prepare(
        "INSERT INTO measures (drink_id, position, measure) VALUES (@drink_id, @position, @measure)",
      );
      const insertTag = db.prepare(
        "INSERT INTO drink_tags (drink_id, tag) VALUES (@drink_id, @tag)",
      );

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
    } finally {
      db.close();
    }

    const sqliteBuffer = await fs.readFile(sqlitePath);
    const zstd = await loadZstd();
    const compressedBuffer = Buffer.from(zstd.compress(sqliteBuffer));
    const sha256 = crypto.createHash("sha256").update(compressedBuffer).digest("hex");

    return {
      compressed: compressedBuffer,
      sha256,
      sizeBytes: compressedBuffer.byteLength,
    };
  } finally {
    await fs.rm(tmpDir, { recursive: true, force: true });
  }
};
