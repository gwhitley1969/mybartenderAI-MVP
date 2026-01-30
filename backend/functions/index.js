const { app } = require('@azure/functions');
const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');
const { getOrCreateUser } = require('./services/userService');
const { decodeJwtClaims } = require('./shared/auth/jwtDecode');

// =============================================================================
// 1. Health - GET /health
// =============================================================================
app.http('health', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'health',
    handler: async (request, context) => {
        context.log('Health check endpoint called');

        return {
            status: 200,
            jsonBody: {
                status: 'ok',
                message: 'Azure Functions v4 Programming Model on Windows Premium',
                timestamp: new Date().toISOString()
            }
        };
    }
});

// =============================================================================
// 2. Ask Bartender Simple - POST /v1/ask-bartender-simple
// =============================================================================
app.http('ask-bartender-simple', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/ask-bartender-simple',
    handler: async (request, context) => {
        context.log('Ask Bartender Simple - Request received');

        // Simple CORS headers
        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
        };

        // Handle OPTIONS request
        if (request.method === 'OPTIONS') {
            return {
                status: 200,
                headers: headers,
                body: ''
            };
        }

        try {
            // Fire-and-forget: sync user profile from JWT
            const userId = request.headers.get('x-user-id');
            const authHeader = request.headers.get('authorization');
            const jwtClaims = !userId && authHeader ? decodeJwtClaims(authHeader) : null;
            const effectiveUserId = userId || jwtClaims?.sub;
            if (effectiveUserId) {
                const userEmail = request.headers.get('x-user-email') || jwtClaims?.email || null;
                const userName = request.headers.get('x-user-name') || jwtClaims?.name || null;
                getOrCreateUser(effectiveUserId, context, { email: userEmail, displayName: userName })
                    .catch(err => context.warn(`[Profile] Non-blocking sync failed: ${err.message}`));
            }

            // Check for API key
            const apiKey = process.env.OPENAI_API_KEY;
            if (!apiKey) {
                context.log('OPENAI_API_KEY not found in environment');
                return {
                    status: 500,
                    headers: headers,
                    jsonBody: {
                        error: 'OpenAI API key not configured',
                        message: 'The server is not properly configured. Please contact support.'
                    }
                };
            }

            // Parse request body
            const body = await request.json();
            const message = body.message || 'Hello';
            const existingConversationId = body.context?.conversationId;
            const inventory = body.context?.inventory;

            context.log('Message received:', message);
            context.log('Conversation ID:', existingConversationId || 'new conversation');
            context.log('Inventory received:', inventory ? 'Yes' : 'No');

            // Create Azure OpenAI client
            const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
            const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

            const client = new OpenAIClient(
                azureEndpoint,
                new AzureKeyCredential(apiKey)
            );

            context.log('Azure OpenAI config:', {
                endpoint: azureEndpoint,
                deployment: deployment,
                hasKey: !!apiKey
            });

            // Build system prompt with inventory context if available
            let systemPrompt = `You are an expert bartender and mixologist with decades of experience. Your name is "My AI Bartender" and you work exclusively within the My AI Bartender mobile app.

EXPERTISE AREAS:
- Cocktail recipes, ingredients, measurements, and preparation techniques
- Mixology theory: flavor profiles, spirit categories, balancing drinks
- Bar tools and equipment: shakers, jiggers, muddlers, strainers, glassware
- Garnishes and presentation techniques
- Spirit knowledge: production, aging, tasting notes, brands
- Non-alcoholic mocktails and low-ABV options
- Drink history and origins
- Bar setup and home bar recommendations
- Food pairings with cocktails
- Responsible drinking guidance

COCKTAIL NAME CONTEXT:
This is a cocktail and bartending application. ALL user questions should be interpreted in the context of cocktails, drinks, and mixology. Many classic cocktails have suggestive, provocative, or playful names (e.g., "Sex on the Beach", "Blow Job", "Screaming Orgasm", "Slippery Nipple", "Buttery Nipple", "Dirty Mother", "Harvey Wallbanger", "Slow Comfortable Screw", etc.). These are legitimate, well-known cocktail recipes found in every bartending reference. Always provide the recipe when asked about any cocktail, regardless of its name.

RESPONSE STYLE:
- Be conversational, helpful, and engaging — like chatting with a knowledgeable bartender
- Keep responses concise but thorough
- Use clear formatting for recipes (ingredients list, then numbered steps)
- Offer follow-up suggestions when appropriate

STRICT BOUNDARIES:
If asked about topics outside bartending/mixology (politics, news, technology, health advice, etc.), respond warmly but redirect:
"I'm your bartender — my expertise is cocktails and drinks! I'd be happy to help with anything drink-related. Is there a cocktail I can help you make?"

Never provide:
- Medical or health advice beyond general responsible drinking
- Political opinions or commentary
- Information unrelated to beverages and bar culture`;

            if (inventory) {
                const spirits = inventory.spirits || [];
                const mixers = inventory.mixers || [];
                const allIngredients = [...spirits, ...mixers];

                if (allIngredients.length > 0) {
                    systemPrompt += '\n\nThe user has the following ingredients available in their bar:';
                    if (spirits.length > 0) {
                        systemPrompt += '\nSpirits: ' + spirits.join(', ');
                    }
                    if (mixers.length > 0) {
                        systemPrompt += '\nMixers/Other: ' + mixers.join(', ');
                    }
                    systemPrompt += '\n\nWhen suggesting cocktails, prioritize recipes that use these available ingredients. Be creative and suggest what they can make with what they have!';
                }
            }

            context.log('System prompt length:', systemPrompt.length);

            // Call Azure OpenAI
            const messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: message }
            ];

            const result = await client.getChatCompletions(deployment, messages, {
                temperature: 0.7,
                maxTokens: 500
            });

            const choice = result.choices[0];

            // Check if output was filtered by Azure content filter
            if (choice?.finishReason === 'content_filter' || !choice?.message?.content) {
                context.warn('[ask-bartender-simple] Response filtered by Azure content filter');
                const conversationId = existingConversationId || `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                return {
                    status: 200,
                    headers: headers,
                    jsonBody: {
                        response: "I'd be happy to help with that cocktail! Could you rephrase your question? For example, try asking 'What is the recipe for [drink name]?' and I'll get you the details.",
                        conversationId: conversationId,
                        filtered: true,
                        usage: {
                            promptTokens: result.usage?.promptTokens || 0,
                            completionTokens: result.usage?.completionTokens || 0,
                            totalTokens: result.usage?.totalTokens || 0,
                        }
                    }
                };
            }

            const responseText = choice.message.content;

            // Generate or use existing conversation ID
            const conversationId = existingConversationId || `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

            context.log('Response generated successfully');
            context.log('Using conversation ID:', conversationId);

            // Return success response
            return {
                status: 200,
                headers: headers,
                jsonBody: {
                    response: responseText,
                    conversationId: conversationId,
                    usage: {
                        promptTokens: result.usage?.promptTokens || 0,
                        completionTokens: result.usage?.completionTokens || 0,
                        totalTokens: result.usage?.totalTokens || 0,
                    }
                }
            };

        } catch (error) {
            // Check if error is from Azure content filter (input blocked)
            const isContentFilter = error.code === 'content_filter'
                || error.message?.includes('content filter')
                || error.message?.includes('content management policy')
                || (error.status === 400 && error.message?.includes('ResponsibleAIPolicyViolation'));

            if (isContentFilter) {
                context.warn(`[ask-bartender-simple] Input blocked by content filter: ${error.message}`);
                const conversationId = `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
                return {
                    status: 200,
                    headers: headers,
                    jsonBody: {
                        response: "I'd be happy to help with that cocktail! Could you rephrase your question? For example, try asking 'What is the recipe for [drink name]?' and I'll get you the details.",
                        conversationId: conversationId,
                        filtered: true
                    }
                };
            }

            context.error('Error in ask-bartender-simple:', error.message);
            context.error('Stack trace:', error.stack);

            return {
                status: 500,
                headers: headers,
                jsonBody: {
                    error: 'Internal server error',
                    message: error.message,
                    details: process.env.NODE_ENV === 'development' ? error.stack : undefined
                }
            };
        }
    }
});

// =============================================================================
// 3. Test KeyVault - GET /test/keyvault
// =============================================================================
app.http('test-keyvault', {
    methods: ['GET'],
    authLevel: 'function',
    route: 'test/keyvault',
    handler: async (request, context) => {
        const diagnostics = {
            endpoint: {
                exists: !!process.env.AZURE_OPENAI_ENDPOINT,
                value: process.env.AZURE_OPENAI_ENDPOINT || 'NOT_SET',
                isKeyVaultRef: (process.env.AZURE_OPENAI_ENDPOINT || '').startsWith('@Microsoft.KeyVault')
            },
            apiKey: {
                exists: !!process.env.OPENAI_API_KEY,
                length: process.env.OPENAI_API_KEY ? process.env.OPENAI_API_KEY.length : 0,
                prefix: process.env.OPENAI_API_KEY ? process.env.OPENAI_API_KEY.substring(0, 8) + '...' : 'NOT_SET',
                isKeyVaultRef: (process.env.OPENAI_API_KEY || '').startsWith('@Microsoft.KeyVault')
            },
            deployment: {
                exists: !!process.env.AZURE_OPENAI_DEPLOYMENT,
                value: process.env.AZURE_OPENAI_DEPLOYMENT || 'NOT_SET'
            }
        };

        return {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            jsonBody: diagnostics
        };
    }
});

// =============================================================================
// 4. Validate Age - POST /validate-age
// =============================================================================
app.http('validate-age', {
    methods: ['POST'],
    authLevel: 'anonymous',
    handler: async (request, context) => {
        context.log('Age verification request');

        const body = await request.json();

        // Extract birthdate
        let birthdate;
        if (body?.data?.userSignUpInfo?.attributes) {
            const attributes = body.data.userSignUpInfo.attributes;
            birthdate = attributes.birthdate?.value || attributes.birthdate;
            if (!birthdate) {
                const birthdateKey = Object.keys(attributes).find(key =>
                    key.toLowerCase().includes('dateofbirth') || key.toLowerCase().includes('birthdate')
                );
                if (birthdateKey) birthdate = attributes[birthdateKey]?.value || attributes[birthdateKey];
            }
        } else if (body?.birthdate) {
            birthdate = body.birthdate;
        }

        if (!birthdate) {
            return {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: {
                    data: {
                        "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                        "actions": [{ "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage", "message": "Date of birth is required." }]
                    }
                }
            };
        }

        // Parse birthdate
        let birthDate;
        const usDateRegex = /^(\d{2})\/(\d{2})\/(\d{4})$/;
        const usDateNoSepRegex = /^(\d{2})(\d{2})(\d{4})$/;
        const isoDateRegex = /^\d{4}-\d{2}-\d{2}$/;

        if (usDateRegex.test(birthdate)) {
            const match = birthdate.match(usDateRegex);
            birthDate = new Date(parseInt(match[3]), parseInt(match[1]) - 1, parseInt(match[2]));
        } else if (usDateNoSepRegex.test(birthdate)) {
            const match = birthdate.match(usDateNoSepRegex);
            birthDate = new Date(parseInt(match[3]), parseInt(match[1]) - 1, parseInt(match[2]));
        } else if (isoDateRegex.test(birthdate)) {
            birthDate = new Date(birthdate);
        } else {
            return {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: {
                    data: {
                        "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                        "actions": [{ "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage", "message": "Please enter valid birthdate (MM/DD/YYYY)." }]
                    }
                }
            };
        }

        if (isNaN(birthDate.getTime())) {
            return {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: {
                    data: {
                        "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                        "actions": [{ "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage", "message": "Invalid date." }]
                    }
                }
            };
        }

        // Calculate age
        const today = new Date();
        let age = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) age--;

        context.log(`Age: ${age}`);

        if (age < 21) {
            return {
                status: 200,
                headers: { 'Content-Type': 'application/json' },
                jsonBody: {
                    data: {
                        "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                        "actions": [{ "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage", "message": "You must be 21 or older." }]
                    }
                }
            };
        }

        return {
            status: 200,
            headers: { 'Content-Type': 'application/json' },
            jsonBody: {
                data: {
                    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
                    "actions": [{ "@odata.type": "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior" }]
                }
            }
        };
    }
});

// =============================================================================
// 5. Test MI Access - GET /test/mi-access
// =============================================================================
app.http('test-mi-access', {
    methods: ['GET'],
    authLevel: 'function',
    route: 'test/mi-access',
    handler: async (request, context) => {
        const { DefaultAzureCredential } = require("@azure/identity");
        const { BlobServiceClient } = require("@azure/storage-blob");

        context.log('[test-mi-access] Testing Managed Identity access to storage');

        const results = {
            timestamp: new Date().toISOString(),
            storageAccount: process.env.STORAGE_ACCOUNT_NAME,
            clientId: process.env.AZURE_CLIENT_ID,
            tests: {}
        };

        try {
            // Test 1: Can we create the credential?
            context.log('[test-mi-access] Creating DefaultAzureCredential...');
            const credential = new DefaultAzureCredential({
                managedIdentityClientId: process.env.AZURE_CLIENT_ID || undefined
            });
            results.tests.credentialCreated = true;

            // Test 2: Can we create BlobServiceClient?
            context.log('[test-mi-access] Creating BlobServiceClient...');
            const accountName = process.env.STORAGE_ACCOUNT_NAME || 'cocktaildbfun';
            const blobServiceClient = new BlobServiceClient(
                `https://${accountName}.blob.core.windows.net`,
                credential
            );
            results.tests.blobServiceClientCreated = true;

            // Test 3: Can we list containers?
            context.log('[test-mi-access] Attempting to list containers...');
            const containers = [];
            try {
                for await (const container of blobServiceClient.listContainers()) {
                    containers.push(container.name);
                    if (containers.length >= 5) break; // Limit to first 5
                }
                results.tests.listContainers = {
                    success: true,
                    containers: containers
                };
            } catch (listError) {
                results.tests.listContainers = {
                    success: false,
                    error: listError.message,
                    code: listError.code
                };
            }

            // Test 4: Can we access the snapshots container?
            context.log('[test-mi-access] Accessing snapshots container...');
            const containerName = process.env.SNAPSHOT_CONTAINER_NAME || 'snapshots';
            const containerClient = blobServiceClient.getContainerClient(containerName);

            try {
                const exists = await containerClient.exists();
                results.tests.snapshotsContainer = {
                    success: true,
                    exists: exists
                };

                // Test 5: Can we list blobs in the container?
                if (exists) {
                    context.log('[test-mi-access] Listing blobs in snapshots container...');
                    const blobs = [];
                    for await (const blob of containerClient.listBlobsFlat({ maxPageSize: 5 })) {
                        blobs.push(blob.name);
                        if (blobs.length >= 5) break;
                    }
                    results.tests.listBlobs = {
                        success: true,
                        blobCount: blobs.length,
                        sampleBlobs: blobs
                    };
                }
            } catch (containerError) {
                results.tests.snapshotsContainer = {
                    success: false,
                    error: containerError.message,
                    code: containerError.code
                };
            }

            // Test 6: Can we get a User Delegation Key?
            context.log('[test-mi-access] Attempting to get User Delegation Key...');
            try {
                const now = new Date();
                const startsOn = new Date(now.getTime() - 5 * 60 * 1000);
                const expiresOn = new Date(now.getTime() + 60 * 60 * 1000);

                const userDelegationKey = await blobServiceClient.getUserDelegationKey(
                    startsOn,
                    expiresOn
                );

                results.tests.userDelegationKey = {
                    success: true,
                    keyId: userDelegationKey.signedObjectId,
                    signedTenantId: userDelegationKey.signedTenantId,
                    signedService: userDelegationKey.signedService,
                    signedVersion: userDelegationKey.signedVersion
                };
            } catch (keyError) {
                results.tests.userDelegationKey = {
                    success: false,
                    error: keyError.message,
                    code: keyError.code,
                    statusCode: keyError.statusCode
                };
            }

            return {
                status: 200,
                jsonBody: results
            };

        } catch (error) {
            context.error('[test-mi-access] Error:', error);

            results.error = {
                message: error.message,
                code: error.code,
                stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
            };

            return {
                status: 500,
                jsonBody: results
            };
        }
    }
});

