import { readFileSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";
import type { Pool } from "pg";
import type { HttpRequest, InvocationContext } from "@azure/functions";
import { beforeAll, afterAll, beforeEach, describe, expect, it, vi } from "vitest";
import { newDb } from "pg-mem";

import { __dangerous__resetPool, __dangerous__setPool } from "../src/shared/db/postgresPool.js";

vi.mock("../src/services/snapshotStorageService.js", () => ({
  generateSnapshotSas: vi.fn(() => "https://example/blob.db.zst?sas"),
}));

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const sqlDir = path.resolve(__dirname, "../sql");

const loadSql = (filename: string): string =>
  readFileSync(path.join(sqlDir, filename), "utf-8");

let pool: Pool;

const insertMetadataRow = async (): Promise<void> => {
  await pool.query(
    `INSERT INTO snapshot_metadata (
       schema_version,
       snapshot_version,
       blob_path,
       size_bytes,
       sha256,
       counts,
       created_at
     ) VALUES ($1, $2, $3, $4, $5, $6::jsonb, NOW())`,
    [
      "1",
      "20251010.010203",
      "snapshots/sqlite/1/20251010.010203.db.zst",
      1024,
      "abc123",
      JSON.stringify({
        drinks: 1,
        ingredients: 2,
        measures: 2,
        categories: 1,
        glasses: 1,
        tags: 1,
      }),
    ],
  );
};

describe("snapshotsLatestHandler", () => {
  beforeAll(async () => {
    process.env.BLOB_STORAGE_CONNECTION_STRING =
      process.env.BLOB_STORAGE_CONNECTION_STRING ??
      "AccountName=devstoreaccount1;AccountKey=ZmFrZUtleQ==;EndpointSuffix=core.windows.net";
    process.env.SNAPSHOT_CONTAINER_NAME = process.env.SNAPSHOT_CONTAINER_NAME ?? "snapshots";

    const db = newDb({ autoCreateForeignKeyIndices: true });
    const migrations = [
      "001_token_quotas.sql",
      "002_rate_limit_events.sql",
      "003_rate_limit_counters.sql",
      "004_cocktaildb_schema.sql",
    ];
    for (const file of migrations) {
      db.public.none(loadSql(file));
    }

    const adapter = db.adapters.createPg();
    const { Pool: PgPool } = adapter;
    pool = new PgPool();
    __dangerous__setPool(pool);
  });

  afterAll(async () => {
    await __dangerous__resetPool();
  });

  beforeEach(async () => {
    await pool.query('DELETE FROM snapshot_metadata');
    await insertMetadataRow();
  });

  it('returns latest snapshot information with signedUrl', async () => {
    const { snapshotsLatestHandler } = await import(
      '../src/functions/snapshots-latest/index.js'
    );

    const response = await snapshotsLatestHandler(
      {
        method: 'GET',
      } as HttpRequest,
      {
        invocationId: 'test-trace',
        log: vi.fn(),
      } as unknown as InvocationContext,
    );

    expect(response.status).toBe(200);
    expect(response.jsonBody).toMatchObject({
      schemaVersion: '1',
      snapshotVersion: '20251010.010203',
      signedUrl: expect.stringContaining('https://example/blob'),
      counts: {
        drinks: 1,
        ingredients: 2,
      },
    });
  });

  it('returns 503 when no snapshot exists', async () => {
    await pool.query('DELETE FROM snapshot_metadata');
    const { snapshotsLatestHandler } = await import(
      '../src/functions/snapshots-latest/index.js'
    );

    const response = await snapshotsLatestHandler(
      {
        method: 'GET',
      } as HttpRequest,
      {
        invocationId: 'test-trace',
        log: vi.fn(),
      } as unknown as InvocationContext,
    );

    expect(response.status).toBe(503);
    expect(response.jsonBody).toMatchObject({
      code: 'snapshot_unavailable',
    });
  });
});
