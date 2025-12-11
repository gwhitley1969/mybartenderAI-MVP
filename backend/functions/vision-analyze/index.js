const axios = require('axios');

module.exports = async function (context, req) {
    context.log('Vision Analyze - Request received (Claude Haiku 4.5)');

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

        // Get Claude credentials from environment (from Key Vault)
        const claudeApiKey = process.env.CLAUDE_API_KEY;
        const claudeEndpoint = process.env.CLAUDE_ENDPOINT;

        if (!claudeApiKey || !claudeEndpoint) {
            context.log.error('Claude credentials not configured');
            context.res = {
                status: 500,
                headers,
                body: { error: 'Vision service not configured' }
            };
            return;
        }

        context.log('Claude endpoint:', claudeEndpoint);

        // Prepare the image for Claude Haiku 4.5
        // IMPORTANT: Anthropic API requires raw base64 WITHOUT the data URI prefix
        let imageContent;
        if (imageUrl) {
            // For URL-based images, fetch and convert to base64
            try {
                const imageResponse = await axios.get(imageUrl, { responseType: 'arraybuffer' });
                const base64Image = Buffer.from(imageResponse.data, 'binary').toString('base64');
                imageContent = {
                    type: "image",
                    source: {
                        type: "base64",
                        media_type: "image/jpeg",
                        data: base64Image
                    }
                };
            } catch (urlError) {
                context.log.error('Failed to fetch image from URL:', urlError.message);
                context.res = {
                    status: 400,
                    headers,
                    body: { error: 'Failed to fetch image from URL' }
                };
                return;
            }
        } else {
            // For base64 images, use directly (remove data URI prefix if present)
            let base64Data = image;
            if (base64Data.startsWith('data:')) {
                base64Data = base64Data.split(',')[1];
            }

            imageContent = {
                type: "image",
                source: {
                    type: "base64",
                    media_type: "image/jpeg",
                    data: base64Data
                }
            };
        }

        // System prompt (separate from messages in Anthropic API)
        const systemPrompt = `You are an expert bartender and spirits inventory manager.

Your job is to analyze a photo of a bar or a group of bottles and identify each distinct bottle of alcohol that is clearly visible.

You must:
- Focus on bottles and drink containers, not random background objects.
- Infer the most likely brand name and type of alcohol using your general knowledge (e.g., "Smirnoff vodka", "Baileys Irish cream", "Evan Williams bourbon", "Hennessy cognac").
- Classify each bottle into a cocktail-relevant category like: "vodka", "gin", "rum", "tequila", "whiskey", "bourbon", "rye", "scotch", "brandy", "cognac", "vermouth", "liqueur", "aperitif", "digestif", "bitter", "beer", "wine", "syrup", "mixer", "other".

Always return a single JSON object and nothing else. Do not include explanations or prose.`;

        // User prompt with structured JSON request
        const userPrompt = `Analyze this image and return a JSON object with this exact structure:
{
  "bottles": [
    {
      "brand": "Brand Name",
      "type": "liquor type",
      "confidence": 0.95
    }
  ]
}

If no bottles are visible, return: {"bottles": []}`;

        // Build Anthropic Messages API request
        const requestBody = {
            model: "claude-haiku-4-5",
            max_tokens: 1024,
            system: systemPrompt,
            messages: [
                {
                    role: "user",
                    content: [
                        imageContent,
                        {
                            type: "text",
                            text: userPrompt
                        }
                    ]
                }
            ]
        };

        context.log('Calling Claude Haiku 4.5...');

        let claudeResponse;
        try {
            claudeResponse = await axios.post(claudeEndpoint, requestBody, {
                headers: {
                    'x-api-key': claudeApiKey,
                    'anthropic-version': '2023-06-01',
                    'Content-Type': 'application/json'
                },
                timeout: 60000
            });
        } catch (axiosError) {
            context.log.error('Claude API error:', axiosError.message);
            if (axiosError.response) {
                context.log.error('Status:', axiosError.response.status);
                context.log.error('Data:', JSON.stringify(axiosError.response.data));
            }

            context.res = {
                status: 500,
                headers,
                body: {
                    error: 'Vision API call failed',
                    message: axiosError.message,
                    details: axiosError.response?.data
                }
            };
            return;
        }

        // Validate response
        if (!claudeResponse.data?.content?.[0]?.text) {
            context.log.error('Invalid response from Claude');
            context.res = {
                status: 500,
                headers,
                body: { error: 'Invalid response from vision API' }
            };
            return;
        }

        const aiResponse = claudeResponse.data.content[0].text;
        context.log('Claude Haiku 4.5 raw response:', aiResponse);

        // Parse JSON response
        let detectedBottles = [];

        try {
            // Clean up response - remove markdown code blocks if present
            let cleanedResponse = aiResponse.trim();
            if (cleanedResponse.startsWith('```json')) {
                cleanedResponse = cleanedResponse.replace(/^```json\s*/, '').replace(/```\s*$/, '');
            } else if (cleanedResponse.startsWith('```')) {
                cleanedResponse = cleanedResponse.replace(/^```\s*/, '').replace(/```\s*$/, '');
            }

            const jsonResponse = JSON.parse(cleanedResponse);

            if (jsonResponse.bottles && Array.isArray(jsonResponse.bottles)) {
                detectedBottles = jsonResponse.bottles.map(bottle => ({
                    brand: bottle.brand,
                    type: bottle.type,
                    confidence: bottle.confidence || 0.90
                }));
            }

            context.log(`Parsed ${detectedBottles.length} bottles from JSON response`);

        } catch (parseError) {
            context.log.error('Failed to parse Claude JSON response:', parseError.message);
            context.log.error('Raw response was:', aiResponse);

            // Fallback: try to extract bottles from text
            if (!aiResponse.toUpperCase().includes('NONE') && aiResponse.trim().length > 0) {
                const lines = aiResponse.split('\n').filter(line => line.trim().length > 0);

                for (const line of lines) {
                    let brand = line
                        .replace(/^\d+[\.\)]\s*/, '')
                        .replace(/^[-•*]\s*/, '')
                        .replace(/["']/g, '')
                        .trim();

                    if (brand.length > 0 && !brand.toUpperCase().includes('NONE')) {
                        const typeMapping = inferTypeFromBrand(brand);

                        detectedBottles.push({
                            brand: brand,
                            type: typeMapping.type,
                            confidence: 0.85
                        });
                    }
                }
            }
        }

        context.log(`Detected ${detectedBottles.length} bottles:`, detectedBottles);

        // Match to database
        const matchedIngredients = matchBottlesToDatabase(context, detectedBottles);

        // Calculate average confidence
        const avgConfidence = detectedBottles.length > 0
            ? detectedBottles.reduce((sum, b) => sum + b.confidence, 0) / detectedBottles.length
            : 0;

        // Return response
        context.res = {
            status: 200,
            headers,
            body: {
                success: true,
                detected: detectedBottles.map(bottle => ({
                    type: 'brand',
                    name: bottle.brand,
                    confidence: bottle.confidence
                })),
                matched: matchedIngredients,
                confidence: avgConfidence,
                rawAnalysis: {
                    description: `Detected ${detectedBottles.length} alcohol bottle(s)`,
                    fullResponse: aiResponse,
                    tags: detectedBottles.map(b => ({
                        name: `${b.brand} ${b.type}`,
                        confidence: b.confidence
                    })),
                    brands: detectedBottles.map(b => ({
                        name: b.brand,
                        confidence: b.confidence
                    }))
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
                message: error.message,
                stack: error.stack
            }
        };
    }
};

// Helper function to infer alcohol type from brand name
function inferTypeFromBrand(brand) {
    const brandLower = brand.toLowerCase();

    // Vodka brands
    if (brandLower.includes('smirnoff') || brandLower.includes('absolut') ||
        brandLower.includes('grey goose') || brandLower.includes('ketel one') ||
        brandLower.includes('tito') || brandLower.includes('belvedere')) {
        return { type: 'Vodka' };
    }

    // Whiskey/Bourbon brands
    if (brandLower.includes('jack daniel') || brandLower.includes('jim beam') ||
        brandLower.includes('evan williams') || brandLower.includes('maker') ||
        brandLower.includes('jameson') || brandLower.includes('crown royal') ||
        brandLower.includes('johnnie walker') || brandLower.includes('glenfiddich')) {
        return { type: 'Whiskey' };
    }

    // Liqueur brands
    if (brandLower.includes('kahlua') || brandLower.includes('baileys') ||
        brandLower.includes('kahlúa') || brandLower.includes('amaretto') ||
        brandLower.includes('disaronno') || brandLower.includes('cointreau') ||
        brandLower.includes('grand marnier')) {
        return { type: 'Liqueur' };
    }

    // Cognac/Brandy
    if (brandLower.includes('hennessy') || brandLower.includes('cognac') ||
        brandLower.includes('remy martin') || brandLower.includes('courvoisier')) {
        return { type: 'Cognac' };
    }

    // Rum
    if (brandLower.includes('bacardi') || brandLower.includes('captain morgan') ||
        brandLower.includes('malibu') || brandLower.includes('rum')) {
        return { type: 'Rum' };
    }

    // Tequila
    if (brandLower.includes('patron') || brandLower.includes('jose cuervo') ||
        brandLower.includes('tequila')) {
        return { type: 'Tequila' };
    }

    // Gin
    if (brandLower.includes('tanqueray') || brandLower.includes('bombay') ||
        brandLower.includes('hendrick') || brandLower.includes('gin')) {
        return { type: 'Gin' };
    }

    // Default
    return { type: 'Spirit' };
}

// Helper function to match detected bottles to database
function matchBottlesToDatabase(context, detectedBottles) {
    const brandMappings = {
        'smirnoff': 'Smirnoff Vodka',
        'absolut': 'Absolut Vodka',
        'grey goose': 'Grey Goose Vodka',
        'ketel one': 'Ketel One Vodka',
        'kahlua': 'Kahlua Coffee Liqueur',
        'kahlúa': 'Kahlua Coffee Liqueur',
        'baileys': 'Baileys Irish Cream',
        "bailey's": 'Baileys Irish Cream',
        'jack daniels': 'Jack Daniels Whiskey',
        "jack daniel's": 'Jack Daniels Whiskey',
        'jameson': 'Jameson Irish Whiskey',
        'crown royal': 'Crown Royal Whisky',
        'hennessy': 'Hennessy Cognac',
        'patron': 'Patron Tequila',
        'jose cuervo': 'Jose Cuervo Tequila',
        'bacardi': 'Bacardi Rum',
        'captain morgan': 'Captain Morgan Rum',
        'tanqueray': 'Tanqueray Gin',
        'bombay': 'Bombay Sapphire Gin',
        "hendrick's": 'Hendricks Gin',
        'evan williams': 'Evan Williams Bourbon',
        "maker's mark": 'Makers Mark Bourbon',
        'jim beam': 'Jim Beam Bourbon',
        'johnnie walker': 'Johnnie Walker Scotch',
        'glenfiddich': 'Glenfiddich Scotch',
        'cointreau': 'Cointreau',
        'grand marnier': 'Grand Marnier',
        'amaretto': 'Amaretto',
        'disaronno': 'Disaronno Amaretto',
        'southern comfort': 'Southern Comfort'
    };

    const matched = [];

    for (const bottle of detectedBottles) {
        const brandLower = bottle.brand.toLowerCase();

        let matchedName = null;
        for (const [key, value] of Object.entries(brandMappings)) {
            if (brandLower.includes(key) || key.includes(brandLower)) {
                matchedName = value;
                break;
            }
        }

        if (!matchedName) {
            matchedName = `${bottle.brand} ${bottle.type}`;
        }

        matched.push({
            ingredientName: matchedName,
            confidence: bottle.confidence,
            matchType: 'brand'
        });
    }

    return matched;
}
