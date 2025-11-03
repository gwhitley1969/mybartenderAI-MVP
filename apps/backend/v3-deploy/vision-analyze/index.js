const axios = require('axios');

module.exports = async function (context, req) {
    context.log('Vision Analyze - Request received');

    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
    };

    // Handle OPTIONS
    if (req.method === 'OPTIONS') {
        context.res = { status: 200, headers, body: '' };
        return;
    }

    try {
        // Validate request
        const body = req.body || {};
        const { image, imageUrl } = body;

        if (!image && !imageUrl) {
            context.res = {
                status: 400,
                headers,
                body: { error: 'Either image (base64) or imageUrl is required' }
            };
            return;
        }

        // Get Computer Vision credentials
        const cvKey = process.env.AZURE_CV_KEY;
        const cvEndpoint = process.env.AZURE_CV_ENDPOINT;

        if (!cvKey || !cvEndpoint) {
            context.log.error('Computer Vision credentials not configured');
            context.res = {
                status: 500,
                headers,
                body: { error: 'Vision service not configured' }
            };
            return;
        }

        // Prepare image data
        let imageData;
        let contentType;

        if (imageUrl) {
            // URL-based image
            imageData = JSON.stringify({ url: imageUrl });
            contentType = 'application/json';
        } else {
            // Base64 image - convert to binary
            imageData = Buffer.from(image, 'base64');
            contentType = 'application/octet-stream';
        }

        // Call Computer Vision API
        const visionUrl = `${cvEndpoint}vision/v3.2/analyze?visualFeatures=Tags,Description,Objects,Brands&language=en`;

        context.log('Calling Computer Vision API...');
        const visionResponse = await axios.post(visionUrl, imageData, {
            headers: {
                'Ocp-Apim-Subscription-Key': cvKey,
                'Content-Type': contentType
            }
        });

        // Process results
        const analysis = visionResponse.data;
        context.log('Vision analysis complete:', {
            tags: analysis.tags?.length || 0,
            objects: analysis.objects?.length || 0,
            brands: analysis.brands?.length || 0
        });

        // Extract potential alcohol-related items
        const detectedItems = extractAlcoholItems(analysis);

        // Match to database ingredients
        const matchedIngredients = await matchToDatabase(context, detectedItems);

        // Return results
        context.res = {
            status: 200,
            headers,
            body: {
                success: true,
                detected: detectedItems,
                matched: matchedIngredients,
                confidence: calculateConfidence(analysis),
                rawAnalysis: {
                    description: analysis.description?.captions?.[0]?.text || '',
                    tags: analysis.tags?.slice(0, 10) || [],
                    brands: analysis.brands || []
                }
            }
        };

    } catch (error) {
        context.log.error('Vision analysis error:', error);
        context.res = {
            status: 500,
            headers,
            body: {
                error: 'Failed to analyze image',
                message: error.message
            }
        };
    }
};

// Helper function to extract alcohol-related items
function extractAlcoholItems(analysis) {
    const items = [];
    const alcoholKeywords = [
        'bottle', 'whiskey', 'vodka', 'rum', 'gin', 'tequila', 'wine',
        'beer', 'liquor', 'alcohol', 'spirit', 'bourbon', 'scotch',
        'brandy', 'cognac', 'champagne', 'prosecco', 'liqueur'
    ];

    // Check tags
    if (analysis.tags) {
        for (const tag of analysis.tags) {
            const name = tag.name.toLowerCase();
            if (alcoholKeywords.some(keyword => name.includes(keyword))) {
                items.push({
                    type: 'tag',
                    name: tag.name,
                    confidence: tag.confidence
                });
            }
        }
    }

    // Check brands (for alcohol brands)
    if (analysis.brands) {
        for (const brand of analysis.brands) {
            items.push({
                type: 'brand',
                name: brand.name,
                confidence: brand.confidence || 0.8
            });
        }
    }

    // Check objects for bottles
    if (analysis.objects) {
        for (const obj of analysis.objects) {
            if (obj.object.toLowerCase().includes('bottle')) {
                items.push({
                    type: 'object',
                    name: 'bottle',
                    confidence: obj.confidence,
                    rectangle: obj.rectangle
                });
            }
        }
    }

    return items;
}

// Helper function to match detected items to database
async function matchToDatabase(context, detectedItems) {
    // For MVP, use a simple matching table
    // In production, this would query PostgreSQL
    const knownBrands = {
        'absolut': 'Absolut Vodka',
        'jack daniels': 'Jack Daniels',
        'jack daniel\'s': 'Jack Daniels',
        'smirnoff': 'Smirnoff Vodka',
        'bacardi': 'Bacardi Rum',
        'captain morgan': 'Captain Morgan Rum',
        'grey goose': 'Grey Goose Vodka',
        'patron': 'Patron Tequila',
        'hennessy': 'Hennessy Cognac',
        'johnnie walker': 'Johnnie Walker Scotch',
        'jim beam': 'Jim Beam Bourbon',
        'maker\'s mark': 'Maker\'s Mark Bourbon',
        'tanqueray': 'Tanqueray Gin',
        'bombay': 'Bombay Sapphire Gin',
        'jose cuervo': 'Jose Cuervo Tequila',
        'crown royal': 'Crown Royal Whisky',
        'jameson': 'Jameson Irish Whiskey',
        'baileys': 'Baileys Irish Cream',
        'kahlua': 'Kahlua',
        'cointreau': 'Cointreau',
        'grand marnier': 'Grand Marnier',
        'amaretto': 'Amaretto',
        'southern comfort': 'Southern Comfort'
    };

    const matched = [];

    for (const item of detectedItems) {
        if (item.type === 'brand' || item.type === 'tag') {
            const itemLower = item.name.toLowerCase();

            // Direct brand match
            for (const [key, value] of Object.entries(knownBrands)) {
                if (itemLower.includes(key) || key.includes(itemLower)) {
                    matched.push({
                        ingredientName: value,
                        confidence: item.confidence,
                        matchType: 'brand'
                    });
                    break;
                }
            }
        }
    }

    // Remove duplicates
    const unique = matched.filter((item, index, self) =>
        index === self.findIndex((t) => t.ingredientName === item.ingredientName)
    );

    return unique;
}

// Helper function to calculate overall confidence
function calculateConfidence(analysis) {
    let totalConfidence = 0;
    let count = 0;

    if (analysis.tags) {
        for (const tag of analysis.tags.slice(0, 5)) {
            totalConfidence += tag.confidence;
            count++;
        }
    }

    return count > 0 ? totalConfidence / count : 0;
}