// =============================================================================
// 6. Test Write - GET /test/write
// =============================================================================
app.http('test-write', {
    methods: ['GET'],
    authLevel: 'function',
    route: 'test/write',
    handler: async (request, context) => {
        const { BlobServiceClient } = require('@azure/storage-blob');
        const { DefaultAzureCredential } = require('@azure/identity');

        context.log('[test-write] Testing blob write with Managed Identity');

        // Diagnostic information
        const diagnostics = {
            envVars: {
                STORAGE_ACCOUNT_NAME: process.env.STORAGE_ACCOUNT_NAME || 'NOT SET',
                AZURE_CLIENT_ID: process.env.AZURE_CLIENT_ID || 'NOT SET',
                SNAPSHOT_CONTAINER_NAME: process.env.SNAPSHOT_CONTAINER_NAME || 'NOT SET'
            },
            timestamp: new Date().toISOString()
        };

        context.log('[test-write] Environment check:', diagnostics.envVars);

        try {
            // Validate required environment variables
            const accountName = process.env.STORAGE_ACCOUNT_NAME;
            if (!accountName) {
                throw new Error('STORAGE_ACCOUNT_NAME environment variable is required but not set. Please configure it in Function App settings.');
            }

            const containerName = 'test-writes';

            // Log credential configuration
            const clientId = process.env.AZURE_CLIENT_ID;
            context.log(`[test-write] Using Managed Identity${clientId ? ` with Client ID: ${clientId}` : ' (system-assigned)'}`);

            // Create BlobServiceClient with Managed Identity
            const credential = new DefaultAzureCredential({
                managedIdentityClientId: clientId || undefined
            });

            const blobServiceClient = new BlobServiceClient(
                `https://${accountName}.blob.core.windows.net`,
                credential
            );

            // Get container client
            const containerClient = blobServiceClient.getContainerClient(containerName);

            // Create container if it doesn't exist
            context.log(`[test-write] Creating container if needed: ${containerName}`);
            const createResult = await containerClient.createIfNotExists();
            context.log(`[test-write] Container status: ${createResult.succeeded ? 'created' : 'already exists'}`);

            // Write a test blob
            const testContent = JSON.stringify({
                timestamp: new Date().toISOString(),
                message: 'Test write from Managed Identity',
                functionName: 'test-write',
                storageAccount: accountName,
                clientId: clientId || 'system-assigned',
                diagnostics: diagnostics
            }, null, 2);

            const blobName = `test-${Date.now()}.json`;
            const blockBlobClient = containerClient.getBlockBlobClient(blobName);

            context.log(`[test-write] Writing blob: ${blobName}`);
            const uploadResult = await blockBlobClient.upload(testContent, testContent.length, {
                blobHTTPHeaders: {
                    blobContentType: 'application/json'
                }
            });

            context.log(`[test-write] Upload successful! ETag: ${uploadResult.etag}`);

            return {
                status: 200,
                jsonBody: {
                    success: true,
                    message: 'Successfully wrote to blob storage using Managed Identity',
                    storageAccount: accountName,
                    container: containerName,
                    blob: blobName,
                    url: blockBlobClient.url,
                    authMethod: 'managed-identity',
                    clientId: clientId || 'system-assigned',
                    uploadETag: uploadResult.etag,
                    diagnostics: diagnostics
                }
            };

        } catch (error) {
            context.error('[test-write] Error:', error);
            context.error('[test-write] Error stack:', error.stack);

            let errorMessage = 'Failed to write to blob storage';
            let errorCode = 'write_failed';
            let suggestions = [];

            if (error.message?.includes('STORAGE_ACCOUNT_NAME')) {
                errorMessage = 'Missing STORAGE_ACCOUNT_NAME environment variable';
                errorCode = 'missing_config';
                suggestions.push('Set STORAGE_ACCOUNT_NAME=mbacocktaildb3 in Function App settings');
            } else if (error.message?.includes('DefaultAzureCredential') || error.message?.includes('ManagedIdentityCredential')) {
                errorMessage = 'Managed Identity authentication failed';
                errorCode = 'auth_failed';
                suggestions.push('Ensure the managed identity is assigned to the Function App');
                suggestions.push('Check that AZURE_CLIENT_ID is set to: 94d9cf74-99a3-49d5-9be4-98ce2eae1d33');
            } else if (error.message?.includes('403') || error.statusCode === 403) {
                errorMessage = 'Access denied - Managed Identity lacks required permissions';
                errorCode = 'access_denied';
                suggestions.push('Assign "Storage Blob Data Contributor" role to the managed identity');
                suggestions.push('Run: az role assignment create --assignee 94d9cf74-99a3-49d5-9be4-98ce2eae1d33 --role "Storage Blob Data Contributor" --scope /subscriptions/YOUR_SUB/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/mbacocktaildb3');
            } else if (error.message?.includes('404')) {
                errorMessage = 'Storage account not found';
                errorCode = 'not_found';
                suggestions.push('Verify storage account name is correct: mbacocktaildb3');
                suggestions.push('Check that the storage account exists in the same subscription');
            }

            return {
                status: 500,
                jsonBody: {
                    error: errorCode,
                    message: errorMessage,
                    details: error.message,
                    statusCode: error.statusCode,
                    storageAccount: process.env.STORAGE_ACCOUNT_NAME || 'NOT SET',
                    clientId: process.env.AZURE_CLIENT_ID || 'NOT SET',
                    suggestions: suggestions,
                    diagnostics: diagnostics
                }
            };
        }
    }
});

// =============================================================================
// 7. Ask Bartender - POST /ask-bartender
// =============================================================================
app.http('ask-bartender', {
    methods: ['POST'],
    authLevel: 'function',
    route: 'v1/ask-bartender',
    handler: async (request, context) => {
        const { z } = require('zod');
        const { trackEvent, trackException, getOrCreateTraceId } = require('./shared/telemetry');

        // Request validation schema
        const requestSchema = z.object({
            message: z.string().min(1).max(500),
            context: z.object({
                inventory: z.object({
                    spirits: z.array(z.string()).optional(),
                    mixers: z.array(z.string()).optional(),
                }).optional(),
                preferences: z.object({
                    preferredFlavors: z.array(z.string()).optional(),
                    dislikedFlavors: z.array(z.string()).optional(),
                    abvRange: z.string().optional(),
                }).optional(),
                conversationId: z.string().optional(),
            }).optional(),
        }).strict();

        const buildErrorResponse = (status, code, message, traceId, details) => {
            const errorBody = {
                code,
                message,
                traceId,
                ...(details ? { details } : {}),
            };

            return {
                status,
                headers: {
                    'Content-Type': 'application/json',
                },
                jsonBody: errorBody,
            };
        };

        // Check method
        if (request.method?.toUpperCase() !== 'POST') {
            return {
                status: 405,
                headers: { 'Allow': 'POST' },
                jsonBody: { error: 'Method not allowed' }
            };
        }

        const traceId = getOrCreateTraceId(request);

        trackEvent(context, traceId, 'ask-bartender.request.received', {
            method: request.method,
        });

        // Parse and validate request body
        let payload;
        try {
            const json = await request.json();
            payload = requestSchema.parse(json);
        } catch (error) {
            trackException(context, traceId, error);
            return buildErrorResponse(400, 'invalid_request', 'Request body does not match the expected schema.', traceId, {
                reason: error.message,
            });
        }

        // Build context for the AI
        let contextInfo = '';
        if (payload.context) {
            if (payload.context.inventory?.spirits?.length > 0) {
                contextInfo += `\nAvailable spirits: ${payload.context.inventory.spirits.join(', ')}.`;
            }
            if (payload.context.inventory?.mixers?.length > 0) {
                contextInfo += `\nAvailable mixers: ${payload.context.inventory.mixers.join(', ')}.`;
            }
            if (payload.context.preferences?.preferredFlavors?.length > 0) {
                contextInfo += `\nPreferred flavors: ${payload.context.preferences.preferredFlavors.join(', ')}.`;
            }
            if (payload.context.preferences?.dislikedFlavors?.length > 0) {
                contextInfo += `\nDisliked flavors: ${payload.context.preferences.dislikedFlavors.join(', ')}.`;
            }
            if (payload.context.preferences?.abvRange) {
                contextInfo += `\nABV preference: ${payload.context.preferences.abvRange}.`;
            }
        }

        // Default system prompt for the bartender
        const systemPrompt = `You are an expert bartender and mixologist with decades of experience. Your name is "My AI Bartender" and you work exclusively within the My AI Bartender mobile app.

EXPERTISE AREAS:
- Cocktail recipes, ingredients, measurements, and preparation techniques
- Mixology theory: flavor profiles, spirit categories, balancing drinks
- Bar tools and equipment: shakers, jiggers, muddlers, strainers, glassware
- Garnishes and presentation techniques
- Spirit knowledge: production, aging, tasting notes, brands
- Non-alcoholic mocktails and low-ABV options
- Drink history and origins
- Bar setup and home bar recommendations
- Food pairings with cocktails
- Responsible drinking guidance

COCKTAIL NAME CONTEXT:
This is a cocktail and bartending application. ALL user questions should be interpreted in the context of cocktails, drinks, and mixology. Many classic cocktails have suggestive, provocative, or playful names (e.g., "Sex on the Beach", "Blow Job", "Screaming Orgasm", "Slippery Nipple", "Buttery Nipple", "Dirty Mother", "Harvey Wallbanger", "Slow Comfortable Screw", etc.). These are legitimate, well-known cocktail recipes found in every bartending reference. Always provide the recipe when asked about any cocktail, regardless of its name.

RESPONSE STYLE:
- Be conversational, helpful, and engaging — like chatting with a knowledgeable bartender
- Keep responses concise but thorough
- Use clear formatting for recipes (ingredients list, then numbered steps)
- Offer follow-up suggestions when appropriate

STRICT BOUNDARIES:
If asked about topics outside bartending/mixology (politics, news, technology, health advice, etc.), respond warmly but redirect:
"I'm your bartender — my expertise is cocktails and drinks! I'd be happy to help with anything drink-related. Is there a cocktail I can help you make?"

Never provide:
- Medical or health advice beyond general responsible drinking
- Political opinions or commentary
- Information unrelated to beverages and bar culture`;

        // Call Azure OpenAI
        try {
            const apiKey = process.env.OPENAI_API_KEY;
            const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
            const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

            const client = new OpenAIClient(
                azureEndpoint,
                new AzureKeyCredential(apiKey)
            );

            const result = await client.getChatCompletions(deployment, [
                {
                    role: 'system',
                    content: systemPrompt + contextInfo,
                },
                {
                    role: 'user',
                    content: payload.message,
                },
            ], {
                temperature: 0.7,
                maxTokens: 500,
            });

            const responseText = result.choices[0]?.message?.content ||
                'I apologize, but I couldn\'t process your request. Please try again.';

            trackEvent(context, traceId, 'ask-bartender.response.success', {
                promptTokens: result.usage?.promptTokens || 0,
                completionTokens: result.usage?.completionTokens || 0,
                totalTokens: result.usage?.totalTokens || 0,
            });

            return {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'X-Trace-Id': traceId,
                },
                jsonBody: {
                    response: responseText,
                    usage: {
                        promptTokens: result.usage?.promptTokens || 0,
                        completionTokens: result.usage?.completionTokens || 0,
                        totalTokens: result.usage?.totalTokens || 0,
                    },
                    conversationId: payload.context?.conversationId || traceId,
                },
            };

        } catch (error) {
            trackException(context, traceId, error);

            return buildErrorResponse(500, 'ai_service_error', 'Failed to process your request. Please try again.', traceId);
        }
    }
});

