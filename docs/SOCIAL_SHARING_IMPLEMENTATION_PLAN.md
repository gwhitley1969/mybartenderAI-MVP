# Social Sharing Implementation Plan

**Feature**: Social Sharing for My AI Bartender
**Approach**: OS Native Share Sheet with Open Graph Tags
**Target Platforms**: iOS & Android (via Flutter)
**Created**: November 20, 2025
**For**: Implementation by Sonnet

---

## Executive Summary

Implement social sharing for cocktail recipes using the **OS native share sheet** as the primary mechanism, with excellent Open Graph tags for rich previews on Instagram and Facebook. This approach avoids OAuth complexity while delivering a familiar user experience.

---

## Core Architecture

### Primary Sharing Flow

```
1. User taps share button on cocktail detail screen
2. App generates shareable URL (https://fd-mba-share.azurefd.net/cocktail/{id})
3. Native OS share sheet opens
4. User selects Instagram, Facebook, or any other app
5. Social platform crawls URL and displays rich preview via OG tags
6. Recipients clicking the link are deep-linked into the app
```

### Key Design Decisions

- **No OAuth required** for basic sharing
- **Native OS experience** that users already understand
- **Open Graph tags** provide rich previews
- **Deep linking** brings users back to the app
- **Optional**: Direct API posting for future enhancements (e.g., Facebook pages)

---

## Implementation Steps

### Phase 1: Backend - Share Preview Pages

#### 1.1 Create Preview Page Function

**File**: `backend/functions/cocktail-preview/index.js`

```javascript
const { app } = require('@azure/functions');
const { getSnapshotData } = require('../shared/snapshot-service');

app.http('cocktail-preview', {
    methods: ['GET'],
    authLevel: 'anonymous',  // Public access for social crawlers
    route: 'v1/cocktails/{id}/preview',
    handler: async (request, context) => {
        const cocktailId = request.params.id;

        try {
            // Get cocktail from snapshot or database
            const cocktails = await getSnapshotData();
            const cocktail = cocktails.find(c => c.id === cocktailId);

            if (!cocktail) {
                return {
                    status: 404,
                    headers: { 'Content-Type': 'text/html' },
                    body: generateErrorPage('Cocktail not found')
                };
            }

            const html = generatePreviewPage(cocktail);

            return {
                status: 200,
                headers: {
                    'Content-Type': 'text/html',
                    'Cache-Control': 'public, max-age=300'  // Cache for 5 minutes
                },
                body: html
            };
        } catch (error) {
            context.error('Failed to generate preview', error);
            return {
                status: 500,
                headers: { 'Content-Type': 'text/html' },
                body: generateErrorPage('Unable to load cocktail')
            };
        }
    }
});

function generatePreviewPage(cocktail) {
    const shareUrl = `https://fd-mba-share.azurefd.net/cocktail/${cocktail.id}`;
    const imageUrl = cocktail.imageUrl || 'https://mbacocktaildb3.blob.core.windows.net/images/default-cocktail.jpg';
    const description = cocktail.description || `Discover how to make ${cocktail.name} with My AI Bartender`;

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${cocktail.name} - My AI Bartender</title>

    <!-- Open Graph Tags for Facebook -->
    <meta property="og:title" content="${cocktail.name} - My AI Bartender">
    <meta property="og:description" content="${description}">
    <meta property="og:image" content="${imageUrl}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:url" content="${shareUrl}">
    <meta property="og:type" content="article">
    <meta property="og:site_name" content="My AI Bartender">

    <!-- Twitter Card Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${cocktail.name}">
    <meta name="twitter:description" content="${description}">
    <meta name="twitter:image" content="${imageUrl}">

    <!-- Deep Linking for Mobile Apps -->
    <meta property="al:android:url" content="mybartender://cocktail/${cocktail.id}">
    <meta property="al:android:package" content="com.mybartenderai.app">
    <meta property="al:android:app_name" content="My AI Bartender">
    <meta property="al:ios:url" content="mybartender://cocktail/${cocktail.id}">
    <meta property="al:ios:app_store_id" content="YOUR_APP_STORE_ID">
    <meta property="al:ios:app_name" content="My AI Bartender">

    <!-- Fallback redirect -->
    <script>
        // Try to open the app
        window.location.href = "mybartender://cocktail/${cocktail.id}";

        // Fallback to app store after a delay
        setTimeout(function() {
            const userAgent = navigator.userAgent || navigator.vendor;
            if (/android/i.test(userAgent)) {
                window.location.href = "https://play.google.com/store/apps/details?id=com.mybartenderai.app";
            } else if (/iPad|iPhone|iPod/.test(userAgent)) {
                window.location.href = "https://apps.apple.com/app/idYOUR_APP_STORE_ID";
            }
        }, 1000);
    </script>

    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
        }
        .container {
            padding: 2rem;
        }
        h1 {
            font-size: 2rem;
            margin-bottom: 1rem;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🍹 ${cocktail.name}</h1>
        <p>Opening My AI Bartender...</p>
        <p style="font-size: 0.9rem; opacity: 0.7;">If the app doesn't open, you can download it from your app store.</p>
    </div>
</body>
</html>`;
}

function generateErrorPage(message) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My AI Bartender</title>
</head>
<body>
    <h1>My AI Bartender</h1>
    <p>${message}</p>
</body>
</html>`;
}

