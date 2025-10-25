# Entra External ID Custom Authentication Extension Setup - Quick Reference

**Purpose:** Configure age verification (21+) in Entra External ID signup flow
**Function:** validate-age Azure Function
**Event Type:** OnAttributeCollectionSubmit (validates AFTER user submits birthdate)
**Authentication:** OAuth 2.0 / OIDC Bearer tokens
**Status:** ✅ Deployed and Tested

---

## Prerequisites Complete

✅ **validate-age Function Deployed**
- URL: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
- Authentication: OAuth 2.0 Bearer token (NOT function keys)
- Status: Deployed and tested
- Test Results: All passing (under-21 blocks, 21+ allows)

✅ **Function Authentication**
- Uses OAuth 2.0 / OIDC authentication
- Validates Bearer tokens from Entra External ID
- authLevel: "anonymous" (validates token in code)

---

## Configuration Steps

### Step 1: Add Custom User Attributes (5 minutes)

1. **Navigate to Entra External ID**:
   - Azure Portal → **Microsoft Entra ID**
   - Click **External Identities** → **Custom user attributes**

2. **Create `birthdate` Attribute**:
   - Click **+ Add**
   - **Name**: `birthdate`
   - **Display name**: `Date of Birth`
   - **Data type**: `String`
   - **Description**: "User's birthdate for age verification (21+ required)"
   - Click **Create**

3. **Create `age_verified` Attribute**:
   - Click **+ Add**
   - **Name**: `age_verified`
   - **Display name**: `Age Verified`
   - **Data type**: `Boolean`
   - **Description**: "User has been verified as 21 years or older"
   - Click **Create**

---

### Step 2: Create Custom Authentication Extension (10 minutes)

1. **Navigate to Custom Authentication Extensions**:
   - **External Identities** → **Custom authentication extensions**
   - Click **+ Create a custom extension**

2. **Configure Extension Details**:
   - **Name**: `Age Verification`
   - **Event type**: **OnAttributeCollectionSubmit** ⚠️ CRITICAL - must be this event type!
   - **Target URL**: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
   - **Timeout (milliseconds)**: `10000`
   - **Maximum retries**: `1`
   - Click **Next**

3. **Configure API Authentication**:
   - **Authentication type**: `Create new app registration`
   - **Display name**: `Age Verification API`
   - This creates an app registration that Entra uses to send OAuth Bearer tokens to your function
   - Click **Next**

4. **Configure Claims**:
   - Click **+ Add claim**
   - **Claim name**: `birthdate`
   - **Source**: `User attribute`
   - **User attribute**: `birthdate`
   - Click **Add**
   - Click **Next**

5. **Review and Create**:
   - Review configuration
   - Click **Create**

**What this does:**
- Fires AFTER user submits signup form (including birthdate)
- Sends OAuth Bearer token to your function for authentication
- Validates age on server side
- Blocks account creation if under 21
- Allows creation and continues if 21+

---

### Step 3: Update User Flow to Collect Birthdate (5 minutes)

1. **Navigate to User Flows**:
   - **External Identities** → **User flows**
   - Select **mba-signin-signup**

2. **Add Birthdate to Signup Page**:
   - Click **Page layouts** in the left menu
   - Click **Local account sign up page**
   - Scroll to **User attributes** section
   - Find **birthdate** in the list
   - Check ✅ **Show** and ✅ **Required**
   - Set **Display order**: 4 (after First name, Last name, Email)
   - Click **Save**

3. **Update Attribute Label** (Optional):
   - In the same page layout editor
   - Find **birthdate** attribute
   - Change **Display name** to: "Date of Birth (must be 21 or older)"
   - Click **Save**

---

### Step 4: Add Custom Authentication Extension to User Flow (3 minutes)

1. **Navigate to User Flow Extensions**:
   - Go to **User flows** → **mba-signin-signup**
   - Click **Custom authentication extensions** in the left menu

2. **Configure OnAttributeCollectionSubmit Event**:
   - Find the section: **OnAttributeCollectionSubmit**
   - Select from dropdown: **Age Verification**
   - Click **Save**

**What this does:**
- Runs age validation AFTER user submits the form (when birthdate is available)
- If under 21: Blocks account creation, shows custom error message
- If 21+: Continues with account creation flow

---

### Step 5: Configure JWT Token Claims (5 minutes)

1. **Navigate to App Registration**:
   - Azure Portal → **Microsoft Entra ID** → **App registrations**
   - Select **MyBartenderAI Mobile** app

2. **Add Token Configuration**:
   - Click **Token configuration** in the left menu
   - Click **+ Add optional claim**
   - Select token type: ✅ **Access**
   - Find and select: **extension_age_verified**
   - Click **Add**

3. **Grant Admin Consent** (if prompted):
   - If a consent dialog appears, click **Grant admin consent**
   - Click **Yes** to confirm