// =============================================================================
// 8. Ask Bartender Test - POST /ask-bartender-test
// =============================================================================
app.http('ask-bartender-test', {
    methods: ['POST'],
    authLevel: 'function',
    route: 'ask-bartender-test',
    handler: async (request, context) => {
        const { z } = require('zod');
        const { trackEvent, trackException, getOrCreateTraceId } = require('./shared/telemetry');

        // Request validation schema
        const requestSchema = z.object({
            message: z.string().min(1).max(500),
            context: z.object({
                inventory: z.object({
                    spirits: z.array(z.string()).optional(),
                    mixers: z.array(z.string()).optional(),
                }).optional(),
                preferences: z.object({
                    preferredFlavors: z.array(z.string()).optional(),
                    dislikedFlavors: z.array(z.string()).optional(),
                    abvRange: z.string().optional(),
                }).optional(),
                conversationId: z.string().optional(),
            }).optional(),
        }).strict();

        const buildErrorResponse = (status, code, message, traceId, details) => {
            const errorBody = {
                code,
                message,
                traceId,
                ...(details ? { details } : {}),
            };

            return {
                status,
                headers: {
                    'Content-Type': 'application/json',
                },
                jsonBody: errorBody,
            };
        };

        // Check method
        if (request.method?.toUpperCase() !== 'POST') {
            return {
                status: 405,
                headers: { 'Allow': 'POST' },
                jsonBody: { error: 'Method not allowed' }
            };
        }

        const traceId = getOrCreateTraceId(request);

        trackEvent(context, traceId, 'ask-bartender-test.request.received', {
            method: request.method,
        });

        // Parse and validate request body
        let payload;
        try {
            const json = await request.json();
            payload = requestSchema.parse(json);
        } catch (error) {
            trackException(context, traceId, error);
            return buildErrorResponse(400, 'invalid_request', 'Request body does not match the expected schema.', traceId, {
                reason: error.message,
            });
        }

        // Build context for the AI
        let contextInfo = '';
        if (payload.context) {
            if (payload.context.inventory?.spirits?.length > 0) {
                contextInfo += `\nAvailable spirits: ${payload.context.inventory.spirits.join(', ')}.`;
            }
            if (payload.context.inventory?.mixers?.length > 0) {
                contextInfo += `\nAvailable mixers: ${payload.context.inventory.mixers.join(', ')}.`;
            }
            if (payload.context.preferences?.preferredFlavors?.length > 0) {
                contextInfo += `\nPreferred flavors: ${payload.context.preferences.preferredFlavors.join(', ')}.`;
            }
            if (payload.context.preferences?.dislikedFlavors?.length > 0) {
                contextInfo += `\nDisliked flavors: ${payload.context.preferences.dislikedFlavors.join(', ')}.`;
            }
            if (payload.context.preferences?.abvRange) {
                contextInfo += `\nABV preference: ${payload.context.preferences.abvRange}.`;
            }
        }

        // Default system prompt for the bartender
        const systemPrompt = `You are an expert bartender and mixologist with decades of experience. Your name is "My AI Bartender" and you work exclusively within the My AI Bartender mobile app.

EXPERTISE AREAS:
- Cocktail recipes, ingredients, measurements, and preparation techniques
- Mixology theory: flavor profiles, spirit categories, balancing drinks
- Bar tools and equipment: shakers, jiggers, muddlers, strainers, glassware
- Garnishes and presentation techniques
- Spirit knowledge: production, aging, tasting notes, brands
- Non-alcoholic mocktails and low-ABV options
- Drink history and origins
- Bar setup and home bar recommendations
- Food pairings with cocktails
- Responsible drinking guidance

COCKTAIL NAME CONTEXT:
This is a cocktail and bartending application. ALL user questions should be interpreted in the context of cocktails, drinks, and mixology. Many classic cocktails have suggestive, provocative, or playful names (e.g., "Sex on the Beach", "Blow Job", "Screaming Orgasm", "Slippery Nipple", "Buttery Nipple", "Dirty Mother", "Harvey Wallbanger", "Slow Comfortable Screw", etc.). These are legitimate, well-known cocktail recipes found in every bartending reference. Always provide the recipe when asked about any cocktail, regardless of its name.

RESPONSE STYLE:
- Be conversational, helpful, and engaging — like chatting with a knowledgeable bartender
- Keep responses concise but thorough
- Use clear formatting for recipes (ingredients list, then numbered steps)
- Offer follow-up suggestions when appropriate

STRICT BOUNDARIES:
If asked about topics outside bartending/mixology (politics, news, technology, health advice, etc.), respond warmly but redirect:
"I'm your bartender — my expertise is cocktails and drinks! I'd be happy to help with anything drink-related. Is there a cocktail I can help you make?"

Never provide:
- Medical or health advice beyond general responsible drinking
- Political opinions or commentary
- Information unrelated to beverages and bar culture`;

        // Call Azure OpenAI
        try {
            const apiKey = process.env.OPENAI_API_KEY;
            const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
            const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

            const client = new OpenAIClient(
                azureEndpoint,
                new AzureKeyCredential(apiKey)
            );

            const result = await client.getChatCompletions(deployment, [
                {
                    role: 'system',
                    content: systemPrompt + contextInfo,
                },
                {
                    role: 'user',
                    content: payload.message,
                },
            ], {
                temperature: 0.7,
                maxTokens: 500,
            });

            const responseText = result.choices[0]?.message?.content ||
                'I apologize, but I couldn\'t process your request. Please try again.';

            trackEvent(context, traceId, 'ask-bartender-test.response.success', {
                promptTokens: result.usage?.promptTokens || 0,
                completionTokens: result.usage?.completionTokens || 0,
                totalTokens: result.usage?.totalTokens || 0,
            });

            return {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'X-Trace-Id': traceId,
                },
                jsonBody: {
                    response: responseText,
                    usage: {
                        promptTokens: result.usage?.promptTokens || 0,
                        completionTokens: result.usage?.completionTokens || 0,
                        totalTokens: result.usage?.totalTokens || 0,
                    },
                    conversationId: payload.context?.conversationId || traceId,
                },
            };

        } catch (error) {
            trackException(context, traceId, error);

            return buildErrorResponse(500, 'ai_service_error', 'Failed to process your request. Please try again.', traceId);
        }
    }
});

