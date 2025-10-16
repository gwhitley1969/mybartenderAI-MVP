import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { getLatestSnapshotMetadata } from "../../services/snapshotMetadataService.js";
import { generateSnapshotSas } from "../../services/snapshotStorageService.js";

async function snapshotsLatest(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  context.log('[snapshots/latest] Handling request.');

  const metadata = await getLatestSnapshotMetadata();
  if (!metadata) {
    return {
      status: 503,
      jsonBody: {
        code: 'snapshot_unavailable',
        message: 'No snapshot available yet.',
        traceId: context.invocationId,
      },
    };
  }

  const signedUrl = generateSnapshotSas(metadata.blobPath);

  return {
    status: 200,
    jsonBody: {
      schemaVersion: metadata.schemaVersion,
      snapshotVersion: metadata.snapshotVersion,
      sizeBytes: metadata.sizeBytes,
      sha256: metadata.sha256,
      signedUrl,
      createdAtUtc: metadata.createdAtUtc,
      counts: metadata.counts,
    },
  };
}

app.http('snapshots-latest', {
  methods: ['GET'],
  authLevel: 'anonymous',
  route: 'v1/snapshots/latest',
  handler: snapshotsLatest,
});