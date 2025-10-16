"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getLatestSnapshotMetadata = exports.recordSnapshotMetadata = void 0;
const postgresPool_js_1 = require("../shared/db/postgresPool.js");
const recordSnapshotMetadata = async (metadata) => {
    await (0, postgresPool_js_1.withTransaction)(async (client) => {
        await client.query(`INSERT INTO snapshot_metadata (
         schema_version,
         snapshot_version,
         blob_path,
         size_bytes,
         sha256,
         counts,
         created_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7)`, [
            metadata.schemaVersion,
            metadata.snapshotVersion,
            metadata.blobPath,
            metadata.sizeBytes,
            metadata.sha256,
            JSON.stringify(metadata.counts),
            metadata.createdAtUtc,
        ]);
    });
};
exports.recordSnapshotMetadata = recordSnapshotMetadata;
const getLatestSnapshotMetadata = async () => {
    const pool = (0, postgresPool_js_1.getPool)();
    const result = await pool.query(`SELECT schema_version, snapshot_version, blob_path, size_bytes, sha256, counts, created_at
       FROM snapshot_metadata
       ORDER BY created_at DESC
       LIMIT 1`);
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
        counts: row.counts,
        createdAtUtc: row.created_at.toISOString(),
    };
};
exports.getLatestSnapshotMetadata = getLatestSnapshotMetadata;

