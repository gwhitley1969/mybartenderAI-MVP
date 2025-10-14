"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateSnapshotSas = exports.uploadSnapshotArtifacts = void 0;
const storage_blob_1 = require("@azure/storage-blob");
const path_1 = __importDefault(require("path"));
const getRequiredEnv = (key) => {
    const value = process.env[key];
    if (!value) {
        throw new Error(`${key} environment variable is required.`);
    }
    return value;
};
const getContainerClient = () => {
    const connectionString = getRequiredEnv("BLOB_STORAGE_CONNECTION_STRING");
    const containerName = process.env.SNAPSHOT_CONTAINER_NAME ?? "snapshots";
    const blobServiceClient = storage_blob_1.BlobServiceClient.fromConnectionString(connectionString);
    return blobServiceClient.getContainerClient(containerName);
};
const getSharedKeyCredential = () => {
    const connectionString = getRequiredEnv("BLOB_STORAGE_CONNECTION_STRING");
    const parts = Object.fromEntries(connectionString.split(";").map((segment) => {
        const [key, value] = segment.split("=");
        return [key, value];
    }));
    const accountName = parts.AccountName;
    const accountKey = parts.AccountKey;
    if (!accountName || !accountKey) {
        throw new Error('BLOB_STORAGE_CONNECTION_STRING must include AccountName and AccountKey.');
    }
    return new storage_blob_1.StorageSharedKeyCredential(accountName, accountKey);
};
const uploadSnapshotArtifacts = async (args) => {
    const containerClient = getContainerClient();
    await containerClient.createIfNotExists();
    const blobPath = path_1.default.posix.join('snapshots', 'sqlite', args.schemaVersion, `${args.snapshotVersion}.db.zst`);
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
exports.uploadSnapshotArtifacts = uploadSnapshotArtifacts;
const generateSnapshotSas = (blobPath, expiresInMinutes = Number(process.env.SNAPSHOT_SAS_TTL_MINUTES ?? '15')) => {
    const containerClient = getContainerClient();
    const credential = getSharedKeyCredential();
    const expiresOn = new Date(Date.now() + expiresInMinutes * 60 * 1000);
    const client = containerClient.getBlockBlobClient(blobPath);
    const sas = (0, storage_blob_1.generateBlobSASQueryParameters)({
        containerName: containerClient.containerName,
        blobName: blobPath,
        permissions: storage_blob_1.BlobSASPermissions.parse('r'),
        expiresOn,
    }, credential);
    return `${client.url}?${sas.toString()}`;
};
exports.generateSnapshotSas = generateSnapshotSas;
