# Friends via Code - Static HTML Template Examples

## Overview

This document provides complete HTML templates for the static website hosted on Azure Blob Storage ($web container) at share.mybartender.ai. These templates handle recipe share previews and friend invitations with responsive design and social media integration.

## Azure Blob Storage Configuration

### Static Website Setup
```bash
# Enable static website hosting
az storage blob service-properties update \
  --account-name mbacocktaildb3 \
  --static-website \
  --index-document index.html \
  --404-document 404.html

# Set CORS rules
az storage cors add \
  --services b \
  --methods GET OPTIONS \
  --origins "https://share.mybartender.ai" \
  --allowed-headers "*" \
  --exposed-headers "*" \
  --max-age 3600 \
  --account-name mbacocktaildb3

# Upload templates
az storage blob upload-batch \
  --source ./static-templates \
  --destination '$web' \
  --account-name mbacocktaildb3
```

## 1. Recipe Share Preview Template

**File**: `recipe-share.html`
**URL Pattern**: `https://share.mybartender.ai/{shareCode}`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{recipeName}} - My AI Bartender</title>

    <!-- Open Graph Tags for Social Media -->
    <meta property="og:type" content="website">
    <meta property="og:title" content="{{recipeName}} - Shared by {{sharer}}">
    <meta property="og:description" content="{{recipeDescription}}">
    <meta property="og:image" content="{{recipeImageUrl}}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:url" content="https://share.mybartender.ai/{{shareCode}}">
    <meta property="og:site_name" content="My AI Bartender">

    <!-- Twitter Card Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="{{recipeName}} - My AI Bartender">
    <meta name="twitter:description" content="{{recipeDescription}}">
    <meta name="twitter:image" content="{{recipeImageUrl}}">
    <meta name="twitter:creator" content="@mybartenderai">

    <!-- App Links for Deep Linking -->
    <meta property="al:android:package" content="com.mybartender.ai">
    <meta property="al:android:url" content="mybartender://recipe/{{recipeId}}">
    <meta property="al:android:app_name" content="My AI Bartender">
    <meta property="al:ios:url" content="mybartender://recipe/{{recipeId}}">
    <meta property="al:ios:app_store_id" content="1234567890">
    <meta property="al:ios:app_name" content="My AI Bartender">

    <!-- Favicon -->
    <link rel="icon" type="image/png" href="/favicon.png">

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container {
            max-width: 480px;
            width: 100%;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
            animation: slideUp 0.5s ease-out;
        }

        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(20px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }

        .recipe-image {
            width: 100%;
            height: 280px;
            object-fit: cover;
            background: linear-gradient(to bottom, transparent, rgba(0,0,0,0.3));
        }

        .content {
            padding: 30px;
        }

        .share-badge {
            display: inline-block;
            background: #FF00FF;
            color: white;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 15px;
        }

        .recipe-name {
            font-size: 28px;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 10px;
        }

        .sharer-info {
            display: flex;
            align-items: center;
            margin-bottom: 20px;
            padding-bottom: 20px;
            border-bottom: 1px solid #e0e0e0;
        }

        .sharer-avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: linear-gradient(135deg, #667eea, #764ba2);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 600;
            margin-right: 12px;
        }

        .sharer-details {
            flex: 1;
        }

        .sharer-name {
            font-weight: 600;
            color: #1a1a1a;
            font-size: 14px;
        }

        .sharer-alias {
            color: #00D4FF;
            font-size: 13px;
        }

        .custom-message {
            background: #f5f5f5;
            border-left: 3px solid #FF00FF;
            padding: 15px;
            margin-bottom: 25px;
            border-radius: 5px;
            font-style: italic;
            color: #555;
        }

        .recipe-details {
            margin-bottom: 25px;
        }

        .detail-section {
            margin-bottom: 20px;
        }

        .detail-title {
            font-size: 12px;
            font-weight: 600;
            text-transform: uppercase;
            color: #888;
            letter-spacing: 0.5px;
            margin-bottom: 8px;
        }

        .ingredients-list {
            list-style: none;
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 8px;
        }

        .ingredient-item {
            display: flex;
            align-items: center;
            font-size: 14px;
            color: #333;
        }

        .ingredient-item::before {
            content: '•';
            color: #FF00FF;
            font-weight: bold;
            margin-right: 8px;
        }

        .instructions {
            line-height: 1.6;
            color: #333;
            font-size: 14px;
        }

        .cta-section {
            background: linear-gradient(135deg, #FF00FF, #00D4FF);
            padding: 25px;
            border-radius: 15px;
            text-align: center;
            color: white;
            margin-bottom: 20px;
        }

        .cta-title {
            font-size: 20px;
            font-weight: 700;
            margin-bottom: 10px;
        }

        .cta-subtitle {
            font-size: 14px;
            opacity: 0.9;
            margin-bottom: 20px;
        }

        .app-buttons {
            display: flex;
            gap: 12px;
            justify-content: center;
            flex-wrap: wrap;
        }

        .app-button {
            display: inline-flex;
            align-items: center;
            padding: 12px 20px;
            background: white;
            color: #1a1a1a;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
            font-size: 14px;
            transition: transform 0.2s;
        }

        .app-button:hover {
            transform: scale(1.05);
        }

        .app-button img {
            width: 20px;
            height: 20px;
            margin-right: 8px;
        }

        .share-actions {
            display: flex;
            justify-content: center;
            gap: 15px;
            margin-top: 20px;
        }

        .share-button {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            width: 48px;
            height: 48px;
            border-radius: 50%;
            background: #f5f5f5;
            text-decoration: none;
            transition: all 0.3s;
        }

        .share-button:hover {
            background: #e0e0e0;
            transform: scale(1.1);
        }

        .share-button svg {
            width: 24px;
            height: 24px;
            fill: #666;
        }

        .footer {
            text-align: center;
            padding: 20px;
            color: #888;
            font-size: 12px;
        }

        .expire-notice {
            display: inline-flex;
            align-items: center;
            background: #fff3cd;
            color: #856404;
            padding: 8px 12px;
            border-radius: 5px;
            font-size: 12px;
            margin-top: 15px;
        }

        .expire-notice svg {
            width: 16px;
            height: 16px;
            margin-right: 6px;
        }

        @media (max-width: 480px) {
            .container {
                border-radius: 0;
                box-shadow: none;
            }

            .content {
                padding: 20px;
            }

            .recipe-name {
                font-size: 24px;
            }

            .ingredients-list {
                grid-template-columns: 1fr;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <img src="{{recipeImageUrl}}" alt="{{recipeName}}" class="recipe-image" onerror="this.src='/default-cocktail.jpg'">

        <div class="content">
            <span class="share-badge">Shared Recipe</span>

            <h1 class="recipe-name">{{recipeName}}</h1>

            <div class="sharer-info">
                <div class="sharer-avatar">{{sharerInitials}}</div>
                <div class="sharer-details">
                    <div class="sharer-name">{{sharerDisplayName}}</div>
                    <div class="sharer-alias">{{sharerAlias}}</div>
                </div>
            </div>

            {{#if customMessage}}
            <div class="custom-message">
                "{{customMessage}}"
            </div>
            {{/if}}

            <div class="recipe-details">
                <div class="detail-section">
                    <div class="detail-title">Ingredients</div>
                    <ul class="ingredients-list">
                        {{#each ingredients}}
                        <li class="ingredient-item">{{this}}</li>
                        {{/each}}
                    </ul>
                </div>

                <div class="detail-section">
                    <div class="detail-title">Instructions</div>
                    <div class="instructions">{{instructions}}</div>
                </div>
            </div>

            <div class="cta-section">
                <div class="cta-title">Create Your Perfect Cocktail</div>
                <div class="cta-subtitle">Join {{sharerDisplayName}} on My AI Bartender</div>

                <div class="app-buttons">
                    <a href="https://play.google.com/store/apps/details?id=com.mybartender.ai" class="app-button" onclick="trackClick('google_play')">
                        <img src="/icons/google-play.svg" alt="Google Play">
                        Google Play
                    </a>
                    <a href="https://apps.apple.com/app/my-ai-bartender/id1234567890" class="app-button" onclick="trackClick('app_store')">
                        <img src="/icons/app-store.svg" alt="App Store">
                        App Store
                    </a>
                </div>
            </div>

            <div class="share-actions">
                <a href="https://www.facebook.com/sharer/sharer.php?u={{shareUrl}}" class="share-button" target="_blank" onclick="trackShare('facebook')">
                    <svg viewBox="0 0 24 24"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
                </a>
                <a href="https://twitter.com/intent/tweet?text={{tweetText}}&url={{shareUrl}}" class="share-button" target="_blank" onclick="trackShare('twitter')">
                    <svg viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg>
                </a>
                <a href="whatsapp://send?text={{whatsappText}}" class="share-button" onclick="trackShare('whatsapp')">
                    <svg viewBox="0 0 24 24"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.149-.67.149-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414-.074-.123-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413Z"/></svg>
                </a>
                <button class="share-button" onclick="copyToClipboard()">
                    <svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>
                </button>
            </div>

            <div style="text-align: center;">
                <div class="expire-notice">
                    <svg viewBox="0 0 24 24"><path d="M11 17a1 1 0 001.447.894l4-2A1 1 0 0017 15V9.236a1 1 0 00-1.447-.894l-4 2a1 1 0 00-.553.894V17zM15.211 9.276L12 11.236V9.276l3.211-1.605v2.605zm-3.211 5.448v-2.605l3.211 1.605-3.211 1.605z"/><path d="M12 2C6.486 2 2 6.486 2 12s4.486 10 10 10 10-4.486 10-10S17.514 2 12 2zm0 18c-4.411 0-8-3.589-8-8s3.589-8 8-8 8 3.589 8 8-3.589 8-8 8z"/></svg>
                    Expires {{expiryDate}}
                </div>
            </div>
        </div>

        <div class="footer">
            <div>My AI Bartender © 2025</div>
            <div>Share Code: {{shareCode}}</div>
        </div>
    </div>

    <script>
        // Track page view
        fetch('/api/share/{{shareCode}}/view', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                source: 'web',
                userAgent: navigator.userAgent
            })
        });

        // Track clicks
        function trackClick(action) {
            fetch('/api/share/{{shareCode}}/click', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: action})
            });
        }

        // Track shares
        function trackShare(platform) {
            fetch('/api/share/{{shareCode}}/share', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({platform: platform})
            });
        }

        // Copy to clipboard
        function copyToClipboard() {
            const url = window.location.href;
            navigator.clipboard.writeText(url).then(() => {
                alert('Link copied to clipboard!');
                trackClick('copy_link');
            });
        }

        // App detection and redirect
        setTimeout(() => {
            const isAndroid = /Android/i.test(navigator.userAgent);
            const isIOS = /iPhone|iPad|iPod/i.test(navigator.userAgent);

            if (isAndroid || isIOS) {
                const appUrl = isAndroid
                    ? 'mybartender://recipe/{{recipeId}}'
                    : 'mybartender://recipe/{{recipeId}}';

                window.location = appUrl;

                setTimeout(() => {
                    if (document.hasFocus()) {
                        window.location = isAndroid
                            ? 'https://play.google.com/store/apps/details?id=com.mybartender.ai'
                            : 'https://apps.apple.com/app/my-ai-bartender/id1234567890';
                    }
                }, 2500);
            }
        }, 100);
    </script>