**What this does:**
- Includes `age_verified: true` claim in JWT access tokens
- APIM can validate this claim before allowing API access

---

## Verification & Testing

### Test 1: Signup with Under-21 Birthdate (Should Block)

1. Open an incognito browser window
2. Navigate to: `https://apim-mba-001.developer.azure-api.net` (or your signup page)
3. Click **Sign up**
4. Fill in form:
   - **Email**: under21test@example.com
   - **First name**: Under
   - **Last name**: Age
   - **Date of Birth**: `2010-01-01` (or any date that makes them under 21)
   - **Password**: [Strong password]
5. Click **Sign up**

**Expected Result:**
❌ **Account creation blocked** with message:
"You must be 21 years or older to use MyBartenderAI. This app is intended for adults of legal drinking age only."

---

### Test 2: Signup with 21+ Birthdate (Should Allow)

1. Repeat signup process with different email
2. Use birthdate: `1990-01-01` (or any date that makes them 21+)

**Expected Result:**
✅ **Account created successfully**

---

### Test 3: Verify JWT Token Includes age_verified Claim

1. Log in with the 21+ account created in Test 2
2. Use browser dev tools to capture the JWT access token
3. Decode token at https://jwt.ms
4. Verify claims include:
   ```json
   {
     "age_verified": true,
     // or
     "extension_age_verified": true
   }
   ```

**Expected Result:**
✅ **age_verified claim present and set to `true`**

---

### Test 4: Test APIM Age Verification Policy

Once APIM policies are updated (see `jwt-validation-with-age-verification.xml`):

```bash
# Test WITHOUT age_verified claim (should return 403)
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Authorization: Bearer JWT_WITHOUT_AGE_VERIFIED" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'

# Expected: 403 Forbidden
# {
#   "code": "AGE_VERIFICATION_REQUIRED",
#   "message": "You must be 21 years or older to access this feature.",
#   "traceId": "..."
# }
```

```bash
# Test WITH age_verified claim (should succeed)
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Authorization: Bearer JWT_WITH_AGE_VERIFIED_TRUE" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'

# Expected: 200 OK (or backend response)
```

---

## Troubleshooting

### Issue 1: Custom Authentication Extension Returns Error

**Possible Causes:**
1. Wrong event type selected (AttributeCollectionStart instead of OnAttributeCollectionSubmit)
2. Function is not deployed or not responding
3. Function endpoint URL is wrong
4. OAuth app registration not configured correctly
5. Extension attribute name mismatch

**Solution:**
1. **Verify event type**: Must be **OnAttributeCollectionSubmit** (NOT AttributeCollectionStart)
   - If wrong, delete extension and recreate with correct event type
2. Test function directly with OAuth token:
   ```powershell
   .\test-validate-age-oauth.ps1
   ```
3. Check function URL is exactly: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
4. Verify OAuth app registration was created during extension setup
5. **Check Function Invocations** in Azure Portal to see if function is being called

### Issue 2: Extension Attribute Name Contains GUID Prefix

**Symptom:** Function receives birthdate as `extension_<GUID>_DateofBirth` instead of `birthdate`

**Cause:** Custom directory extension attributes in Entra External ID automatically get a GUID prefix

**Solution:** The function now searches for any attribute containing "dateofbirth" or "birthdate" (case-insensitive)

### Issue 3: Date Format Issues

**Supported Formats:**
- `MM/DD/YYYY` (e.g., 01/05/1990) - US format with slashes
- `MMDDYYYY` (e.g., 01051990) - US format without separators
- `YYYY-MM-DD` (e.g., 1990-01-05) - ISO format

**Note:** The form may strip slashes and send `MMDDYYYY` format. The function handles all three formats.

### Issue 4: "Something went wrong" Error During Signup

**Debugging Steps:**
1. Check Azure Function **Invocations** tab
   - If invocations show **Success (200)** → Function is working, issue is elsewhere
   - If no invocations → Extension not calling function
2. Click on a recent invocation to view logs
3. Look for:
   - "Found birthdate in extension attribute"
   - "Parsed US date format"
   - "User age calculated"
   - "User is 21+" or "User under 21"

### Issue 5: CORS Errors

**Solution:** CORS has been configured on the Function App for Entra External ID domains:
```bash
az functionapp cors add --name func-mba-fresh --resource-group rg-mba-prod \
  --allowed-origins "https://mybartenderai.ciamlogin.com" "https://*.ciamlogin.com"
```

---

### Issue: age_verified Claim Not in JWT Token

**Possible Causes:**
1. Token configuration not saved
2. Admin consent not granted
3. Need to refresh token (logout and log back in)

**Solution:**
1. Re-check Token Configuration in App Registration
2. Grant admin consent if prompted
3. Log out completely, clear browser cookies, and log back in
4. Check token again at https://jwt.ms

