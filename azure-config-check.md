# Azure Configuration Checklist

## 1. Check Supported Account Types
**Navigate to**: App registrations → MyBartenderAI Mobile → Authentication

**Look for**: "Supported account types"
- [ ] Should be: "Accounts in any identity provider or organizational directory"
- [ ] NOT: "Accounts in this organizational directory only"

## 2. Check Identity Providers Status
**Navigate to**: External Identities → All identity providers

For EACH provider (Google, Facebook, Microsoft):
- [ ] Status should show "Enabled"
- [ ] Client credentials should be configured

## 3. Check User Flow Configuration
**Navigate to**: User flows → mba-signin-signup

- [ ] User flow should be "Running"
- [ ] Identity providers should all be selected
- [ ] Application should show "MyBartenderAI Mobile"

## 4. Test Different Redirect URI Format
In App Registration → Authentication → Mobile and desktop applications:

**Try adding this alternative redirect URI:**
```
msalf9f7f159-b847-4211-98c9-18e5b8193045://auth
```

This is the MSAL-specific format that might work better.

## 5. Check Implicit Grant Settings
In App Registration → Authentication:

Under "Implicit grant and hybrid flows":
- [ ] Try checking "ID tokens"
- [ ] Save changes

This might help with the redirect flow.