</body>
</html>
```

## 2. Friend Invite Preview Template

**File**: `invite.html`
**URL Pattern**: `https://share.mybartender.ai/invite/{inviteCode}`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>You're Invited! - My AI Bartender</title>

    <!-- Open Graph Tags -->
    <meta property="og:type" content="website">
    <meta property="og:title" content="{{senderName}} invited you to My AI Bartender">
    <meta property="og:description" content="Join me on My AI Bartender to discover and share amazing cocktail recipes!">
    <meta property="og:image" content="https://share.mybartender.ai/images/invite-og.jpg">
    <meta property="og:url" content="https://share.mybartender.ai/invite/{{inviteCode}}">

    <!-- Twitter Card Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="Join My AI Bartender">
    <meta name="twitter:description" content="{{senderName}} wants to share cocktail recipes with you">
    <meta name="twitter:image" content="https://share.mybartender.ai/images/invite-twitter.jpg">

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #FF00FF 0%, #00D4FF 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .invite-container {
            max-width: 420px;
            width: 100%;
            background: white;
            border-radius: 24px;
            padding: 40px;
            text-align: center;
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.2);
            animation: bounceIn 0.6s ease-out;
        }

        @keyframes bounceIn {
            0% {
                opacity: 0;
                transform: scale(0.9) translateY(20px);
            }
            60% {
                transform: scale(1.05) translateY(-5px);
            }
            100% {
                opacity: 1;
                transform: scale(1) translateY(0);
            }
        }

        .celebration-icon {
            font-size: 64px;
            margin-bottom: 20px;
            animation: shake 2s infinite;
        }

        @keyframes shake {
            0%, 100% { transform: rotate(0deg); }
            25% { transform: rotate(-10deg); }
            75% { transform: rotate(10deg); }
        }

        .invite-title {
            font-size: 28px;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 15px;
        }

        .sender-info {
            display: inline-flex;
            align-items: center;
            background: #f5f5f5;
            padding: 12px 20px;
            border-radius: 30px;
            margin-bottom: 20px;
        }

        .sender-avatar {
            width: 48px;
            height: 48px;
            border-radius: 50%;
            background: linear-gradient(135deg, #FF00FF, #00D4FF);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 700;
            font-size: 18px;
            margin-right: 12px;
        }

        .sender-text {
            text-align: left;
        }

        .sender-name {
            font-weight: 600;
            color: #1a1a1a;
            font-size: 16px;
        }

        .sender-alias {
            color: #00D4FF;
            font-size: 14px;
        }

        .invite-message {
            background: linear-gradient(135deg, #f5f5f5, #fafafa);
            border-radius: 12px;
            padding: 20px;
            margin: 25px 0;
            font-style: italic;
            color: #555;
            line-height: 1.5;
        }

        .features {
            margin: 30px 0;
        }

        .feature {
            display: flex;
            align-items: center;
            margin: 15px 0;
            text-align: left;
        }

        .feature-icon {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: linear-gradient(135deg, #FF00FF20, #00D4FF20);
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 15px;
            flex-shrink: 0;
        }

        .feature-text {
            flex: 1;
        }

        .feature-title {
            font-weight: 600;
            color: #1a1a1a;
            font-size: 14px;
        }

        .feature-desc {
            color: #888;
            font-size: 12px;
            margin-top: 2px;
        }

        .cta-button {
            display: block;
            width: 100%;
            padding: 16px;
            background: linear-gradient(135deg, #FF00FF, #00D4FF);
            color: white;
            text-decoration: none;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            margin: 20px 0;
            transition: transform 0.2s;
        }

        .cta-button:hover {
            transform: scale(1.05);
        }

        .app-links {
            display: flex;
            gap: 12px;
            margin: 20px 0;
        }

        .app-link {
            flex: 1;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 10px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            text-decoration: none;
            color: #1a1a1a;
            font-size: 12px;
            transition: background 0.2s;
        }

        .app-link:hover {
            background: #f5f5f5;
        }

        .app-link img {
            width: 20px;
            height: 20px;
            margin-right: 8px;
        }

        .expire-notice {
            display: inline-flex;
            align-items: center;
            color: #888;
            font-size: 12px;
            margin-top: 20px;
        }

        .expire-notice svg {
            width: 16px;
            height: 16px;
            margin-right: 6px;
            fill: #888;
        }

        @media (max-width: 480px) {
            .invite-container {
                border-radius: 0;
                padding: 30px 20px;
            }
        }
    </style>
</head>
<body>
    <div class="invite-container">
        <div class="celebration-icon">🎉</div>

        <h1 class="invite-title">You're Invited!</h1>

        <div class="sender-info">
            <div class="sender-avatar">{{senderInitials}}</div>
            <div class="sender-text">
                <div class="sender-name">{{senderDisplayName}}</div>
                <div class="sender-alias">{{senderAlias}}</div>
            </div>
        </div>

        {{#if inviteMessage}}
        <div class="invite-message">
            "{{inviteMessage}}"
        </div>
        {{else}}
        <div class="invite-message">
            "Let's discover and share amazing cocktail recipes together!"
        </div>
        {{/if}}

        <div class="features">
            <div class="feature">
                <div class="feature-icon">🍹</div>
                <div class="feature-text">
                    <div class="feature-title">Share Recipes</div>
                    <div class="feature-desc">Exchange your favorite cocktails</div>
                </div>
            </div>

            <div class="feature">
                <div class="feature-icon">🤖</div>
                <div class="feature-text">
                    <div class="feature-title">AI Bartender</div>
                    <div class="feature-desc">Get personalized recommendations</div>
                </div>
            </div>

            <div class="feature">
                <div class="feature-icon">📸</div>
                <div class="feature-text">
                    <div class="feature-title">Smart Scanner</div>
                    <div class="feature-desc">Inventory your bar with camera</div>
                </div>
            </div>
        </div>

        <a href="mybartender://invite/accept/{{inviteCode}}" class="cta-button" onclick="trackAccept()">
            Accept Invitation
        </a>

        <div class="app-links">
            <a href="https://play.google.com/store/apps/details?id=com.mybartender.ai" class="app-link">
                <img src="/icons/google-play.svg" alt="">
                Google Play
            </a>
            <a href="https://apps.apple.com/app/my-ai-bartender/id1234567890" class="app-link">
                <img src="/icons/app-store.svg" alt="">
                App Store
            </a>
        </div>

        <div class="expire-notice">
            <svg viewBox="0 0 24 24"><path d="M12 2C6.486 2 2 6.486 2 12s4.486 10 10 10 10-4.486 10-10S17.514 2 12 2zm0 18c-4.411 0-8-3.589-8-8s3.589-8 8-8 8 3.589 8 8-3.589 8-8 8z"/><path d="M13 7h-2v6l5.25 3.15.75-1.23-4-2.4z"/></svg>
            Expires in {{daysRemaining}} days
        </div>
    </div>

    <script>
        // Track invite view
        fetch('/api/invite/{{inviteCode}}/view', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
                source: 'web',
                userAgent: navigator.userAgent
            })
        });

        // Track accept click
        function trackAccept() {
            fetch('/api/invite/{{inviteCode}}/click', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({action: 'accept'})
            });

            // Try to open app, fallback to store
            setTimeout(() => {
                if (document.hasFocus()) {
                    const isAndroid = /Android/i.test(navigator.userAgent);
                    window.location = isAndroid
                        ? 'https://play.google.com/store/apps/details?id=com.mybartender.ai'
                        : 'https://apps.apple.com/app/my-ai-bartender/id1234567890';
                }
            }, 2500);
        }
    </script>
</body>
</html>
```

## 3. Landing Page Template

**File**: `index.html`
**URL**: `https://share.mybartender.ai/`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My AI Bartender - Your Personal Cocktail Expert</title>

    <meta property="og:title" content="My AI Bartender">
    <meta property="og:description" content="Discover, create, and share amazing cocktails with AI-powered recommendations">
    <meta property="og:image" content="https://share.mybartender.ai/images/hero-og.jpg">

    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #0a0a0a;
            color: white;
            overflow-x: hidden;
        }

        .hero {
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            background: radial-gradient(circle at center, #1a1a1a 0%, #0a0a0a 100%);
            position: relative;
            padding: 20px;
        }

        .hero::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: url('/images/cocktail-bg.jpg') center/cover;
            opacity: 0.1;
        }

        .hero-content {
            position: relative;
            z-index: 1;
            text-align: center;
            max-width: 600px;
        }

        .logo {
            width: 120px;
            height: 120px;
            margin-bottom: 30px;
            animation: float 3s ease-in-out infinite;
        }

        @keyframes float {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(-10px); }
        }

        .hero-title {
            font-size: 48px;
            font-weight: 800;
            background: linear-gradient(135deg, #FF00FF, #00D4FF);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 20px;
        }

        .hero-subtitle {
            font-size: 20px;
            color: #aaa;
            margin-bottom: 40px;
            line-height: 1.5;
        }

        .download-section {
            display: flex;
            gap: 20px;
            justify-content: center;
            margin-bottom: 40px;
        }

        .store-button {
            display: inline-block;
            transition: transform 0.2s;
        }

        .store-button:hover {
            transform: scale(1.05);
        }

        .store-button img {
            height: 50px;
        }

        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 30px;
            margin-top: 60px;
        }

        .feature-card {
            text-align: center;
        }

        .feature-icon {
            font-size: 48px;
            margin-bottom: 15px;
        }

        .feature-name {
            font-weight: 600;
            margin-bottom: 8px;
        }

        .feature-desc {
            font-size: 14px;
            color: #888;
        }

        @media (max-width: 640px) {
            .hero-title {
                font-size: 36px;
            }

            .hero-subtitle {
                font-size: 18px;
            }

            .download-section {
                flex-direction: column;
                align-items: center;
            }
        }
    </style>
