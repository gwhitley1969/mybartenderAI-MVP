# MyBartenderAI - Age Verification Ready to Test

**Last Updated:** 2025-10-26
**Status:** ✅ Phase 1 Ready for Testing

---

## 🎯 What's Been Fixed

1. ✅ **Content-Type Headers** - All responses now include `Content-Type: application/json`
2. ✅ **HTTP Status Codes** - All responses return HTTP 200 (Entra requirement)
3. ✅ **OAuth Validation** - Implemented and ready to enable
4. ✅ **Extension Attributes** - Handles GUID-prefixed custom attributes
5. ✅ **Multiple Date Formats** - Supports MM/DD/YYYY, MMDDYYYY, YYYY-MM-DD
6. ✅ **Function Deployed** - All changes live on func-mba-fresh

---

## 🧪 Phase 1: Test NOW (OAuth Disabled)

### Your Signup URL
```
https://mybartenderai.ciamlogin.com/mybartenderai.onmicrosoft.com/oauth2/v2.0/authorize?client_id=f9f7f159-b847-4211-98c9-18e5b8193045&nonce=axMegJYZrN&redirect_uri=https://jwt.ms&scope=openid&response_type=code&prompt=login&code_challenge_method=S256&code_challenge=zScucDE0bV--QtBcz21bMxAaSWTNu7DC7lHr-zo8w2U
```

### Test 1: Under-21 User (Should Block)

1. **Open incognito/private browser window**
2. **Navigate to your signup URL** (copy the URL above)
3. **Fill out the signup form:**
   - **Email:** under21test@mybartenderai.com
   - **First Name:** Test
   - **Last Name:** Under21
   - **Date of Birth:** 01/05/2010 (14 years old)
   - **Password:** TestPassword123!
4. **Click "Sign up"**

**Expected Result:**
```
❌ BLOCKED with message:
"You must be 21 years or older to use MyBartenderAI.
This app is intended for adults of legal drinking age only."
```

---

### Test 2: 21+ User (Should Succeed)

1. **Open NEW incognito/private browser window**
2. **Navigate to signup URL** (same as above)
3. **Fill out the signup form:**
   - **Email:** over21test@mybartenderai.com
   - **First Name:** Test
   - **Last Name:** Over21
   - **Date of Birth:** 01/05/1990 (34 years old)
   - **Password:** TestPassword123!
4. **Click "Sign up"**

**Expected Result:**
```
✅ SUCCESS - Account created!
- Should see success message or redirect to sign in
- NO "Something went wrong" error
- NO "Contact IT administrator" error
```

---

### Test 3: Verify Account in Entra

After Test 2 succeeds:

1. **Navigate to:**
   ```
   Azure Portal → Microsoft Entra ID → Users
   ```

2. **Search for:** `over21test@mybartenderai.com`

3. **Expected Result:**
   ```
   ✅ Account appears in users list
   - Display name: Test Over21
   - User principal name: over21test@mybartenderai.com
   - Account enabled: Yes
   ```

---

### Test 4: Check Function Logs

1. **Navigate to:**
   ```
   Azure Portal → Function Apps → func-mba-fresh
   → Functions → validate-age → Invocations
   ```

2. **Click on most recent successful invocation**

3. **Verify logs contain:**
   ```
   [OAuth] Validation DISABLED - proceeding without token validation
   User age calculated: 34 years
   User is 21+ (age: 34), allowing signup with age_verified claim
   ```

4. **Verify response:**
   - Status: 200
   - Content-Type: application/json
   - Response contains: "continueWithDefaultBehavior"

---

## ✅ Phase 1 Success Criteria

Check all that apply:

- [ ] Under-21 signup blocked with correct error message
- [ ] 21+ signup succeeds without errors
- [ ] Account appears in Entra External ID users list
- [ ] Function logs show successful validation
- [ ] No "Something went wrong" errors
- [ ] No "Contact IT administrator" errors

**If all boxes checked → Proceed to Phase 2**

---

## 🔐 Phase 2: Enable OAuth Validation (After Phase 1 Success)

### Step 1: Configure Environment Variables

**Ready-to-run commands for your tenant:**

```bash
# Configure OAuth validation with YOUR tenant ID
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings \
    "ENTRA_TENANT_ID=a82813af-1054-4e2d-a8ec-c6b9c2908c91" \
    "ENABLE_OAUTH_VALIDATION=true"
```

### Step 2: Restart Function App

```bash
az functionapp restart \
  --name func-mba-fresh \
  --resource-group rg-mba-prod
```

**Wait 30 seconds** for restart to complete.

### Step 3: Verify Configuration

```bash
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
ENTRA_TENANT_ID           a82813af-1054-4e2d-a8ec-c6b9c2908c91
```

---

### Step 4: Test Again (Same Tests, OAuth Now Enabled)

