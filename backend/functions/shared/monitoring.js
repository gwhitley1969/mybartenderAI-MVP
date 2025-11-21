// Shared monitoring and alerting utilities for Azure Functions

const appInsightsPackage = require('applicationinsights');

// Initialize Application Insights if connection string is provided
let appInsights;
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    appInsights = appInsightsPackage.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
        .setAutoDependencyCorrelation(true)
        .setAutoCollectRequests(true)
        .setAutoCollectPerformance(true)
        .setAutoCollectExceptions(true)
        .setAutoCollectDependencies(true)
        .setAutoCollectConsole(true)
        .start();
}

/**
 * Track authentication failure events
 * @param {string} userId - User ID (or 'unknown' if not available)
 * @param {string} reason - Failure reason
 * @param {object} details - Additional details
 */
function trackAuthFailure(userId, reason, details = {}) {
    const event = {
        name: 'AuthenticationFailure',
        properties: {
            userId: userId || 'unknown',
            reason: reason,
            timestamp: new Date().toISOString(),
            ...details
        }
    };

    console.log(`[AUTH_FAILURE] User: ${userId}, Reason: ${reason}`, details);

    if (appInsights) {
        appInsights.defaultClient.trackEvent(event);
    }
}

/**
 * Track rate limit exceeded events
 * @param {string} userId - User ID
 * @param {string} endpoint - API endpoint
 * @param {object} details - Additional details
 */
function trackRateLimitExceeded(userId, endpoint, details = {}) {
    const event = {
        name: 'RateLimitExceeded',
        properties: {
            userId: userId,
            endpoint: endpoint,
            timestamp: new Date().toISOString(),
            ...details
        }
    };

    console.log(`[RATE_LIMIT] User: ${userId}, Endpoint: ${endpoint}`, details);

    if (appInsights) {
        appInsights.defaultClient.trackEvent(event);

        // Also track as metric for easier alerting
        appInsights.defaultClient.trackMetric({
            name: 'RateLimitExceeded',
            value: 1
        });
    }
}

/**
 * Track successful authentication events
 * @param {string} userId - User ID
 * @param {string} tier - User tier
 * @param {object} details - Additional details
 */
function trackAuthSuccess(userId, tier, details = {}) {
    const event = {
        name: 'AuthenticationSuccess',
        properties: {
            userId: userId,
            tier: tier,
            timestamp: new Date().toISOString(),
            ...details
        }
    };

    console.log(`[AUTH_SUCCESS] User: ${userId}, Tier: ${tier}`);

    if (appInsights) {
        appInsights.defaultClient.trackEvent(event);

        // Track tier distribution as metric
        appInsights.defaultClient.trackMetric({
            name: `AuthSuccess_${tier}`,
            value: 1
        });
    }
}

/**
 * Track key rotation events
 * @param {string} subscriptionId - APIM subscription ID
 * @param {boolean} success - Whether rotation succeeded
 * @param {object} details - Additional details
 */
function trackKeyRotation(subscriptionId, success, details = {}) {
    const event = {
        name: success ? 'KeyRotationSuccess' : 'KeyRotationFailure',
        properties: {
            subscriptionId: subscriptionId,
            timestamp: new Date().toISOString(),
            ...details
        }
    };

    console.log(`[KEY_ROTATION] Subscription: ${subscriptionId}, Success: ${success}`, details);

    if (appInsights) {
        appInsights.defaultClient.trackEvent(event);

        if (!success) {
            // Track failures as metric for alerting
            appInsights.defaultClient.trackMetric({
                name: 'KeyRotationFailures',
                value: 1
            });
        }
    }
}

/**
 * Track suspicious activity (potential attacks)
 * @param {string} userId - User ID (or IP if not authenticated)
 * @param {string} activity - Type of suspicious activity
 * @param {object} details - Additional details
 */
function trackSuspiciousActivity(userId, activity, details = {}) {
    const event = {
        name: 'SuspiciousActivity',
        properties: {
            userId: userId || 'unknown',
            activity: activity,
            timestamp: new Date().toISOString(),
            severity: 'high',
            ...details
        }
    };

    console.warn(`[SUSPICIOUS_ACTIVITY] User: ${userId}, Activity: ${activity}`, details);

    if (appInsights) {
        appInsights.defaultClient.trackEvent(event);

        // Track as high-severity metric
        appInsights.defaultClient.trackMetric({
            name: 'SuspiciousActivity',
            value: 1
        });

        // Also track as exception for immediate visibility
        appInsights.defaultClient.trackException({
            exception: new Error(`Suspicious activity: ${activity}`),
            properties: event.properties
        });
    }
}

/**
 * Track JWT validation failures
 * @param {string} reason - Validation failure reason
 * @param {object} details - Additional details
 */
function trackJwtValidationFailure(reason, details = {}) {
    const event = {
        name: 'JwtValidationFailure',
        properties: {
            reason: reason,
            timestamp: new Date().toISOString(),
            ...details
        }
    };

    console.log(`[JWT_FAILURE] Reason: ${reason}`, details);

    if (appInsights) {
        appInsights.defaultClient.trackEvent(event);

        // Track metric for alerting
        appInsights.defaultClient.trackMetric({
            name: 'JwtValidationFailures',
            value: 1
        });
    }
}

/**
 * Check if failure rate is high and alert if needed
 * This is a simple in-memory tracker - production should use distributed cache
 */
const failureTracker = {
    window: 5 * 60 * 1000, // 5 minute window
    threshold: 50, // Alert if >50 failures in 5 minutes
    failures: []
};

function checkFailureRate() {
    const now = Date.now();
    // Remove old failures outside the window
    failureTracker.failures = failureTracker.failures.filter(
        timestamp => now - timestamp < failureTracker.window
    );

    failureTracker.failures.push(now);

    if (failureTracker.failures.length > failureTracker.threshold) {
        console.error(`[ALERT] High failure rate detected: ${failureTracker.failures.length} failures in last 5 minutes`);

        if (appInsights) {
            appInsights.defaultClient.trackException({
                exception: new Error('High authentication failure rate detected'),
                properties: {
                    failureCount: failureTracker.failures.length,
                    window: failureTracker.window,
                    threshold: failureTracker.threshold
                },
                severity: 3 // Critical
            });
        }

        return true;
    }

    return false;
}

module.exports = {
    trackAuthFailure,
    trackRateLimitExceeded,
    trackAuthSuccess,
    trackKeyRotation,
    trackSuspiciousActivity,
    trackJwtValidationFailure,
    checkFailureRate,
    appInsights: appInsights ? appInsights.defaultClient : null
};