// =============================================================================
// 9. Voice Bartender - POST /voice-bartender
// =============================================================================
app.http('voice-bartender', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'voice-bartender',
    handler: async (request, context) => {
        const sdk = require('microsoft-cognitiveservices-speech-sdk');

        context.log('Voice Bartender - Request received');
        context.log('IMPORTANT: Using Azure Speech Services (NOT OpenAI Realtime API)');

        // CORS headers
        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
        };

        // Handle OPTIONS request
        if (request.method === 'OPTIONS') {
            return {
                status: 200,
                headers: headers,
                body: ''
            };
        }

        try {
            // Fire-and-forget: sync user profile from JWT
            const userId = request.headers.get('x-user-id');
            const authHeader = request.headers.get('authorization');
            const jwtClaims = !userId && authHeader ? decodeJwtClaims(authHeader) : null;
            const effectiveUserId = userId || jwtClaims?.sub;
            if (effectiveUserId) {
                const userEmail = request.headers.get('x-user-email') || jwtClaims?.email || null;
                const userName = request.headers.get('x-user-name') || jwtClaims?.name || null;
                getOrCreateUser(effectiveUserId, context, { email: userEmail, displayName: userName })
                    .catch(err => context.warn(`[Profile] Non-blocking sync failed: ${err.message}`));
            }

            // Check for required Azure Speech Services configuration
            const speechKey = process.env.AZURE_SPEECH_KEY;
            const speechRegion = process.env.AZURE_SPEECH_REGION;
            const openaiKey = process.env.OPENAI_API_KEY;

            if (!speechKey || !speechRegion) {
                context.error('Azure Speech Services not configured');
                return {
                    status: 500,
                    headers: headers,
                    jsonBody: {
                        error: 'Azure Speech Services not configured',
                        message: 'The server is missing Azure Speech configuration. Please contact support.'
                    }
                };
            }

            if (!openaiKey) {
                context.error('OpenAI API key not found');
                return {
                    status: 500,
                    headers: headers,
                    jsonBody: {
                        error: 'OpenAI API key not configured',
                        message: 'The server is not properly configured. Please contact support.'
                    }
                };
            }

            // Parse request body
            const body = await request.json();
            const audioBase64 = body.audioData;
            const voicePreference = body.voicePreference || 'en-US-JennyNeural';
            const conversationContext = body.context || {};

            if (!audioBase64) {
                return {
                    status: 400,
                    headers: headers,
                    jsonBody: {
                        error: 'Missing audio data',
                        message: 'No audio data provided in request'
                    }
                };
            }

            context.log('Processing voice request with Azure Speech Services');
            context.log('Selected Azure Neural voice:', voicePreference);

            // Helper: Azure Speech-to-Text
            const convertSpeechToText = async (audioBuffer) => {
                return new Promise((resolve, reject) => {
                    try {
                        const speechConfig = sdk.SpeechConfig.fromSubscription(speechKey, speechRegion);
                        speechConfig.speechRecognitionLanguage = 'en-US';

                        const pushStream = sdk.AudioInputStream.createPushStream();
                        pushStream.write(audioBuffer);
                        pushStream.close();

                        const audioConfig = sdk.AudioConfig.fromStreamInput(pushStream);
                        const recognizer = new sdk.SpeechRecognizer(speechConfig, audioConfig);

                        const phraseList = sdk.PhraseListGrammar.fromRecognizer(recognizer);
                        phraseList.addPhrase('Margarita');
                        phraseList.addPhrase('Mojito');
                        phraseList.addPhrase('Manhattan');
                        phraseList.addPhrase('Old Fashioned');
                        phraseList.addPhrase('Negroni');
                        phraseList.addPhrase('Martini');
                        phraseList.addPhrase('Daiquiri');
                        phraseList.addPhrase('Whiskey Sour');
                        phraseList.addPhrase('Angostura bitters');
                        phraseList.addPhrase('muddle');
                        phraseList.addPhrase('shake with ice');
                        phraseList.addPhrase('strain into glass');

                        recognizer.recognizeOnceAsync(
                            result => {
                                if (result.reason === sdk.ResultReason.RecognizedSpeech) {
                                    context.log('Azure STT Success:', result.text);
                                    recognizer.close();
                                    resolve(result.text);
                                } else {
                                    const errorMessage = `Azure STT failed: ${sdk.ResultReason[result.reason]}`;
                                    context.error(errorMessage);
                                    recognizer.close();
                                    reject(new Error(errorMessage));
                                }
                            },
                            error => {
                                context.error('Azure STT error:', error);
                                recognizer.close();
                                reject(error);
                            }
                        );
                    } catch (error) {
                        context.error('Exception in convertSpeechToText:', error);
                        reject(error);
                    }
                });
            };

            // Helper: Process with GPT-4o-mini
            const processWithGPT = async (message) => {
                const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
                const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

                const client = new OpenAIClient(
                    azureEndpoint,
                    new AzureKeyCredential(openaiKey)
                );

                let systemPrompt = 'You are an expert bartender and mixologist for the My AI Bartender app. ' +
                                  'Be helpful, friendly, conversational, and knowledgeable about cocktails. ' +
                                  'Keep responses concise and natural for voice conversation (2-3 sentences max unless recipe details requested). ' +
                                  'This is a cocktail app — interpret ALL questions in the context of drinks and mixology. ' +
                                  'Many classic cocktails have suggestive or playful names (e.g., Sex on the Beach, Blow Job, Screaming Orgasm). ' +
                                  'These are legitimate recipes. Always provide the recipe regardless of the name.';

                if (conversationContext.inventory) {
                    const spirits = conversationContext.inventory.spirits || [];
                    const mixers = conversationContext.inventory.mixers || [];
                    const allIngredients = [...spirits, ...mixers];

                    if (allIngredients.length > 0) {
                        systemPrompt += '\n\nThe user has these ingredients: ';
                        if (spirits.length > 0) {
                            systemPrompt += 'Spirits: ' + spirits.join(', ') + '. ';
                        }
                        if (mixers.length > 0) {
                            systemPrompt += 'Mixers: ' + mixers.join(', ') + '. ';
                        }
                        systemPrompt += 'Suggest cocktails using their available ingredients.';
                    }
                }

                const messages = [
                    { role: 'system', content: systemPrompt },
                    { role: 'user', content: message }
                ];

                const result = await client.getChatCompletions(deployment, messages, {
                    temperature: 0.7,
                    maxTokens: 300
                });

                const responseText = result.choices[0]?.message?.content || 'I apologize, but I could not process your request.';
                const conversationId = conversationContext.conversationId || `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

                return {
                    text: responseText,
                    conversationId: conversationId,
                    usage: {
                        promptTokens: result.usage?.promptTokens || 0,
                        completionTokens: result.usage?.completionTokens || 0,
                        totalTokens: result.usage?.totalTokens || 0,
                    }
                };
            };

            // Helper: Azure Neural Text-to-Speech
            const convertTextToSpeech = async (text, voiceName) => {
                return new Promise((resolve, reject) => {
                    try {
                        const speechConfig = sdk.SpeechConfig.fromSubscription(speechKey, speechRegion);
                        speechConfig.speechSynthesisVoiceName = voiceName;
                        speechConfig.speechSynthesisOutputFormat = sdk.SpeechSynthesisOutputFormat.Audio16Khz32KBitRateMonoMp3;

                        const synthesizer = new sdk.SpeechSynthesizer(speechConfig, null);

                        synthesizer.speakTextAsync(
                            text,
                            result => {
                                if (result.reason === sdk.ResultReason.SynthesizingAudioCompleted) {
                                    context.log('Azure TTS Success');
                                    const audioBase64 = Buffer.from(result.audioData).toString('base64');
                                    synthesizer.close();
                                    resolve(audioBase64);
                                } else {
                                    const errorMessage = `Azure TTS failed: ${sdk.ResultReason[result.reason]}`;
                                    context.error(errorMessage);
                                    synthesizer.close();
                                    reject(new Error(errorMessage));
                                }
                            },
                            error => {
                                context.error('Azure TTS error:', error);
                                synthesizer.close();
                                reject(error);
                            }
                        );
                    } catch (error) {
                        context.error('Exception in convertTextToSpeech:', error);
                        reject(error);
                    }
                });
            };

            // Helper: Calculate estimated cost
            const calculateCost = (audioBytes, textChars, gptTokens) => {
                const audioDurationSeconds = audioBytes / 32000;
                const sttCost = (audioDurationSeconds / 3600) * 1.00;
                const ttsCost = (textChars / 1000000) * 16.00;
                const gptCost = (gptTokens / 1000000) * 0.30;
                const totalCost = sttCost + ttsCost + gptCost;

                return {
                    speechToText: sttCost,
                    textToSpeech: ttsCost,
                    gptProcessing: gptCost,
                    total: totalCost,
                    currency: 'USD'
                };
            };

            // Step 1: Convert speech to text
            context.log('Step 1: Azure Speech-to-Text conversion');
            const audioBuffer = Buffer.from(audioBase64, 'base64');
            const transcript = await convertSpeechToText(audioBuffer);
            context.log('Transcript:', transcript);

            // Step 2: Process with GPT-4o-mini
            context.log('Step 2: GPT-4o-mini text processing');
            const aiResponse = await processWithGPT(transcript);
            context.log('AI response generated');

            // Step 3: Convert response to speech
            context.log('Step 3: Azure Neural Text-to-Speech conversion');
            const audioResponse = await convertTextToSpeech(aiResponse.text, voicePreference);
            context.log('Audio response generated');

            // Track usage
            const usage = {
                speechToTextDuration: audioBuffer.length / 32000,
                textToSpeechCharacters: aiResponse.text.length,
                gptTokens: aiResponse.usage.totalTokens,
                estimatedCost: calculateCost(audioBuffer.length, aiResponse.text.length, aiResponse.usage.totalTokens)
            };

            context.log('Usage stats:', usage);

            // Return response
            return {
                status: 200,
                headers: headers,
                jsonBody: {
                    audioData: audioResponse,
                    transcript: transcript,
                    textResponse: aiResponse.text,
                    conversationId: aiResponse.conversationId,
                    usage: usage,
                    technology: 'Azure Speech Services',
                    voiceUsed: voicePreference
                }
            };

        } catch (error) {
            context.error('Error in voice-bartender:', error.message);
            context.error('Stack trace:', error.stack);

            return {
                status: 500,
                headers: headers,
                jsonBody: {
                    error: 'Internal server error',
                    message: error.message,
                    details: process.env.NODE_ENV === 'development' ? error.stack : undefined
                }
            };
        }
    }
});

// =============================================================================
// 10. Recommend - POST /recommend
// =============================================================================
app.http('recommend', {
    methods: ['POST'],
    authLevel: 'function',
    route: 'recommend',
    handler: async (request, context) => {
        const { z } = require('zod');
        const { authenticateRequest, AuthenticationError } = require('./shared/auth/jwtMiddleware');
        const { enforceRequestGuards, RequestGuardError, getClientIp } = require('./shared/requestGuards');
        const { ensureWithinLimit, RateLimitError } = require('./services/pgRateLimiter');
        const { trackEvent, trackException, getOrCreateTraceId, sanitizeHeaders } = require('./shared/telemetry');
        const { incrementAndCheck, QuotaExceededError } = require('./services/pgTokenQuotaService');
        const { OpenAIRecommendationService } = require('./services/openAIRecommendationService');

        // Request validation schema
        const requestSchema = z
            .object({
                inventory: z
                    .object({
                        spirits: z.array(z.string()).optional(),
                        mixers: z.array(z.string()).optional(),
                    })
                    .strict(),
                tasteProfile: z
                    .object({
                        preferredFlavors: z.array(z.string()).optional(),
                        dislikedFlavors: z.array(z.string()).optional(),
                        abvRange: z.string().optional(),
                    })
                    .strict()
                    .optional(),
            })
            .strict();

        let openAiService = null;
        const getOpenAiService = () => {
            if (!openAiService) {
                openAiService = new OpenAIRecommendationService();
            }
            return openAiService;
        };

        const buildErrorResponse = (status, code, message, traceId, details) => {
            const errorBody = {
                code,
                message,
                traceId,
                ...(details ? { details } : {}),
            };

            return {
                status,
                headers: {
                    'Content-Type': 'application/json',
                },
                jsonBody: errorBody,
            };
        };

        const safeGetPathname = (url) => {
            try {
                if (!url) return undefined;
                const urlObj = new URL(url, 'http://localhost');
                return urlObj.pathname;
            } catch {
                return undefined;
            }
        };

        // Check method
        if (request.method?.toUpperCase() !== 'POST') {
            return {
                status: 405,
                headers: { 'Allow': 'POST' },
                jsonBody: { error: 'Method not allowed' }
            };
        }

        const traceId = getOrCreateTraceId(request);
        const requestPath = safeGetPathname(request.url);

        trackEvent(context, traceId, 'recommend.request.received', {
            path: requestPath,
            method: request.method,
            headers: sanitizeHeaders(request.headers),
        });

        // Apply request guards
        try {
            enforceRequestGuards(request, context);
        } catch (error) {
            if (error instanceof RequestGuardError) {
                trackException(context, traceId, error);
                return buildErrorResponse(error.status, error.code, error.message, traceId);
            }
            trackException(context, traceId, error);
            throw error;
        }

        // Authenticate request
        let authenticatedUser;
        try {
            authenticatedUser = await authenticateRequest(request, context);
        } catch (error) {
            if (error instanceof AuthenticationError) {
                trackException(context, traceId, error);
                return buildErrorResponse(error.status, error.code, error.message, traceId);
            }
            trackException(context, traceId, error);
            throw error;
        }

        const userId = authenticatedUser.sub;
        if (!userId) {
            trackException(context, traceId, new Error('Missing subject claim in authenticated principal.'), { reason: 'missing_sub_claim' });
            return buildErrorResponse(400, 'missing_user_id', 'Authenticated principal must include a `sub` claim for quota enforcement.', traceId);
        }

        // Rate limiting
        const clientIp = getClientIp(request);
        try {
            await ensureWithinLimit(context, {
                userId,
                ipAddress: clientIp,
                path: requestPath,
            });
        } catch (error) {
            if (error instanceof RateLimitError) {
                trackException(context, traceId, error);
                return buildErrorResponse(429, 'rate_limit_exceeded', 'Too many requests. Please retry later.', traceId, {
                    retryAfterSeconds: error.retryAfterSeconds,
                });
            }
            trackException(context, traceId, error);
            throw error;
        }

        // Parse and validate request body
        let payload;
        try {
            const json = await request.json();
            payload = requestSchema.parse(json);
        } catch (error) {
            trackException(context, traceId, error);
            return buildErrorResponse(400, 'invalid_request', 'Request body does not match the expected schema.', traceId, {
                reason: error.message,
            });
        }

        // Generate recommendations
        try {
            const result = await getOpenAiService().recommend({
                inventory: payload.inventory,
                tasteProfile: payload.tasteProfile,
                traceId,
            });

            // Check token quota
            try {
                await incrementAndCheck(userId, result.usage.totalTokens);
            } catch (error) {
                if (error instanceof QuotaExceededError) {
                    trackException(context, traceId, error);
                    return buildErrorResponse(429, 'quota_exceeded', 'Monthly token quota exceeded.', traceId, {
                        remainingTokens: error.remaining
                    });
                }
                throw error;
            }

            trackEvent(context, traceId, 'recommend.response.success', {
                cacheHit: result.cacheHit,
                cacheKeyHash: getOpenAiService().cacheKeyHash,
                promptTokens: result.usage.promptTokens,
                completionTokens: result.usage.completionTokens,
            });

            return {
                status: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'X-Cache-Hit': String(result.cacheHit),
                },
                jsonBody: result.recommendations,
            };

        } catch (error) {
            trackException(context, traceId, error);
            return buildErrorResponse(500, 'internal_error', 'An unexpected error occurred.', traceId);
        }
    }
});

// =============================================================================
// 11. Refine Cocktail - POST /v1/create-studio/refine
// =============================================================================
app.http('refine-cocktail', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/create-studio/refine',
    handler: async (request, context) => {
        context.log('Refine Cocktail - Request received');

        // CORS headers
        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
        };

        // Handle OPTIONS request
        if (request.method === 'OPTIONS') {
            return {
                status: 200,
                headers: headers,
                body: ''
            };
        }

        try {
            // Fire-and-forget: sync user profile from JWT
            const userId = request.headers.get('x-user-id');
            const authHeader = request.headers.get('authorization');
            const jwtClaims = !userId && authHeader ? decodeJwtClaims(authHeader) : null;
            const effectiveUserId = userId || jwtClaims?.sub;
            if (effectiveUserId) {
                const userEmail = request.headers.get('x-user-email') || jwtClaims?.email || null;
                const userName = request.headers.get('x-user-name') || jwtClaims?.name || null;
                getOrCreateUser(effectiveUserId, context, { email: userEmail, displayName: userName })
                    .catch(err => context.warn(`[Profile] Non-blocking sync failed: ${err.message}`));
            }

            // Check for API key
            const apiKey = process.env.OPENAI_API_KEY;
            if (!apiKey) {
                context.error('OPENAI_API_KEY not found in environment');
                return {
                    status: 500,
                    headers: headers,
                    jsonBody: {
                        error: 'OpenAI API key not configured',
                        message: 'The server is not properly configured. Please contact support.'
                    }
                };
            }

            // Parse request body
            const cocktail = await request.json();

            // Validate required fields
            if (!cocktail.name || !cocktail.ingredients || cocktail.ingredients.length === 0) {
                return {
                    status: 400,
                    headers: headers,
                    jsonBody: {
                        error: 'Invalid request',
                        message: 'Cocktail must have a name and at least one ingredient.'
                    }
                };
            }

            context.log('Refining cocktail:', cocktail.name);
            context.log('Ingredients count:', cocktail.ingredients.length);

            // Create Azure OpenAI client
            const azureEndpoint = process.env.AZURE_OPENAI_ENDPOINT || 'https://mybartenderai-scus.openai.azure.com';
            const deployment = process.env.AZURE_OPENAI_DEPLOYMENT || 'gpt-4o-mini';

            const client = new OpenAIClient(
                azureEndpoint,
                new AzureKeyCredential(apiKey)
            );

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

Be encouraging and professional. Focus on enhancing what's already good while offering improvements.

Note: Many cocktails have suggestive or playful names. This is a normal and accepted part of cocktail culture. Never flag or discourage a cocktail name for being suggestive.`;

            const userPrompt = `Please review and provide refinement suggestions for this cocktail recipe:

${cocktailDescription}`;

            context.log('Calling Azure OpenAI for refinement...');

            // Call OpenAI
            const result = await client.getChatCompletions(deployment, [
                {
                    role: 'system',
                    content: systemPrompt
                },
                {
                    role: 'user',
                    content: userPrompt
                }
            ], {
                temperature: 0.7,
                maxTokens: 1000,
                responseFormat: { type: 'json_object' }
            });

            const responseText = result.choices[0]?.message?.content;
            let refinement;

            try {
                refinement = JSON.parse(responseText);
            } catch (parseError) {
                context.error('Failed to parse AI response as JSON:', parseError);
                refinement = {
                    overall: responseText || 'Unable to generate refinement suggestions.',
                    suggestions: [],
                    refinedRecipe: null
                };
            }

            context.log('Refinement generated successfully');

            // Return success response
            return {
                status: 200,
                headers: headers,
                jsonBody: {
                    ...refinement,
                    usage: {
                        promptTokens: result.usage?.promptTokens || 0,
                        completionTokens: result.usage?.completionTokens || 0,
                        totalTokens: result.usage?.totalTokens || 0,
                    }
                }
            };

        } catch (error) {
            context.error('Error in refine-cocktail:', error.message);
            context.error('Stack trace:', error.stack);

            return {
                status: 500,
                headers: headers,
                jsonBody: {
                    error: 'Internal server error',
                    message: error.message,
                    details: process.env.NODE_ENV === 'development' ? error.stack : undefined
                }
            };
        }
    }
});