module.exports = app;
```

#### 1.2 Register Function in Main Index

**File**: `backend/functions/index.js` (ADD to existing v4 functions)

```javascript
// Add with other function registrations
require('./cocktail-preview');
```

#### 1.3 Configure APIM Route

**PowerShell Script**: `deploy-preview-endpoint.ps1`

```powershell
# Add cocktail preview operation to APIM
$apimContext = New-AzApiManagementContext -ResourceGroupName "rg-mba-prod" -ServiceName "apim-mba-002"

$operation = @{
    Context = $apimContext
    ApiId = "mybartenderai-api"
    OperationId = "get-cocktail-preview"
    Method = "GET"
    UrlTemplate = "/v1/cocktails/{id}/preview"
    DisplayName = "Get Cocktail Preview"
    Description = "Returns HTML preview page with Open Graph tags for social sharing"
}

New-AzApiManagementOperation @operation

# Set backend to Azure Functions
$backend = @{
    Context = $apimContext
    ApiId = "mybartenderai-api"
    OperationId = "get-cocktail-preview"
    PolicyContent = @"
<policies>
    <inbound>
        <base />
        <set-backend-service base-url="https://func-mba-fresh.azurewebsites.net/api" />
        <cache-lookup vary-by-developer="false" vary-by-developer-groups="false" must-revalidate="true" downstream-caching-type="public" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
        <cache-store duration="300" />
    </outbound>
</policies>
"@
}

Set-AzApiManagementPolicy @backend
```

---

### Phase 2: Mobile App - Native Share Integration

#### 2.1 Add Share Package

**File**: `mobile/app/pubspec.yaml`

```yaml
dependencies:
  # ... existing dependencies ...
  share_plus: ^7.2.1  # Native share functionality
```

#### 2.2 Update Cocktail Detail Screen

**File**: `mobile/app/lib/src/features/cocktails/presentation/cocktail_detail_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

class CocktailDetailScreen extends ConsumerWidget {
  final String cocktailId;

  const CocktailDetailScreen({
    Key? key,
    required this.cocktailId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cocktail = ref.watch(cocktailProvider(cocktailId));

    return Scaffold(
      appBar: AppBar(
        title: Text(cocktail.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareRecipe(context, cocktail),
          ),
        ],
      ),
      body: /* existing body */,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _shareRecipe(context, cocktail),
        label: const Text('Share Recipe'),
        icon: const Icon(Icons.share),
      ),
    );
  }

  Future<void> _shareRecipe(BuildContext context, Cocktail cocktail) async {
    // Generate share URL - this will be crawled for OG tags
    final shareUrl = 'https://fd-mba-share.azurefd.net/cocktail/${cocktail.id}';

    // Create share text
    final shareText = '''
🍹 ${cocktail.name}

Check out this amazing cocktail recipe I found on My AI Bartender!

${cocktail.shortDescription ?? 'A delicious cocktail you have to try.'}
''';

    try {
      final result = await Share.shareWithResult(
        '$shareText\n$shareUrl',
        subject: '${cocktail.name} - My AI Bartender Recipe',
      );

      // Track share event
      if (result.status == ShareResultStatus.success) {
        ref.read(analyticsProvider).logShare(
          contentType: 'cocktail',
          itemId: cocktail.id,
          method: result.raw ?? 'native_share',
        );

        // Optional: Show success feedback
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe shared successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Handle share errors gracefully
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to share recipe. Please try again.'),
          ),
        );
      }
    }
  }
}
```

#### 2.3 Configure Deep Linking

**File**: `mobile/app/lib/src/routing/app_router.dart`

```dart
// Add deep link handling for shared cocktails
GoRoute(
  path: '/cocktail/:id',
  builder: (context, state) {
    final cocktailId = state.pathParameters['id']!;
    return CocktailDetailScreen(cocktailId: cocktailId);
  },
),
```

**Android**: `mobile/app/android/app/src/main/AndroidManifest.xml`

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />

    <!-- Deep link for cocktails -->
    <data android:scheme="mybartender"
          android:host="cocktail" />

    <!-- App Links for web URLs -->
    <data android:scheme="https"
          android:host="fd-mba-share.azurefd.net"
          android:pathPrefix="/cocktail" />
</intent-filter>
```

**iOS**: `mobile/app/ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>mybartender</string>
        </array>
    </dict>
</array>
```

---

### Phase 3: Configuration & Constants

#### 3.1 Add Configuration Constants

**File**: `backend/functions/config/social.js`

