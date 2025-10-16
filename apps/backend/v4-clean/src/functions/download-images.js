"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const functions_1 = require("@azure/functions");
const postgresPool_1 = require("../../shared/db/postgresPool.js");
const storage_blob_1 = require("@azure/storage-blob");
const https_1 = __importDefault(require("https"));
const url_1 = require("url");
const BLOB_CONNECTION_STRING = process.env.BLOB_STORAGE_CONNECTION_STRING;
const IMAGES_CONTAINER_NAME = "drink-images";
const downloadImage = (url) => {
    return new Promise((resolve, reject) => {
        https_1.default.get(url, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`Failed to download ${url}: ${response.statusCode}`));
                return;
            }
            const chunks = [];
            response.on("data", (chunk) => chunks.push(chunk));
            response.on("end", () => resolve(Buffer.concat(chunks)));
            response.on("error", reject);
        }).on("error", reject);
    });
};
async function downloadImages(request, context) {
    context.log("[download-images] Starting image download process");
    try {
        // Initialize blob service
        const blobServiceClient = storage_blob_1.BlobServiceClient.fromConnectionString(BLOB_CONNECTION_STRING);
        const containerClient = blobServiceClient.getContainerClient(IMAGES_CONTAINER_NAME);
        // Ensure container exists (no public access)
        await containerClient.createIfNotExists();
        context.log(`[download-images] Container '${IMAGES_CONTAINER_NAME}' ready`);
        // Get all drinks with thumbnails
        const pool = (0, postgresPool_1.getPool)();
        const result = await pool.query("SELECT id, thumbnail FROM drinks WHERE thumbnail IS NOT NULL");
        context.log(`[download-images] Found ${result.rowCount} drinks with images`);
        let downloaded = 0;
        let skipped = 0;
        let failed = 0;
        const failures = [];
        // Process each drink
        for (const drink of result.rows) {
            try {
                // Extract filename from URL
                const url = new url_1.URL(drink.thumbnail);
                const filename = url.pathname.split("/").pop() || `${drink.id}.jpg`;
                const blobName = `drinks/${filename}`;
                const blobClient = containerClient.getBlockBlobClient(blobName);
                // Check if already exists
                const exists = await blobClient.exists();
                if (exists) {
                    skipped++;
                    continue;
                }
                // Download image
                context.log(`[download-images] Downloading ${filename}...`);
                const imageBuffer = await downloadImage(drink.thumbnail);
                // Upload to blob storage
                await blobClient.upload(imageBuffer, imageBuffer.length, {
                    blobHTTPHeaders: {
                        blobContentType: "image/jpeg"
                    }
                });
                downloaded++;
                // Update database with new URL
                const newUrl = blobClient.url;
                await pool.query("UPDATE drinks SET thumbnail = $1 WHERE id = $2", [newUrl, drink.id]);
            }
            catch (error) {
                failed++;
                const errorMessage = error instanceof Error ? error.message : String(error);
                failures.push(`${drink.id}: ${errorMessage}`);
                context.log(`[download-images] Failed to process ${drink.id}:`, error);
            }
        }
        const summary = {
            total: result.rowCount,
            downloaded,
            skipped,
            failed,
            failures: failures.slice(0, 10) // First 10 failures
        };
        context.log(`[download-images] Complete. Downloaded: ${downloaded}, Skipped: ${skipped}, Failed: ${failed}`);
        return {
            status: 200,
            jsonBody: summary
        };
    }
    catch (error) {
        context.log("[download-images] Fatal error:", error);
        return {
            status: 500,
            jsonBody: {
                error: "Failed to download images",
                message: error instanceof Error ? error.message : String(error)
            }
        };
    }
}
functions_1.app.http('download-images', {
    methods: ['POST'],
    authLevel: 'admin',
    route: 'admin/download-images',
    handler: downloadImages,
});