// =============================================================================
// 12. Vision Analyze - POST /vision-analyze (Claude Haiku 4.5)
// =============================================================================
app.http('vision-analyze', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'vision-analyze',
    handler: async (request, context) => {
        const axios = require('axios');

        context.log('Vision Analyze - Request received (Claude Haiku 4.5)');

        // CORS headers
        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
        };

        // Handle OPTIONS
        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            // Fire-and-forget: sync user profile from JWT
            const userId = request.headers.get('x-user-id');
            const authHeader = request.headers.get('authorization');
            const jwtClaims = !userId && authHeader ? decodeJwtClaims(authHeader) : null;
            const effectiveUserId = userId || jwtClaims?.sub;
            if (effectiveUserId) {
                const userEmail = request.headers.get('x-user-email') || jwtClaims?.email || null;
                const userName = request.headers.get('x-user-name') || jwtClaims?.name || null;
                getOrCreateUser(effectiveUserId, context, { email: userEmail, displayName: userName })
                    .catch(err => context.warn(`[Profile] Non-blocking sync failed: ${err.message}`));
            }

            // Validate request
            const body = await request.json();
            const { image, imageUrl } = body;

            if (!image && !imageUrl) {
                return {
                    status: 400,
                    headers,
                    jsonBody: { error: 'Either image (base64) or imageUrl is required' }
                };
            }

            // Get Claude credentials from environment (from Key Vault)
            const claudeApiKey = process.env.CLAUDE_API_KEY;
            const claudeEndpoint = process.env.CLAUDE_ENDPOINT;

            if (!claudeApiKey || !claudeEndpoint) {
                context.error('Claude credentials not configured');
                return {
                    status: 500,
                    headers,
                    jsonBody: { error: 'Vision service not configured' }
                };
            }

            context.log('Claude endpoint:', claudeEndpoint);

            // Prepare the image for Claude Haiku 4.5
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
                    context.error('Failed to fetch image from URL:', urlError.message);
                    return {
                        status: 400,
                        headers,
                        jsonBody: { error: 'Failed to fetch image from URL' }
                    };
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

            // System prompt for Claude
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
                context.error('Claude API error:', axiosError.message);
                if (axiosError.response) {
                    context.error('Status:', axiosError.response.status);
                    context.error('Data:', JSON.stringify(axiosError.response.data));
                }

                return {
                    status: 500,
                    headers,
                    jsonBody: {
                        error: 'Vision API call failed',
                        message: axiosError.message,
                        details: axiosError.response?.data
                    }
                };
            }

            // Validate response
            if (!claudeResponse.data?.content?.[0]?.text) {
                context.error('Invalid response from Claude');
                return {
                    status: 500,
                    headers,
                    jsonBody: { error: 'Invalid response from vision API' }
                };
            }

            const aiResponse = claudeResponse.data.content[0].text;
            context.log('Claude Haiku 4.5 raw response:', aiResponse);

            // Parse JSON response
            let detectedBottles = [];

            try {
                // Extract JSON from response - handle markdown code blocks and extra text
                let cleanedResponse = aiResponse.trim();

                // Try to extract JSON from markdown code block first
                const jsonBlockMatch = cleanedResponse.match(/```(?:json)?\s*([\s\S]*?)```/);
                if (jsonBlockMatch) {
                    cleanedResponse = jsonBlockMatch[1].trim();
                } else {
                    // Try to find raw JSON object
                    const jsonMatch = cleanedResponse.match(/\{[\s\S]*\}/);
                    if (jsonMatch) {
                        cleanedResponse = jsonMatch[0];
                    }
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
                context.error('Failed to parse Claude JSON response:', parseError.message);
                context.error('Raw response was:', aiResponse);

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

            context.log(`Detected ${detectedBottles.length} bottles`);

            // Match to database
            const matchedIngredients = matchBottlesToDatabase(detectedBottles);

            // Calculate average confidence
            const avgConfidence = detectedBottles.length > 0
                ? detectedBottles.reduce((sum, b) => sum + b.confidence, 0) / detectedBottles.length
                : 0;

            // Return response
            return {
                status: 200,
                headers,
                jsonBody: {
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
            context.error('Vision analysis error:', error);
            return {
                status: 500,
                headers,
                jsonBody: {
                    error: 'Failed to analyze image',
                    message: error.message,
                    stack: error.stack
                }
            };
        }

        // Helper function to infer alcohol type from brand name
        function inferTypeFromBrand(brand) {
            const brandLower = brand.toLowerCase();

            if (brandLower.includes('smirnoff') || brandLower.includes('absolut') ||
                brandLower.includes('grey goose') || brandLower.includes('ketel one') ||
                brandLower.includes('tito') || brandLower.includes('belvedere')) {
                return { type: 'Vodka' };
            }

            if (brandLower.includes('jack daniel') || brandLower.includes('jim beam') ||
                brandLower.includes('evan williams') || brandLower.includes('maker') ||
                brandLower.includes('jameson') || brandLower.includes('crown royal') ||
                brandLower.includes('johnnie walker') || brandLower.includes('glenfiddich')) {
                return { type: 'Whiskey' };
            }

            if (brandLower.includes('kahlua') || brandLower.includes('baileys') ||
                brandLower.includes('amaretto') || brandLower.includes('disaronno') ||
                brandLower.includes('cointreau') || brandLower.includes('grand marnier')) {
                return { type: 'Liqueur' };
            }

            if (brandLower.includes('hennessy') || brandLower.includes('cognac') ||
                brandLower.includes('remy martin') || brandLower.includes('courvoisier')) {
                return { type: 'Cognac' };
            }

            if (brandLower.includes('bacardi') || brandLower.includes('captain morgan') ||
                brandLower.includes('malibu') || brandLower.includes('rum')) {
                return { type: 'Rum' };
            }

            if (brandLower.includes('patron') || brandLower.includes('jose cuervo') ||
                brandLower.includes('tequila')) {
                return { type: 'Tequila' };
            }

            if (brandLower.includes('tanqueray') || brandLower.includes('bombay') ||
                brandLower.includes('hendrick') || brandLower.includes('gin')) {
                return { type: 'Gin' };
            }

            return { type: 'Spirit' };
        }

        // Helper function to match detected bottles to database
        function matchBottlesToDatabase(detectedBottles) {
            const brandMappings = {
                'smirnoff': 'Smirnoff Vodka',
                'absolut': 'Absolut Vodka',
                'grey goose': 'Grey Goose Vodka',
                'ketel one': 'Ketel One Vodka',
                'kahlua': 'Kahlua Coffee Liqueur',
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
    }
});

// =============================================================================
// 13. Speech Token - GET /speech-token
// =============================================================================
app.http('speech-token', {
    methods: ['GET', 'OPTIONS'],
    authLevel: 'function',
    route: 'speech-token',
    handler: async (request, context) => {
        const https = require('https');

        context.log('Speech Token - Request received');

        // CORS headers
        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, x-functions-key',
        };

        // Handle OPTIONS request
        if (request.method === 'OPTIONS') {
            return {
                status: 200,
                headers: headers,
                body: ''
            };
        }

        try {
            // Get Speech Services credentials from environment
            const speechKey = process.env.AZURE_SPEECH_KEY;
            const region = process.env.AZURE_SPEECH_REGION;

            if (!speechKey || !region) {
                context.error('Azure Speech credentials not found in environment');
                return {
                    status: 500,
                    headers: headers,
                    jsonBody: {
                        error: 'Speech Services not configured',
                        message: 'The server is not properly configured. Please contact support.'
                    }
                };
            }

            context.log('Requesting token for region:', region);

            // Exchange API key for ephemeral token (10 minutes)
            const token = await new Promise((resolve, reject) => {
                const options = {
                    hostname: `${region}.api.cognitive.microsoft.com`,
                    port: 443,
                    path: '/sts/v1.0/issueToken',
                    method: 'POST',
                    headers: {
                        'Ocp-Apim-Subscription-Key': speechKey,
                        'Content-Length': '0'
                    },
                };

                const tokenReq = https.request(options, (res) => {
                    let tokenData = '';

                    res.on('data', (chunk) => {
                        tokenData += chunk;
                    });

                    res.on('end', () => {
                        if (res.statusCode === 200) {
                            resolve(tokenData);
                        } else {
                            context.error('Token request failed:', res.statusCode, tokenData);
                            reject(new Error(`Token request failed: ${res.statusCode}`));
                        }
                    });
                });

                tokenReq.on('error', (error) => {
                    context.error('Token request error:', error);
                    reject(error);
                });

                tokenReq.end();
            });

            context.log('Token retrieved successfully');

            // Return token with region and expiration info
            return {
                status: 200,
                headers: headers,
                jsonBody: {
                    token: token,
                    region: region,
                    expiresIn: 600
                }
            };

        } catch (error) {
            context.error('Error in speech-token:', error.message);
            context.error('Stack trace:', error.stack);

            return {
                status: 500,
                headers: headers,
                jsonBody: {
                    error: 'Internal server error',
                    message: error.message,
                    details: process.env.NODE_ENV === 'development' ? error.stack : undefined
                }
            };
        }
    }
});

// =============================================================================
// 14. Auth Exchange - POST /v1/auth/exchange
// =============================================================================
app.http('auth-exchange', {
    methods: ['POST'],
    authLevel: 'anonymous',
    route: 'v1/auth/exchange',
    handler: async (request, context) => {
        const authExchangeModule = require('./auth-exchange');
        return await authExchangeModule(context, request);
    }
});

// =============================================================================
// 15. Auth Rotate - POST /v1/auth/rotate
// =============================================================================
app.http('auth-rotate', {
    methods: ['POST'],
    authLevel: 'function',
    route: 'v1/auth/rotate',
    handler: async (request, context) => {
        const authRotateModule = require('./auth-rotate');
        return await authRotateModule(context, request);
    }
});

// =============================================================================
// 16. Users Me - GET/PATCH /v1/users/me
// =============================================================================
app.http('users-me', {
    methods: ['GET', 'PATCH'],
    authLevel: 'anonymous',
    route: 'v1/users/me',
    handler: async (request, context) => {
        const usersMeModule = require('./users-me');
        return await usersMeModule(context, request);
    }
});

// =============================================================================
// 17. Snapshots Latest - GET /snapshots/latest
// =============================================================================
app.http('snapshots-latest', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'v1/snapshots/latest',
    handler: async (request, context) => {
        const snapshotsLatestModule = require('./snapshots-latest');
        return await snapshotsLatestModule(context, request);
    }
});

// =============================================================================
// 18. Snapshots Latest MI - GET /snapshots/latest-mi
// =============================================================================
app.http('snapshots-latest-mi', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'snapshots/latest-mi',
    handler: async (request, context) => {
        const snapshotsLatestMiModule = require('./snapshots-latest-mi');
        return await snapshotsLatestMiModule(context, request);
    }
});

// =============================================================================
// 19. Download Images - POST /download-images
// =============================================================================
app.http('download-images', {
    methods: ['POST'],
    authLevel: 'function',
    route: 'download-images',
    handler: async (request, context) => {
        const downloadImagesModule = require('./download-images');
        return await downloadImagesModule(context, request);
    }
});

// =============================================================================
// 20. Download Images MI - POST /download-images-mi
// =============================================================================
app.http('download-images-mi', {
    methods: ['POST'],
    authLevel: 'function',
    route: 'download-images-mi',
    handler: async (request, context) => {
        const downloadImagesMiModule = require('./download-images-mi');
        return await downloadImagesMiModule(context, request);
    }
});

// =============================================================================
// 21. Social Inbox - GET /v1/social/inbox
// =============================================================================
app.http('social-inbox', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'v1/social/inbox',
    handler: async (request, context) => {
        const socialInboxModule = require('./social-inbox');
        return await socialInboxModule(context, request);
    }
});