Repeat Tests 1-4 from Phase 1:
- Under-21 should still be blocked
- 21+ should still succeed
- **NEW: Logs should show OAuth validation**

### Step 5: Verify OAuth Validation in Logs

1. **Check function logs** (same as Test 4)

2. **Verify logs NOW show:**
   ```
   [OAuth] Validation ENABLED - validating token
   [OAuth] Validating token from issuer: https://login.microsoftonline.com/a82813af-1054-4e2d-a8ec-c6b9c2908c91/v2.0
   [OAuth] Token validated successfully
   [OAuth] Token subject: <service-principal-id>
   [OAuth] Service principal app ID: <app-id>
   [OAuth] Token validated - proceeding with age verification
   User age calculated: X years
   User is 21+ (age: X), allowing signup with age_verified claim
   ```

---

## ✅ Phase 2 Success Criteria

Check all that apply:

- [ ] OAuth validation logs show "Token validated successfully"
- [ ] Service principal app ID logged
- [ ] Token issuer matches your tenant ID
- [ ] Under-21 signup still blocked
- [ ] 21+ signup still succeeds
- [ ] No authentication errors

**If all boxes checked → Production Ready! 🎉**

---

## 🚨 Troubleshooting

### Issue: OAuth Validation Fails After Enabling

**Symptoms:**
- Signup fails with "Authentication failed" message
- Logs show: "[OAuth] Token validation failed"

**Solution 1: Verify Custom Authentication Extension**

1. Navigate to:
   ```
   Azure Portal → Microsoft Entra ID → External Identities
   → Custom authentication extensions
   ```

2. Verify "Age Verification" extension exists

3. Click on it and verify:
   - Event type: **OnAttributeCollectionSubmit** (NOT AttributeCollectionStart)
   - Target URL: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
   - Authentication: App registration exists

**Solution 2: Temporarily Disable OAuth**

If needed to isolate the issue:

```bash
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings "ENABLE_OAUTH_VALIDATION=false"

az functionapp restart \
  --name func-mba-fresh \
  --resource-group rg-mba-prod
```

---

### Issue: "Something went wrong" Returns

**Most Likely Cause:** Function app needs time to warm up after restart

**Solutions:**
1. Wait 2-3 minutes after restart
2. Try signup again
3. Check Application Insights for timeout errors:
   ```bash
   az monitor app-insights query \
     --app func-mba-fresh \
     --resource-group rg-mba-prod \
     --analytics-query "exceptions | where timestamp > ago(30m)"
   ```

---

### Issue: Accounts Not Appearing in Tenant

**Debugging Steps:**

1. **Check Audit Logs:**
   ```
   Azure Portal → Microsoft Entra ID → Audit logs
   Filter: Activity = "Add user"
   Date range: Last hour
   ```

2. **Verify User Flow Configuration:**
   ```
   Azure Portal → External Identities → User flows
   → mba-signin-signup → Custom authentication extensions
   Should show: "Age Verification" on OnAttributeCollectionSubmit event
   ```

3. **Check if birthdate attribute is in the signup form:**
   ```
   User flows → mba-signin-signup → Page layouts
   → Local account sign up page
   Verify: birthdate attribute is ✅ Show and ✅ Required
   ```

---

## 📊 Current Configuration

**Your Tenant:**
- Name: mybartenderai
- Tenant ID: a82813af-1054-4e2d-a8ec-c6b9c2908c91
- Domain: mybartenderai.onmicrosoft.com
- Login URL: https://mybartenderai.ciamlogin.com

**Function App:**
- Name: func-mba-fresh
- Resource Group: rg-mba-prod
- Endpoint: https://func-mba-fresh.azurewebsites.net/api/validate-age
- OAuth Validation: DISABLED (Phase 1) → Enable for Phase 2

**Custom Authentication Extension:**
- Name: Age Verification (verify this exists)
- Event Type: OnAttributeCollectionSubmit
- Target: validate-age function
- Authentication: OAuth 2.0 Bearer tokens

---

## 📞 Next Steps After Testing

### If Phase 1 Succeeds:
1. ✅ Content-Type header fix has resolved the issue!
2. → Proceed to Phase 2 (Enable OAuth validation)
3. → Test with OAuth enabled
4. → Implement audit logging (Priority 3)

### If Phase 1 Fails:
1. Share the error message you see
2. Check function logs (Test 4 steps)
3. Share Application Insights errors
4. I'll help debug the issue

### When Both Phases Complete:
1. ✅ Age verification working correctly
2. ✅ OAuth security enabled
3. → Implement audit logging for COPPA/GDPR compliance
4. → Configure mobile app with Entra authentication
5. → Test complete flow: Mobile → Entra → APIM → Functions

---

## 🎯 Ready to Test!

**Start with Test 1** (Under-21 signup) using your signup URL above.

**Report back:**
- ✅ What works
- ❌ What doesn't work
- 📋 Any error messages you see

**Good luck!** 🎉
