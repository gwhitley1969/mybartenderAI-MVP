# APIM Developer Portal Setup Guide

**Date:** 2025-10-24
**APIM Instance:** apim-mba-001
**Developer Portal URL:** https://apim-mba-001.developer.azure-api.net

---

## Overview

The APIM Developer Portal provides:
- Self-service API key provisioning
- Interactive API documentation
- API testing console
- Subscription management (Free/Premium/Pro tiers)
- Usage analytics for developers

---

## Prerequisites

- Azure Portal access to `apim-mba-001`
- Administrator permissions on APIM instance
- Understanding of the three subscription tiers (Free, Premium, Pro)

---

## Step 1: Access the Developer Portal Admin Interface

### 1.1 Navigate to APIM in Azure Portal

1. Go to **Azure Portal**: https://portal.azure.com
2. Search for **API Management** → Select **apim-mba-001**
3. In the left menu, click **Developer portal** → **Portal overview**

### 1.2 Access the Administrative Interface

1. Click **"Developer portal"** in the top menu
2. You'll see two options:
   - **"Visit published portal"** - What end users see
   - **"Administrative interface"** - Where you customize the portal

3. Click **"Administrative interface"** to open the portal editor

---

## Step 2: Publish the Developer Portal

The Developer Portal comes with a default template but must be published to be accessible to users.

### 2.1 Initial Publishing

1. In the administrative interface, click **"Publish"** in the top-right corner
2. Confirm the publication
3. Wait for the publishing process to complete (~30 seconds)

### 2.2 Verify Portal is Live

1. Click **"Visit published portal"** or navigate to: https://apim-mba-001.developer.azure-api.net
2. You should see the default APIM Developer Portal homepage
3. If not accessible, wait a few minutes and try again (DNS propagation)

---

## Step 3: Configure Signup and Authentication

### 3.1 Enable User Signup

