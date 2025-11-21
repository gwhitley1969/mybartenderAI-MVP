const { getPool } = require('../shared/db/postgresPool');

/**
 * cocktail-preview function
 * Generates HTML preview pages with Open Graph tags for social sharing
 * Route: GET /v1/cocktails/{id}/preview
 */

async function getCocktailById(cocktailId) {
    const pool = getPool();

    // Query cocktail by ID from PostgreSQL
    const result = await pool.query(
        `SELECT
            id,
            name,
            category,
            glass,
            instructions,
            image_url,
            ingredients
         FROM cocktails
         WHERE id = $1 OR LOWER(REPLACE(name, ' ', '-')) = LOWER($1)
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
        imageUrl: row.image_url,
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

function generatePreviewPage(cocktail) {
    const shareUrl = `https://fd-mba-share.azurefd.net/cocktail/${cocktail.id}`;
    const imageUrl = cocktail.imageUrl || 'https://mbacocktaildb3.blob.core.windows.net/images/default-cocktail.jpg';
    const description = escapeHtml(generateDescription(cocktail));
    const cocktailName = escapeHtml(cocktail.name);

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
    <meta property="al:android:package" content="com.mybartenderai.app">
    <meta property="al:android:app_name" content="My AI Bartender">
    <meta property="al:ios:url" content="mybartender://cocktail/${cocktail.id}">
    <meta property="al:ios:app_store_id" content="YOUR_APP_STORE_ID">
    <meta property="al:ios:app_name" content="My AI Bartender">

    <!-- Fallback redirect -->
    <script>
        // Try to open the app via deep link
        window.location.href = "mybartender://cocktail/${cocktail.id}";

        // Fallback to app store after a delay if app not installed
        setTimeout(function() {
            const userAgent = navigator.userAgent || navigator.vendor;
            if (/android/i.test(userAgent)) {
                window.location.href = "https://play.google.com/store/apps/details?id=com.mybartenderai.app";
            } else if (/iPad|iPhone|iPod/.test(userAgent)) {
                window.location.href = "https://apps.apple.com/app/idYOUR_APP_STORE_ID";
            } else {
                // Desktop - show the web page
                document.getElementById('install-prompt').style.display = 'block';
            }
        }, 1000);
    </script>

    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            padding: 2rem;
        }
        .container {
            max-width: 600px;
            padding: 2rem;
        }
        .cocktail-image {
            width: 200px;
            height: 200px;
            border-radius: 50%;
            object-fit: cover;
            margin: 0 auto 1.5rem;
            display: block;
            border: 4px solid rgba(255, 255, 255, 0.3);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
        }
        h1 {
            font-size: 2.5rem;
            margin-bottom: 1rem;
            font-weight: bold;
        }
        .category {
            font-size: 1rem;
            opacity: 0.8;
            margin-bottom: 1.5rem;
            text-transform: uppercase;
            letter-spacing: 2px;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
            line-height: 1.6;
        }
        .loading {
            margin-top: 2rem;
            font-size: 0.9rem;
            opacity: 0.7;
        }
        #install-prompt {
            display: none;
            margin-top: 2rem;
            padding: 1.5rem;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 12px;
            backdrop-filter: blur(10px);
        }
        .store-buttons {
            display: flex;
            gap: 1rem;
            justify-content: center;
            margin-top: 1rem;
            flex-wrap: wrap;
        }
        .store-button {
            display: inline-block;
            padding: 0.75rem 1.5rem;
            background: rgba(255, 255, 255, 0.2);
            border: 2px solid white;
            border-radius: 8px;
            color: white;
            text-decoration: none;
            font-weight: bold;
            transition: all 0.3s;
        }
        .store-button:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
    </style>
</head>
<body>
    <div class="container">
        <img src="${imageUrl}" alt="${cocktailName}" class="cocktail-image" onerror="this.style.display='none'">
        <h1>🍹 ${cocktailName}</h1>
        ${cocktail.category ? `<div class="category">${escapeHtml(cocktail.category)}</div>` : ''}
        <p>${description}</p>
        <p class="loading">Opening My AI Bartender...</p>

        <div id="install-prompt">
            <p style="font-size: 1rem; margin-bottom: 1rem;">Get the My AI Bartender app to view this recipe and discover more!</p>
            <div class="store-buttons">
                <a href="https://play.google.com/store/apps/details?id=com.mybartenderai.app" class="store-button">
                    Get on Google Play
                </a>
                <a href="https://apps.apple.com/app/idYOUR_APP_STORE_ID" class="store-button">
                    Get on App Store
                </a>
            </div>
        </div>
    </div>
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
        <a href="https://play.google.com/store/apps/details?id=com.mybartenderai.app" class="home-button">
            Get the App
        </a>
    </div>
</body>
</html>`;
}

module.exports = async function (context, req) {
    const cocktailId = context.bindingData.id;

    context.log(`[cocktail-preview] Request for cocktail: ${cocktailId}`);

    try {
        // Get cocktail from database
        const cocktail = await getCocktailById(cocktailId);

        if (!cocktail) {
            context.log(`[cocktail-preview] Cocktail not found: ${cocktailId}`);
            context.res = {
                status: 404,
                headers: { 'Content-Type': 'text/html; charset=utf-8' },
                body: generateErrorPage('Cocktail not found. The recipe you\'re looking for doesn\'t exist.', 'COCKTAIL_NOT_FOUND')
            };
            return;
        }

        context.log(`[cocktail-preview] Found cocktail: ${cocktail.name}`);

        // Generate HTML preview page
        const html = generatePreviewPage(cocktail);

        context.res = {
            status: 200,
            headers: {
                'Content-Type': 'text/html; charset=utf-8',
                'Cache-Control': 'public, max-age=300'  // Cache for 5 minutes
            },
            body: html
        };

    } catch (error) {
        context.log.error('[cocktail-preview] Error:', error);
        context.res = {
            status: 500,
            headers: { 'Content-Type': 'text/html; charset=utf-8' },
            body: generateErrorPage('Unable to load cocktail preview. Please try again later.', 'INTERNAL_ERROR')
        };
    }
};
