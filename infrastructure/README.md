# MyBartenderAI Infrastructure Configuration

This directory contains all infrastructure configuration files for deploying and managing the MyBartenderAI application.

## Directory Structure

```
infrastructure/
├── apim/                          # Azure API Management configuration
│   ├── configure-apim.ps1        # PowerShell script to configure APIM
│   └── policies/                 # APIM policy XML files
│       ├── free-tier-policy.xml
│       ├── premium-tier-policy.xml
│       ├── pro-tier-policy.xml
│       └── jwt-validation-policy.xml
├── database/                      # PostgreSQL database scripts
│   ├── schema.sql                # Complete database schema
│   └── deploy-schema.ps1         # Deployment script
└── README.md                      # This file
```

## Prerequisites

- Azure CLI installed and authenticated
- PowerShell 7+ (for cross-platform scripts)
- Azure subscription with permissions to manage:
  - API Management
  - Azure Functions
  - PostgreSQL
  - Key Vault

## Azure Resources

### Deployed Resources
- **Resource Group**: `rg-mba-prod` (South Central US)
- **APIM**: `apim-mba-001` (Developer tier → Consumption in production)
- **Function App**: `func-mba-fresh` (Windows Consumption Plan)
- **PostgreSQL**: `pg-mybartenderdb` (Flexible Server)
- **Storage Account**: `mbacocktaildb3`
- **Key Vault**: `kv-mybartenderai-prod` (in `rg-mba-dev`)

## Configuration Steps

### Step 1: Configure APIM

Run the APIM configuration script:

```powershell
cd infrastructure/apim
./configure-apim.ps1 -ResourceGroup "rg-mba-prod" -ApimServiceName "apim-mba-001"
```

This script will:
1. Create backend configuration for Function App
2. Create three Products (Free/Premium/Pro)
3. Import OpenAPI specification
4. Add API to all products

### Step 2: Apply APIM Policies

After running the script, manually apply policies via Azure Portal:

1. Navigate to APIM instance: https://portal.azure.com
2. Go to APIs → Products
3. For each product (Free/Premium/Pro):
   - Select the product
   - Go to Policies
   - Copy content from corresponding policy XML file
   - Paste and save

**Policy Files:**
- `policies/free-tier-policy.xml` → Free Tier Product
- `policies/premium-tier-policy.xml` → Premium Tier Product
- `policies/pro-tier-policy.xml` → Pro Tier Product
- `policies/jwt-validation-policy.xml` → Apply to API level

### Step 3: Deploy Database Schema

Deploy the PostgreSQL schema:

```powershell
cd infrastructure/database
./deploy-schema.ps1 -ServerName "pg-mybartenderdb" -DatabaseName "mybartenderai"
```

Or manually via psql:

```bash
psql -h pg-mybartenderdb.postgres.database.azure.com -U adminuser -d mybartenderai -f schema.sql
```

### Step 4: Configure JWT Validation

Update `jwt-validation-policy.xml` with your Azure AD B2C details:

1. Replace `{tenant-name}` with your B2C tenant name
2. Replace `{your-client-id}` with your app's client ID
3. Replace `{tenant-id}` with your B2C tenant ID

Apply the policy:
1. Go to APIM → APIs → MyBartenderAI API
2. Select "All operations"
3. In Inbound processing, add the JWT validation policy

### Step 5: Verify Configuration

Test the health endpoint:

```bash
curl https://apim-mba-001.azure-api.net/api/health
```

Expected response:
```json
{
  "status": "ok",
  "message": "MyBartenderAI API is running",
  "timestamp": "2025-10-22T..."
}
```

## Three-Tier Subscription Model

### Free Tier
- **Rate Limit**: 100 API calls/day
- **AI Recommendations**: 10/month (enforced by backend)
- **Voice**: Blocked (403 Forbidden)
- **Vision**: Blocked (403 Forbidden)
- **Custom Recipes**: 3 total

### Premium Tier ($4.99/month)
- **Rate Limit**: 1,000 API calls/day
- **AI Recommendations**: 100/month
- **Voice**: 30 minutes/month
- **Vision**: 5 scans/month
- **Custom Recipes**: 25 total
- **Priority Routing**: Yes

### Pro Tier ($9.99/month)
- **Rate Limit**: 10,000 API calls/day (abuse prevention)
- **AI Recommendations**: Unlimited
- **Voice**: 5 hours (300 minutes)/month
- **Vision**: 50 scans/month
- **Custom Recipes**: Unlimited
- **Priority Routing**: Highest priority
- **Support**: Dedicated support

