import { BlobServiceClient } from "@azure/storage-blob";
import https from "https";
import { URL } from "url";

const BLOB_CONNECTION_STRING = process.env.BLOB_STORAGE_CONNECTION_STRING!;
const IMAGES_CONTAINER_NAME = "drink-images";

interface ImageDownloadResult {
  drinkId: string;
  success: boolean;
  blobUrl?: string;
  error?: string;
}

const downloadImage = (url: string): Promise<Buffer> => {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download ${url}: ${response.statusCode}`));
        return;
      }

      const chunks: Buffer[] = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => resolve(Buffer.concat(chunks)));
      response.on("error", reject);
    }).on("error", reject);
  });
};

export const downloadDrinkImages = async (
  drinks: Array<{ id: string; thumbnail: string | null }>,
  log: (message: string) => void
): Promise<ImageDownloadResult[]> => {
  const results: ImageDownloadResult[] = [];
  
  if (!BLOB_CONNECTION_STRING) {
    log("[imageDownload] Warning: BLOB_STORAGE_CONNECTION_STRING not configured");
    return results;
  }

  try {
    // Initialize blob service
    const blobServiceClient = BlobServiceClient.fromConnectionString(BLOB_CONNECTION_STRING);
    const containerClient = blobServiceClient.getContainerClient(IMAGES_CONTAINER_NAME);
    
    // Ensure container exists (no public access)
    await containerClient.createIfNotExists();
    log(`[imageDownload] Container '${IMAGES_CONTAINER_NAME}' ready`);

    // Process drinks with thumbnails
    const drinksWithImages = drinks.filter(d => d.thumbnail);
    log(`[imageDownload] Processing ${drinksWithImages.length} drinks with images`);

    for (const drink of drinksWithImages) {
      try {
        // Extract filename from URL
        const url = new URL(drink.thumbnail!);
        const filename = url.pathname.split("/").pop() || `${drink.id}.jpg`;
        const blobName = `drinks/${filename}`;
        
        const blobClient = containerClient.getBlockBlobClient(blobName);
        
        // Check if already exists
        const exists = await blobClient.exists();
        if (exists) {
          results.push({
            drinkId: drink.id,
            success: true,
            blobUrl: blobClient.url,
          });
          continue;
        }

        // Download image
        log(`[imageDownload] Downloading ${filename}...`);
        const imageBuffer = await downloadImage(drink.thumbnail!);
        
        // Upload to blob storage
        await blobClient.upload(imageBuffer, imageBuffer.length, {
          blobHTTPHeaders: {
            blobContentType: "image/jpeg"
          }
        });
        
        results.push({
          drinkId: drink.id,
          success: true,
          blobUrl: blobClient.url,
        });
        
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : String(error);
        log(`[imageDownload] Failed to process ${drink.id}: ${errorMessage}`);
        results.push({
          drinkId: drink.id,
          success: false,
          error: errorMessage,
        });
      }
    }

    const successful = results.filter(r => r.success).length;
    const failed = results.filter(r => !r.success).length;
    log(`[imageDownload] Complete. Successful: ${successful}, Failed: ${failed}`);

  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    log(`[imageDownload] Fatal error: ${errorMessage}`);
  }

  return results;
};
