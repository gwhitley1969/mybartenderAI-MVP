# JWT Validation Fix

## The Problem (From Debug Logs)

✅ **What's Working:**
- JWT token is being sent (1301 chars, valid format)
- Token is NOT expired
- Headers are correct (Authorization: Bearer + Subscription Key)
- Recipe Vault works (confirms subscription key is correct)

❌ **What's Failing:**
- APIM returns 401 when validating the JWT
- Error: "Client error - the request contains bad syntax or cannot be fulfilled"

## Root Cause

The JWT validation policy in APIM is likely misconfigured. The token from Entra External ID doesn't match what APIM expects.

## Quick Fix - Remove JWT Validation Temporarily

To verify this is the issue, let's temporarily remove JWT validation from the ask-bartender-simple operation:

### Option 1: Via Azure Portal

1. Go to Azure Portal
2. Navigate to: API Management services > apim-mba-001
3. APIs > mybartenderai-api
4. Operations > askBartenderSimple
5. Inbound processing > Policy code editor
6. Remove or comment out the `<validate-jwt>` section
7. Save

### Option 2: Empty Policy XML

Create file `temp-no-jwt-policy.xml`:
```xml
<policies>
    <inbound>
        <base />
        <set-query-parameter name="code" exists-action="override">
            <value>{{function-key}}</value>
        </set-query-parameter>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

## Test After Removing JWT Validation

Once JWT validation is removed:
1. Try the AI Chat again
2. If it works, we know JWT validation is the issue
3. We can then fix the JWT validation policy

## The Correct JWT Validation Policy

Based on your Entra External ID configuration, the policy should be:

```xml
<policies>
    <inbound>
        <base />
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Invalid or missing JWT token">
            <openid-config url="https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/v2.0/.well-known/openid-configuration" />
            <audiences>
                <audience>f9f7f159-b847-4211-98c9-18e5b8193045</audience>
            </audiences>
            <!-- Remove issuer validation for now - Entra External ID uses dynamic issuers -->
            <required-claims>
                <claim name="aud" match="any">
                    <value>f9f7f159-b847-4211-98c9-18e5b8193045</value>
                </claim>
            </required-claims>
        </validate-jwt>
        <set-query-parameter name="code" exists-action="override">
            <value>{{function-key}}</value>
        </set-query-parameter>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
```

## Key Issues to Check

1. **Audience (aud)**: Must match your app's client ID: `f9f7f159-b847-4211-98c9-18e5b8193045`
2. **Issuer**: Entra External ID uses dynamic issuers, might need to remove issuer validation
3. **OpenID Config URL**: Should point to the correct Entra External ID endpoint

## Immediate Action

1. **Remove JWT validation temporarily** to confirm that's the issue
2. **Test the AI Chat** - it should work without JWT validation
3. **Fix the JWT validation policy** with correct values
4. **Re-enable JWT validation** with the corrected policy

This will get the AI Chat working while maintaining security for your tiered pricing model.