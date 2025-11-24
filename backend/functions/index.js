const { app } = require('@azure/functions');
const { OpenAIClient, AzureKeyCredential } = require('@azure/openai');

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
            let systemPrompt = 'You are a sophisticated AI bartender for MyBartenderAI. Be helpful, friendly, and knowledgeable about cocktails.';

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

            const responseText = result.choices[0]?.message?.content || 'I apologize, but I could not process your request.';

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
            context.log('Error in ask-bartender-simple:', error.message);
            context.log('Stack trace:', error.stack);

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
            context.log.error('[test-mi-access] Error:', error);

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
            context.log.error('[test-write] Error:', error);
            context.log.error('[test-write] Error stack:', error.stack);

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
        const systemPrompt = `You are a sophisticated AI bartender for MyBartenderAI, a premium mixology app.
        You have extensive knowledge of cocktails, spirits, techniques, and bar culture.
        Be conversational, helpful, and engaging. Help users discover new cocktails, perfect their techniques,
        and elevate their home bartending experience. When suggesting cocktails, consider the user's preferences
        and available ingredients if mentioned.`;

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
        const systemPrompt = `You are a sophisticated AI bartender for MyBartenderAI, a premium mixology app.
        You have extensive knowledge of cocktails, spirits, techniques, and bar culture.
        Be conversational, helpful, and engaging. Help users discover new cocktails, perfect their techniques,
        and elevate their home bartending experience. When suggesting cocktails, consider the user's preferences
        and available ingredients if mentioned.`;

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
            // Check for required Azure Speech Services configuration
            const speechKey = process.env.AZURE_SPEECH_KEY;
            const speechRegion = process.env.AZURE_SPEECH_REGION;
            const openaiKey = process.env.OPENAI_API_KEY;

            if (!speechKey || !speechRegion) {
                context.log.error('Azure Speech Services not configured');
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
                context.log.error('OpenAI API key not found');
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
                                    context.log.error(errorMessage);
                                    recognizer.close();
                                    reject(new Error(errorMessage));
                                }
                            },
                            error => {
                                context.log.error('Azure STT error:', error);
                                recognizer.close();
                                reject(error);
                            }
                        );
                    } catch (error) {
                        context.log.error('Exception in convertSpeechToText:', error);
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

                let systemPrompt = 'You are a sophisticated AI bartender for MyBartenderAI voice interaction. ' +
                                  'Be helpful, friendly, conversational, and knowledgeable about cocktails. ' +
                                  'Keep responses concise and natural for voice conversation (2-3 sentences max unless recipe details requested).';

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
                                    context.log.error(errorMessage);
                                    synthesizer.close();
                                    reject(new Error(errorMessage));
                                }
                            },
                            error => {
                                context.log.error('Azure TTS error:', error);
                                synthesizer.close();
                                reject(error);
                            }
                        );
                    } catch (error) {
                        context.log.error('Exception in convertTextToSpeech:', error);
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
            context.log.error('Error in voice-bartender:', error.message);
            context.log.error('Stack trace:', error.stack);

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
            // Check for API key
            const apiKey = process.env.OPENAI_API_KEY;
            if (!apiKey) {
                context.log.error('OPENAI_API_KEY not found in environment');
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

Be encouraging and professional. Focus on enhancing what's already good while offering improvements.`;

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
                context.log.error('Failed to parse AI response as JSON:', parseError);
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
            context.log.error('Error in refine-cocktail:', error.message);
            context.log.error('Stack trace:', error.stack);

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
// 26. Sync CocktailDB - Timer Trigger (daily at 03:30 UTC)
// =============================================================================
app.timer('sync-cocktaildb', {
    schedule: '0 30 3 * * *', // Daily at 03:30 UTC
    handler: async (myTimer, context) => {
        const syncCocktaildbModule = require('./sync-cocktaildb');
        return await syncCocktaildbModule(context, myTimer);
    }
});

// =============================================================================
// 27. Sync CocktailDB MI - Timer Trigger (daily at 03:30 UTC)
// =============================================================================
app.timer('sync-cocktaildb-mi', {
    schedule: '0 30 3 * * *', // Daily at 03:30 UTC
    handler: async (myTimer, context) => {
        const syncCocktaildbMiModule = require('./sync-cocktaildb-mi');
        return await syncCocktaildbMiModule(context, myTimer);
    }
});

// =============================================================================
// 28. Cocktail Preview - GET /v1/cocktails/{id}/preview
// =============================================================================
app.http('cocktail-preview', {
    methods: ['GET'],
    authLevel: 'anonymous',  // Public access for social crawlers
    route: 'v1/cocktails/{id}/preview',
    handler: async (request, context) => {
        const cocktailPreviewModule = require('./cocktail-preview');
        return await cocktailPreviewModule(context, request);
    }
});