// =============================================================================
// 22. Social Invite - POST/GET /v1/social/invite/{token?}
// =============================================================================
app.http('social-invite', {
    methods: ['POST', 'GET'],
    authLevel: 'anonymous',
    route: 'v1/social/invite/{token?}',
    handler: async (request, context) => {
        const socialInviteModule = require('./social-invite');
        return await socialInviteModule(context, request);
    }
});

// =============================================================================
// 23. Social Outbox - GET /v1/social/outbox
// =============================================================================
app.http('social-outbox', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'v1/social/outbox',
    handler: async (request, context) => {
        const socialOutboxModule = require('./social-outbox');
        return await socialOutboxModule(context, request);
    }
});

// =============================================================================
// 24. Social Share Internal - POST /v1/social/share-internal
// =============================================================================
app.http('social-share-internal', {
    methods: ['POST'],
    authLevel: 'anonymous',
    route: 'v1/social/share-internal',
    handler: async (request, context) => {
        const socialShareInternalModule = require('./social-share-internal');
        return await socialShareInternalModule(context, request);
    }
});

// =============================================================================
// 25. Rotate Keys Timer - Timer Trigger (monthly)
// =============================================================================
app.timer('rotate-keys-timer', {
    schedule: '0 0 0 1 * *', // First day of every month at midnight
    handler: async (myTimer, context) => {
        const rotateKeysTimerModule = require('./rotate-keys-timer');
        return await rotateKeysTimerModule(context, myTimer);
    }
});

// =============================================================================
// 26. Sync CocktailDB - DISABLED (Dec 2025)
// TheCocktailDB sync is permanently disabled. PostgreSQL is now the master.
// Use rebuild-sqlite-snapshot.js to generate snapshots manually.
// =============================================================================
// DISABLED - DO NOT RE-ENABLE
// app.timer('sync-cocktaildb', {
//     schedule: '0 30 3 * * *', // Daily at 03:30 UTC
//     handler: async (myTimer, context) => {
//         const syncCocktaildbModule = require('./sync-cocktaildb');
//         return await syncCocktaildbModule(context, myTimer);
//     }
// });

// =============================================================================
// 27. Sync CocktailDB MI - DISABLED (Dec 2025)
// TheCocktailDB sync is permanently disabled. PostgreSQL is now the master.
// Use rebuild-sqlite-snapshot.js to generate snapshots manually.
// =============================================================================
// DISABLED - DO NOT RE-ENABLE
// app.timer('sync-cocktaildb-mi', {
//     schedule: '0 30 3 * * *', // Daily at 03:30 UTC
//     handler: async (myTimer, context) => {
//         const syncCocktaildbMiModule = require('./sync-cocktaildb-mi');
//         return await syncCocktaildbMiModule(context, myTimer);
//     }
// });

// =============================================================================
// 28. Cocktail Preview - GET /cocktail/{id}
// For social sharing with Open Graph tags
// URL: https://share.mybartenderai.com/cocktail/{id}
// =============================================================================
app.http('cocktail-preview', {
    methods: ['GET'],
    authLevel: 'anonymous',  // Public access for social crawlers
    route: 'cocktail/{id}',
    handler: async (request, context) => {
        const cocktailPreviewModule = require('./cocktail-preview');
        return await cocktailPreviewModule(context, request);
    }
});

// =============================================================================
// 29. Voice Realtime Test - GET/POST /v1/voice/test
// Tests Azure OpenAI Realtime API connectivity and ephemeral token generation
// =============================================================================
app.http('voice-realtime-test', {
    methods: ['GET', 'POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/voice/test',
    handler: async (request, context) => {
        context.log('Voice Realtime Test - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key'
        };

        // Handle CORS preflight
        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            // Get configuration from environment (populated from Key Vault)
            const realtimeEndpoint = process.env.AZURE_OPENAI_REALTIME_ENDPOINT;
            const realtimeKey = process.env.AZURE_OPENAI_REALTIME_KEY;
            const realtimeDeployment = process.env.AZURE_OPENAI_REALTIME_DEPLOYMENT;

            // Validate configuration
            const configCheck = {
                endpoint: !!realtimeEndpoint,
                key: !!realtimeKey,
                deployment: !!realtimeDeployment
            };

            if (!realtimeEndpoint || !realtimeKey || !realtimeDeployment) {
                context.error('Missing Realtime API configuration:', configCheck);
                return {
                    status: 500,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'Missing configuration',
                        configCheck,
                        message: 'One or more Realtime API settings are not configured. Check Key Vault references.'
                    }
                };
            }

            context.log('Configuration validated. Attempting ephemeral token request...');
            context.log('Endpoint:', realtimeEndpoint);
            context.log('Deployment:', realtimeDeployment);

            // Build the sessions URL for ephemeral token
            // Format: POST https://{endpoint}/openai/realtimeapi/sessions?api-version=2025-04-01-preview
            const sessionsUrl = `${realtimeEndpoint}/openai/realtimeapi/sessions?api-version=2025-04-01-preview`;

            context.log('Sessions URL:', sessionsUrl);

            // Session configuration for the ephemeral token request
            const sessionConfig = {
                model: realtimeDeployment,
                voice: 'alloy',
                instructions: 'You are a helpful AI bartender assistant.',
                input_audio_transcription: {
                    model: 'whisper-1'
                },
                turn_detection: {
                    type: 'semantic_vad',        // AI-based detection - understands speech semantically
                    eagerness: 'low',            // 'low' = more tolerant of background noise/pauses
                    create_response: true,
                    interrupt_response: false    // Prevents AI from being interrupted by noise
                },
                input_audio_noise_reduction: {
                    type: 'far_field'            // For phone speaker/mic - filters ambient noise
                }
            };

            // Request ephemeral token
            const response = await fetch(sessionsUrl, {
                method: 'POST',
                headers: {
                    'api-key': realtimeKey,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(sessionConfig)
            });

            const responseText = await response.text();
            context.log('Response status:', response.status);
            context.log('Response body:', responseText.substring(0, 500));

            if (!response.ok) {
                context.error('Ephemeral token request failed');
                return {
                    status: response.status,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'Ephemeral token request failed',
                        httpStatus: response.status,
                        details: responseText,
                        sessionsUrl: sessionsUrl
                    }
                };
            }

            // Parse successful response
            const sessionData = JSON.parse(responseText);

            // The WebRTC URL for East US2
            const webrtcUrl = 'https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc';

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    message: 'Realtime API connection validated successfully!',
                    session: {
                        id: sessionData.id,
                        model: sessionData.model,
                        voice: sessionData.voice,
                        hasClientSecret: !!sessionData.client_secret,
                        expiresAt: sessionData.client_secret?.expires_at
                    },
                    webrtcUrl,
                    note: 'Ephemeral token generated successfully. The token is valid for ~60 seconds and can be used for WebRTC connection.'
                }
            };

        } catch (error) {
            context.error('Exception in voice-realtime-test:', error.message);
            context.error('Stack:', error.stack);

            return {
                status: 500,
                headers,
                jsonBody: {
                    success: false,
                    error: 'Exception occurred',
                    message: error.message,
                    stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
                }
            };
        }
    }
});

// =============================================================================
// 30. Voice Session - POST /v1/voice/session
// Creates a voice session and returns ephemeral token for WebRTC connection
// Pro tier only, checks quota before issuing token
// =============================================================================
app.http('voice-session', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/voice/session',
    handler: async (request, context) => {
        context.log('Voice Session - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, x-user-id'
        };

        // Handle CORS preflight
        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            const db = require('./shared/database');

            // Get user ID from header (set by APIM after JWT validation)
            const userId = request.headers.get('x-user-id');

            if (!userId) {
                return {
                    status: 401,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'unauthorized',
                        message: 'User ID not provided'
                    }
                };
            }

            context.log('Checking user tier for azure_ad_sub:', userId);

            // Read APIM-forwarded profile headers from JWT claims
            const userEmail = request.headers.get('x-user-email') || null;
            const userName = request.headers.get('x-user-name') || null;

            // Look up or create user with email/display_name from APIM headers
            const user = await getOrCreateUser(userId, context, {
                email: userEmail,
                displayName: userName
            });

            if (user.tier !== 'pro') {
                return {
                    status: 403,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'tier_required',
                        requiredTier: 'pro',
                        currentTier: user.tier,
                        message: 'Voice AI is a Pro tier feature. Upgrade to Pro to access real-time voice conversations.'
                    }
                };
            }

            context.log('User is Pro tier, checking quota for internal user.id:', user.id);

            // Check voice quota using database function (uses internal UUID, not azure_ad_sub)
            const quotaResult = await db.query(
                'SELECT * FROM check_voice_quota($1)',
                [user.id]
            );

            const quota = quotaResult.rows[0];
            context.log('Quota check result:', quota);

            if (!quota.has_quota) {
                return {
                    status: 403,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'quota_exceeded',
                        quota: {
                            monthlyUsedSeconds: quota.monthly_used_seconds,
                            monthlyLimitSeconds: quota.monthly_limit_seconds,
                            addonSecondsRemaining: quota.addon_seconds_remaining,
                            totalRemainingSeconds: quota.total_remaining_seconds
                        },
                        message: 'Voice quota exhausted. Purchase additional minutes to continue.'
                    }
                };
            }

            // Parse request body for optional inventory context
            let inventory = null;
            try {
                const body = await request.json();
                inventory = body.inventory;
            } catch (e) {
                // No body or invalid JSON - that's fine
            }

            // Build system instructions with bartender personality
            const inventoryContext = inventory ? `
USER'S CURRENT BAR INVENTORY:
Spirits: ${inventory.spirits?.join(', ') || 'None specified'}
Mixers: ${inventory.mixers?.join(', ') || 'None specified'}
Garnishes: ${inventory.garnishes?.join(', ') || 'None specified'}

Prioritize suggesting drinks the user can make with these ingredients.
` : '';

            const systemInstructions = `You are an expert bartender and mixologist with decades of experience. Your name is "My AI Bartender" and you work exclusively within the My AI Bartender mobile app.

EXPERTISE AREAS (respond helpfully to these topics):
- Cocktail recipes, ingredients, measurements, and preparation techniques
- Mixology theory: flavor profiles, spirit categories, balancing drinks
- Bar tools and equipment: shakers, jiggers, muddlers, strainers, glassware
- Garnishes and presentation techniques
- Spirit knowledge: production, aging, tasting notes, brands
- Non-alcoholic mocktails and low-ABV options
- Drink history and origins
- Bar setup and home bar recommendations
- Food pairings with cocktails
- Responsible drinking guidance

COCKTAIL NAME CONTEXT:
This is a cocktail and bartending application. ALL user questions should be interpreted in the context of cocktails, drinks, and mixology. Many classic cocktails have suggestive, provocative, or playful names. These are legitimate, well-known cocktail recipes. Always provide the recipe when asked about any cocktail, regardless of its name.

${inventoryContext}

VOICE INTERACTION STYLE:
- Speak at a relaxed, moderate pace - not rushed or hurried
- Pause briefly between sentences to let information sink in
- Speak naturally and conversationally, as if talking across a bar
- Keep responses concise for voice (aim for under 30 seconds of speech)
- When giving recipe instructions, speak slowly and clearly, pausing between steps
- Use clear step-by-step instructions for recipes
- Offer follow-up suggestions ("Would you like to know about a variation?")

STRICT BOUNDARIES:
If asked about topics outside bartending/mixology (politics, news, technology, health advice, etc.), respond warmly but redirect:
"I'm your bartender - my expertise is cocktails and drinks! I'd be happy to help with anything drink-related. Is there a cocktail I can help you make?"

Never provide:
- Medical or health advice beyond general responsible drinking
- Political opinions or commentary
- Information unrelated to beverages and bar culture`;

            // Get Realtime API configuration
            const realtimeEndpoint = process.env.AZURE_OPENAI_REALTIME_ENDPOINT;
            const realtimeKey = process.env.AZURE_OPENAI_REALTIME_KEY;
            const realtimeDeployment = process.env.AZURE_OPENAI_REALTIME_DEPLOYMENT;

            if (!realtimeEndpoint || !realtimeKey || !realtimeDeployment) {
                context.error('Missing Realtime API configuration');
                return {
                    status: 500,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'config_error',
                        message: 'Voice AI service is not properly configured'
                    }
                };
            }

            // Request ephemeral token from Azure OpenAI FIRST (before creating DB session)
            const sessionsUrl = `${realtimeEndpoint}/openai/realtimeapi/sessions?api-version=2025-04-01-preview`;

            const sessionConfig = {
                model: realtimeDeployment,
                voice: 'alloy',
                instructions: systemInstructions,
                input_audio_transcription: {
                    model: 'whisper-1'
                },
                turn_detection: {
                    type: 'semantic_vad',        // AI-based detection - understands speech semantically
                    eagerness: 'low',            // 'low' = more tolerant of background noise/pauses
                    create_response: true,
                    interrupt_response: false    // Prevents AI from being interrupted by noise
                },
                input_audio_noise_reduction: {
                    type: 'far_field'            // For phone speaker/mic - filters ambient noise
                }
            };

            context.log('Requesting ephemeral token from Azure OpenAI...');
            const response = await fetch(sessionsUrl, {
                method: 'POST',
                headers: {
                    'api-key': realtimeKey,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(sessionConfig)
            });

            if (!response.ok) {
                const errorText = await response.text();
                context.error('Ephemeral token request failed:', response.status, errorText);

                return {
                    status: 500,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'token_error',
                        message: 'Failed to initialize voice session'
                    }
                };
            }

            const sessionData = await response.json();
            context.log('Ephemeral token obtained, realtime session:', sessionData.id);

            // NOW create session record in database with the realtime session_id
            const sessionInsertResult = await db.query(
                `INSERT INTO voice_sessions (user_id, session_id, status, started_at)
                 VALUES ($1, $2, 'active', NOW())
                 RETURNING id`,
                [user.id, sessionData.id]
            );
            const dbSessionId = sessionInsertResult.rows[0].id;
            context.log('Created database session:', dbSessionId);

            // WebRTC URL for East US2
            const webrtcUrl = 'https://eastus2.realtimeapi-preview.ai.azure.com/v1/realtimertc';

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    session: {
                        dbSessionId: dbSessionId,
                        realtimeSessionId: sessionData.id,
                        model: sessionData.model,
                        voice: sessionData.voice
                    },
                    token: {
                        value: sessionData.client_secret?.value,
                        expiresAt: sessionData.client_secret?.expires_at
                    },
                    webrtcUrl: webrtcUrl,
                    quota: {
                        remainingSeconds: quota.total_remaining_seconds,
                        monthlyUsedSeconds: quota.monthly_used_seconds,
                        monthlyLimitSeconds: quota.monthly_limit_seconds,
                        addonSecondsRemaining: quota.addon_seconds_remaining,
                        warningThreshold: 360 // 6 minutes = 80% of 30 min used
                    }
                }
            };

        } catch (error) {
            context.log('Exception in voice-session:', error.message);
            context.log('Stack:', error.stack);

            // Ensure headers are defined for error response
            const errorHeaders = {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, x-user-id'
            };

            return {
                status: 500,
                headers: errorHeaders,
                jsonBody: {
                    success: false,
                    error: 'exception',
                    message: error.message || 'An unexpected error occurred'
                }
            };
        }
    }
});

