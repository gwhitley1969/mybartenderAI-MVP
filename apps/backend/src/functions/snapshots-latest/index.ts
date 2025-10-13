import { getLatestSnapshotMetadata } from "../../services/snapshotMetadataService";
import { generateSnapshotSas } from "../../services/snapshotStorageService";

const httpTrigger = async function (context: any, req: any): Promise<void> {
  context.log('[snapshots/latest] Handling request.');

  const metadata = await getLatestSnapshotMetadata();
  if (!metadata) {
    context.res = {
      status: 503,
      body: {
        code: 'snapshot_unavailable',
        message: 'No snapshot available yet.',
        traceId: context.invocationId,
      },
    };
    return;
  }

  const signedUrl = generateSnapshotSas(metadata.blobPath);

  context.res = {
    status: 200,
    body: {
      schemaVersion: metadata.schemaVersion,
      snapshotVersion: metadata.snapshotVersion,
      sizeBytes: metadata.sizeBytes,
      sha256: metadata.sha256,
      signedUrl,
      createdAtUtc: metadata.createdAtUtc,
      counts: metadata.counts,
    },
  };
};

export default httpTrigger;