```javascript
module.exports = {
  // Meta API Configuration
  META_GRAPH_VERSION: 'v19.0',

  // Share URLs
  SHARE_BASE_URL: process.env.SHARE_BASE_URL || 'https://fd-mba-share.azurefd.net',

  // App Store URLs
  ANDROID_STORE_URL: 'https://play.google.com/store/apps/details?id=com.mybartenderai.app',
  IOS_STORE_URL: 'https://apps.apple.com/app/idYOUR_APP_STORE_ID',

  // Future: Direct API posting credentials
  // META_FACEBOOK_APP_ID: process.env['META-FACEBOOK-APP-ID'],
  // META_FACEBOOK_APP_SECRET: process.env['META-FACEBOOK-APP-SECRET'],
};
```

---

## Testing Plan

### 1. Open Graph Tag Validation

```bash
# Test with Meta's Sharing Debugger
https://developers.facebook.com/tools/debug/
# Enter: https://fd-mba-share.azurefd.net/cocktail/test-cocktail-id

# Verify:
- [ ] Title displays correctly
- [ ] Description is present
- [ ] Image loads (1200x630 preferred)
- [ ] No warnings about missing required tags
```

### 2. Mobile Share Testing

**Android Testing:**

```bash
# Build and install debug APK
cd mobile/app
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk

# Test sharing to:
- [ ] Facebook app
- [ ] Instagram app
- [ ] WhatsApp
- [ ] Email
- [ ] SMS
```

**iOS Testing:**

```bash
# Build and run on iOS
cd mobile/app
flutter build ios --debug
flutter install

# Test sharing to:
- [ ] Facebook app
- [ ] Instagram app
- [ ] Messages
- [ ] Mail
- [ ] Notes
```

### 3. Deep Link Testing

```bash
# Android
adb shell am start -W -a android.intent.action.VIEW -d "mybartender://cocktail/margarita" com.mybartenderai.app

# iOS (Simulator)
xcrun simctl openurl booted "mybartender://cocktail/margarita"
```

### 4. End-to-End Scenarios

- [ ] Share cocktail → Facebook → Click link → Opens app at correct cocktail
- [ ] Share cocktail → Instagram Story → Swipe up → Opens app
- [ ] Share when app not installed → Redirects to app store
- [ ] Share with poor network → Graceful timeout
- [ ] Share very long cocktail name → Truncation works

---

## Deployment Checklist

### Week 1: Backend Setup

- [ ] Deploy cocktail-preview function (NOTE: Do Not Delete ANY existing functions)
- [ ] Configure APIM route for preview endpoint (NOTE: Do NOT Delete ANY existing operations)
- [ ] Set up Azure Front Door rules for /cocktail/* paths
- [ ] Test OG tags with Meta debugger
- [ ] Verify caching headers are set correctly

### Week 2: Mobile Integration

- [ ] Add share_plus package
- [ ] Implement share button on cocktail detail
- [ ] Configure deep linking for both platforms
- [ ] Test on physical devices
- [ ] Add analytics tracking

### Pre-Launch

- [ ] Replace YOUR_APP_STORE_ID with actual iOS app ID
- [ ] Update Android package name if different
- [ ] Test with production URLs
- [ ] Verify all images are accessible publicly
- [ ] Monitor for crawler traffic

---

## Future Enhancements (Phase 2)

**Optional Direct API Posting** (Not for initial release)

- Store Meta tokens in existing social tables
- Add "Share to Facebook Page" option for business users
- Post directly via Graph API with stored tokens
- Implement token refresh logic

**Analytics & Tracking**

- Track share button clicks vs actual shares
- Monitor which platforms users share to most
- Track deep link conversion rates
- A/B test different share text templates

---

## Important Notes

1. **Database**: Use existing social tables schema - do not modify
2. **APIM**: Using `apim-mba-002` (not apim-mba-001)
3. **Authentication**: Preview pages are public (no auth) for crawler access
4. **Images**: All cocktail images must be publicly accessible in blob storage
5. **Primary UX**: Native OS share sheet - familiar and requires no login

---

## Success Criteria

- [ ] Users can share any cocktail via native share sheet
- [ ] Shared links show rich previews on Facebook and Instagram
- [ ] Deep links open the app at the correct cocktail
- [ ] No OAuth or login required for basic sharing
- [ ] Analytics capture share events

---

## Support & Debugging

**Common Issues:**

1. **OG tags not showing**: Clear Facebook cache via Sharing Debugger
2. **Deep links not working**: Check app manifest/plist configuration
3. **Share sheet not opening**: Ensure share_plus is properly initialized
4. **Image not loading**: Verify blob storage allows public access

**Debug URLs:**

- Meta Sharing Debugger: https://developers.facebook.com/tools/debug/
- Test preview page: https://fd-mba-share.azurefd.net/cocktail/test
- APIM trace: Enable tracing in Azure Portal for debugging

---

**Document Version**: 1.0
**Last Updated**: November 20, 2025
**Implementation Target**: Sonnet