</head>
<body>
    <div class="hero">
        <div class="hero-content">
            <img src="/images/logo.png" alt="My AI Bartender" class="logo">

            <h1 class="hero-title">My AI Bartender</h1>

            <p class="hero-subtitle">
                Your personal cocktail expert powered by AI.
                Discover recipes, scan your bar, and share with friends.
            </p>

            <div class="download-section">
                <a href="https://play.google.com/store/apps/details?id=com.mybartender.ai" class="store-button">
                    <img src="/images/google-play-badge.png" alt="Get it on Google Play">
                </a>
                <a href="https://apps.apple.com/app/my-ai-bartender/id1234567890" class="store-button">
                    <img src="/images/app-store-badge.png" alt="Download on the App Store">
                </a>
            </div>

            <div class="features-grid">
                <div class="feature-card">
                    <div class="feature-icon">🤖</div>
                    <div class="feature-name">AI Bartender</div>
                    <div class="feature-desc">Personalized recipes</div>
                </div>

                <div class="feature-card">
                    <div class="feature-icon">📸</div>
                    <div class="feature-name">Smart Scanner</div>
                    <div class="feature-desc">Inventory your bar</div>
                </div>

                <div class="feature-card">
                    <div class="feature-icon">👥</div>
                    <div class="feature-name">Social Sharing</div>
                    <div class="feature-desc">Share with friends</div>
                </div>

                <div class="feature-card">
                    <div class="feature-icon">🎨</div>
                    <div class="feature-name">Create Studio</div>
                    <div class="feature-desc">Design cocktails</div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
