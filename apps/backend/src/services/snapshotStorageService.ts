import {
  BlobServiceClient,
  StorageSharedKeyCredential,
  generateBlobSASQueryParameters,
  ContainerClient,
  BlobSASPermissions,
} from "@azure/storage-blob";
import path from "path";

interface UploadArgs {
  schemaVersion: string;
  snapshotVersion: string;
  compressed: Buffer;
  sha256: string;
}

interface UploadResult {
  blobPath: string;
  sizeBytes: number;
}

const getRequiredEnv = (key: string): string => {
  const value = process.env[key];
  if (!value) {
    throw new Error(`${key} environment variable is required.`);
  }
  return value;
};

const getContainerClient = (): ContainerClient => {
  const connectionString = getRequiredEnv("BLOB_STORAGE_CONNECTION_STRING");
  const containerName = process.env.SNAPSHOT_CONTAINER_NAME ?? "snapshots";
  const blobServiceClient = BlobServiceClient.fromConnectionString(connectionString);
  return blobServiceClient.getContainerClient(containerName);
};

const getSharedKeyCredential = (): StorageSharedKeyCredential => {
  const connectionString = getRequiredEnv("BLOB_STORAGE_CONNECTION_STRING");
  const parts = Object.fromEntries(
    connectionString.split(";").map((segment) => {
      const [key, value] = segment.split("=");
      return [key, value];
    }),
  ) as Record<string, string>;

  const accountName = parts.AccountName;
  const accountKey = parts.AccountKey;
  if (!accountName || !accountKey) {
    throw new Error('BLOB_STORAGE_CONNECTION_STRING must include AccountName and AccountKey.');
  }
  return new StorageSharedKeyCredential(accountName, accountKey);
};

export const uploadSnapshotArtifacts = async (
  args: UploadArgs,
): Promise<UploadResult> => {
  const containerClient = getContainerClient();
  await containerClient.createIfNotExists();

  const blobPath = path.posix.join(
    'snapshots',
    'sqlite',
    args.schemaVersion,
    `${args.snapshotVersion}.db.zst`,
  );
  const blobClient = containerClient.getBlockBlobClient(blobPath);

  await blobClient.uploadData(args.compressed, {
    blobHTTPHeaders: {
      blobContentType: 'application/octet-stream',
    },
  });

  const shaPath = `${blobPath}.sha256`;
  const shaBlobClient = containerClient.getBlockBlobClient(shaPath);
  await shaBlobClient.uploadData(Buffer.from(args.sha256, 'utf-8'), {
    blobHTTPHeaders: {
      blobContentType: 'text/plain',
    },
  });

  return {
    blobPath,
    sizeBytes: args.compressed.byteLength,
  };
};

export const generateSnapshotSas = (
  blobPath: string,
  expiresInMinutes = Number(process.env.SNAPSHOT_SAS_TTL_MINUTES ?? '15'),
): string => {
  const containerClient = getContainerClient();
  const credential = getSharedKeyCredential();
  const expiresOn = new Date(Date.now() + expiresInMinutes * 60 * 1000);

  const client = containerClient.getBlockBlobClient(blobPath);
  const sas = generateBlobSASQueryParameters(
    {
      containerName: containerClient.containerName,
      blobName: blobPath,
      permissions: BlobSASPermissions.parse('r'),
      expiresOn,
    },
    credential,
  );

  return `${client.url}?${sas.toString()}`;
};