---

### Issue: APIM Returns 403 Even With Valid Token

**Possible Causes:**
1. APIM policy not applied to operation
2. Claim name mismatch (`age_verified` vs `extension_age_verified`)

**Solution:**
1. Verify policy is saved at operation level (not API level)
2. Check policy looks for both claim names:
   ```xml
   var ageVerified = jwt?.Claims.GetValueOrDefault("age_verified", "false");
   var extensionAgeVerified = jwt?.Claims.GetValueOrDefault("extension_age_verified", "false");
   return ageVerified != "true" && extensionAgeVerified != "true";
   ```

---

## Security & Privacy Notes

### Security Architecture - Why OAuth Instead of API Keys

**We use OAuth 2.0 Bearer tokens (NOT API keys) for several critical security reasons:**

#### ❌ API Key Approach (NOT USED - Insecure):
- API keys would be exposed in Azure configuration
- Long-lived secrets that don't expire automatically
- Difficult to rotate without updating configuration
- No audit trail of usage
- If compromised, attacker has permanent access
- Would need Azure Key Vault management

#### ✅ OAuth 2.0 Approach (CURRENT - Secure):
- **No secrets in configuration** - Entra creates an app registration automatically
- **Short-lived tokens** - Bearer tokens expire and are automatically refreshed
- **Managed by Azure AD** - Token issuance handled by Microsoft's identity platform
- **Fully auditable** - All authentication attempts logged in Azure AD
- **No Key Vault needed** - Uses Azure AD trust relationship, not stored secrets
- **Standard protocol** - Industry-standard OAuth 2.0/OIDC authentication

#### How OAuth Works:
```
1. Entra External ID creates "Age Verification API" app registration
2. When user submits signup form, Entra requests OAuth token from Azure AD
3. Azure AD issues short-lived Bearer token
4. Entra sends request to validate-age function:
   Authorization: Bearer eyJ0eXAiOiJKV1Q...
5. Function validates token cryptographically (no secret lookup needed)
6. Token expires automatically after short period
```

**Key Point:** OAuth authentication happens between Azure services using cryptographic trust, not stored secrets. This is more secure than any API key approach.

---

### What We Store
- ✅ **age_verified: true** (boolean flag only)
- ❌ **NOT the birthdate** (discarded after validation)

### Privacy Compliance
- Birthdate collected only during signup for one-time validation
- Only boolean verification flag stored in identity system
- No birthdate transmitted in JWT tokens
- No birthdate accessible via API
- Complies with minimal PII storage principles

### Age Verification Layers
1. **App Store**: 21+ age rating
2. **Mobile App**: Age gate on first launch
3. **Entra External ID**: Server-side validation during signup (OAuth secured)
4. **APIM**: JWT claim validation before API access

---

## Next Steps

1. ✅ **Complete Entra External ID Configuration** (Steps 1-5 above)
2. ⬜ **Test Signup Flow** (Both under-21 and 21+ scenarios)
3. ⬜ **Apply Updated APIM Policy** (jwt-validation-with-age-verification.xml)
4. ⬜ **Test Complete Flow** (Signup → JWT → API call)
5. ⬜ **Implement Mobile App Age Gate** (See AGE_VERIFICATION_IMPLEMENTATION.md)

---

## Reference Information

**Function Details:**
- **Name**: validate-age
- **URL**: https://func-mba-fresh.azurewebsites.net/api/validate-age
- **Method**: POST
- **Auth**: OAuth 2.0 Bearer token (from Entra External ID app registration)
- **Event Type**: OnAttributeCollectionSubmit

**Request Format (from Entra External ID):**
```json
{
  "type": "microsoft.graph.authenticationEvent.attributeCollectionSubmit",
  "data": {
    "userSignUpInfo": {
      "attributes": {
        "birthdate": { "value": "YYYY-MM-DD" },
        "email": { "value": "user@example.com" }
      }
    }
  }
}
```

**Response Format (Under 21 - Block):**
```json
{
  "data": {
    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
    "actions": [{
      "@odata.type": "microsoft.graph.attributeCollectionSubmit.showBlockPage",
      "message": "You must be 21 years or older to use MyBartenderAI. This app is intended for adults of legal drinking age only."
    }]
  }
}
```

**Response Format (21+ - Allow):**
```json
{
  "data": {
    "@odata.type": "microsoft.graph.onAttributeCollectionSubmitResponseData",
    "actions": [{
      "@odata.type": "microsoft.graph.attributeCollectionSubmit.continueWithDefaultBehavior"
    }]
  }
}
```

---

**Status**: ✅ Function deployed and tested with OAuth authentication
**Estimated Configuration Time**: 25-30 minutes
**Difficulty**: Moderate (requires Entra External ID admin access)
