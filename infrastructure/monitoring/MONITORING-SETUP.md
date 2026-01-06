# Friends via Code - Monitoring Setup Guide

## Overview

This document describes the monitoring configuration for the Friends via Code social sharing feature.

## Application Insights

### Resource Details
- **Name**: `func-mba-fresh`
- **Resource Group**: `rg-mba-prod`
- **Instrumentation Key**: `aa0dc4f9-2683-4a09-9146-ef316de3b81c`

### Monitored Components
1. **Azure Functions** (automatically monitored)
   - users-me (GET/PATCH)
   - social-share-internal (POST)
   - social-invite (POST/GET)
   - social-inbox (GET)
   - social-outbox (GET)

2. **APIM Operations** (via Application Insights logger)
   - All social endpoints
   - JWT validation failures
   - Rate limiting events
   - Quota exceeded events

### Key Metrics Script

Run the monitoring script to view real-time metrics:

```powershell
.\infrastructure\monitoring\check-social-metrics.ps1
```

This script provides:
- Social endpoint usage counts
- Error rates and response codes
- APIM rate limit events
- Response time percentiles (P50, P95, P99)
- User tier distribution

## Key Queries for Application Insights

### 1. Social Endpoint Usage
```kusto
requests
| where timestamp > ago(24h)
| where name contains "social" or name contains "users-me"
| summarize RequestCount = count() by name, bin(timestamp, 1h)
| render timechart
```

### 2. Error Rate by Endpoint
```kusto
requests
| where timestamp > ago(24h)
| where (name contains "social" or name contains "users-me") and success == false
| summarize ErrorCount = count(), AvgDuration = avg(duration) by name, resultCode
| order by ErrorCount desc
```

### 3. Rate Limit Violations
```kusto
requests
| where timestamp > ago(24h)
| where resultCode == 429
| extend userId = tostring(customDimensions["X-User-Id"])
| extend userTier = tostring(customDimensions["X-User-Tier"])
| summarize Count = count() by userId, userTier, name
| order by Count desc
```

### 4. Performance Analysis
```kusto
requests
| where timestamp > ago(24h)
| where name contains "social" or name contains "users-me"
| summarize
    P50 = percentile(duration, 50),
    P95 = percentile(duration, 95),
    P99 = percentile(duration, 99),
    MaxDuration = max(duration)
    by name
| order by P95 desc
```

### 5. User Tier Distribution
```kusto
requests
| where timestamp > ago(24h)
| where name contains "social" or name contains "users-me"
| extend userTier = tostring(customDimensions["X-User-Tier"])
| where isnotempty(userTier)
| summarize RequestCount = count() by userTier, bin(timestamp, 1h)
| render timechart
```

## Recommended Alerts

### Critical Alerts

#### 1. High Error Rate
- **Condition**: Error rate > 5% for 5 minutes
- **Action**: Send email notification
- **Query**:
```kusto
requests
| where timestamp > ago(5m)
| where name contains "social" or name contains "users-me"
| summarize SuccessRate = 100.0 * countif(success) / count()
| where SuccessRate < 95
```

#### 2. Slow Response Times
- **Condition**: P95 response time > 2000ms for 5 minutes
- **Action**: Send email notification
- **Query**:
```kusto
requests
| where timestamp > ago(5m)
| where name contains "social" or name contains "users-me"
| summarize P95 = percentile(duration, 95)
| where P95 > 2000
```

### Warning Alerts

#### 3. High Rate Limit Usage
- **Condition**: More than 10 rate limit hits in 15 minutes
- **Action**: Send notification
- **Query**:
```kusto
requests
| where timestamp > ago(15m)
| where resultCode == 429
| summarize Count = count()
| where Count > 10
```

#### 4. Database Connection Failures
- **Condition**: Any database connection errors
- **Action**: Send immediate notification
- **Query**:
```kusto
exceptions
| where timestamp > ago(5m)
| where outerMessage contains "database" or outerMessage contains "postgres"
| summarize Count = count()
```

## APIM Analytics

### Accessing APIM Analytics

