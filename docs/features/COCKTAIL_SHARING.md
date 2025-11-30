# Cocktail Sharing Feature

## Overview

The cocktail sharing feature allows users to share cocktail recipes from the My AI Bartender app to social media platforms. When shared, the link displays a rich preview with Open Graph tags that show the cocktail image, name, and description.

## Architecture

### URL Structure

Share URLs use the custom domain with the `/api/cocktail/{id}` path:
```
https://share.mybartenderai.com/api/cocktail/{cocktailId}
```

Example: `https://share.mybartenderai.com/api/cocktail/17005`

### Request Flow

```
Mobile App Share Button
    │
    ▼
share.mybartenderai.com/api/cocktail/{id}
    │
    ▼
Azure Front Door (fd-mba-share)
    │ Route: /api/* → apim-mba-002
    ▼
Azure API Management (apim-mba-002)
    │ Operation: GET /cocktail/{id}
    │ Backend: func-mba-fresh
    ▼
Azure Function (cocktail-preview)
    │ Queries PostgreSQL for cocktail data
    ▼
Returns HTML with Open Graph tags
```

### Components

1. **Mobile App** (`cocktail_detail_screen.dart`)
   - Share button triggers native OS share sheet
   - Generates share URL and text

2. **Azure Front Door** (`fd-mba-share`)
   - Custom domain: `share.mybartenderai.com`
   - Routes `/api/*` to APIM backend

3. **Azure API Management** (`apim-mba-002`)
   - Operation: `GET /cocktail/{id}`
   - Routes to Azure Function backend

4. **Azure Function** (`cocktail-preview/index.js`)
   - Queries PostgreSQL for cocktail details
   - Generates HTML page with Open Graph meta tags
   - Includes smart deep link behavior

## Implementation Details

### Mobile App Share Function

Location: `mobile/app/lib/src/features/recipe_vault/cocktail_detail_screen.dart`

```dart
Future<void> _shareRecipe(BuildContext context, Cocktail cocktail) async {
  final shareUrl = 'https://share.mybartenderai.com/api/cocktail/${cocktail.id}';

  final shareText = '''
🍹 ${cocktail.name}

Check out this amazing cocktail recipe I found on My AI Bartender!

$description
''';

  await Share.shareWithResult(
    '$shareText\n$shareUrl',
    subject: '${cocktail.name} - My AI Bartender Recipe',
  );
}
```

### Cocktail Preview Function

Location: `backend/functions/cocktail-preview/index.js`

The function:
1. Extracts cocktail ID from URL path
2. Queries PostgreSQL `drinks` table with joined ingredients
3. Generates HTML page with:
   - Open Graph tags for social media previews
   - Twitter Card tags
   - Deep link meta tags for mobile apps
   - Visual preview page for browsers

### Open Graph Tags Generated

```html
<meta property="og:title" content="Cocktail Name - My AI Bartender">
<meta property="og:description" content="Recipe description...">
<meta property="og:image" content="https://mbacocktaildb3.blob.core.windows.net/...">
<meta property="og:url" content="https://share.mybartenderai.com/api/cocktail/12345">
<meta property="og:type" content="article">
<meta property="og:site_name" content="My AI Bartender">
```

### Smart Deep Link Behavior

The preview page includes JavaScript that:
1. **Always shows the cocktail preview** - image, name, description, app download buttons
2. **On mobile devices**: Attempts deep link via hidden iframe (opens app if installed)
3. **No automatic redirects** - user stays on the preview page

```javascript
(function() {
    const isMobile = /android|iPad|iPhone|iPod/i.test(navigator.userAgent);

    // Always show content
    document.querySelector('.loading').style.display = 'none';
    document.getElementById('install-prompt').style.display = 'block';

    if (isMobile) {
        // Try deep link without navigating away
        var iframe = document.createElement('iframe');
        iframe.style.display = 'none';
        iframe.src = "mybartender://cocktail/{id}";
        document.body.appendChild(iframe);
    }
})();
```

## APIM Configuration

### Operation Details

- **API**: cocktail-preview-api (on apim-mba-002)
- **Operation ID**: get-cocktail-preview
- **Method**: GET
- **URL Template**: `/cocktail/{id}`
- **Backend**: `https://func-mba-fresh.azurewebsites.net/api/cocktail/{id}`

### Policy

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service base-url="https://func-mba-fresh.azurewebsites.net/api" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
</policies>
```

## Troubleshooting

### Issue: Blank page on desktop
**Cause**: JavaScript immediately redirecting to deep link URL
**Solution**: Show content first, only attempt deep link on mobile via iframe

### Issue: Redirect to Google Play "Not Found"
**Cause**: Automatic redirect to app store before app is published
**Solution**: Remove automatic app store redirects, show preview page with manual buttons

### Issue: 404 from APIM
**Cause**: Operation not configured or wrong APIM instance
**Solution**: Verify operation exists on correct APIM (apim-mba-002, not apim-mba-001)

### Testing Layers

Test each layer individually to isolate issues:

1. **Function Direct**:
   ```
   https://func-mba-fresh.azurewebsites.net/api/cocktail/17005
   ```

2. **APIM Direct**:
   ```
   https://apim-mba-002.azure-api.net/cocktail/17005
   ```

3. **Front Door**:
   ```
   https://share.mybartenderai.com/api/cocktail/17005
   ```

## Files Modified

| File | Purpose |
|------|---------|
| `mobile/app/lib/src/features/recipe_vault/cocktail_detail_screen.dart` | Share button and URL generation |
| `backend/functions/cocktail-preview/index.js` | HTML generation with OG tags |
| `backend/functions/cocktail-preview/function.json` | Function route binding |

## Date Resolved

November 30, 2025

## Key Learnings

1. **Use correct APIM instance** - Production uses `apim-mba-002` (BasicV2), not `apim-mba-001` (Developer)
2. **Front Door routing** - Use existing `/api/*` route rather than complex URL rewriting
3. **Deep links on mobile** - Use iframe technique to attempt without navigating away
4. **Show content first** - Never hide page content waiting for redirects
