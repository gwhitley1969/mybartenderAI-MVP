const { getPool } = require('../shared/db/postgresPool');

/**
 * cocktail-preview function
 * Generates HTML preview pages with Open Graph tags for social sharing
 * Route: GET /cocktail/{id}
 * URL: https://share.mybartenderai.com/cocktail/{id} (Front Door route-cocktail)
 *      https://share.mybartenderai.com/api/cocktail/{id} (route-api, links shared up to v1.2.2)
 */

async function getCocktailById(cocktailId) {
    const pool = getPool();

    // Query drink from PostgreSQL with ingredients joined
    // Table is 'drinks' not 'cocktails', using 'thumbnail' not 'image_url'
    const result = await pool.query(
        `SELECT
            d.id,
            d.name,
            d.category,
            d.glass,
            d.instructions,
            d.thumbnail,
            COALESCE(
                json_agg(
                    json_build_object('name', i.name, 'measure', m.measure)
                    ORDER BY i.position
                ) FILTER (WHERE i.name IS NOT NULL),
                '[]'::json
            ) as ingredients
         FROM drinks d
         LEFT JOIN ingredients i ON d.id = i.drink_id
         LEFT JOIN measures m ON d.id = m.drink_id AND i.position = m.position
         WHERE d.id = $1 OR LOWER(REPLACE(d.name, ' ', '-')) = LOWER($1)
         GROUP BY d.id, d.name, d.category, d.glass, d.instructions, d.thumbnail
         LIMIT 1`,
        [cocktailId]
    );

    if (result.rowCount === 0) {
        return null;
    }

    const row = result.rows[0];
    return {
        id: row.id,
        name: row.name,
        category: row.category,
        glass: row.glass,
        instructions: row.instructions,
        imageUrl: row.thumbnail,
        ingredients: row.ingredients
    };
}

