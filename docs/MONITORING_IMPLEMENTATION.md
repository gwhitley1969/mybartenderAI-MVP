# Monitoring and Alerting Implementation

**Date**: 2025-11-14
**Status**: ✅ Complete

## Overview

Comprehensive monitoring and alerting has been implemented across all authentication and key management functions using Azure Application Insights.

## Components Implemented

### 1. Shared Monitoring Module (`backend/functions/shared/monitoring.js`)

Central monitoring library with the following capabilities:

#### Tracking Functions

- **`trackAuthFailure(userId, reason, details)`**
  - Tracks authentication failures
  - Logs to console and Application Insights
  - Captures user ID, reason, and contextual details

- **`trackRateLimitExceeded(userId, endpoint, details)`**
  - Tracks rate limit violations
  - Creates both events and metrics for alerting
  - Includes user ID, endpoint, and reset time

- **`trackAuthSuccess(userId, tier, details)`**
  - Tracks successful authentications
  - Records user tier distribution as metrics
  - Helps monitor conversion funnel (free → premium → pro)

- **`trackKeyRotation(subscriptionId, success, details)`**
  - Tracks both successful and failed key rotations
  - Creates failure metrics for alerting
  - Records subscription ID and rotation context

- **`trackSuspiciousActivity(userId, activity, details)`**
  - Tracks potential security threats
  - High severity logging
  - Creates both events and exceptions for immediate visibility

- **`trackJwtValidationFailure(reason, details)`**
  - Tracks JWT validation failures
  - Creates metrics for alerting
  - Records failure reasons for analysis

- **`checkFailureRate()`**
  - Monitors authentication failure rate
  - Triggers critical alert if >50 failures in 5 minutes
  - Helps detect DDoS attacks or service issues
  - Uses in-memory sliding window (production should use distributed cache)

### 2. Auth Exchange Function (`backend/functions/auth-exchange/index.js`)

Monitoring integrated for:

- ✅ Missing or invalid Authorization headers
- ✅ JWT validation failures (with automatic attack detection)
- ✅ Rate limit violations (with suspicious activity tracking)
- ✅ Successful token exchanges (tracking tier distribution)

**Key Metrics Captured:**
- Authentication success/failure rates per tier
- Rate limit violations per user
- JWT validation failure reasons
- High failure rate detection (potential attacks)

### 3. Auth Rotate Function (`backend/functions/auth-rotate/index.js`)

Monitoring integrated for:

- ✅ Successful manual key rotations
- ✅ Failed rotation attempts with error details
- ✅ Tracks who initiated rotation (user vs system)

**Key Metrics Captured:**
- Individual key rotation success/failure rates
- Rotation reasons (scheduled, compromised, manual)
- Subscription IDs rotated

### 4. Rotate Keys Timer Function (`backend/functions/rotate-keys-timer/index.js`)

Comprehensive batch rotation monitoring:

- ✅ Individual subscription rotation tracking (success/failure)
- ✅ Bulk rotation summary events
- ✅ Monthly rotation metrics (total, succeeded, failed)
- ✅ Warning-level exceptions for partial failures
- ✅ Critical-level exceptions for fatal errors

**Key Metrics Captured:**
- Total subscriptions rotated per batch
- Rotation error count per batch
- Individual rotation failures with details
- Fatal failure alerts

## Application Insights Integration

### Connection String

The monitoring module automatically initializes Application Insights if the `APPLICATIONINSIGHTS_CONNECTION_STRING` environment variable is set:

```javascript
if (process.env.APPLICATIONINSIGHTS_CONNECTION_STRING) {
    appInsights = ApplicationInsights.setup(process.env.APPLICATIONINSIGHTS_CONNECTION_STRING)
        .setAutoDependencyCorrelation(true)
        .setAutoCollectRequests(true)
        .setAutoCollectPerformance(true)
        .setAutoCollectExceptions(true)
        .setAutoCollectDependencies(true)
        .setAutoCollectConsole(true)
        .start();
}
```

### Event Types

The following custom events are tracked:

1. **AuthenticationFailure** - Failed auth attempts
2. **AuthenticationSuccess** - Successful auth with tier info
3. **RateLimitExceeded** - Rate limit violations
4. **JwtValidationFailure** - JWT validation errors
5. **SuspiciousActivity** - Potential attacks
6. **KeyRotationSuccess** - Successful key rotations
7. **KeyRotationFailure** - Failed key rotations
8. **BulkKeyRotation** - Monthly batch rotation summary

### Metrics for Alerting

The following metrics are tracked for easy alerting:

1. **RateLimitExceeded** - Count of rate limit events
2. **AuthSuccess_{tier}** - Success count per tier (free, premium, pro)
3. **JwtValidationFailures** - Count of JWT failures
4. **SuspiciousActivity** - Count of suspicious events
5. **KeyRotationFailures** - Count of rotation failures
6. **MonthlyKeyRotations** - Count of successful monthly rotations
7. **KeyRotationErrors** - Count of errors during monthly rotation

## Alert Configuration Recommendations

### Critical Alerts (Immediate Response)

1. **High Authentication Failure Rate**
   - Trigger: >50 failures in 5 minutes
   - Already tracked by `checkFailureRate()`
   - Severity: Critical
   - Action: Investigate potential DDoS or service outage

2. **Fatal Key Rotation Failure**
   - Trigger: Exception in rotate-keys-timer with severity 3
   - Severity: Critical
   - Action: Manual intervention required - all rotations failed

3. **Suspicious Activity Detected**
   - Trigger: SuspiciousActivity event created
   - Severity: High
   - Action: Review logs, potential security breach

### Warning Alerts (Review Required)

1. **Bulk Key Rotation Errors**
   - Trigger: KeyRotationErrors metric > 0 after monthly rotation
   - Severity: Warning
   - Action: Review failed subscriptions, manual rotation may be needed

2. **Elevated JWT Validation Failures**
   - Trigger: JwtValidationFailures > 10 per hour
   - Severity: Warning
   - Action: Check Entra External ID service health, review failure reasons

3. **Multiple Rate Limit Violations**
   - Trigger: RateLimitExceeded metric > 5 per user per hour
   - Severity: Warning
   - Action: Review user behavior, potential abuse

### Informational Metrics

1. **Tier Distribution**
   - Metrics: AuthSuccess_free, AuthSuccess_premium, AuthSuccess_pro
   - Purpose: Monitor conversion funnel
   - Action: No alert, use for business analytics

2. **Monthly Rotation Summary**
   - Metric: MonthlyKeyRotations
   - Purpose: Confirm scheduled rotations are running
   - Action: No alert unless count is 0 (rotations not running)

## Security Benefits

1. **Attack Detection**: Automatic detection of brute force attacks via high failure rate monitoring
2. **Abuse Prevention**: Rate limit tracking helps identify abusive users
3. **Audit Trail**: Complete logging of all authentication and key rotation events
4. **Incident Response**: Rich context in logs for troubleshooting security incidents
5. **Compliance**: Comprehensive audit logs for security compliance requirements

## Performance Considerations

- All tracking is non-blocking (fire-and-forget)
- Application Insights SDK handles batching and retries
- Failed tracking attempts do not block authentication flows
- In-memory failure rate tracking should be replaced with distributed cache (Redis) in production

## Testing Recommendations

1. **Test Authentication Failure Tracking**
   - Send requests with invalid JWT
   - Verify events appear in Application Insights

2. **Test Rate Limit Tracking**
   - Send >10 requests per minute from same user
   - Verify rate limit events and metrics

3. **Test Key Rotation Tracking**
   - Trigger manual rotation via auth-rotate
   - Trigger scheduled rotation via rotate-keys-timer
   - Verify success/failure events

4. **Test Attack Detection**
   - Simulate >50 failed auth attempts in 5 minutes
   - Verify critical exception is created

5. **Test Monitoring Resilience**
   - Remove Application Insights connection string
   - Verify authentication still works (fails open)

## Next Steps

1. **Configure Azure Alerts**: Set up actual alert rules in Azure Portal based on recommendations above
2. **Create Dashboards**: Build Application Insights dashboards for real-time monitoring
3. **Implement Distributed Cache**: Replace in-memory failure tracking with Redis/Azure Cache
4. **Add Email/SMS Notifications**: Configure action groups for critical alerts
5. **Set Up Runbooks**: Create automated response playbooks for common incidents
6. **Regular Review**: Schedule weekly review of monitoring data and alert thresholds

## Related Files

- `backend/functions/shared/monitoring.js` - Main monitoring module
- `backend/functions/auth-exchange/index.js` - Token exchange with monitoring
- `backend/functions/auth-rotate/index.js` - Manual key rotation with monitoring
- `backend/functions/rotate-keys-timer/index.js` - Scheduled rotation with monitoring
- `backend/functions/package.json` - Includes `applicationinsights` dependency

## Dependencies

```json
{
  "applicationinsights": "^2.9.0"
}
```

Already included in `package.json`.

---

**Implementation Status**: ✅ **COMPLETE**

All "Before Production" monitoring requirements from code review have been implemented.
