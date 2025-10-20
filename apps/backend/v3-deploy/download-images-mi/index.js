const { getPool } = require('../shared/db/postgresPool');
const { batchDownloadImages } = require('../services/imageDownloadServiceMI'); // Use MI version

module.exports = async function (context, req) {
    context.log('[download-images-mi] Starting image download process with Managed Identity');
    
    try {
        // Get cocktails without local images
        const pool = getPool();
        const query = `
            SELECT id, name, image_url 
            FROM drinks 
            WHERE image_url IS NOT NULL 
            AND image_url NOT LIKE '%blob.core.windows.net%'
            ORDER BY id
        `;
        
        const result = await pool.query(query);
        const cocktails = result.rows;
        
        context.log(`[download-images-mi] Found ${cocktails.length} cocktails needing image download`);
        
        if (cocktails.length === 0) {
            context.res = {
                status: 200,
                body: {
                    message: 'No images to download',
                    totalCocktails: 0,
                    downloaded: 0,
                    failed: 0,
                    alreadyExists: 0
                }
            };
            return;
        }
        
        // Download images in batches using Managed Identity
        const downloadResults = await batchDownloadImages(cocktails, 5);
        
        // Update database with new image URLs
        const updatePromises = downloadResults
            .filter(r => r.success && !r.error?.includes('already exists'))
            .map(r => 
                pool.query(
                    'UPDATE drinks SET image_url = $1 WHERE id = $2',
                    [r.imageUrl, r.id]
                )
            );
        
        await Promise.all(updatePromises);
        
        // Calculate summary
        const summary = {
            message: 'Image download completed using Managed Identity',
            totalCocktails: cocktails.length,
            downloaded: downloadResults.filter(r => r.success && !r.error?.includes('already exists')).length,
            failed: downloadResults.filter(r => !r.success).length,
            alreadyExists: downloadResults.filter(r => r.error?.includes('already exists')).length,
            authMethod: 'managed-identity',
            results: downloadResults
        };
        
        context.log(`[download-images-mi] Download complete: ${summary.downloaded} new, ${summary.alreadyExists} existing, ${summary.failed} failed`);
        
        context.res = {
            status: 200,
            body: summary
        };
        
    } catch (error) {
        context.log.error('[download-images-mi] Error:', error);
        
        let errorMessage = 'Failed to download images';
        let errorCode = 'download_failed';
        
        if (error.message?.includes('DefaultAzureCredential') || error.message?.includes('ManagedIdentityCredential')) {
            errorMessage = 'Managed Identity authentication failed. Ensure the identity has proper blob storage roles.';
            errorCode = 'auth_failed';
        } else if (error.message?.includes('STORAGE_ACCOUNT_NAME')) {
            errorMessage = 'Storage account name not configured.';
            errorCode = 'missing_configuration';
        }
        
        context.res = {
            status: 500,
            body: {
                error: errorCode,
                message: errorMessage,
                details: process.env.NODE_ENV === 'development' ? error.message : undefined
            }
        };
    }
};
