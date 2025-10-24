# Entra External ID API Connector Setup - Quick Reference

**Purpose:** Configure age verification (21+) in Entra External ID signup flow
**Function:** validate-age Azure Function
**Status:** ✅ Deployed and Tested

---

## Prerequisites Complete

✅ **validate-age Function Deployed**
- URL: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
- Status: Deployed and tested
- Test Results: All passing (under-21 blocks, 21+ allows)

✅ **Function Key Available**
- Retrieve with Azure CLI:
  ```bash
  az functionapp function keys list \
    --name func-mba-fresh \
    --resource-group rg-mba-prod \
    --function-name validate-age \
    --query "default" -o tsv
  ```

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

### Step 2: Configure API Connector (5 minutes)

1. **Navigate to API Connectors**:
   - **External Identities** → **API connectors**
   - Click **+ New API connector**

2. **Configure Connector**:
   - **Name**: `Age Verification`
   - **Endpoint URL**: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
   - **Authentication type**: `API key in header`
   - **Header name**: `code`
   - **Header value**: [Paste function key from Azure CLI]
   - Click **Save**

3. **Test the Connector** (Optional):
   - Click **Test** button
   - Enter test JSON:
     ```json
     {
       "birthdate": "1990-01-01",
       "email": "test@example.com"
     }
     ```
   - Expected response:
     ```json
     {
       "version": "1.0.0",
       "action": "Continue",
       "extension_age_verified": true
     }
     ```

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

### Step 4: Add API Connector to User Flow (3 minutes)

1. **Navigate to User Flow API Connectors**:
   - Still in **mba-signin-signup** user flow
   - Click **API connectors** in the left menu

2. **Configure "Before creating the user" Step**:
   - Find the section: **Before creating the user**
   - Select from dropdown: **Age Verification**
   - Click **Save**

**What this does:**
- Runs age validation BEFORE the user account is created
- If under 21: Blocks account creation, shows error page
- If 21+: Creates account and sets `extension_age_verified: true`

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

### Issue: API Connector Returns 500 Error

**Possible Causes:**
1. Function key is incorrect
2. Function is not deployed
3. Function endpoint URL is wrong

**Solution:**
1. Verify function key:
   ```bash
   az functionapp function keys list --name func-mba-fresh --resource-group rg-mba-prod --function-name validate-age --query "default" -o tsv
   ```
2. Test function directly (use test script):
   ```powershell
   .\test-age-validation.ps1
   ```
3. Check function URL is exactly: `https://func-mba-fresh.azurewebsites.net/api/validate-age`

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
3. **Entra External ID**: Server-side validation during signup
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
- **Auth**: Function key (code parameter)

**Request Format:**
```json
{
  "birthdate": "YYYY-MM-DD",
  "email": "user@example.com"
}
```

**Response Format (Under 21):**
```json
{
  "version": "1.0.0",
  "action": "ShowBlockPage",
  "userMessage": "You must be 21 years or older to use MyBartenderAI..."
}
```

**Response Format (21+):**
```json
{
  "version": "1.0.0",
  "action": "Continue",
  "extension_age_verified": true
}
```

---

**Status**: ✅ Function deployed and tested
**Estimated Configuration Time**: 20-25 minutes
**Difficulty**: Moderate (requires Entra External ID admin access)
