const { DefaultAzureCredential } = require('@azure/identity');
const { ApiManagementClient } = require('@azure/arm-apimanagement');

// Configuration
const APIM_SUBSCRIPTION_ID = process.env.AZURE_SUBSCRIPTION_ID;
const APIM_RESOURCE_GROUP = 'rg-mba-prod';
const APIM_SERVICE_NAME = 'apim-mba-001';

// Helper to mask keys
function maskKey(key) {
    if (!key || key.length < 8) return '****';
    return `****${key.slice(-4)}`;
}

module.exports = async function (context, myTimer) {
    const timestamp = new Date().toISOString();

    context.log('Monthly key rotation timer triggered at:', timestamp);

    if (myTimer.isPastDue) {
        context.log('Timer is past due, running late rotation');
    }

    try {
        const credential = new DefaultAzureCredential();
        const client = new ApiManagementClient(credential, APIM_SUBSCRIPTION_ID);

        // Get all subscriptions that need rotation
        // Filter for user subscriptions (naming pattern: user-{userId}-{tier})
        const subscriptions = await client.subscription.list(
            APIM_RESOURCE_GROUP,
            APIM_SERVICE_NAME,
            {
                filter: "contains(name, 'user-')"
            }
        );

        let rotatedCount = 0;
        let skippedCount = 0;
        let errorCount = 0;
        const rotationResults = [];

        for await (const subscription of subscriptions) {
            // Only rotate active subscriptions
            if (subscription.state !== 'active') {
                context.log(`Skipping inactive subscription: ${subscription.name} (state: ${subscription.state})`);
                skippedCount++;
                continue;
            }

            // Check if this subscription was created or modified recently (within 7 days)
            // This prevents rotating keys for very new users
            const createdDate = new Date(subscription.createdDate);
            const daysSinceCreated = (Date.now() - createdDate.getTime()) / (1000 * 60 * 60 * 24);

            if (daysSinceCreated < 7) {
                context.log(`Skipping recent subscription: ${subscription.name} (created ${Math.floor(daysSinceCreated)} days ago)`);
                skippedCount++;
                continue;
            }

            try {
                context.log(`Rotating keys for subscription: ${subscription.name}`);

                // Rotate the primary key
                await client.subscription.regeneratePrimaryKey(
                    APIM_RESOURCE_GROUP,
                    APIM_SERVICE_NAME,
                    subscription.name
                );

                // Get the updated subscription to verify
                const updated = await client.subscription.get(
                    APIM_RESOURCE_GROUP,
                    APIM_SERVICE_NAME,
                    subscription.name
                );

                rotatedCount++;
                rotationResults.push({
                    subscriptionName: subscription.name,
                    displayName: subscription.displayName,
                    maskedNewKey: maskKey(updated.primaryKey),
                    rotatedAt: timestamp
                });

                context.log(`Successfully rotated: ${subscription.name} (new key: ${maskKey(updated.primaryKey)})`);

                // Add a small delay to avoid overwhelming the API
                await new Promise(resolve => setTimeout(resolve, 100));

            } catch (error) {
                errorCount++;
                context.log.error(`Failed to rotate ${subscription.name}: ${error.message}`);
                rotationResults.push({
                    subscriptionName: subscription.name,
                    error: error.message,
                    failedAt: timestamp
                });
            }
        }

        // Log summary
        const summary = {
            timestamp: timestamp,
            totalSubscriptions: rotatedCount + skippedCount + errorCount,
            rotatedCount: rotatedCount,
            skippedCount: skippedCount,
            errorCount: errorCount,
            results: rotationResults
        };

        context.log('Monthly rotation completed:', JSON.stringify(summary, null, 2));

        // You might want to send this summary to a monitoring service or store it
        // For example, send to Application Insights or store in Table Storage
        if (context.bindings.outputTable) {
            context.bindings.outputTable = summary;
        }

        // Send alert if there were errors
        if (errorCount > 0) {
            context.log.warn(`Key rotation completed with ${errorCount} errors. Manual review may be needed.`);
            // Could trigger an alert or send an email here
        }

    } catch (error) {
        context.log.error('Fatal error during key rotation:', error.message);
        context.log.error('Stack trace:', error.stack);

        // This is a critical failure - all rotations failed
        // You should trigger an alert here
        throw error;
    }
};