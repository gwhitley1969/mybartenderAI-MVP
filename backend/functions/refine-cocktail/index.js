const OpenAI = require('openai');

module.exports = async function (context, req) {
    context.log('Refine Cocktail - Request received');

    // CORS headers
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
    };

    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
        context.res = {
            status: 200,
            headers: headers,
            body: ''
        };
        return;
    }

    try {
        // Check for API key
        const apiKey = process.env.OPENAI_API_KEY;
        if (!apiKey) {
            context.log.error('OPENAI_API_KEY not found in environment');
            context.res = {
                status: 500,
                headers: headers,
                body: {
                    error: 'OpenAI API key not configured',
                    message: 'The server is not properly configured. Please contact support.'
                }
            };
            return;
        }

        // Parse request body
        const cocktail = req.body || {};

        // Validate required fields
        if (!cocktail.name || !cocktail.ingredients || cocktail.ingredients.length === 0) {
            context.res = {
                status: 400,
                headers: headers,
                body: {
                    error: 'Invalid request',
                    message: 'Cocktail must have a name and at least one ingredient.'
                }
            };
            return;
        }

        context.log('Refining cocktail:', cocktail.name);
        context.log('Ingredients count:', cocktail.ingredients.length);

        // Create OpenAI client configured for Azure
        const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
        const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4.1-mini';

        const openai = new OpenAI({
            apiKey: apiKey,
            baseURL: `${azureEndpoint}/openai/deployments/${deployment}`,
            defaultQuery: { 'api-version': '2024-10-21' },
            defaultHeaders: { 'api-key': apiKey }
        });

        // Build cocktail description for AI
        const ingredientsList = cocktail.ingredients
            .map(ing => `${ing.measure || ''} ${ing.name}`.trim())
            .join('\n');

        const cocktailDescription = `
Name: ${cocktail.name}
Category: ${cocktail.category || 'Not specified'}
Glass: ${cocktail.glass || 'Not specified'}
Alcoholic: ${cocktail.alcoholic || 'Not specified'}

Ingredients:
${ingredientsList}

Instructions:
${cocktail.instructions || 'Not specified'}
`.trim();

        // System prompt for cocktail refinement
        const systemPrompt = `You are an expert mixologist and cocktail consultant for MyBartenderAI's Create Studio feature.

Your role is to provide professional, constructive feedback on user-created cocktail recipes to help them refine and improve their creations.

When reviewing a cocktail recipe, analyze:
1. **Name**: Is it evocative, appropriate, and memorable?
2. **Ingredient Balance**: Are proportions appropriate? Any missing complementary ingredients?
3. **Technique**: Are the instructions clear, complete, and following proper mixology techniques?
4. **Glass Selection**: Is the suggested glass appropriate for the drink type and volume?
5. **Category**: Is the category classification accurate?
6. **Overall Appeal**: Does this create a balanced, enjoyable cocktail?

Provide your feedback in a structured JSON format with these fields:
{
  "overall": "Brief overall assessment (1-2 sentences)",
  "suggestions": [
    {
      "category": "name|ingredients|instructions|glass|balance|other",
      "suggestion": "Specific, actionable suggestion",
      "priority": "high|medium|low"
    }
  ],
  "refinedRecipe": {
    "name": "Improved name (if applicable, otherwise original)",
    "ingredients": [{"name": "ingredient", "measure": "amount"}],
    "instructions": "Refined instructions with proper technique",
    "glass": "Recommended glass type",
    "category": "Recommended category"
  }
}

Be encouraging and professional. Focus on enhancing what's already good while offering improvements.`;

        const userPrompt = `Please review and provide refinement suggestions for this cocktail recipe:

${cocktailDescription}`;

        context.log('Calling Azure OpenAI for refinement...');

        // Call OpenAI
        const completion = await openai.chat.completions.create({
            model: deployment,
            messages: [
                {
                    role: 'system',
                    content: systemPrompt
                },
                {
                    role: 'user',
                    content: userPrompt
                }
            ],
            temperature: 0.7,
            max_tokens: 1000,
            response_format: { type: 'json_object' }
        });

        const responseText = completion.choices[0]?.message?.content;
        let refinement;

        try {
            refinement = JSON.parse(responseText);
        } catch (parseError) {
            context.log.error('Failed to parse AI response as JSON:', parseError);
            // Fallback response if JSON parsing fails
            refinement = {
                overall: responseText || 'Unable to generate refinement suggestions.',
                suggestions: [],
                refinedRecipe: null
            };
        }

        context.log('Refinement generated successfully');

        // Return success response
        context.res = {
            status: 200,
            headers: headers,
            body: {
                ...refinement,
                usage: {
                    promptTokens: completion.usage?.prompt_tokens || 0,
                    completionTokens: completion.usage?.completion_tokens || 0,
                    totalTokens: completion.usage?.total_tokens || 0,
                }
            }
        };

    } catch (error) {
        context.log.error('Error in refine-cocktail:', error.message);
        context.log.error('Stack trace:', error.stack);

        context.res = {
            status: 500,
            headers: headers,
            body: {
                error: 'Internal server error',
                message: error.message,
                details: process.env.NODE_ENV === 'development' ? error.stack : undefined
            }
        };
    }
};
