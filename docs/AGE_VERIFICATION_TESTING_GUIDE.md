# Age Verification Testing Guide

**Last Updated:** 2025-10-26

## Overview

This guide provides a two-phase testing approach for age verification:
- **Phase 1:** Test with Content-Type header fix (OAuth validation disabled)
- **Phase 2:** Enable OAuth validation and test security

## ✅ Completed Fixes

1. **Content-Type Headers** - All responses now include `Content-Type: application/json`
2. **HTTP Status Codes** - All responses return HTTP 200 (Entra requirement)
3. **OAuth Validation** - Implemented with configurable enable/disable
4. **Extension Attribute Handling** - Supports GUID-prefixed attributes
5. **Multiple Date Formats** - Supports MM/DD/YYYY, MMDDYYYY, and YYYY-MM-DD

## Phase 1: Test Signup Flow (OAuth Disabled)

**Goal:** Verify the Content-Type header fix resolves the "Something went wrong" error

### Current Configuration
- ✅ Content-Type headers added to all responses
- ✅ OAuth validation **DISABLED** (default)
- ✅ Function deployed and operational

### Testing Steps

#### Test 1: Sign Up with Under-21 Birthdate (Should Block)

1. **Open incognito/private browser window**
   ```
   This ensures clean cookies and no cached authentication
   ```

2. **Navigate to your Entra External ID signup page**
   ```
   Example: https://mybartenderai.ciamlogin.com/...
   ```

3. **Fill out the signup form:**
   - **Email:** under21test@example.com
   - **First Name:** Test
   - **Last Name:** Under21
   - **Date of Birth:** 01/05/2010 (or any date making them under 21)
   - **Password:** [Strong password - letters, numbers, symbols]

4. **Click "Sign up" or "Create account"**

**Expected Result:**
❌ **Account creation BLOCKED** with message:
```
You must be 21 years or older to use MyBartenderAI.
This app is intended for adults of legal drinking age only.
```

**If this fails:**
- Check Azure Portal → func-mba-fresh → validate-age → Invocations
- Look for recent execution and click to view logs
- Verify function was called and returned proper response
- Check for any errors in Application Insights

---

#### Test 2: Sign Up with 21+ Birthdate (Should Allow)

1. **Open new incognito/private browser window**

2. **Navigate to signup page again**

3. **Fill out the signup form:**
   - **Email:** over21test@example.com
   - **First Name:** Test
   - **Last Name:** Over21
   - **Date of Birth:** 01/05/1990 (or any date making them 21+)
   - **Password:** [Strong password]

4. **Click "Sign up"**

**Expected Result:**
✅ **Account created successfully!**
- You should see a success message or be redirected to sign in
- No "Something went wrong" error
- No "Contact IT administrator" error

**After successful creation:**

5. **Verify account exists in Entra External ID:**
   - Azure Portal → Microsoft Entra ID
   - External Identities → Users
   - Search for "over21test@example.com"
   - **Account should appear in the tenant list**

---

#### Test 3: Verify Function Logs

1. **Navigate to Function App logs:**
   ```
   Azure Portal → func-mba-fresh → validate-age → Invocations
   ```

2. **Click on most recent successful invocation (21+ test)**

3. **Verify logs contain:**
   ```
   [OAuth] Validation DISABLED - proceeding without token validation
   User age calculated: [age] years
   User is 21+ (age: [age]), allowing signup with age_verified claim
   ```

4. **Check response includes Content-Type header:**
   - Status: 200
   - Headers: Content-Type: application/json
   - Response contains: continueWithDefaultBehavior

---

### Phase 1 Success Criteria

✅ Under-21 signup blocked with correct error message
✅ 21+ signup succeeds without errors
✅ Account appears in Entra External ID users list
✅ Function logs show successful validation
✅ No "Something went wrong" errors

**If all checks pass → Proceed to Phase 2**

---

## Phase 2: Enable OAuth Validation (Production Security)

**Goal:** Enable full OAuth token validation for production security

### Prerequisites
- Phase 1 tests all passing
- Custom Authentication Extension configured in Entra
- "Age Verification API" app registration exists

### Step 1: Get Your Entra Tenant Information

1. **Find your tenant ID:**
   ```bash
   # Option 1: From Azure Portal
   Azure Portal → Microsoft Entra ID → Overview → Tenant ID (copy the GUID)

   # Option 2: From CLI
   az account show --query tenantId -o tsv
   ```

2. **Note your tenant name:**
   ```
   Example: mybartenderai.onmicrosoft.com
   ```

### Step 2: Configure Environment Variables

Run these commands to enable OAuth validation:

```bash
# Set your tenant ID (replace with your actual tenant ID)
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings \
    "ENTRA_TENANT_ID=<your-tenant-id-guid>" \
    "ENABLE_OAUTH_VALIDATION=true"
```

**Example:**
```bash
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings \
    "ENTRA_TENANT_ID=12345678-1234-1234-1234-123456789012" \
    "ENABLE_OAUTH_VALIDATION=true"
```

### Step 3: Verify Configuration

```bash
# Verify settings are applied
az functionapp config appsettings list \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --query "[?name=='ENABLE_OAUTH_VALIDATION' || name=='ENTRA_TENANT_ID'].{Name:name, Value:value}" \
  --output table
```

**Expected output:**
```
Name                      Value
------------------------  ------------------------------------
ENABLE_OAUTH_VALIDATION   true
ENTRA_TENANT_ID           12345678-1234-1234-1234-123456789012
```