1. Navigate to Azure Portal
2. Go to APIM instance: `apim-mba-001`
3. Select **Analytics** from left menu
4. View:
   - API usage by operation
   - Response times
   - Error rates
   - Geographic distribution

### Key APIM Metrics

- **Requests**: Total API calls per endpoint
- **Latency**: Backend vs total response time
- **Errors**: 4xx and 5xx response codes
- **Capacity**: APIM instance utilization

## Azure Front Door Monitoring

### Metrics to Monitor

1. **Request Count**: Total requests to share.mybartenderai.com
2. **Response Time**: Time to serve static pages
3. **Cache Hit Ratio**: Effectiveness of CDN caching
4. **Origin Health**: Static website availability
5. **SSL Certificate Expiry**: Managed certificate renewal

### Accessing Front Door Metrics

```bash
az monitor metrics list \
  --resource "/subscriptions/<sub-id>/resourceGroups/rg-mba-prod/providers/Microsoft.Cdn/profiles/fd-mba-share" \
  --metric-names "RequestCount,TotalLatency,CacheHitRatio" \
  --start-time "2025-11-15T00:00:00Z" \
  --end-time "2025-11-16T00:00:00Z"
```

## Dashboard Configuration

### Creating Custom Dashboard

1. Navigate to Azure Portal
2. Click **Dashboard** > **New dashboard**
3. Add tiles:
   - **Function App Metrics**: Request count, errors, response time
   - **APIM Analytics**: Social API usage
   - **Application Insights**: Custom queries
   - **Front Door Metrics**: CDN performance

### Recommended Tiles

1. **Social Endpoint Requests (Last 24h)**
   - Chart type: Line chart
   - Metric: Request count by endpoint

2. **Error Rate**
   - Chart type: Bar chart
   - Metric: Failed requests percentage

3. **Response Time P95**
   - Chart type: Line chart
   - Metric: 95th percentile duration

4. **User Tier Distribution**
   - Chart type: Pie chart
   - Metric: Requests by tier

5. **Rate Limit Events**
   - Chart type: Number
   - Metric: Count of 429 responses

## Cost Monitoring

### Estimated Monthly Costs

- **Application Insights**: ~$2-5/month (based on log ingestion)
- **APIM Analytics**: Included in Developer tier
- **Front Door**: ~$35/month base + data transfer
- **Storage (logs)**: ~$1/month

### Cost Optimization

1. Set log retention to 90 days (Application Insights)
2. Use sampling for high-volume endpoints (95% sampling)
3. Archive old logs to Storage Account for long-term retention

## Troubleshooting

### Common Issues

#### No Data in Application Insights
- **Check**: Function App has APPLICATIONINSIGHTS_CONNECTION_STRING configured
- **Verify**: Requests are reaching the functions
- **Wait**: Data can take 2-5 minutes to appear

#### High Error Rates
- **Check**: Database connectivity
- **Review**: Application Insights exceptions
- **Verify**: APIM policies are not blocking legitimate requests

#### Rate Limit Exceeded
- **Review**: User tier configuration in JWT claims
- **Check**: APIM quota policies match product tiers
- **Verify**: Client is not making excessive requests

## Next Steps

1. **Set up alerts** using the queries above
2. **Create dashboard** with recommended tiles
3. **Configure** log retention policies
4. **Review metrics** daily for first week
5. **Adjust thresholds** based on actual usage patterns

## Links

- [Application Insights Portal](https://portal.azure.com/#@/resource/subscriptions/a30b74bc-d8dd-4564-8356-2269a68a9e18/resourceGroups/rg-mba-prod/providers/microsoft.insights/components/func-mba-fresh)
- [APIM Analytics](https://portal.azure.com/#@/resource/subscriptions/a30b74bc-d8dd-4564-8356-2269a68a9e18/resourceGroups/rg-mba-prod/providers/Microsoft.ApiManagement/service/apim-mba-001/analytics)
- [Front Door Metrics](https://portal.azure.com/#@/resource/subscriptions/a30b74bc-d8dd-4564-8356-2269a68a9e18/resourceGroups/rg-mba-prod/providers/Microsoft.Cdn/profiles/fd-mba-share/overview)
