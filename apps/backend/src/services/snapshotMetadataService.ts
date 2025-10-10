import { getPool, withTransaction } from "../shared/db/postgresPool.js";

interface SnapshotCounts {
  drinks: number;
  ingredients: number;
  measures: number;
  categories: number;
  glasses: number;
  tags: number;
}

export interface SnapshotMetadata {
  schemaVersion: string;
  snapshotVersion: string;
  blobPath: string;
  sizeBytes: number;
  sha256: string;
  counts: SnapshotCounts;
  createdAtUtc: string;
}

export const recordSnapshotMetadata = async (
  metadata: SnapshotMetadata,
): Promise<void> => {
  await withTransaction(async (client) => {
    await client.query(
      `INSERT INTO snapshot_metadata (
         schema_version,
         snapshot_version,
         blob_path,
         size_bytes,
         sha256,
         counts,
         created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        metadata.schemaVersion,
        metadata.snapshotVersion,
        metadata.blobPath,
        metadata.sizeBytes,
        metadata.sha256,
        JSON.stringify(metadata.counts),
        metadata.createdAtUtc,
      ],
    );
  });
};

export const getLatestSnapshotMetadata = async (): Promise<SnapshotMetadata | null> => {
  const pool = getPool();
  const result = await pool.query<{
    schema_version: string;
    snapshot_version: string;
    blob_path: string;
    size_bytes: number;
    sha256: string;
    counts: any;
    created_at: Date;
  }>(
    `SELECT schema_version, snapshot_version, blob_path, size_bytes, sha256, counts, created_at
       FROM snapshot_metadata
       ORDER BY created_at DESC
       LIMIT 1`,
  );

  if (result.rowCount === 0) {
    return null;
  }

  const row = result.rows[0];
  return {
    schemaVersion: row.schema_version,
    snapshotVersion: row.snapshot_version,
    blobPath: row.blob_path,
    sizeBytes: Number(row.size_bytes ?? 0),
    sha256: row.sha256,
    counts: row.counts as SnapshotCounts,
    createdAtUtc: row.created_at.toISOString(),
  };
};