1. In Azure Portal, go to **apim-mba-001**
2. Click **Identities** in the left menu
3. Verify settings:
   - **Username and password**: Enabled (default)
   - **Azure Active Directory**: Optional (can add later for enterprise users)
   - **Azure AD B2C**: Disabled (we're using Entra External ID at API level)

### 3.2 Configure Email Templates

1. Click **Notifications** in the left menu
2. Review and customize these email templates:
   - **New developer account** - Welcome email
   - **New subscription** - Confirmation email
   - **Subscription request** - Approval notification
   - **Password reset** - Self-service password reset

### 3.3 Configure User Approval Settings

1. In Azure Portal → **apim-mba-001** → **Users**
2. Click **Settings** tab
3. Configure:
   - **Require administrator approval for new users**: Choose based on your preference
     - **Recommended for MVP**: ✅ **Enabled** (manual approval for quality control)
     - **Production**: Disabled (automatic approval for better UX)

---

## Step 4: Configure Product Visibility

### 4.1 Make Products Visible in Developer Portal

For each product (Free, Premium, Pro):

1. Go to **Products** in the left menu
2. Click on the product (e.g., **"Free"**)
3. Click **Settings** tab
4. Verify/Configure:
   - **Published**: ✅ Checked
   - **Requires subscription**: ✅ Checked
   - **Requires approval**:
     - **Free**: Unchecked (auto-approve)
     - **Premium**: ✅ Checked (manual approval)
     - **Pro**: ✅ Checked (manual approval)
   - **Subscription limit**:
     - **Free**: 1 subscription per user
     - **Premium**: 1 subscription per user
     - **Pro**: 1 subscription per user
   - **Visible in Developer Portal**: ✅ Checked

5. Click **Save**

### 4.2 Verify API is Assigned to Products

1. For each product, click the **APIs** tab
2. Ensure **MyBartenderAI API** is listed
3. If not, click **+ Add** and select the API

---

## Step 5: Configure API Documentation

### 5.1 Review OpenAPI Spec Import

1. Go to **APIs** in the left menu
2. Click **MyBartenderAI API**
3. Click **Settings** tab
4. Verify:
   - **Display name**: MyBartenderAI API
   - **Description**: Well-documented description
   - **Version**: v1
   - **Products**: Free, Premium, Pro (all selected)

### 5.2 Test Interactive API Console

1. In the Developer Portal (user view), navigate to the API
2. Click on an operation (e.g., **GET /v1/snapshots/latest**)
3. Click **"Try it"**
4. Verify the interactive console loads with:
   - Request parameters
   - Headers (including Ocp-Apim-Subscription-Key)
   - Example responses

---

## Step 6: Customize Developer Portal Branding (Optional)

### 6.1 Customize Homepage

1. Open **Administrative interface**
2. Click on the homepage content
3. Edit text to include:
   - MyBartenderAI branding
   - Brief description of the API
   - Links to documentation
4. Click **Publish** to save changes

### 6.2 Add Custom Styling

1. In administrative interface, click **Styling**
2. Customize:
   - **Colors**: Match MyBartenderAI brand colors
   - **Logo**: Upload custom logo
   - **Fonts**: Choose appropriate typography
3. Click **Publish** to apply changes

### 6.3 Configure Menu and Navigation

1. Click **Navigation** in the administrative interface
2. Organize menu items:
   - **APIs** - Main API documentation
   - **Products** - Subscription tiers
   - **FAQ** - Common questions
   - **Contact** - Support information
3. Click **Publish**

---

## Step 7: Test the Developer Portal Workflow

### 7.1 Test User Signup

1. Open an **Incognito/Private browser window**
2. Navigate to: https://apim-mba-001.developer.azure-api.net
3. Click **Sign up**
4. Create a test account:
   - Email: Use a test email address
   - Username: testuser01
   - Password: (Strong password)
5. Complete signup
6. Check email for confirmation link
7. Confirm the account

### 7.2 Test Subscription Request (Free Tier)

1. Log in to the Developer Portal as test user
2. Navigate to **Products** → **Free**
3. Click **Subscribe**
4. Enter subscription name: "Test Free Subscription"
5. Click **Subscribe**
6. Verify:
   - Subscription created successfully
   - API key displayed (Primary and Secondary keys)
   - Subscription appears in **Profile** → **Subscriptions**

### 7.3 Test API Call with Subscription Key

1. In Developer Portal, navigate to **APIs** → **MyBartenderAI API**
2. Click on **GET /v1/snapshots/latest**
3. Click **"Try it"**
4. Ensure **Subscription** is selected (should auto-populate)
5. Click **Send**
6. Verify response (should be 200 OK or appropriate response from backend)

### 7.4 Test Premium/Pro Subscription Approval Flow

1. As test user, navigate to **Products** → **Premium**
2. Click **Subscribe**
3. Enter subscription name: "Test Premium Subscription"
4. Click **Subscribe**
5. Verify message: "Subscription request pending approval"

**As Administrator:**
1. Go to Azure Portal → **apim-mba-001** → **Subscriptions**
2. Find the pending subscription
3. Click on it
4. Click **Activate** or **Reject**
5. Test user should receive email notification

---

## Step 8: Configure Subscription Management

### 8.1 Set Subscription Limits

For production, you may want to limit subscriptions:

1. Go to **Products** → Select a product
2. Click **Subscriptions** tab
3. Review active subscriptions
4. Configure limits in **Settings**:
   - **Subscription count limit**: 1 per user (recommended)
   - **Lifetime in days**: Blank (unlimited for paid tiers)
   - **Grace period**: 7 days (for payment failures)

### 8.2 Monitor Subscription Usage

1. Go to **Subscriptions** in the left menu
2. View all active subscriptions across all products
3. Use filters to find:
   - Subscriptions by product
   - Subscriptions by user
   - Pending subscriptions (requiring approval)

---

## Step 9: Configure Developer Portal Settings

### 9.1 CORS Configuration

If your mobile app needs to call the Developer Portal API:

1. Go to **Developer portal** → **Portal overview**
2. Click **CORS** settings
3. Add allowed origins:
   - `https://apim-mba-001.developer.azure-api.net` (default)
   - Add mobile app domains if needed

### 9.2 Delegation (Advanced - Optional)

For integrating with external user management:

1. Go to **Developer portal** → **Delegation**
2. Configure delegation endpoints for:
   - User signup/signin delegation
   - Subscription delegation
3. This allows you to handle user management in your own system

**For MVP**: Skip delegation, use built-in user management

---

## Step 10: Document Access for Team

### 10.1 Developer Portal URLs

| Purpose | URL |
|---------|-----|
| Public Developer Portal | https://apim-mba-001.developer.azure-api.net |
| Administrative Interface | https://apim-mba-001.developer.azure-api.net/admin |
| API Gateway | https://apim-mba-001.azure-api.net |
| Management API | https://apim-mba-001.management.azure-api.net |

### 10.2 Test Subscription Keys

Create test subscriptions for development:

**Free Tier Test Key:**
- Product: Free
- User: Create "dev-test-free@mybartenderai.com"
- Purpose: Testing Free tier rate limits

**Premium Tier Test Key:**
- Product: Premium
- User: Create "dev-test-premium@mybartenderai.com"
- Purpose: Testing Premium tier features

**Pro Tier Test Key:**
- Product: Pro
- User: Create "dev-test-pro@mybartenderai.com"
- Purpose: Testing Pro tier features

---

## Verification Checklist

After completing setup, verify:

- ✅ Developer Portal is published and accessible
- ✅ Users can sign up (with or without approval)
- ✅ All three products (Free/Premium/Pro) are visible
- ✅ Free tier subscriptions auto-approve
- ✅ Premium/Pro tier subscriptions require approval
- ✅ API documentation is visible and accurate
- ✅ Interactive API console works ("Try it" feature)
- ✅ Subscription keys are displayed to users
- ✅ Email notifications are sent for signup/subscriptions
- ✅ Rate limiting is enforced per product tier

---

## Common Issues and Solutions

### Issue 1: Developer Portal Not Accessible

**Symptom**: 404 or "Portal not found"

**Solution**:
1. Verify portal is published (Step 2)
2. Wait 5-10 minutes for DNS propagation
3. Check APIM service status in Azure Portal
4. Try accessing from different network (DNS cache)

### Issue 2: Users Can't Sign Up

**Symptom**: Signup button missing or errors

**Solution**:
1. Check **Identities** → "Username and password" is enabled
2. Verify email templates are configured
3. Check if admin approval is blocking (disable temporarily for testing)

### Issue 3: Subscription Keys Not Working

**Symptom**: 401 Unauthorized even with valid key

**Solution**:
1. Verify subscription is **Active** (not pending)
2. Check product is **Published**
3. Verify API is assigned to the product
4. Ensure correct header: `Ocp-Apim-Subscription-Key: {key}`

### Issue 4: Premium/Pro Operations Return 401

**Symptom**: JWT validation error even with subscription key

**Solution**:
- This is expected! Premium/Pro operations require **both**:
  1. APIM subscription key (`Ocp-Apim-Subscription-Key` header)
  2. JWT token (`Authorization: Bearer {token}` header)
- Subscription key authorizes the app, JWT authorizes the user

---

## Next Steps

1. ✅ Publish Developer Portal
2. ✅ Configure product visibility and approval settings
3. ✅ Test signup and subscription flow
4. ⬜ Create test subscriptions for each tier
5. ⬜ Test rate limiting enforcement
6. ⬜ Document subscription key provisioning for mobile app
7. ⬜ Integrate Developer Portal signup with mobile app onboarding

---

## Security Considerations

### API Key Security

- **Primary and Secondary Keys**: Users get both; rotate without downtime
- **Key Regeneration**: Can be done at any time in Developer Portal or Azure Portal
- **Key Scope**: Scoped to product, not individual APIs

### JWT + Subscription Key

For Premium/Pro tiers:
1. **Subscription Key**: Identifies the mobile app installation
2. **JWT Token**: Identifies the authenticated user
3. Both required for Premium/Pro operations (JWT validation policy)

### Best Practices

- Limit subscription count to 1 per user per product
- Require approval for paid tiers (Premium/Pro)
- Auto-approve Free tier for better UX
- Monitor subscription usage in Analytics
- Rotate test keys regularly
- Never share admin subscription keys publicly

---

## References

- **Azure APIM Developer Portal Docs**: https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-developer-portal
- **Customization Guide**: https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-developer-portal-customize
- **Authentication Options**: https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-aad

---

**Status**: Ready for configuration
**Estimated Setup Time**: 30-45 minutes
**Testing Time**: 15-20 minutes
