/// Authentication configuration for Entra External ID (Azure AD B2C)
class AuthConfig {
  // Entra External ID tenant configuration
  static const String tenantName = 'mybartenderai';
  static const String tenantId = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';

  // Mobile app registration (from Entra External ID tenant)
  static const String clientId = 'f9f7f159-b847-4211-98c9-18e5b8193045';

  // User flow (for sign-in/sign-up)
  static const String userFlowName = 'mba-signin-signup';

  // Authority URLs (Entra External ID / CIAM)
  static String get authority =>
      'https://$tenantName.ciamlogin.com/$tenantId';

  // Discovery URL for CIAM with policy (recommended by external reviewer)
  static String get discoveryUrl =>
      'https://$tenantName.ciamlogin.com/$tenantName.onmicrosoft.com/v2.0/.well-known/openid-configuration?p=$userFlowName';

  // Explicit endpoints WITH policy in path for Azure AD B2C/Entra External ID
  static String get authorizationEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantName.onmicrosoft.com/$userFlowName/oauth2/v2.0/authorize';

  static String get tokenEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantName.onmicrosoft.com/$userFlowName/oauth2/v2.0/token';

  static String get endSessionEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/oauth2/v2.0/logout';

  // Redirect URIs (must match Azure AD app registration EXACTLY)
  // Using standard custom scheme for flutter_appauth (NOT MSAL format)
  static const String redirectUrl = 'com.mybartenderai.app://oauth/redirect';
  static const String redirectUrlScheme = 'com.mybartenderai.app';

  // Scopes
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access', // For refresh tokens
  ];

  // Additional parameters for Entra External ID
  // Note: In flutter_appauth 7.x, prompt is passed via promptValues parameter
  static const Map<String, String> additionalParameters = {
    // 'prompt': 'select_account', // Now handled via promptValues
    // Policy is now in URL path, not as parameter
    // REMOVED response_mode - let flutter_appauth use correct default for code+PKCE
  };

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String idTokenKey = 'id_token';
  static const String expiresAtKey = 'expires_at';
  static const String userProfileKey = 'user_profile';
}