```

## 4. Error Page Template

**File**: `404.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - My AI Bartender</title>

    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .error-container {
            text-align: center;
            background: white;
            padding: 60px 40px;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 400px;
        }

        .error-icon {
            font-size: 80px;
            margin-bottom: 20px;
        }

        .error-title {
            font-size: 28px;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 10px;
        }

        .error-message {
            color: #666;
            margin-bottom: 30px;
        }

        .home-button {
            display: inline-block;
            padding: 12px 30px;
            background: linear-gradient(135deg, #FF00FF, #00D4FF);
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="error-container">
        <div class="error-icon">🍸</div>
        <h1 class="error-title">Oops! Page Not Found</h1>
        <p class="error-message">
            This cocktail recipe seems to have vanished.
            The link may be expired or incorrect.
        </p>
        <a href="/" class="home-button">Go to Homepage</a>
    </div>
</body>
</html>
```

## Azure Function for Template Rendering

**File**: `backend/functions/render-share/index.js`

```javascript
const { BlobServiceClient } = require('@azure/storage-blob');
const Handlebars = require('handlebars');

module.exports = async function (context, req) {
    const shareCode = context.bindingData.shareCode;

    try {
        // Get share details from database
        const shareDetails = await getShareDetails(shareCode);

        if (!shareDetails || shareDetails.expiresAt < new Date()) {
            // Serve 404 page
            const html = await getTemplate('404.html');
            context.res = {
                status: 404,
                headers: { 'Content-Type': 'text/html' },
                body: html
            };
            return;
        }

        // Get appropriate template
        const templateName = shareDetails.type === 'invite'
            ? 'invite.html'
            : 'recipe-share.html';

        const template = await getTemplate(templateName);
        const compiledTemplate = Handlebars.compile(template);

        // Prepare template data
        const templateData = {
            ...shareDetails,
            shareUrl: `https://share.mybartender.ai/${shareCode}`,
            tweetText: encodeURIComponent(`Check out this ${shareDetails.recipeName} recipe!`),
            whatsappText: encodeURIComponent(`${shareDetails.recipeName} - ${shareDetails.shareUrl}`),
            sharerInitials: getInitials(shareDetails.sharerDisplayName || shareDetails.sharerAlias),
            expiryDate: formatDate(shareDetails.expiresAt),
            daysRemaining: getDaysRemaining(shareDetails.expiresAt)
        };

        // Render HTML
        const html = compiledTemplate(templateData);

        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'text/html',
                'Cache-Control': 'public, max-age=3600'
            },
            body: html
        };

    } catch (error) {
        context.log.error('Error rendering share page:', error);

        // Serve error page
        const html = await getTemplate('404.html');
        context.res = {
            status: 500,
            headers: { 'Content-Type': 'text/html' },
            body: html
        };
    }
};

