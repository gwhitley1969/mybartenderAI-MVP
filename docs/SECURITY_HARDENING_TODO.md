# Security Hardening TODO - Defense in Depth

> **STATUS: TO BE IMPLEMENTED BEFORE PRODUCTION**
>
> Created: December 12, 2025
> Last Reviewed: December 12, 2025
> Target: Before production launch with paying customers

---

## Overview

This document tracks security hardening items that should be addressed before moving to production. The current MVP/Beta setup prioritizes development velocity, but these items are essential for a production-ready security posture.

---

## 1. Function App Ingress Restrictions

### Current State (MVP/Beta)

- Function App (`func-mba-fresh`) is **publicly accessible** at `https://func-mba-fresh.azurewebsites.net`
- APIM (`apim-mba-002`) sits in front and provides:
  - JWT token validation
  - Rate limiting
  - Subscription key requirements
  - Tier-based access control
- **Risk**: Someone who discovers the direct Function URL could bypass ALL APIM protections

### Recommended Change

Restrict Function App ingress to only accept traffic from:
1. Azure API Management (`apim-mba-002`)
2. Azure Front Door (`fd-mba-share`)

This implements **defense-in-depth** - even if the direct URL is discovered, requests will be rejected.

### Implementation Steps

```powershell
# 1. Get APIM outbound IPs
$apimIps = az apim show --name apim-mba-002 --resource-group rg-mba-prod --query "publicIpAddresses" -o tsv

# 2. Add Access Restrictions to Function App
# Allow APIM
az functionapp config access-restriction add \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --rule-name "Allow-APIM" \
  --priority 100 \
  --ip-address $apimIps

# Allow Azure Front Door (service tag)
az functionapp config access-restriction add \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --rule-name "Allow-FrontDoor" \
  --priority 200 \
  --service-tag AzureFrontDoor.Backend

# 3. Verify restrictions
az functionapp config access-restriction show \
  --name func-mba-fresh \
  --resource-group rg-mba-prod
```

### Alternative: Front Door Header Validation

For Front Door specifically, also validate the `X-Azure-FDID` header matches your Front Door instance ID to prevent other Front Door instances from accessing your backend.

### Cost Impact

- Access Restrictions: **Free** (no additional cost)
- No plan upgrade required

### Testing After Implementation

1. Direct Function URL should return 403 Forbidden
2. Requests through APIM should work normally
3. Requests through Front Door (share.mybartenderai.com) should work normally

---

## 2. Additional Security Items to Consider

### Before Production

| Item | Priority | Status | Notes |
|------|----------|--------|-------|
| Function App ingress restrictions | High | TODO | See Section 1 above |
| Key Vault network restrictions | Medium | TODO | Restrict to VNet/trusted services |
| PostgreSQL firewall rules | Medium | Review | Currently allows Azure services |
| Storage account public access | Medium | Review | Disable anonymous blob access |
| APIM subscription key rotation | Low | TODO | Automate periodic rotation |
| Managed Identity audit | Low | TODO | Review all MI permissions |

### Future Considerations (Scale Phase)

| Item | Priority | Notes |
|------|----------|-------|
| VNet integration for Function App | Medium | Enables private endpoints |
| Private endpoints for PostgreSQL | Medium | Removes public endpoint |
| Private endpoints for Storage | Low | For sensitive data scenarios |
| WAF on Front Door | Medium | If facing DDoS/bot attacks |
| Azure DDoS Protection Standard | Low | For high-value targets |

---

## 3. Current Security Controls (Already Implemented)

These are working and should be maintained:

- [x] Managed Identity for Key Vault access (no stored credentials)
- [x] Managed Identity for Blob Storage access
- [x] Key Vault for all secrets (connection strings, API keys)
- [x] JWT validation at APIM layer
- [x] Rate limiting per tier (Free/Premium/Pro)
- [x] HTTPS enforced on all endpoints
- [x] Entra External ID for user authentication
- [x] No hardcoded credentials in code (as of Dec 12, 2025)
- [x] .gitignore configured for sensitive files

---

## 4. Action Items Checklist

Before production launch, complete these items:

- [ ] Implement Function App Access Restrictions (Section 1)
- [ ] Test all endpoints work through APIM after restrictions
- [ ] Test Front Door endpoints work after restrictions
- [ ] Verify direct Function URL returns 403
- [ ] Review PostgreSQL firewall rules
- [ ] Review Storage account public access settings
- [ ] Audit Key Vault access policies/RBAC
- [ ] Document final security architecture
- [ ] Security review sign-off

---

## References

- [Azure Function App Access Restrictions](https://learn.microsoft.com/en-us/azure/app-service/app-service-ip-restrictions)
- [Azure Front Door Security](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-security-headers)
- [APIM + Functions Best Practices](https://learn.microsoft.com/en-us/azure/api-management/import-function-app-as-api)
- [Defense in Depth - Azure Security](https://learn.microsoft.com/en-us/azure/security/fundamentals/infrastructure)

---

**Remember: Security is not a one-time task. Review this document periodically and update as the architecture evolves.**