## APIM Endpoints

Base URL: `https://apim-mba-001.azure-api.net/api`

### Public (No Auth)
- `GET /health` - Health check

### Authenticated (API Key + JWT)
- `GET /v1/snapshots/latest` - Get cocktail database snapshot
- `GET /v1/images/manifest` - Get image manifest
- `POST /v1/recommend` - AI cocktail recommendations
- `POST /v1/ask-bartender` - Conversational AI chat
- `GET /v1/speech/token` - Get Speech Services token (Premium/Pro)
- `POST /v1/voice/session` - Track voice session
- `POST /v1/vision/scan` - Scan bar photo (Premium/Pro)
- `GET /v1/inventory` - Get user's bar inventory
- `POST /v1/inventory` - Update user's inventory
- `GET /v1/user/tier` - Get user's tier and quota
- `POST /v1/auth/register` - Register user and provision subscription

### Admin (Function Key)
- `POST /v1/admin/sync` - Manually trigger CocktailDB sync

## Database Schema

### Key Tables
- **drinks**: Cocktail recipes from TheCocktailDB
- **ingredients**: Ingredient master list
- **drink_ingredients**: Recipe ingredient relationships
- **users**: User accounts with tier information
- **user_inventory**: User's bar ingredients
- **usage_tracking**: Feature usage for quota enforcement
- **voice_sessions**: Voice assistant session tracking
- **vision_scans**: Vision scan history

### Helper Functions
- `get_user_quotas(tier)`: Returns quota limits for a tier
- `check_user_quota(user_id, feature_type)`: Check remaining quota
- `record_usage(user_id, feature_type, count)`: Record feature usage

## Monitoring and Analytics

### Application Insights
All functions and APIM operations log to Application Insights for:
- Request tracing with correlation IDs
- Performance metrics
- Error tracking
- Custom events (AI usage, voice sessions, etc.)

### Database Views
- `user_usage_summary`: User usage by feature and month
- `monthly_tier_stats`: User count and revenue potential by tier

## Cost Optimization

### Development (~$60-70/month)
- APIM Developer tier: $50/month
- Functions: ~$0.20/month
- PostgreSQL Basic: $12-30/month
- Storage: ~$1/month

### Production Target (~$20-30/month + usage)
- APIM Consumption: $5-15/month
- Functions: ~$0.20/month
- PostgreSQL Optimized: $12-20/month
- Storage: ~$1/month
- AI/Speech: Covered by subscription revenue

## Security Best Practices

1. **Never commit secrets** - Use Key Vault for all sensitive data
2. **Rotate keys regularly** - APIM subscription keys, function keys
3. **Enable HTTPS only** - All endpoints must use HTTPS
4. **Validate JWT tokens** - APIM validates before backend
5. **Rate limiting** - Prevent abuse with tier-based limits
6. **Monitor usage** - Track for anomalies

## Troubleshooting

### APIM Returns 401 Unauthorized
- Check JWT token is valid and not expired
- Verify JWT validation policy is correctly configured
- Ensure Authorization header format: `Bearer <token>`

### APIM Returns 403 Forbidden
- Verify user is subscribed to correct product (Free/Premium/Pro)
- Check if tier allows access to requested feature
- Free tier users cannot access voice/vision endpoints

### APIM Returns 429 Too Many Requests
- User has exceeded rate limit for their tier
- Free: 100 calls/day
- Premium: 1,000 calls/day
- Pro: 10,000 calls/day
- Wait for `Retry-After` seconds or upgrade tier

### Database Connection Issues
- Check PostgreSQL firewall rules allow Azure services
- Verify connection string in Key Vault is correct
- Check Function App has access to Key Vault

## Next Steps

1. **Complete APIM configuration** by applying all policies
2. **Deploy database schema** to PostgreSQL
3. **Configure Azure AD B2C** for authentication
4. **Test endpoints** with Postman or APIM Developer Portal
5. **Implement backend Functions** for AI and voice features
6. **Build Flutter mobile app** to consume APIM APIs

## Support

For issues or questions:
- Review logs in Application Insights
- Check APIM Analytics for request patterns
- Consult main documentation in `/docs/`

---

**Last Updated**: October 22, 2025
**Version**: 1.0
