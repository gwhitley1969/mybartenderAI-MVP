# Cocktail Sharing Feature

## Overview

The cocktail sharing feature allows users to share cocktail recipes from the My AI Bartender app to social media platforms. When shared, the link displays a rich preview with Open Graph tags that show the cocktail image, name, and description. On an Android phone with the app installed, the link opens the cocktail in the app.

## Architecture

### URL Structure

Share URLs use the custom domain with the `/cocktail/{id}` path:
```
https://share.mybartenderai.com/cocktail/{cocktailId}
```

Example: `https://share.mybartenderai.com/cocktail/17005`

Builds up to v1.2.1 shared `https://share.mybartenderai.com/api/cocktail/{cocktailId}`. Both paths serve the same preview page, and the app opens both. The app builds the URL in one place: `cocktailShareUrl()` in `mobile/app/lib/src/utils/cocktail_links.dart`.

> **Rollout (October 2026):** Front Door `route-cocktail` has served `/cocktail/{id}` since October 18, 2026, and the preview page with the Open button and the canonical `og:url` has been live since October 20, 2026. The app shares `/cocktail/{id}` from v1.2.2 (built October 20, 2026; store release pending); installed builds up to v1.2.1 still share `/api/cocktail/{id}`, which serves the same page. See [Rollout](#rollout-shared-links-open-the-app).

### Request Flow

```
share.mybartenderai.com/cocktail/{id}      share.mybartenderai.com/api/cocktail/{id}
    │ Front Door route-cocktail                │ Front Door route-api
    │ /cocktail/* → og-apim                    │ /api/* → og-apim
    │ origin path /api/cocktail                │ (no origin path)
    └───────────────────┬──────────────────────┘
                        ▼
Azure API Management (apim-mba-002): /api/cocktail/{id}
    │ API mybartenderai-api, operation cocktail-preview (GET /cocktail/{id})
    │ Backend: func-mba-fresh
    ▼
Azure Function (cocktail-preview)
    │ Queries PostgreSQL for cocktail data
    ▼
Returns HTML with Open Graph tags
```

Front Door Standard **replaces** the part of the path matched by the route pattern with the route's origin path: `/cocktail/17005` reaches APIM as `/api/cocktail/17005`. `route-well-known` works the same way (`/.well-known/*` → origin path `/api/.well-known`).

### Components

1. **Mobile App**
   - `services/recipe_card_share_service.dart`: share sheet text and image (custom cocktails get no URL: they don't exist on the server)
   - `utils/cocktail_links.dart`: the share URL, and the mapping of incoming links to the `/cocktail/:id` route
   - `android/app/src/main/AndroidManifest.xml`: App Link filter for `https://share.mybartenderai.com` paths `/cocktail/` and `/api/cocktail/`, plus the `mybartender://cocktail` custom scheme

2. **Azure Front Door** (`fd-mba-share`)
   - Custom domain: `share.mybartenderai.com`
   - `route-cocktail` (`/cocktail/*`) and `route-api` (`/api/*`) send preview requests to APIM

3. **Azure API Management** (`apim-mba-002`)
   - API `mybartenderai-api` (path `api`), operation `cocktail-preview`: `GET /cocktail/{id}`, no JWT (social crawlers must read it)
   - Routes to Azure Function backend

4. **Azure Function** (`cocktail-preview/index.js`)
   - Queries PostgreSQL for cocktail details
   - Generates HTML page with Open Graph meta tags
   - Shows an "Open in My AI Bartender" button on phones

## Implementation Details

### Mobile App Share Function

Location: `mobile/app/lib/src/services/recipe_card_share_service.dart` (called from the Share button in `cocktail_detail_screen.dart`)

The share sheet gets a rendered recipe card image plus text: the cocktail name, `cocktailShareUrl(cocktail.id)` for standard cocktails, and the Play Store link.

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
<meta property="og:url" content="https://share.mybartenderai.com/cocktail/12345">
<meta property="og:type" content="article">
<meta property="og:site_name" content="My AI Bartender">
```

`og:url` names the canonical `/cocktail/{id}` link even when the page was opened through `/api/cocktail/{id}`.

### Opening the App

**Android App Links.** The manifest's `autoVerify` intent filter claims `https://share.mybartenderai.com` with the path prefixes `/cocktail/` and `/api/cocktail/` (the second from v1.2.2, so links shared by older builds open the app too). A tapped link opens the app directly only once Android has verified the domain, which needs `https://share.mybartenderai.com/.well-known/assetlinks.json` (Front Door `route-well-known` → APIM → `well-known-assetlinks` function) to list the key the installed build is signed with. It lists one SHA-256 fingerprint, the Play App Signing key (confirmed in Play Console on October 18, 2026), so only Play-installed builds verify; debug and sideloaded upload-key builds don't.

**iOS.** No Universal Links yet: the app has no Associated Domains entitlement and the domain serves no `apple-app-site-association`. A tapped link opens the preview page in Safari.

**Preview page button.** When the page shows on a phone anyway (no app, iOS, an in-app browser that ignores App Links, an unverified install), it offers **Open in My AI Bartender**. Browsers only open an app from a user's tap, so the page never tries on its own:

- Android: `intent://share.mybartenderai.com/cocktail/{id}#Intent;scheme=https;package=ai.mybartender.mybartenderai;S.browser_fallback_url=<Play Store URL>;end`. Android filters links by verified domain only when the intent names no package, so this opens every build since February 2026 (when the `share.mybartenderai.com` App Link was added), verified or not. Without the app, Chrome goes to the Play Store.
- iOS: `mybartender:///cocktail/{id}`. With no host the URI path is `/cocktail/{id}`, which every app version routes. Safari asks before opening the app, and shows an error if the app isn't installed. `al:ios:url` uses the same link.

Before October 2026 the page tried a hidden `mybartender://` iframe from a `<head>` script. It never worked: `document.body` is null there, so the script threw before creating the iframe, and browsers don't open apps without a user gesture anyway.

**Inside the app.** Android and iOS hand the whole link to Flutter, and GoRouter matches routes on the URI path alone. `cocktailDeepLinkRedirect()` (the first step of the router's `redirect` in `main.dart`) maps the link forms the routes can't match:

| Incoming link | Path GoRouter sees | Result |
|---|---|---|
| `https://share.mybartenderai.com/cocktail/17005` | `/cocktail/17005` | matches `/cocktail/:id` |
| `https://share.mybartenderai.com/api/cocktail/17005` | `/api/cocktail/17005` | mapped to `/cocktail/17005` |
| `mybartender://cocktail/17005` | `/17005` | mapped to `/cocktail/17005` |
| `mybartender:///cocktail/17005` | `/cocktail/17005` | matches `/cocktail/:id` |

Without the mapping (v1.2.1 and earlier) the second and third forms show GoRouter's "Page Not Found".

A link replaces the navigation stack, so the detail screen is the only page. Its back arrow pops when it can and otherwise goes home (popping the only page left a blank screen). As for notification taps, `/cocktail/:id` skips the age and sign-in redirects but not the subscription gate for signed-in users.

## Rollout: Shared Links Open the App

Status on October 20, 2026: steps 1, 3 and 4 done, and step 5's Android bundle is built; the store releases and the device check remain. The order changed on October 20: Gene chose to ship this branch in v1.2.2 together with the Flutter 3.47.7 upgrade, so both platforms release the same code from `main`. Each step with Gene's OK:

1. **App Links verification** (done, BUG-014 in `docs/BUG_FIXES.md`): `route-well-known` origin path `/api/.well-known`, applied October 18, 2026. At 15:52 UTC `https://share.mybartenderai.com/.well-known/assetlinks.json` returned 200 and Google's checker listed the app's statement:
   ```
   https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://share.mybartenderai.com&relation=delegate_permission/common.handle_all_urls
   ```
2. **iOS v1.2.2+36 first** (superseded October 20, 2026): the plan was to release v1.2.2 from `main` before this branch merged, so both platforms would ship the same code. Instead the branch merged first (PR #7), the Android bundle was rebuilt from `main`, and both platforms ship it in v1.2.2.
3. **Front Door `route-cocktail`** (done): created October 18, 2026 at 19:29 UTC with the command below and live at the edge from 19:51 UTC. It matches `route-api` in every setting except the pattern and origin path, and the other four routes were unchanged. Checked at 19:51 UTC: `/cocktail/17005` 200 (A True Amaretto Sour, five tries), `/cocktail/11007` 200 (Margarita), an unknown id gets the function's 404 page, and `/api/cocktail/17005`, `/.well-known/assetlinks.json` and `/` answer as before. It could go before step 2 because it only replaces the static website's 404 for `/cocktail/*`. Same settings as `route-api`, caching off:
   ```bash
   az afd route create --subscription "My AI Bartender" -g rg-mba-prod --profile-name fd-mba-share --endpoint-name mba-share --route-name route-cocktail --patterns-to-match "[/cocktail/*]" --origin-group og-apim --origin-path "/api/cocktail" --formatted-custom-domains "[{id:/subscriptions/a30b74bc-d8dd-4564-8356-2269a68a9e18/resourceGroups/rg-mba-prod/providers/Microsoft.Cdn/profiles/fd-mba-share/customDomains/share-mybartenderai-com}]" --supported-protocols "[Https]" --forwarding-protocol HttpsOnly --https-redirect Enabled --link-to-default-domain Enabled --enabled-state Enabled
   ```
   Verify (allow time for Front Door to propagate): `curl -s https://share.mybartenderai.com/cocktail/17005` returns 200 with `<title>A True Amaretto Sour - My AI Bartender</title>`.
   Rollback: `az afd route delete --subscription "My AI Bartender" -g rg-mba-prod --profile-name fd-mba-share --endpoint-name mba-share --route-name route-cocktail --yes`
4. **Merge, then deploy the backend** (done): merged to `main` by PR #7 (`68400c9`) on October 20, 2026; `cocktail-preview` (Open button, canonical `og:url`) deployed at 17:18 UTC, package `20261020171645.zip`. `/cocktail/17005` and `/api/cocktail/17005` serve the new page with `og:url` `https://share.mybartenderai.com/cocktail/17005`. Needed step 3 too: otherwise Facebook scrapes the `og:url` and gets the 404 page.
5. **App release v1.2.2+36** (share URL, App Link paths, link mapping, back arrow), together with the Flutter 3.47.7 upgrade: Android bundle built from `main` on October 20, 2026 after a sideloaded test on Gene's phone; Play upload and the iOS build pending. Needs step 3: otherwise people without the app get the 404 page. The upgrade's regression pass covers the link handling.
6. **Device check** on a Play-installed v1.2.2 (Play signs with the key `assetlinks.json` lists):
   ```bash
   adb shell pm get-app-links ai.mybartender.mybartenderai
   adb shell pm verify-app-links --re-verify ai.mybartender.mybartenderai
   adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://share.mybartenderai.com/cocktail/17005"
   adb shell am start -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d "https://share.mybartenderai.com/api/cocktail/17005"
   adb shell am start -a android.intent.action.VIEW -d "mybartender://cocktail/17005"
   ```
   `get-app-links` should show `share.mybartenderai.com: verified` (wait a few minutes after `--re-verify`). Each `am start` should open the cocktail screen, and its back arrow should go home.

## APIM Configuration

### Operation Details

- **API**: `mybartenderai-api` (path `api`) on apim-mba-002
- **Operation ID**: `cocktail-preview`
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
**Solution**: Show content first; open the app only from the user's tap on the Open button

### Issue: Redirect to Google Play "Not Found"
**Cause**: Automatic redirect to app store before app is published
**Solution**: Remove automatic app store redirects, show preview page with manual buttons

### Issue: 404 from APIM
**Cause**: Operation not configured or wrong APIM instance
**Solution**: Verify operation exists on correct APIM (apim-mba-002, not apim-mba-001)

### Issue: Shared link opens the browser, not the app (Android)
**Cause**: The domain isn't verified for the installed app, or the link's path isn't claimed by the App Link filter. Up to v1.2.1 the app shared `/api/cocktail/{id}` while the filter claimed only `/cocktail`, so shared links never opened the app.
**Solution**: Check `adb shell pm get-app-links ai.mybartender.mybartenderai` and the asset links file (Rollout step 1). A link opened in another app's built-in browser may stay there; the page's Open button covers that case.

### Issue: App opens on "Page Not Found"
**Cause**: GoRouter matches the URI path only, so `mybartender://cocktail/{id}` (path `/{id}`) and `/api/cocktail/{id}` match no route in builds up to v1.2.1.
**Solution**: `cocktailDeepLinkRedirect()` maps them to `/cocktail/:id`.

### Testing Layers

Test each layer individually to isolate issues:

1. **Function Direct**:
   ```
   https://func-mba-fresh.azurewebsites.net/api/cocktail/17005
   ```

2. **APIM Direct**:
   ```
   https://apim-mba-002.azure-api.net/api/cocktail/17005
   ```

3. **Front Door**:
   ```
   https://share.mybartenderai.com/cocktail/17005
   https://share.mybartenderai.com/api/cocktail/17005
   ```

Automated tests: `backend/functions/cocktail-preview/index.test.js` (Jest: Open button links, `og:url`), `mobile/app/test/utils/cocktail_links_test.dart` (share URL, link mapping, links delivered through GoRouter) and `mobile/app/test/features/recipe_vault/cocktail_detail_screen_test.dart` (back arrow on a linked cocktail).

## Files Modified

| File | Purpose |
|------|---------|
| `mobile/app/lib/src/services/recipe_card_share_service.dart` | Share sheet text and recipe card image |
| `mobile/app/lib/src/utils/cocktail_links.dart` | Share URL; incoming link mapping |
| `mobile/app/lib/main.dart` | Router `redirect` applies the link mapping first |
| `mobile/app/lib/src/features/recipe_vault/cocktail_detail_screen.dart` | Share button; back arrow on a linked cocktail |
| `mobile/app/android/app/src/main/AndroidManifest.xml` | App Link and custom scheme intent filters |
| `backend/functions/cocktail-preview/index.js` | HTML generation with OG tags and the Open button |
| `backend/functions/cocktail-preview/function.json` | Function route binding |

## Enhanced Preview Page (December 2025)

### Background

User feedback requested that the shared link preview page show the full recipe card (like in the app) instead of just a minimal preview with cocktail image and name.

### Before Enhancement

The original preview page showed:
- Circular cocktail image
- Cocktail name with emoji
- Category label
- Brief description (instructions truncated)
- "Get the App" buttons

### After Enhancement

The enhanced preview page now displays a full recipe card matching the app's design:

```
┌─────────────────────────────────────┐
│      [Full-width Cocktail Image]    │
├─────────────────────────────────────┤
│  Cocktail Name                      │
│  [Cocktail] [Alcoholic] [Glass]     │
│                                     │
│  Ingredients                        │
│  ┌─────────────────────────────┐    │
│  │ • Vodka              1 oz   │    │
│  │ • Peach schnapps     1 oz   │    │
│  │ • Orange juice       3 oz   │    │
│  │ • Cranberry juice    3 oz   │    │
│  └─────────────────────────────┘    │
│                                     │
│  Instructions                       │
│  ┌─────────────────────────────┐    │
│  │ Shaken, not stirred!        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Get My AI Bartender...      │    │
│  │ [Google Play] [App Store]   │    │
│  └─────────────────────────────┘    │
│                                     │
│     Shared from My AI Bartender     │
└─────────────────────────────────────┘
```

### Implementation Changes

**File**: `backend/functions/cocktail-preview/index.js`

1. **Added ingredients HTML generation**:
```javascript
const ingredientsHtml = cocktail.ingredients && cocktail.ingredients.length > 0
    ? cocktail.ingredients.map(ing => `
        <div class="ingredient-row">
            <span class="ingredient-dot"></span>
            <span class="ingredient-name">${escapeHtml(ing.name || '')}</span>
            <span class="ingredient-measure">${escapeHtml(ing.measure || '')}</span>
        </div>`).join('')
    : '<p class="no-ingredients">No ingredients listed</p>';
```

2. **Added tags generation** (category, alcoholic, glass type):
```javascript
const tags = [];
if (cocktail.category) tags.push(cocktail.category);
tags.push('Alcoholic');
if (cocktail.glass) tags.push(cocktail.glass);
const tagsHtml = tags.map(tag => `<span class="tag">${escapeHtml(tag)}</span>`).join('');
```

3. **Redesigned HTML template** with:
   - Full-width hero image (not circular)
   - Colored tag badges (purple, pink, blue)
   - Ingredients card with purple gradient background
   - Instructions card
   - App promo section
   - Dark theme (#0d0d1a background) matching the app

4. **CSS styling** includes:
   - Responsive design (mobile and desktop)
   - Purple accent colors (#8b5cf6) matching app theme
   - Gradient backgrounds for cards
   - Flexbox layout for ingredients

### Data Already Available

No database changes were needed. The PostgreSQL query already retrieved:
- `category` (e.g., "Cocktail")
- `glass` (e.g., "Collins glass")
- `instructions` (full text)
- `ingredients` array with `name` and `measure`

### Testing

Test URL: `https://share.mybartenderai.com/api/cocktail/16943` (A Gilligan's Island)

### Image Display Fix (December 1, 2025)

**Issue**: The hero image was using `object-fit: cover` which zoomed in too much, cutting off the cocktail garnishes and glass shape. Users could only see a close-up of the drink color.

**Solution**: Changed to `object-fit: contain` so the full cocktail image is always visible.

```css
/* Before */
.hero-image {
    width: 100%;
    height: 280px;
    object-fit: cover;
    display: block;
}

/* After */
.hero-image {
    width: 100%;
    max-height: 350px;
    object-fit: contain;
    display: block;
    background: linear-gradient(180deg, #1a1a2e 0%, #0d0d1a 100%);
    padding: 1rem 0;
}
```

**Changes**:
- `object-fit: contain` - Shows entire image without cropping
- `max-height` instead of fixed `height` - Allows image to size naturally
- Gradient background - Blends with dark theme if image doesn't fill full width
- Padding - Gives image breathing room

---

## Date Resolved

- **Initial sharing fix**: November 30, 2025
- **Enhanced preview page**: December 1, 2025
- **Shared links open the app**: code and Front Door `route-cocktail` October 18, 2026; backend deployed October 20, 2026; ships in v1.2.2 (store release pending) (see [Rollout](#rollout-shared-links-open-the-app))

## Key Learnings

1. **Use correct APIM instance** - Production uses `apim-mba-002` (BasicV2), not `apim-mba-001` (Developer)
2. **Keep the share path and the App Link path the same** - Moving shares to the existing `/api/*` route (November 2025) avoided a Front Door route but left the URL outside the App Link filter, so shared links never opened the app
3. **Open apps from a tap** - Browsers ignore app launches without a user gesture; the old hidden-iframe attempt also ran before `<body>` existed
4. **Show content first** - Never hide page content waiting for redirects
5. **Data availability** - Check what data is already being queried before assuming backend changes are needed
6. **Match app design** - Use same color palette and styling for brand consistency
7. **GoRouter routes on the path** - A custom-scheme link's host isn't part of the route; map such links in the router's `redirect`
