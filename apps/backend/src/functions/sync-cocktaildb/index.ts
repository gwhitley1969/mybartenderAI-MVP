import type { Timer } from "@azure/functions";
import { app } from "@azure/functions";

import { CocktailDbClient } from "../../services/cocktailDbClient.js";
import { syncCocktailCatalog } from "../../services/cocktailDbSyncService.js";
import { buildSqliteSnapshot } from "../../services/sqliteSnapshotBuilder.js";
import { uploadSnapshotArtifacts } from "../../services/snapshotStorageService.js";
import { recordSnapshotMetadata } from "../../services/snapshotMetadataService.js";

const formatSnapshotVersion = (date: Date): string => {
  const pad = (value: number) => value.toString().padStart(2, "0");
  return `${date.getUTCFullYear()}${pad(date.getUTCMonth() + 1)}${pad(date.getUTCDate())}.${pad(
    date.getUTCHours(),
  )}${pad(date.getUTCMinutes())}${pad(date.getUTCSeconds())}`;
};

const getCocktailApiKey = (): string => {
  const value = process.env['COCKTAILDB-API-KEY'];
  if (!value) {
    throw new Error('COCKTAILDB-API-KEY environment variable is required.');
  }
  return value;
};

const SCHEMA_VERSION = process.env.SNAPSHOT_SCHEMA_VERSION ?? '1';

export const syncCocktailDb = async (timer: Timer, rawContext: unknown): Promise<void> => {
  const context = rawContext as { log: (message: string) => void };
  const start = Date.now();
  context.log(`[sync-cocktaildb] Starting synchronization at ${new Date().toISOString()}`);

  try {
    const client = new CocktailDbClient(getCocktailApiKey());
    const drinks = await client.fetchCatalog();
    context.log(`[sync-cocktaildb] Retrieved ${drinks.length} drinks.`);

    const counts = await syncCocktailCatalog(drinks);
    context.log('[sync-cocktaildb] Normalized data into PostgreSQL tables.');

    const snapshotVersion = formatSnapshotVersion(new Date());
    const snapshot = await buildSqliteSnapshot();
    context.log('[sync-cocktaildb] Built SQLite snapshot.');

    const uploadResult = await uploadSnapshotArtifacts({
      schemaVersion: SCHEMA_VERSION,
      snapshotVersion,
      compressed: snapshot.compressed,
      sha256: snapshot.sha256,
    });

    await recordSnapshotMetadata({
      schemaVersion: SCHEMA_VERSION,
      snapshotVersion,
      blobPath: uploadResult.blobPath,
      sizeBytes: uploadResult.sizeBytes,
      sha256: snapshot.sha256,
      counts,
      createdAtUtc: new Date().toISOString(),
    });

    context.log(
      `[sync-cocktaildb] Completed in ${Date.now() - start}ms; snapshot=${uploadResult.blobPath}`,
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    context.log(`[sync-cocktaildb] Failed: ${message}`);
    throw error;
  }
};

app.timer('sync-cocktaildb', {
  schedule: '0 30 3 * * *',
  handler: syncCocktailDb,
});
