# Google Play Billing Setup Guide

> ## ⚠️ SUPERSEDED as of v1.2.1+35 (Jul 27, 2026)
>
> **Steps 1-4, 6 and 7 (service account, Google Play Developer API, Key Vault secret) no longer apply.** The `in_app_purchase` plugin was removed for Google Play Billing 8 compliance, so Android voice-minute purchases no longer use server-side token verification through the `voice-purchase` function. Both platforms now go through the RevenueCat SDK, and the `NON_RENEWING_PURCHASE` webhook credits the minutes.
>
> **Still relevant:** [Step 5](#step-5-create-in-app-product) — the `voice_minutes_60` product must exist and be Active in Google Play Console, and be mapped in the RevenueCat Play Store catalog (see `REVENUECAT_PLAN.md` §1C / §3A).
>
> The `voice-purchase` function and the `GOOGLE-PLAY-SERVICE-ACCOUNT-KEY` Key Vault secret remain deployed as a rollback path but are unused. Do not delete them without first reverting the billing change.
>
> See `SUBSCRIPTION_DEPLOYMENT.md` for the current flow.

This guide covers the setup that *was* required for server-side verification of voice minute purchases.

## Overview

The voice minute purchase flow (historical):
1. User purchases `voice_minutes_60` ($3.99) in the app
2. Google Play processes payment and returns a `purchaseToken`
3. App sends token to backend: `POST /v1/voice/purchase`
4. Backend verifies token with Google Play Developer API
5. Backend acknowledges purchase and credits 60 minutes

**Note:** The `voice_minutes_20` / 60-minute mismatch described here was resolved in `REVENUECAT_PLAN.md` Phase 5A — `voice-purchase/index.js` now uses `PRODUCT_ID = 'voice_minutes_60'` and credits 60 minutes. Moot as of v1.2.1+35 since the endpoint is no longer called; the `NON_RENEWING_PURCHASE` webhook handler is the only crediting path and has always credited 60.
6. Existing `check_voice_quota()` function includes addon minutes automatically

## Prerequisites

- Google Play Developer account ($25 one-time fee)
- App published to at least Internal Testing track
- Access to Google Cloud Console

---

## Step 1: Create Google Cloud Project (if needed)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Note the **Project ID** for later

---

## Step 2: Enable Google Play Developer API

1. In Google Cloud Console, go to **APIs & Services > Library**
2. Search for "Google Play Android Developer API"
3. Click **Enable**

---

## Step 3: Create Service Account

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > Service Account**
3. Fill in:
   - **Service account name**: `mybartenderai-play-billing`
   - **Service account ID**: (auto-generated)
   - **Description**: "Server-side purchase verification for MyBartenderAI"
4. Click **Create and Continue**
5. Skip the optional role assignment (click **Continue**)
6. Click **Done**

### Generate JSON Key

1. Click on the newly created service account
2. Go to **Keys** tab
3. Click **Add Key > Create new key**
4. Select **JSON** format
5. Click **Create**
6. **Save the downloaded JSON file securely** - you'll need it for Azure

---

## Step 4: Link Service Account to Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to **Settings > API access** (left sidebar, under Setup)
3. If prompted, link to your Google Cloud project
4. Under **Service accounts**, find your service account
5. Click **Grant access**
6. Set permissions:
   - **App permissions**: Select "MyBartenderAI"
   - **Account permissions**:
     - ✅ View financial data, orders, and cancellation survey responses
     - ✅ Manage orders and subscriptions
7. Click **Invite user**
8. Accept the invitation (check email or refresh page)

---

## Step 5: Create In-App Product

1. In Google Play Console, select your app
2. Go to **Monetization > In-app products**
3. Click **Create product**
4. Fill in:

| Field | Value |
|-------|-------|
| Product ID | `voice_minutes_60` |
| Name | 60 Voice Minutes |
| Description | Add 60 minutes to your voice AI balance. Minutes never expire! |
| Default price | $3.99 USD |
| Product type | Consumable (one-time purchase) |

5. Click **Save**
6. Click **Activate** to make it available

### Set Prices for Other Countries (Optional)

1. Click on the product
2. Go to **Manage prices**
3. Set local prices or use auto-conversion

---

## Step 6: Add Service Account Key to Azure

### Option A: Via Azure Key Vault (Recommended)

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Key Vault > kv-mybartenderai-prod**
3. Go to **Secrets > Generate/Import**
4. Fill in:
   - **Name**: `GOOGLE-PLAY-SERVICE-ACCOUNT-KEY`
   - **Value**: Paste the entire contents of the downloaded JSON file
5. Click **Create**

6. Add Key Vault reference to Function App:
```bash
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings "GOOGLE_PLAY_SERVICE_ACCOUNT_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/GOOGLE-PLAY-SERVICE-ACCOUNT-KEY/)"
```

### Option B: Direct App Setting (Not Recommended for Production)

```bash
# Only for testing - use Key Vault for production
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings "GOOGLE_PLAY_SERVICE_ACCOUNT_KEY=$(cat service-account.json)"
```

---

## Step 7: Verify Setup

### Test API Access

```bash
# Get access token using service account
gcloud auth activate-service-account --key-file=service-account.json
gcloud auth print-access-token

# Or test from your backend logs after a test purchase
```

### Test Purchase Flow

1. Add a tester account in Google Play Console:
   - Go to **Settings > License testing**
   - Add your test email address

2. Install the app from Internal Testing track

3. Make a test purchase (won't be charged)

4. Check Azure Function logs:
```bash
az functionapp logs tail --name func-mba-fresh --resource-group rg-mba-prod
```

---

## Service Account JSON Structure

The JSON key file looks like this (keep it secure!):

```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "abc123...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "mybartenderai-play-billing@your-project.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/..."
}
```

---

## Troubleshooting

### "Purchase verification not configured"
- `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` environment variable is missing
- Check Function App settings in Azure Portal

### "Google Play authentication failed" (401/403)
- Service account doesn't have API access
- Check Google Play Console > Settings > API access
- Ensure the service account has correct permissions

### "Purchase not found" (404)
- Invalid purchase token
- Product ID mismatch (`voice_minutes_10`)
- Package name mismatch (`ai.mybartender.mybartenderai`)

### "Purchase was canceled or refunded"
- User canceled during checkout
- Purchase was refunded through Play Store

---

## Security Notes

1. **Never commit the JSON key file to git**
2. **Use Key Vault** for production deployments
3. **Rotate keys periodically** via Google Cloud Console
4. **Monitor API usage** in Google Cloud Console

---

## Related Files

- Backend function: `backend/functions/index.js` (lines 2997-3241, voice-purchase)
- Flutter service: `mobile/app/lib/src/services/purchase_service.dart`
- Flutter provider: `mobile/app/lib/src/providers/purchase_provider.dart`
- Database table: `voice_addon_purchases` (migration 006)
- Quota function: `check_voice_quota()` (migration 006)

---

## Quick Reference

| Item | Value |
|------|-------|
| Package Name | `ai.mybartender.mybartenderai` |
| Product ID | `voice_minutes_60` |
| Price | $3.99 USD |
| Minutes Added | 60 |
| API Endpoint | `POST /v1/voice/purchase` |
| Function App Setting | `GOOGLE_PLAY_SERVICE_ACCOUNT_KEY` |
| Key Vault Secret | `GOOGLE-PLAY-SERVICE-ACCOUNT-KEY` |
