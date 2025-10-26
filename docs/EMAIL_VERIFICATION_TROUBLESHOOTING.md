# Email Verification Code Not Received - Troubleshooting

**Issue:** Stuck at "Enter code" screen, verification email not received
**Status:** This happens BEFORE age verification - different issue

---

## Quick Fixes (Try These First)

### 1. Check Spam/Junk Folder
- Check spam folder in vwhitley1967@gmail.com
- Look for sender: **Microsoft account team** or **no-reply@microsoft.com**
- Mark as "Not Spam" if found

### 2. Wait and Try Again
- Click "try again" link on the page
- Wait 5-10 minutes (Microsoft's email can be slow)
- Check spam folder again

### 3. Try Different Email Provider
- Use a different email (not Gmail)
- Try: Outlook.com, Yahoo, or ProtonMail
- Gmail sometimes blocks Microsoft verification emails

---

## Root Cause Analysis

The signup flow is:
```
1. Fill signup form (with birthdate)
2. Submit form
3. ↓
4. Email verification code sent ← YOU ARE STUCK HERE
5. Enter code
6. ↓
7. Age verification runs (our function)
8. Account created
```

**The issue:** Entra External ID's default email service is not sending emails reliably.

---

## Solution 1: Disable Email Verification (For Testing)

**RECOMMENDED for development/testing**

### Steps:

1. **Navigate to User Flow:**
   ```
   Azure Portal → Microsoft Entra ID → External Identities
   → User flows → mba-signin-signup
   ```

2. **Click "Page layouts" in left menu**

3. **Click "Email verification page"**

4. **Look for setting: "Require email verification"**
   - If enabled, **UNCHECK** it for testing
   - Click **Save**

5. **Try signup again** - should skip email verification

---

## Solution 2: Configure Custom Email Provider

**RECOMMENDED for production**

Entra External ID's default email is unreliable. Configure a custom email provider:

### Option A: Azure Communication Services (Recommended)

1. **Create Azure Communication Services:**
   ```bash
   az communication create \
     --name mba-communication \
     --resource-group rg-mba-prod \
     --location global \
     --data-location UnitedStates
   ```

2. **Get connection string:**
   ```bash
   az communication list-key \
     --name mba-communication \
     --resource-group rg-mba-prod \
     --query primaryConnectionString -o tsv
   ```

3. **Configure in Entra External ID:**
   ```
   Azure Portal → Microsoft Entra ID → External Identities
   → Company branding → Email customization
   Add Azure Communication Services connection string
   ```

### Option B: SendGrid (Alternative)

1. **Create free SendGrid account:**
   - https://sendgrid.com/
   - Free tier: 100 emails/day

2. **Get API key from SendGrid**

3. **Configure in Entra External ID:**
   ```
   Azure Portal → Microsoft Entra ID → External Identities
   → Company branding → Email customization
   Select "Custom email provider" → SendGrid
   Add API key
   ```

---

## Solution 3: Use Different Authentication Method

### Option: Skip Email Verification, Use Phone Instead

1. **Navigate to User Flow:**
   ```
   Azure Portal → External Identities → User flows → mba-signin-signup
   ```

2. **Click "Identity providers"**

3. **Add Phone authentication:**
   - Select "Phone number" as identity provider
   - Configure SMS provider (Twilio or Azure Communication Services)

4. **Update signup page:**
   - Page layouts → Local account sign up page
   - Change primary identifier from Email to Phone

---

## Solution 4: Check Entra Audit Logs

See if email send is failing:

```bash
# Check for email-related events
az monitor activity-log list \
  --resource-group rg-mba-prod \
  --start-time 2025-10-26T14:00:00Z \
  --query "[?contains(operationName.localizedValue, 'Email')]"
```

Or in Azure Portal:
```
Microsoft Entra ID → Audit logs
Filter: Activity = "Send email verification code"
Status: Success or Failed
```

---

## Solution 5: Test with Microsoft Account

**Quick test to isolate issue:**

1. Instead of creating new account, try:
   - "Sign in with Microsoft"
   - "Sign in with Google"

2. This bypasses email verification entirely

3. If this works, issue is definitely with email verification

---

## Immediate Action Plan

### For Testing (Right Now):

1. ✅ **Check spam folder** (vwhitley1967@gmail.com)
2. ✅ **Click "try again"** and wait 5 minutes
3. ✅ **Disable email verification in User Flow** (see Solution 1)
4. ✅ **Try signup again** - should skip email step

### For Production (After Testing):

1. ⬜ Configure Azure Communication Services (Solution 2A)
2. ⬜ Test email delivery with custom provider
3. ⬜ Re-enable email verification
4. ⬜ Test complete signup flow

---

## Quick Disable Email Verification

**Run these commands to disable email verification:**

```bash
# Note: This requires Azure AD PowerShell module
# These commands are for reference - use portal UI instead

# Portal method (RECOMMENDED):
# 1. Go to: External Identities → User flows → mba-signin-signup
# 2. Page layouts → Email verification page
# 3. Uncheck "Require email verification"
# 4. Save
```

---

## Alternative: Create Test User Manually

**Bypass signup entirely for testing:**

1. **Create user directly in Azure AD:**
   ```bash
   az ad user create \
     --display-name "Test User" \
     --user-principal-name testuser@mybartenderai.onmicrosoft.com \
     --password "TestPassword123!" \
     --force-change-password-next-sign-in false
   ```

2. **Add birthdate custom attribute manually** (if needed)

3. **Test sign-in** (not sign-up)

---

## Why This Happens

**Common causes:**
1. **Microsoft's default email service is slow/unreliable**
   - Free tier has low priority
   - Can take 30+ minutes
   - Sometimes emails never arrive

2. **Gmail blocks Microsoft verification emails**
   - Google's spam filter aggressive
   - Microsoft emails marked as spam
   - Need custom email provider

3. **Email verification not configured**
   - Default settings don't work for all scenarios
   - Need to configure custom SMTP or email provider

4. **Tenant configuration issue**
   - Email domain not verified
   - Sender domain mismatch

---

## Next Steps

### Immediate (5 minutes):
1. Check spam folder
2. Try "try again" link
3. Wait 10 minutes, check email again

### Short-term (30 minutes):
1. Disable email verification in User Flow
2. Test signup without email verification
3. Verify age verification works (our function)

### Long-term (Production):
1. Set up Azure Communication Services
2. Configure custom email provider
3. Re-enable email verification
4. Test complete flow

---

## Testing Age Verification Without Email

**You can still test age verification by:**

1. **Disabling email verification** (see Solution 1)
2. **Signup flow becomes:**
   ```
   Fill form → Age verification → Account created
   ```
3. **This lets us test what we actually fixed**

**The age verification function won't run until AFTER email is verified**, so we need to either:
- Fix email verification
- OR disable it for testing

---

## Status Update

**What we fixed:** Age verification (Content-Type headers, OAuth) ✅
**Current blocker:** Email verification (different issue) ⬜
**Next step:** Disable email verification to test age verification

---

## Commands to Check Current User Flow Settings

```bash
# List user flows
az rest --method GET \
  --uri "https://graph.microsoft.com/beta/identity/b2cUserFlows" \
  --query "value[].{id:id, displayName:displayName}"

# This will show if we can modify email verification settings via CLI
```

---

**Bottom Line:** The email verification issue is blocking us from testing the age verification fix. We should disable email verification for now to test the age verification function, then configure proper email delivery for production.
