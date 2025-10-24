# Developer Portal Quick Start Guide

**Time Required:** 10-15 minutes
**Developer Portal URL:** https://apim-mba-001.developer.azure-api.net

---

## ✅ Pre-Configuration Complete

The following settings have been configured via Azure CLI:

- ✅ Products are published (Free, Premium, Pro)
- ✅ Free tier: Auto-approval enabled
- ✅ Premium tier: Manual approval required
- ✅ Pro tier: Manual approval required
- ✅ Developer Portal URL is active

---

## 🚀 Quick Start Steps

### Step 1: Publish the Developer Portal (5 minutes)

1. **Open Azure Portal**: https://portal.azure.com
2. Search for **"API Management"** → Select **"apim-mba-001"**
3. In the left menu, click **"Developer portal"** → **"Portal overview"**
4. Click the button **"Developer portal"** in the top menu bar
5. Select **"Administrative interface"**
6. In the administrative interface, click **"Publish"** button (top-right)
7. Confirm the publication
8. Wait ~30 seconds for publishing to complete

### Step 2: Verify Portal is Live (2 minutes)

1. Open a new browser tab
2. Navigate to: **https://apim-mba-001.developer.azure-api.net**
3. You should see the APIM Developer Portal homepage
4. Verify you can see:
   - **"Sign in"** and **"Sign up"** buttons
   - **"APIs"** menu item
   - **"Products"** menu item

### Step 3: Test Signup Flow (5 minutes)

1. **Open an Incognito/Private browsing window**
2. Navigate to: https://apim-mba-001.developer.azure-api.net
3. Click **"Sign up"**
4. Fill in the form:
   - **Email**: Use a test email you can access
   - **First name**: Test
   - **Last name**: User
   - **Username**: testuser01
   - **Password**: (Strong password, remember it!)
5. Click **"Sign up"**
6. Check your email for a confirmation link
7. Click the confirmation link
8. Log in with your credentials

### Step 4: Test Free Tier Subscription (3 minutes)

1. While logged in as test user, click **"Products"**
2. Click on **"Free Tier"**
3. Review the product details:
   - Rate limit: 100 API calls/day
   - Features: Snapshot downloads only
4. Click **"Subscribe"** button
5. Enter a subscription name: "My Free Subscription"
6. Click **"Subscribe"**
7. ✅ **Verify**: You should see:
   - **Primary key** (long alphanumeric string)
   - **Secondary key** (long alphanumeric string)
   - Subscription status: **Active**

### Step 5: Test API Call (5 minutes)

1. In the Developer Portal, click **"APIs"**
2. Click **"MyBartenderAI API"**
3. Click on the operation: **GET /v1/snapshots/latest**
4. Click **"Try it"** button
5. Ensure your subscription is selected in the dropdown
6. Click **"Send"** button
7. ✅ **Verify**: You should see a response (200 OK or appropriate backend response)

---

## 📋 Post-Setup Tasks

### Task 1: Test Premium Tier Approval Flow

1. As the test user, navigate to **"Products"** → **"Premium Tier ($4.99/month)"**
2. Click **"Subscribe"**
3. Enter subscription name: "My Premium Subscription"
4. Click **"Subscribe"**
5. ✅ **Verify**: You see message "Subscription request pending approval"

**As Administrator:**
1. Go to Azure Portal → **apim-mba-001** → **"Subscriptions"**
2. Find the pending subscription (filter by "Submitted" state)
3. Click on the subscription
4. Click **"Activate"** button
5. Test user should receive email notification

### Task 2: Create Developer Test Subscriptions

For development and testing, create dedicated subscriptions:

**Via Azure Portal:**
1. Go to **apim-mba-001** → **"Subscriptions"**
2. Click **"+ Add subscription"**
3. Configure:
   - **Name**: "Dev Test - Free Tier"
   - **Display name**: "Developer Testing - Free"
   - **Scope**: Product → Free Tier
   - **User**: (Optional - leave blank for service account)
4. Click **"Save"**
5. Copy the **Primary key** and **Secondary key**

Repeat for Premium and Pro tiers.

### Task 3: Hide Default APIM Products

The Developer Portal shows default "Starter" and "Unlimited" products. Hide them:

