const { DefaultAzureCredential } = require('@azure/identity');
const { ApiManagementClient } = require('@azure/arm-apimanagement');
const monitoring = require('../shared/monitoring');

// Configuration
const APIM_SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID;
const APIM_RESOURCE_GROUP = 'rg-mba-prod';
const APIM_SERVICE_NAME = 'apim-mba-001';

// Helper to mask keys
function maskKey(key) {
    if (!key || key.length < 8) return '****';
    return `****${key.slice(-4)}`;
}

module.exports = async function (context, req) {
    console.log('Key rotation request received');

    try {
        const credential = new DefaultAzureCredential();
        const client = new ApiManagementClient(credential, APIM_SUBSCRIPTION_ID);

        const { userId, subscriptionName, reason } = req.body || {};

        // Validate input
        if (!subscriptionName && !userId) {
            context.res = {
                status: 400,
                body: { error: 'Either subscriptionName or userId must be provided' }
            };
            return;
        }

        let targetSubscription = subscriptionName;

        // If userId provided, find their active subscription
        if (userId && !subscriptionName) {
            // List all subscriptions and find the user's active one
            const subscriptions = await client.subscription.list(
                APIM_RESOURCE_GROUP,
                APIM_SERVICE_NAME,
                {
                    filter: `contains(name, 'user-${userId}')`
                }
            );

            const activeSubscription = subscriptions.find(sub =>
                sub.state === 'active' && sub.name.includes(`user-${userId}`)
            );

            if (!activeSubscription) {
                context.res = {
                    status: 404,
                    body: { error: `No active subscription found for user ${userId}` }
                };
                return;
            }

            targetSubscription = activeSubscription.name;
        }

        console.log(`Rotating keys for subscription: ${targetSubscription}, reason: ${reason || 'scheduled'}`);

        // Regenerate primary key
        const regeneratedPrimary = await client.subscription.regeneratePrimaryKey(
            APIM_RESOURCE_GROUP,
            APIM_SERVICE_NAME,
            targetSubscription
        );

        // Get the updated subscription to verify
        const updatedSubscription = await client.subscription.get(
            APIM_RESOURCE_GROUP,
            APIM_SERVICE_NAME,
            targetSubscription
        );

        console.log(`Successfully rotated primary key for ${targetSubscription}: ${maskKey(updatedSubscription.primaryKey)}`);

        // Log rotation event (you might want to store this in a database)
        const rotationEvent = {
            subscriptionName: targetSubscription,
            userId: userId || 'unknown',
            timestamp: new Date().toISOString(),
            reason: reason || 'scheduled',
            maskedNewKey: maskKey(updatedSubscription.primaryKey),
            performedBy: 'system'
        };

        console.log('Rotation event:', JSON.stringify(rotationEvent));

        // Track successful key rotation
        monitoring.trackKeyRotation(targetSubscription, true, {
            userId: userId || 'unknown',
            reason: reason || 'scheduled',
            endpoint: '/v1/auth/rotate'
        });

        context.res = {
            status: 200,
            body: {
                success: true,
                subscriptionName: targetSubscription,
                rotatedAt: rotationEvent.timestamp,
                reason: rotationEvent.reason,
                message: 'Primary key rotated successfully. Clients will need to re-authenticate.'
            }
        };

    } catch (error) {
        console.error('Key rotation error:', error.message);

        // Track failed key rotation
        const subscriptionName = req.body?.subscriptionName || req.body?.userId || 'unknown';
        monitoring.trackKeyRotation(subscriptionName, false, {
            error: error.message,
            endpoint: '/v1/auth/rotate'
        });

        context.res = {
            status: 500,
            body: {
                error: 'Failed to rotate key',
                message: error.message
            }
        };
    }
};