async function getTemplate(templateName) {
    const blobServiceClient = BlobServiceClient.fromConnectionString(
        process.env.STORAGE_CONNECTION_STRING
    );

    const containerClient = blobServiceClient.getContainerClient('$web');
    const blobClient = containerClient.getBlobClient(`templates/${templateName}`);

    const downloadResponse = await blobClient.download();
    return streamToString(downloadResponse.readableStreamBody);
}

function getInitials(name) {
    return name
        .split(/[\s-]+/)
        .map(word => word[0]?.toUpperCase())
        .join('')
        .slice(0, 2) || '??';
}

function getDaysRemaining(expiryDate) {
    const days = Math.ceil((expiryDate - new Date()) / (1000 * 60 * 60 * 24));
    return Math.max(0, days);
}
```

## CDN Configuration

```bash
# Create CDN profile
az cdn profile create \
  --name cdn-mybartender \
  --resource-group rg-mba-prod \
  --sku Standard_Microsoft

# Create CDN endpoint
az cdn endpoint create \
  --name share-mybartender \
  --profile-name cdn-mybartender \
  --resource-group rg-mba-prod \
  --origin mbacocktaildb3.blob.core.windows.net \
  --origin-host-header mbacocktaildb3.blob.core.windows.net \
  --origin-path /$web

# Add custom domain
az cdn custom-domain create \
  --endpoint-name share-mybartender \
  --profile-name cdn-mybartender \
  --resource-group rg-mba-prod \
  --name share \
  --hostname share.mybartender.ai

# Enable HTTPS
az cdn custom-domain enable-https \
  --endpoint-name share-mybartender \
  --profile-name cdn-mybartender \
  --resource-group rg-mba-prod \
  --name share
```

---

**Document Version**: 1.0
**Last Updated**: 2025-11-14
**Template Engine**: Handlebars
**Storage**: Azure Blob Storage Static Website