function escapeHtml(text) {
    if (!text) return '';
    return text
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

function generateDescription(cocktail) {
    if (cocktail.instructions && cocktail.instructions.length > 0) {
        const description = cocktail.instructions.substring(0, 150);
        return description + (cocktail.instructions.length > 150 ? '...' : '');
    }

    if (cocktail.category) {
        return `A delicious ${cocktail.category.toLowerCase()} cocktail you have to try. Get the recipe on My AI Bartender!`;
    }

    return `Discover how to make ${cocktail.name} with My AI Bartender - your personal AI bartender guide!`;
}

const ANDROID_PACKAGE = 'ai.mybartender.mybartenderai';
const PLAY_STORE_URL = `https://play.google.com/store/apps/details?id=${ANDROID_PACKAGE}`;

// Targets for the "Open in My AI Bartender" button. Browsers open an app only
// from a user's tap, so the page can't do it on load.
// - Android: an intent: URL for the app's https App Link. Naming the package
//   opens the app without domain verification; without the app, Chrome
//   follows the Play Store fallback.
// - iOS (no Universal Links yet): the custom scheme with no host, so the path
//   is /cocktail/{id}, which every app version routes.
function openInAppLinks(cocktailId) {
    const id = encodeURIComponent(cocktailId);
    return {
        android: `intent://share.mybartenderai.com/cocktail/${id}#Intent;scheme=https;package=${ANDROID_PACKAGE};` +
            `S.browser_fallback_url=${encodeURIComponent(PLAY_STORE_URL)};end`,
        ios: `mybartender:///cocktail/${id}`
    };
}

function generatePreviewPage(cocktail) {
    // Canonical link (Front Door route-cocktail); /api/cocktail/{id} serves the same page.
    const shareUrl = `https://share.mybartenderai.com/cocktail/${cocktail.id}`;
    const appLinks = openInAppLinks(cocktail.id);
    const imageUrl = cocktail.imageUrl || 'https://mbacocktaildb3.blob.core.windows.net/images/default-cocktail.jpg';
    const description = escapeHtml(generateDescription(cocktail));
    const cocktailName = escapeHtml(cocktail.name);

    // Generate ingredients HTML
    const ingredientsHtml = cocktail.ingredients && cocktail.ingredients.length > 0
        ? cocktail.ingredients.map(ing => `
            <div class="ingredient-row">
                <span class="ingredient-dot"></span>
                <span class="ingredient-name">${escapeHtml(ing.name || '')}</span>
                <span class="ingredient-measure">${escapeHtml(ing.measure || '')}</span>
            </div>`).join('')
        : '<p class="no-ingredients">No ingredients listed</p>';

    // Generate tags
    const tags = [];
    if (cocktail.category) tags.push(cocktail.category);
    tags.push('Alcoholic'); // Most cocktails are alcoholic
    if (cocktail.glass) tags.push(cocktail.glass);

    const tagsHtml = tags.map(tag => `<span class="tag">${escapeHtml(tag)}</span>`).join('');

    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${cocktailName} - My AI Bartender</title>

    <!-- Open Graph Tags for Facebook & Instagram -->
    <meta property="og:title" content="${cocktailName} - My AI Bartender">
    <meta property="og:description" content="${description}">
    <meta property="og:image" content="${imageUrl}">
    <meta property="og:image:width" content="1200">
    <meta property="og:image:height" content="630">
    <meta property="og:url" content="${shareUrl}">
    <meta property="og:type" content="article">
    <meta property="og:site_name" content="My AI Bartender">

    <!-- Twitter Card Tags -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${cocktailName}">
    <meta name="twitter:description" content="${description}">
    <meta name="twitter:image" content="${imageUrl}">

    <!-- Deep Linking for Mobile Apps -->
    <meta property="al:android:url" content="mybartender://cocktail/${cocktail.id}">
    <meta property="al:android:package" content="ai.mybartender.mybartenderai">
    <meta property="al:android:app_name" content="My AI Bartender">
    <meta property="al:ios:url" content="${escapeHtml(appLinks.ios)}">
    <meta property="al:ios:app_store_id" content="6758023541">
    <meta property="al:ios:app_name" content="My AI Bartender">

    <style>
        * {
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            margin: 0;
            padding: 0;
            background: #0d0d1a;
            color: #ffffff;
            min-height: 100vh;
        }
        .hero-image {
            width: 100%;
            max-height: 350px;
            object-fit: contain;
            display: block;
            background: linear-gradient(180deg, #1a1a2e 0%, #0d0d1a 100%);
            padding: 1rem 0;
        }
        .content {
            padding: 1.5rem;
            max-width: 600px;
            margin: 0 auto;
        }
        h1 {
            font-size: 1.75rem;
            margin: 0 0 1rem 0;
            font-weight: 600;
        }
        .tags {
            display: flex;
            gap: 0.5rem;
            flex-wrap: wrap;
            margin-bottom: 1.5rem;
        }
        .tag {
            padding: 0.4rem 0.8rem;
            border-radius: 20px;
            font-size: 0.75rem;
            font-weight: 500;
            border: 1px solid rgba(139, 92, 246, 0.5);
            color: #c4b5fd;
            background: rgba(139, 92, 246, 0.1);
        }
        .tag:nth-child(2) {
            border-color: rgba(244, 114, 182, 0.5);
            color: #f9a8d4;
            background: rgba(244, 114, 182, 0.1);
        }
        .tag:nth-child(3) {
            border-color: rgba(96, 165, 250, 0.5);
            color: #93c5fd;
            background: rgba(96, 165, 250, 0.1);
        }
        .open-app-button {
            display: block;
            margin-bottom: 1.5rem;
            padding: 0.85rem 1.25rem;
            background: #8b5cf6;
            border-radius: 10px;
            color: white;
            text-align: center;
            text-decoration: none;
            font-weight: 600;
        }
        .open-app-button[hidden] {
            display: none;
        }
        .section-title {
            font-size: 1.25rem;
            font-weight: 600;
            margin: 1.5rem 0 1rem 0;
        }
        .ingredients-card {
            background: linear-gradient(135deg, rgba(139, 92, 246, 0.15) 0%, rgba(59, 7, 100, 0.3) 100%);
            border: 1px solid rgba(139, 92, 246, 0.3);
            border-radius: 12px;
            padding: 1rem;
        }
        .ingredient-row {
            display: flex;
            align-items: center;
            padding: 0.75rem 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        .ingredient-row:last-child {
            border-bottom: none;
        }
        .ingredient-dot {
            width: 8px;
            height: 8px;
            background: #8b5cf6;
            border-radius: 50%;
            margin-right: 0.75rem;
            flex-shrink: 0;
        }
        .ingredient-name {
            flex: 1;
            font-size: 0.95rem;
        }
        .ingredient-measure {
            color: rgba(255, 255, 255, 0.7);
            font-size: 0.9rem;
            margin-left: 1rem;
        }
        .instructions-card {
            background: rgba(30, 30, 50, 0.5);
            border-radius: 12px;
            padding: 1rem;
            margin-top: 0.5rem;
        }
        .instructions-text {
            font-size: 0.95rem;
            line-height: 1.6;
            color: rgba(255, 255, 255, 0.9);
            margin: 0;
        }
        .app-promo {
            margin-top: 2rem;
            padding: 1.5rem;
            background: linear-gradient(135deg, rgba(139, 92, 246, 0.2) 0%, rgba(59, 7, 100, 0.4) 100%);
            border-radius: 12px;
            text-align: center;
        }
        .app-promo-text {
            font-size: 0.95rem;
            margin-bottom: 1rem;
            color: rgba(255, 255, 255, 0.9);
        }
        .store-buttons {
            display: flex;
            gap: 0.75rem;
            justify-content: center;
            flex-wrap: wrap;
        }
        .store-button {
            display: inline-block;
            padding: 0.6rem 1.25rem;
            background: #8b5cf6;
            border-radius: 8px;
            color: white;
            text-decoration: none;
            font-weight: 600;
            font-size: 0.85rem;
            transition: all 0.2s;
        }
        .store-button:hover {
            background: #7c3aed;
            transform: translateY(-1px);
        }
        .no-ingredients {
            color: rgba(255, 255, 255, 0.6);
            font-style: italic;
            margin: 0;
        }
        .branding {
            text-align: center;
            margin-top: 2rem;
            padding-bottom: 1rem;
        }
        .branding-text {
            font-size: 0.8rem;
            color: rgba(255, 255, 255, 0.5);
        }
        @media (min-width: 768px) {
            .hero-image {
                max-height: 450px;
            }
            h1 {
                font-size: 2rem;
            }
            .content {
                padding: 2rem;
            }
        }
    </style>
</head>
<body>
    <img src="${imageUrl}" alt="${cocktailName}" class="hero-image" onerror="this.style.display='none'">

    <div class="content">
        <h1>${cocktailName}</h1>

        <div class="tags">
            ${tagsHtml}
        </div>

        <a id="open-in-app" class="open-app-button" hidden
           data-android-href="${escapeHtml(appLinks.android)}"
           data-ios-href="${escapeHtml(appLinks.ios)}">Open in My AI Bartender</a>

        <div class="section-title">Ingredients</div>
        <div class="ingredients-card">
            ${ingredientsHtml}
        </div>

        <div class="section-title">Instructions</div>
        <div class="instructions-card">
            <p class="instructions-text">${cocktail.instructions ? escapeHtml(cocktail.instructions) : 'No instructions available.'}</p>
        </div>

        <div class="app-promo">
            <p class="app-promo-text">Get My AI Bartender for more recipes, AI recommendations, and bar inventory tracking!</p>
            <div class="store-buttons">
                <a href="https://play.google.com/store/apps/details?id=ai.mybartender.mybartenderai" class="store-button">
                    Google Play
                </a>
                <a href="https://apps.apple.com/us/app/my-ai-bartender-scan-create/id6758023541" class="store-button">
                    App Store
                </a>
            </div>
        </div>

        <div class="branding">
            <span class="branding-text">Shared from My AI Bartender</span>
        </div>
    </div>

    <script>
        // Only phones show the button: there's no app to open on a desktop.
        (function () {
            var link = document.getElementById('open-in-app');
            var ua = navigator.userAgent || '';
            // iPadOS Safari reports a Mac user agent.
            var isIOS = /iPad|iPhone|iPod/.test(ua) ||
                (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
            var href = /Android/i.test(ua) ? link.getAttribute('data-android-href')
                : isIOS ? link.getAttribute('data-ios-href')
                : null;
            if (href) {
                link.href = href;
                link.hidden = false;
            }
        })();
    </script>
</body>
</html>`;
}

function generateErrorPage(message, errorCode = null) {
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My AI Bartender</title>
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
            padding: 2rem;
        }
        .container {
            max-width: 600px;
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        .error-code {
            font-size: 0.9rem;
            opacity: 0.7;
            margin-top: 1rem;
        }
        .home-button {
            display: inline-block;
            margin-top: 2rem;
            padding: 0.75rem 1.5rem;
            background: rgba(255, 255, 255, 0.2);
            border: 2px solid white;
            border-radius: 8px;
            color: white;
            text-decoration: none;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🍹 My AI Bartender</h1>
        <p>${escapeHtml(message)}</p>
        ${errorCode ? `<p class="error-code">Error Code: ${escapeHtml(errorCode)}</p>` : ''}
        <a href="https://play.google.com/store/apps/details?id=ai.mybartender.mybartenderai" class="home-button">
            Get the App
        </a>
    </div>
</body>
</html>`;
}

module.exports = async function (context, req) {
    // Support both v3 (bindingData) and v4 (req.params) models
    const cocktailId = context.bindingData?.id || req.params?.id;

    // Use console.log for v4 compatibility (context.log works in v3)
    const log = (msg) => console.log(msg);
    const logError = (msg, err) => console.error(msg, err);

    log(`[cocktail-preview] Request for cocktail: ${cocktailId}`);

    try {
        // Get cocktail from database
        const cocktail = await getCocktailById(cocktailId);

        if (!cocktail) {
            log(`[cocktail-preview] Cocktail not found: ${cocktailId}`);
            return {
                status: 404,
                headers: { 'Content-Type': 'text/html; charset=utf-8' },
                body: generateErrorPage('Cocktail not found. The recipe you\'re looking for doesn\'t exist.', 'COCKTAIL_NOT_FOUND')
            };
        }

        log(`[cocktail-preview] Found cocktail: ${cocktail.name}`);

        // Generate HTML preview page
        const html = generatePreviewPage(cocktail);

        return {
            status: 200,
            headers: {
                'Content-Type': 'text/html; charset=utf-8',
                'Cache-Control': 'public, max-age=300'  // Cache for 5 minutes
            },
            body: html
        };

    } catch (error) {
        logError('[cocktail-preview] Error:', error);
        return {
            status: 500,
            headers: { 'Content-Type': 'text/html; charset=utf-8' },
            body: generateErrorPage('Unable to load cocktail preview. Please try again later.', 'INTERNAL_ERROR')
        };
    }
};