1. Go to **apim-mba-001** → **"Products"**
2. Click on **"Starter"**
3. Click **"Settings"** tab
4. **Uncheck** "Published"
5. Click **"Save"**

Repeat for "Unlimited" product.

---

## 🧪 Testing Checklist

Use this checklist to verify everything works:

### Developer Portal Publishing
- [ ] Portal is published and accessible at https://apim-mba-001.developer.azure-api.net
- [ ] Homepage loads without errors
- [ ] "Sign up" and "Sign in" buttons are visible
- [ ] "APIs" and "Products" menu items work

### User Signup
- [ ] User can sign up with email/password
- [ ] Confirmation email is sent
- [ ] Email confirmation link works
- [ ] User can log in after confirmation

### Free Tier Subscription
- [ ] Free tier is visible in Products list
- [ ] User can subscribe without approval
- [ ] Primary and Secondary keys are displayed
- [ ] Subscription status shows "Active"

### Premium/Pro Tier Subscription
- [ ] Premium tier requires approval (shows "pending")
- [ ] Pro tier requires approval (shows "pending")
- [ ] Administrator can see pending subscriptions
- [ ] Administrator can activate/reject subscriptions
- [ ] User receives email notification on activation

### API Testing
- [ ] APIs are listed in Developer Portal
- [ ] API operations are visible
- [ ] "Try it" button works
- [ ] Can select subscription key from dropdown
- [ ] Can send test requests
- [ ] Response is displayed (200 OK or appropriate)

### JWT-Protected Operations (Premium/Pro)
- [ ] askBartender operation shows in portal
- [ ] Without JWT token: Returns 401 Unauthorized
- [ ] With JWT token: Should work (requires mobile app auth)

---

## 🔑 Test Subscription Keys Reference

After creating test subscriptions, document them here:

### Free Tier Test Key
```
Primary Key: [Copy from Azure Portal]
Secondary Key: [Copy from Azure Portal]
Subscription ID: [Copy from Azure Portal]
```

### Premium Tier Test Key
```
Primary Key: [Copy from Azure Portal]
Secondary Key: [Copy from Azure Portal]
Subscription ID: [Copy from Azure Portal]
```

### Pro Tier Test Key
```
Primary Key: [Copy from Azure Portal]
Secondary Key: [Copy from Azure Portal]
Subscription ID: [Copy from Azure Portal]
```

---

## 🐛 Troubleshooting

### Portal Shows 404 Error

**Solution**: Wait 5-10 minutes after publishing. DNS propagation can take time. Try:
- Clear browser cache
- Use incognito mode
- Try from different network

### Signup Button Not Working

**Solution**:
1. Go to **apim-mba-001** → **"Identities"**
2. Ensure **"Username and password"** is enabled
3. Check **"Notifications"** are configured

### Subscription Keys Don't Work

**Solution**:
1. Verify subscription status is **"Active"** (not pending/suspended)
2. Check correct header: `Ocp-Apim-Subscription-Key: {your-key}`
3. Verify product is published
4. Verify API is assigned to the product

### Premium Operations Return 401

**Expected Behavior**: Premium/Pro operations require **both**:
1. Subscription key (in `Ocp-Apim-Subscription-Key` header)
2. JWT token (in `Authorization: Bearer {token}` header)

Without JWT, you'll get 401 - this is correct!

---

## 📚 Additional Resources

- **Full Setup Guide**: See `DEVELOPER_PORTAL_SETUP.md` for detailed configuration options
- **JWT Policy Guide**: See `JWT_POLICY_DEPLOYMENT_GUIDE.md` for authentication details
- **APIM Docs**: https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-developer-portal

---

## ✅ Success Criteria

You've successfully set up the Developer Portal when:

1. ✅ Portal is published and accessible
2. ✅ Users can sign up and get confirmation emails
3. ✅ Free tier subscriptions are auto-approved
4. ✅ Premium/Pro tier subscriptions require manual approval
5. ✅ Users can get subscription keys (Primary & Secondary)
6. ✅ API documentation is visible and accurate
7. ✅ "Try it" console works for public endpoints
8. ✅ JWT-protected endpoints return 401 (expected without JWT)

---

**Ready to proceed?** Follow the Quick Start steps above! ⬆️
