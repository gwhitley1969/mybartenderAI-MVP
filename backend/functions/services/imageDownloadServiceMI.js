const { DefaultAzureCredential } = require("@azure/identity");
const { BlobServiceClient } = require("@azure/storage-blob");
const https = require('https');
const { URL } = require('url');

// Get storage account name
const getStorageAccountName = () => {
    if (!process.env.STORAGE_ACCOUNT_NAME) {
        throw new Error('STORAGE_ACCOUNT_NAME environment variable is required when using Managed Identity.');
    }
    return process.env.STORAGE_ACCOUNT_NAME;
};

// Lazy initialization of BlobServiceClient with Managed Identity
let blobServiceClient = null;
const getBlobServiceClient = () => {
    if (!blobServiceClient) {
        const accountName = getStorageAccountName();
        const credential = new DefaultAzureCredential({
            // Optional: specify the managed identity client ID if needed
            // managedIdentityClientId: '94d9cf74-99a3-49d5-9be4-98ce2eae1d33'
        });
        
        blobServiceClient = new BlobServiceClient(
            `https://${accountName}.blob.core.windows.net`,
            credential
        );
    }
    return blobServiceClient;
};

const downloadImage = (url) => {
    return new Promise((resolve, reject) => {
        https.get(url, (response) => {
            if (response.statusCode === 200) {
                const chunks = [];
                response.on('data', (chunk) => chunks.push(chunk));
                response.on('end', () => resolve(Buffer.concat(chunks)));
                response.on('error', reject);
            } else {
                reject(new Error(`Failed to download image: ${response.statusCode}`));
            }
        }).on('error', reject);
    });
};

const uploadImageToBlob = async (imageBuffer, blobName) => {
    const containerName = 'drink-images';
    const containerClient = getBlobServiceClient().getContainerClient(containerName);
    
    // Create container if it doesn't exist
    await containerClient.createIfNotExists({
        access: 'blob' // Public read access for images
    });
    
    const blockBlobClient = containerClient.getBlockBlobClient(blobName);
    
    // Determine content type from file extension
    const extension = blobName.split('.').pop()?.toLowerCase();
    const contentType = extension === 'png' ? 'image/png' : 'image/jpeg';
    
    await blockBlobClient.uploadData(imageBuffer, {
        blobHTTPHeaders: {
            blobContentType: contentType,
            blobCacheControl: 'public, max-age=86400' // Cache for 24 hours
        }
    });
    
    return blockBlobClient.url;
};

const downloadAndStoreCocktailImage = async (cocktail) => {
    const result = {
        id: cocktail.id,
        name: cocktail.name,
        success: false,
        error: null,
        imageUrl: null
    };
    
    try {
        if (!cocktail.image_url) {
            result.error = 'No image URL provided';
            return result;
        }
        
        // Parse URL to get file extension
        const url = new URL(cocktail.image_url);
        const pathParts = url.pathname.split('/');
        const filename = pathParts[pathParts.length - 1];
        const extension = filename.includes('.') ? filename.split('.').pop() : 'jpg';
        
        // Create blob name: cocktails/{id}.{extension}
        const blobName = `cocktails/${cocktail.id}.${extension}`;
        
        // Check if image already exists
    const containerClient = getBlobServiceClient().getContainerClient('drink-images');
        const blockBlobClient = containerClient.getBlockBlobClient(blobName);
        
        const exists = await blockBlobClient.exists();
        if (exists) {
            result.success = true;
            result.imageUrl = blockBlobClient.url;
            result.error = 'Image already exists';
            return result;
        }
        
        // Download image
        const imageBuffer = await downloadImage(cocktail.image_url);
        
        // Upload to blob storage
        const uploadedUrl = await uploadImageToBlob(imageBuffer, blobName);
        
        result.success = true;
        result.imageUrl = uploadedUrl;
        
    } catch (error) {
        result.error = error.message;
    }
    
    return result;
};

const batchDownloadImages = async (cocktails, batchSize = 5) => {
    const results = [];
    
    // Process in batches to avoid overwhelming the service
    for (let i = 0; i < cocktails.length; i += batchSize) {
        const batch = cocktails.slice(i, i + batchSize);
        const batchPromises = batch.map(cocktail => downloadAndStoreCocktailImage(cocktail));
        const batchResults = await Promise.all(batchPromises);
        results.push(...batchResults);
        
        // Small delay between batches
        if (i + batchSize < cocktails.length) {
            await new Promise(resolve => setTimeout(resolve, 100));
        }
    }
    
    return results;
};

module.exports = {
    downloadAndStoreCocktailImage,
    batchDownloadImages,
    getBlobServiceClient // Export for testing
};
