/**
 * Social Sharing Configuration
 *
 * Configuration constants for social sharing features including
 * Meta API integration, share URLs, and app store links.
 */

module.exports = {
  // Meta Graph API Configuration
  META_GRAPH_VERSION: 'v19.0',

  // Share URLs
  SHARE_BASE_URL: process.env.SHARE_BASE_URL || 'https://fd-mba-share.azurefd.net',

  // App Store URLs
  ANDROID_STORE_URL: 'https://play.google.com/store/apps/details?id=com.mybartenderai.app',
  IOS_STORE_URL: 'https://apps.apple.com/app/idYOUR_APP_STORE_ID',

  // Deep Link Schemes
  DEEP_LINK_SCHEME: 'mybartender',

  // Future: Direct API posting credentials (Phase 2)
  // These will be used when implementing direct Meta API posting
  // META_FACEBOOK_APP_ID: process.env['META-FACEBOOK-APP-ID'],
  // META_FACEBOOK_APP_SECRET: process.env['META-FACEBOOK-APP-SECRET'],

  // Social Platform Identifiers
  PLATFORMS: {
    FACEBOOK: 'facebook',
    INSTAGRAM: 'instagram'
  }
};