### Step 4: Restart Function App

```bash
az functionapp restart \
  --name func-mba-fresh \
  --resource-group rg-mba-prod
```

Wait 30 seconds for restart to complete.

---

### Phase 2 Testing

Repeat the same tests from Phase 1:

#### Test 4: Sign Up with OAuth Validation Enabled

1. **Test under-21 signup** (should still block)
2. **Test 21+ signup** (should still succeed)

**Additional verification:**

3. **Check function logs for OAuth validation:**
   ```
   Azure Portal → func-mba-fresh → validate-age → Invocations → Click recent execution
   ```

4. **Verify logs now show:**
   ```
   [OAuth] Validation ENABLED - validating token
   [OAuth] Validating token from issuer: https://login.microsoftonline.com/<tenant-id>/v2.0
   [OAuth] Token validated successfully
   [OAuth] Token subject: <service-principal-id>
   [OAuth] Service principal app ID: <app-id>
   [OAuth] Token validated - proceeding with age verification
   ```

---

### Phase 2 Success Criteria

✅ OAuth validation logs show "Token validated successfully"
✅ Service principal app ID logged
✅ Under-21 signup still blocked
✅ 21+ signup still succeeds
✅ No authentication errors

---

## Troubleshooting

### Issue: OAuth Validation Fails After Enabling

**Symptoms:**
- Signup fails with "Authentication failed" message
- Logs show: "[OAuth] Token validation failed"

**Possible Causes:**
1. Wrong ENTRA_TENANT_ID (must be the GUID, not tenant name)
2. Custom Authentication Extension not properly configured
3. "Age Verification API" app registration missing

**Solutions:**

1. **Verify Tenant ID is correct:**
   ```bash
   az account show --query tenantId -o tsv
   ```

2. **Check Custom Authentication Extension exists:**
   - Azure Portal → Microsoft Entra ID → External Identities
   - Custom authentication extensions
   - Verify "Age Verification" extension exists
   - Verify Event Type: OnAttributeCollectionSubmit

3. **Check app registration exists:**
   - Azure Portal → Microsoft Entra ID → App registrations
   - Search for "Age Verification API"
   - Note the Application (client) ID

4. **Temporarily disable OAuth to isolate issue:**
   ```bash
   az functionapp config appsettings set \
     --name func-mba-fresh \
     --resource-group rg-mba-prod \
     --settings "ENABLE_OAUTH_VALIDATION=false"
   ```

---

### Issue: "Something went wrong" Returns After Phase 1 Success

**Possible Cause:** Cold start timeout or function app restart issue

**Solution:**
1. Wait 2-3 minutes for function app to fully warm up
2. Try signup again
3. Check Application Insights for timeout errors

---

### Issue: Accounts Not Appearing in Entra Tenant

**Symptoms:**
- Signup appears to succeed
- No error message shown
- Account doesn't appear in Users list

**Debugging Steps:**

1. **Check Audit Logs:**
   ```
   Azure Portal → Microsoft Entra ID → Audit logs
   Filter: Activity = "Add user"
   Date range: Last hour
   ```

2. **Verify Custom Authentication Extension is added to User Flow:**
   ```
   Azure Portal → External Identities → User flows → mba-signin-signup
   Custom authentication extensions → OnAttributeCollectionSubmit
   Should show: "Age Verification" selected
   ```

3. **Check if extension is blocking ALL signups:**
   - Function logs may show unexpected errors
   - Try with OAuth validation disabled to isolate

---

## Next Steps After Testing

Once both phases pass successfully:

### Security Hardening (Priority)
1. ✅ OAuth validation enabled
2. ⬜ **Implement audit logging** (COPPA/GDPR compliance)
3. ⬜ **Remove verbose logging** (don't log birthdates in production)
4. ⬜ **Set up monitoring alerts** for validation failures

### Documentation Updates
1. ⬜ Update AUTHENTICATION_SETUP.md with test results
2. ⬜ Update TROUBLESHOOTING.md if new issues discovered
3. ⬜ Document actual tenant ID and app registration IDs

### Mobile App Integration
1. ⬜ Configure mobile app with Entra External ID authentication
2. ⬜ Test complete flow: Mobile → Entra → APIM → Functions
3. ⬜ Verify JWT tokens include age_verified claim

---

## Success Metrics

**Phase 1 Complete:**
- ✅ No "Something went wrong" errors
- ✅ Accounts created successfully for 21+ users
- ✅ Accounts blocked successfully for under-21 users
- ✅ Accounts visible in Entra External ID tenant

**Phase 2 Complete:**
- ✅ OAuth tokens validated successfully
- ✅ Service principal authentication working
- ✅ No degradation in functionality
- ✅ Security audit trail in logs

**Production Ready:**
- ✅ Both phases passing
- ✅ Audit logging implemented
- ✅ Monitoring alerts configured
- ✅ Mobile app integration tested

---

## Support

If you encounter issues not covered in this guide:

1. **Check Application Insights:**
   ```bash
   az monitor app-insights query \
     --app func-mba-fresh \
     --resource-group rg-mba-prod \
     --analytics-query "exceptions | where timestamp > ago(1h) | project timestamp, innermostMessage"
   ```

2. **Review function invocations:**
   - Azure Portal → func-mba-fresh → validate-age → Invocations
   - Click on failed invocations to see detailed logs

3. **Check TROUBLESHOOTING.md** for additional common issues

---

**Good luck with testing!** 🎉