// =============================================================================
// 31. Voice Usage - POST /v1/voice/usage
// Records completed voice session usage and updates quotas
// Called by client when WebRTC session ends
// =============================================================================
app.http('voice-usage', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/voice/usage',
    handler: async (request, context) => {
        context.log('Voice Usage - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, x-user-id'
        };

        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            const db = require('./shared/database');

            const userId = request.headers.get('x-user-id');
            if (!userId) {
                return {
                    status: 401,
                    headers,
                    jsonBody: { success: false, error: 'unauthorized' }
                };
            }

            const body = await request.json();
            const { sessionId, durationSeconds, inputTokens, outputTokens, transcripts } = body;

            if (!sessionId || durationSeconds === undefined) {
                return {
                    status: 400,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'invalid_request',
                        message: 'sessionId and durationSeconds are required'
                    }
                };
            }

            context.log('Recording usage for session:', sessionId, 'duration:', durationSeconds);

            // Look up user by azure_ad_sub to get internal UUID
            const userResult = await db.query(
                'SELECT id FROM users WHERE azure_ad_sub = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return {
                    status: 404,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'user_not_found',
                        message: 'User not found'
                    }
                };
            }

            const internalUserId = userResult.rows[0].id;

            // Verify session belongs to user (using internal UUID)
            const sessionCheck = await db.query(
                'SELECT id FROM voice_sessions WHERE id = $1 AND user_id = $2',
                [sessionId, internalUserId]
            );

            if (sessionCheck.rows.length === 0) {
                return {
                    status: 404,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'session_not_found',
                        message: 'Session not found or does not belong to user'
                    }
                };
            }

            // Record the session completion using database function (with internal UUID)
            await db.query(
                'SELECT record_voice_session($1, $2, $3, $4, $5)',
                [internalUserId, sessionId, durationSeconds, inputTokens || null, outputTokens || null]
            );

            // Save transcripts if provided
            if (transcripts && Array.isArray(transcripts) && transcripts.length > 0) {
                for (const msg of transcripts) {
                    await db.query(
                        `INSERT INTO voice_messages (session_id, role, transcript, timestamp)
                         VALUES ($1, $2, $3, $4)`,
                        [sessionId, msg.role, msg.transcript, msg.timestamp || new Date()]
                    );
                }
                context.log('Saved', transcripts.length, 'transcript messages');
            }

            // Get updated quota (using internal UUID)
            const quotaResult = await db.query(
                'SELECT * FROM check_voice_quota($1)',
                [internalUserId]
            );
            const quota = quotaResult.rows[0];

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    message: 'Usage recorded successfully',
                    sessionId: sessionId,
                    durationRecorded: durationSeconds,
                    quota: {
                        remainingSeconds: quota.total_remaining_seconds,
                        monthlyUsedSeconds: quota.monthly_used_seconds,
                        monthlyLimitSeconds: quota.monthly_limit_seconds,
                        addonSecondsRemaining: quota.addon_seconds_remaining
                    }
                }
            };

        } catch (error) {
            context.error('Exception in voice-usage:', error.message);
            return {
                status: 500,
                headers,
                jsonBody: { success: false, error: 'exception', message: error.message }
            };
        }
    }
});

// =============================================================================
// 32. Voice Quota - GET /v1/voice/quota
// Returns current voice quota status for user
// Used by Flutter to display remaining minutes before starting session
// =============================================================================
app.http('voice-quota', {
    methods: ['GET', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/voice/quota',
    handler: async (request, context) => {
        context.log('Voice Quota - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, x-user-id'
        };

        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            const db = require('./shared/database');

            const userId = request.headers.get('x-user-id');
            if (!userId) {
                return {
                    status: 401,
                    headers,
                    jsonBody: { success: false, error: 'unauthorized' }
                };
            }

            // Check user tier - look up by azure_ad_sub (the JWT sub claim)
            const userResult = await db.query(
                'SELECT id, tier FROM users WHERE azure_ad_sub = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return {
                    status: 404,
                    headers,
                    jsonBody: { success: false, error: 'user_not_found' }
                };
            }

            const user = userResult.rows[0];

            // Non-Pro users don't have voice quota
            if (user.tier !== 'pro') {
                return {
                    status: 200,
                    headers,
                    jsonBody: {
                        success: true,
                        hasAccess: false,
                        tier: user.tier,
                        message: 'Voice AI requires Pro tier'
                    }
                };
            }

            // Get quota from database function (using internal UUID)
            const quotaResult = await db.query(
                'SELECT * FROM check_voice_quota($1)',
                [user.id]
            );
            const quota = quotaResult.rows[0];

            // Calculate warning threshold (6 minutes = 360 seconds)
            const warningThreshold = 360;
            const showWarning = quota.total_remaining_seconds <= warningThreshold && quota.total_remaining_seconds > 0;

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    hasAccess: true,
                    hasQuota: quota.has_quota,
                    tier: user.tier,
                    quota: {
                        remainingSeconds: quota.total_remaining_seconds,
                        remainingMinutes: Math.floor(quota.total_remaining_seconds / 60),
                        monthlyUsedSeconds: quota.monthly_used_seconds,
                        monthlyLimitSeconds: quota.monthly_limit_seconds,
                        addonSecondsRemaining: quota.addon_seconds_remaining,
                        percentUsed: Math.round((quota.monthly_used_seconds / quota.monthly_limit_seconds) * 100)
                    },
                    showWarning: showWarning,
                    warningMessage: showWarning ?
                        `${Math.floor(quota.total_remaining_seconds / 60)} minutes remaining this month` : null
                }
            };

        } catch (error) {
            context.error('Exception in voice-quota:', error.message);
            return {
                status: 500,
                headers,
                jsonBody: { success: false, error: 'exception', message: error.message }
            };
        }
    }
});

// =============================================================================
// 33. Voice Purchase - POST /v1/voice/purchase
// Validates Google Play purchase and credits voice minutes to user account
// Uses existing voice_addon_purchases table integrated with check_voice_quota()
// =============================================================================
app.http('voice-purchase', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/voice/purchase',
    handler: async (request, context) => {
        context.log('Voice Purchase - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, Ocp-Apim-Subscription-Key'
        };

        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        // Configuration
        const PACKAGE_NAME = 'ai.mybartender.mybartenderai';
        const PRODUCT_ID = 'voice_minutes_20';
        const SECONDS_PER_PURCHASE = 1200; // 20 minutes ($4.99 for double the value!)
        const PRICE_CENTS = 499;

        try {
            const db = require('./shared/database');
            const { google } = require('googleapis');

            // Get user from x-user-id header (set by APIM from JWT)
            const userId = request.headers.get('x-user-id');
            if (!userId) {
                context.warn('Missing x-user-id header');
                return {
                    status: 401,
                    headers,
                    jsonBody: { success: false, error: 'unauthorized', message: 'Missing user ID' }
                };
            }

            context.log(`User ID from header: ${userId.substring(0, 8)}...`);

            // Parse request body
            const body = await request.json().catch(() => ({}));
            const { purchaseToken, productId } = body;

            if (!purchaseToken) {
                return {
                    status: 400,
                    headers,
                    jsonBody: { success: false, error: 'Missing purchaseToken' }
                };
            }

            if (productId !== PRODUCT_ID) {
                return {
                    status: 400,
                    headers,
                    jsonBody: { success: false, error: `Invalid productId. Expected: ${PRODUCT_ID}` }
                };
            }

            // Look up internal user UUID from Azure AD sub
            const userResult = await db.query(
                'SELECT id, tier FROM users WHERE azure_ad_sub = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return {
                    status: 404,
                    headers,
                    jsonBody: { success: false, error: 'User not found' }
                };
            }

            const user = userResult.rows[0];
            const internalUserId = user.id;
            context.log(`User found: internal ID ${internalUserId}, tier: ${user.tier}`);

            // Check user tier - only pro and premium can purchase
            if (user.tier !== 'pro' && user.tier !== 'premium') {
                return {
                    status: 403,
                    headers,
                    jsonBody: {
                        success: false,
                        error: 'tier_required',
                        message: 'Voice minute purchases require Premium or Pro subscription',
                        currentTier: user.tier
                    }
                };
            }

            // Check if purchase already processed (idempotent)
            const existingPurchase = await db.query(
                'SELECT id FROM voice_addon_purchases WHERE transaction_id = $1',
                [purchaseToken]
            );

            if (existingPurchase.rows.length > 0) {
                context.log('Purchase already processed, returning success (idempotent)');

                const quotaResult = await db.query(
                    'SELECT * FROM check_voice_quota($1)',
                    [internalUserId]
                );
                const quota = quotaResult.rows[0];

                return {
                    status: 200,
                    headers,
                    jsonBody: {
                        success: true,
                        minutesAdded: 0,
                        message: 'Purchase already credited',
                        alreadyProcessed: true,
                        quota: {
                            remainingSeconds: quota.total_remaining_seconds,
                            monthlyUsedSeconds: quota.monthly_used_seconds,
                            monthlyLimitSeconds: quota.monthly_limit_seconds,
                            addonSecondsRemaining: quota.addon_seconds_remaining
                        }
                    }
                };
            }

            // Verify with Google Play API
            const credentialsJson = process.env.GOOGLE_PLAY_SERVICE_ACCOUNT_KEY;
            if (!credentialsJson) {
                context.error('GOOGLE_PLAY_SERVICE_ACCOUNT_KEY not configured');
                return {
                    status: 500,
                    headers,
                    jsonBody: { success: false, error: 'Purchase verification not configured' }
                };
            }

            context.log('Verifying purchase with Google Play...');

            const credentials = JSON.parse(credentialsJson);
            const auth = new google.auth.GoogleAuth({
                credentials,
                scopes: ['https://www.googleapis.com/auth/androidpublisher']
            });

            const androidpublisher = google.androidpublisher({ version: 'v3', auth });

            let verification;
            try {
                const response = await androidpublisher.purchases.products.get({
                    packageName: PACKAGE_NAME,
                    productId: PRODUCT_ID,
                    token: purchaseToken
                });

                const purchase = response.data;
                context.log('Google Play response:', JSON.stringify(purchase, null, 2));

                // purchaseState: 0 = Purchased, 1 = Canceled/Refunded
                if (purchase.purchaseState !== 0) {
                    return {
                        status: 400,
                        headers,
                        jsonBody: { success: false, error: 'Purchase was canceled or refunded' }
                    };
                }

                // Acknowledge if not already done
                if (purchase.acknowledgementState === 0) {
                    context.log('Acknowledging purchase...');
                    await androidpublisher.purchases.products.acknowledge({
                        packageName: PACKAGE_NAME,
                        productId: PRODUCT_ID,
                        token: purchaseToken
                    });
                    context.log('Purchase acknowledged');
                }

                verification = {
                    valid: true,
                    orderId: purchase.orderId,
                    environment: purchase.purchaseType === 0 ? 'sandbox' : 'production'
                };
            } catch (gpError) {
                context.error('Google Play verification error:', gpError.message);
                if (gpError.code === 404) {
                    return { status: 400, headers, jsonBody: { success: false, error: 'Purchase not found' } };
                }
                if (gpError.code === 401 || gpError.code === 403) {
                    return { status: 400, headers, jsonBody: { success: false, error: 'Google Play authentication failed' } };
                }
                throw gpError;
            }

            context.log('Purchase verified successfully, order:', verification.orderId);

            // Insert into existing voice_addon_purchases table
            await db.query(
                `INSERT INTO voice_addon_purchases
                    (user_id, seconds_purchased, price_cents, transaction_id, platform, purchased_at)
                 VALUES ($1, $2, $3, $4, $5, NOW())`,
                [internalUserId, SECONDS_PER_PURCHASE, PRICE_CENTS, purchaseToken, 'android']
            );

            context.log(`Credited ${SECONDS_PER_PURCHASE} seconds (${SECONDS_PER_PURCHASE / 60} minutes) to user`);

            // Get updated quota
            const quotaResult = await db.query(
                'SELECT * FROM check_voice_quota($1)',
                [internalUserId]
            );
            const quota = quotaResult.rows[0];

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    minutesAdded: SECONDS_PER_PURCHASE / 60,
                    message: `${SECONDS_PER_PURCHASE / 60} voice minutes added to your account`,
                    quota: {
                        remainingSeconds: quota.total_remaining_seconds,
                        monthlyUsedSeconds: quota.monthly_used_seconds,
                        monthlyLimitSeconds: quota.monthly_limit_seconds,
                        addonSecondsRemaining: quota.addon_seconds_remaining
                    }
                }
            };

        } catch (error) {
            context.error('Exception in voice-purchase:', error.message);
            context.error('Stack:', error.stack);
            return {
                status: 500,
                headers,
                jsonBody: { success: false, error: 'Purchase processing failed' }
            };
        }
    }
});

// =============================================================================
// 34. Subscription Webhook - POST /v1/subscription/webhook
// Receives RevenueCat server-to-server notifications
// NO JWT - uses RevenueCat webhook signature for authentication
// =============================================================================
app.http('subscription-webhook', {
    methods: ['POST', 'OPTIONS'],
    authLevel: 'anonymous',  // No function key - RevenueCat uses signature auth
    route: 'v1/subscription/webhook',
    handler: async (request, context) => {
        context.log('Subscription Webhook - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, X-RevenueCat-Webhook-Signature'
        };

        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            const db = require('./shared/database');
            const crypto = require('crypto');

            // Get webhook secret from environment
            const webhookSecret = process.env.REVENUECAT_WEBHOOK_SECRET;
            if (!webhookSecret) {
                context.warn('REVENUECAT_WEBHOOK_SECRET not configured - skipping signature verification');
                // In production, you should reject requests without proper configuration
                // For now, we'll log a warning and continue (for testing)
            }

            // Get signature from header
            const signature = request.headers.get('X-RevenueCat-Webhook-Signature');

            // Parse the webhook body
            const rawBody = await request.text();
            const event = JSON.parse(rawBody);

            // Verify signature if secret is configured
            if (webhookSecret && signature) {
                const expectedSignature = crypto
                    .createHmac('sha256', webhookSecret)
                    .update(rawBody)
                    .digest('hex');

                if (signature !== expectedSignature) {
                    context.warn('Webhook signature mismatch');
                    return {
                        status: 401,
                        headers,
                        jsonBody: { error: 'Invalid signature' }
                    };
                }
                context.log('Webhook signature verified');
            }

            // Extract event data
            const eventType = event.event?.type;
            const eventId = event.event?.id;  // For idempotency
            const environment = event.event?.environment;  // SANDBOX or PRODUCTION
            const appUserId = event.event?.app_user_id;  // This is azure_ad_sub
            const productId = event.event?.product_id;
            let expiresAt = event.event?.expiration_at_ms
                ? new Date(event.event.expiration_at_ms)
                : null;

            context.log(`Event type: ${eventType}, ID: ${eventId}, Env: ${environment}, User: ${appUserId?.substring(0, 8)}..., Product: ${productId}`);

            // Filter out sandbox events in production
            if (environment === 'SANDBOX') {
                context.log(`Sandbox event (${eventType}) received - logging only, not processing`);
                // We'll still record in audit log below but won't update subscription
            }

            if (!appUserId) {
                context.warn('Missing app_user_id in webhook');
                return {
                    status: 200,  // Return 200 to prevent retries
                    headers,
                    jsonBody: { received: true, processed: false, reason: 'missing_user_id' }
                };
            }

            // Look up internal user UUID from azure_ad_sub
            const userResult = await db.query(
                'SELECT id FROM users WHERE azure_ad_sub = $1',
                [appUserId]
            );

            let internalUserId = null;
            if (userResult.rows.length > 0) {
                internalUserId = userResult.rows[0].id;
            } else {
                context.warn(`User not found for azure_ad_sub: ${appUserId.substring(0, 8)}...`);
            }

            // Idempotency check - skip if we've already processed this event
            if (eventId) {
                const existingEvent = await db.query(
                    'SELECT id FROM subscription_events WHERE revenuecat_event_id = $1',
                    [eventId]
                );
                if (existingEvent.rows.length > 0) {
                    context.log(`Duplicate event ${eventId} - already processed, skipping`);
                    return {
                        status: 200,
                        headers,
                        jsonBody: { received: true, processed: false, reason: 'duplicate_event', event_id: eventId }
                    };
                }
            }

            // Record the event in subscription_events (audit log)
            await db.query(
                `INSERT INTO subscription_events
                    (user_id, revenuecat_app_user_id, event_type, product_id, tier, expires_at, raw_event, revenuecat_event_id)
                 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                [
                    internalUserId,
                    appUserId,
                    eventType,
                    productId,
                    productId ? (productId.startsWith('pro_') ? 'pro' : 'premium') : null,
                    expiresAt,
                    event,
                    eventId
                ]
            );
            context.log('Event recorded in subscription_events');

            // For sandbox events, we logged it but don't update production subscriptions
            if (environment === 'SANDBOX') {
                return {
                    status: 200,
                    headers,
                    jsonBody: { received: true, processed: false, reason: 'sandbox_event', event_type: eventType }
                };
            }

            // If user not found, we can't update their subscription
            if (!internalUserId) {
                return {
                    status: 200,
                    headers,
                    jsonBody: { received: true, processed: false, reason: 'user_not_found' }
                };
            }

            // Handle event types
            let isActive = false;
            let autoRenewing = true;
            let cancelReason = null;

            switch (eventType) {
                case 'INITIAL_PURCHASE':
                case 'RENEWAL':
                case 'UNCANCELLATION':
                case 'PRODUCT_CHANGE':
                    isActive = true;
                    autoRenewing = true;
                    context.log('Activating/renewing subscription');
                    break;

                case 'CANCELLATION':
                    // User cancelled but still has access until expiry
                    isActive = true;
                    autoRenewing = false;
                    cancelReason = 'CUSTOMER_CANCELLED';
                    context.log('Subscription cancelled (access until expiry)');
                    break;

                case 'EXPIRATION':
                    isActive = false;
                    autoRenewing = false;
                    cancelReason = 'EXPIRED';
                    context.log('Subscription expired');
                    break;

                case 'BILLING_ISSUE':
                    // Check if user is still in grace period
                    const gracePeriodExpires = event.event?.grace_period_expires_date_ms
                        ? new Date(event.event.grace_period_expires_date_ms)
                        : null;

                    if (gracePeriodExpires && gracePeriodExpires > new Date()) {
                        // Still in grace period - keep access active
                        isActive = true;
                        autoRenewing = false;
                        cancelReason = 'BILLING_ISSUE_GRACE_PERIOD';
                        expiresAt = gracePeriodExpires;  // Update expiry to grace period end
                        context.log(`Billing issue - grace period active until ${gracePeriodExpires.toISOString()}`);
                    } else {
                        // No grace period or it has expired
                        isActive = false;
                        autoRenewing = false;
                        cancelReason = 'BILLING_ERROR';
                        context.log('Billing issue - no grace period, deactivating');
                    }
                    break;

                case 'SUBSCRIPTION_PAUSED':
                    isActive = false;
                    autoRenewing = true;
                    cancelReason = 'PAUSED';
                    context.log('Subscription paused');
                    break;

                default:
                    context.log(`Unhandled event type: ${eventType}`);
                    return {
                        status: 200,
                        headers,
                        jsonBody: { received: true, processed: false, reason: 'unhandled_event_type' }
                    };
            }

            // Upsert subscription using the helper function
            if (productId) {
                await db.query(
                    `SELECT upsert_subscription_from_webhook($1, $2, $3, $4, $5, $6, $7)`,
                    [internalUserId, appUserId, productId, isActive, autoRenewing, expiresAt, cancelReason]
                );
                context.log('Subscription upserted successfully');
            }

            return {
                status: 200,
                headers,
                jsonBody: { received: true, processed: true, event_type: eventType }
            };

        } catch (error) {
            context.error('Subscription webhook error:', error.message);
            context.error('Stack:', error.stack);

            // Return 200 to prevent RevenueCat from retrying (we logged the error)
            // In a real scenario, you might want to return 500 for transient errors
            return {
                status: 200,
                headers,
                jsonBody: { received: true, processed: false, error: error.message }
            };
        }
    }
});

// =============================================================================
// 35. Subscription Status - GET /v1/subscription/status
// Returns user's current subscription status
// JWT required (x-user-id header from APIM)
// =============================================================================
app.http('subscription-status', {
    methods: ['GET', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/subscription/status',
    handler: async (request, context) => {
        context.log('Subscription Status - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, Ocp-Apim-Subscription-Key'
        };

        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            const db = require('./shared/database');

            // Get user from x-user-id header (set by APIM from JWT)
            const userId = request.headers.get('x-user-id');
            if (!userId) {
                context.warn('Missing x-user-id header');
                return {
                    status: 401,
                    headers,
                    jsonBody: { success: false, error: 'unauthorized', message: 'Missing user ID' }
                };
            }

            context.log(`User ID from header: ${userId.substring(0, 8)}...`);

            // Look up internal user UUID from Azure AD sub
            const userResult = await db.query(
                'SELECT id, tier FROM users WHERE azure_ad_sub = $1',
                [userId]
            );

            if (userResult.rows.length === 0) {
                return {
                    status: 404,
                    headers,
                    jsonBody: { success: false, error: 'User not found' }
                };
            }

            const user = userResult.rows[0];
            const internalUserId = user.id;

            // Get subscription status using helper function
            const statusResult = await db.query(
                'SELECT * FROM get_subscription_status($1)',
                [internalUserId]
            );

            const status = statusResult.rows[0] || {
                tier: 'free',
                product_id: null,
                is_active: false,
                auto_renewing: false,
                expires_at: null,
                cancel_reason: null
            };

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    subscription: {
                        tier: status.tier,
                        productId: status.product_id,
                        isActive: status.is_active,
                        autoRenewing: status.auto_renewing,
                        expiresAt: status.expires_at ? status.expires_at.toISOString() : null,
                        cancelReason: status.cancel_reason
                    },
                    // Also include the current tier from users table for redundancy
                    currentTier: user.tier
                }
            };

        } catch (error) {
            context.error('Subscription status error:', error.message);
            context.error('Stack:', error.stack);
            return {
                status: 500,
                headers,
                jsonBody: { success: false, error: 'Failed to get subscription status' }
            };
        }
    }
});

// =============================================================================
// 36. Subscription Config - GET /v1/subscription/config
// Returns RevenueCat configuration (API key from Key Vault)
// JWT required (x-user-id header from APIM)
// =============================================================================
app.http('subscription-config', {
    methods: ['GET', 'OPTIONS'],
    authLevel: 'function',
    route: 'v1/subscription/config',
    handler: async (request, context) => {
        context.log('Subscription Config - Request received');

        const headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-functions-key, Ocp-Apim-Subscription-Key'
        };

        if (request.method === 'OPTIONS') {
            return { status: 200, headers, body: '' };
        }

        try {
            // Verify user is authenticated (x-user-id header from APIM JWT validation)
            const userId = request.headers.get('x-user-id');
            if (!userId) {
                context.warn('Missing x-user-id header');
                return {
                    status: 401,
                    headers,
                    jsonBody: { success: false, error: 'unauthorized', message: 'Missing user ID' }
                };
            }

            context.log(`User ID from header: ${userId.substring(0, 8)}...`);

            // Get RevenueCat API key from environment (Key Vault reference)
            const revenueCatApiKey = process.env.REVENUECAT_PUBLIC_API_KEY;
            if (!revenueCatApiKey) {
                context.error('REVENUECAT_PUBLIC_API_KEY not configured');
                return {
                    status: 500,
                    headers,
                    jsonBody: { success: false, error: 'Configuration error' }
                };
            }

            return {
                status: 200,
                headers,
                jsonBody: {
                    success: true,
                    config: {
                        revenueCatApiKey: revenueCatApiKey
                    }
                }
            };

        } catch (error) {
            context.error('Subscription config error:', error.message);
            return {
                status: 500,
                headers,
                jsonBody: { success: false, error: 'Failed to get subscription config' }
            };
        }
    }
});
