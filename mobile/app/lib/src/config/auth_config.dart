/// Authentication configuration for Entra External ID (Azure AD B2C)
class AuthConfig {
  // Entra External ID tenant configuration
  static const String tenantName = 'mybartenderai';
  static const String tenantId = 'a82813af-1054-4e2d-a8ec-c6b9c2908c91';

  // Mobile app registration
  static const String clientId = '0a9decfb-ba92-400d-8d8d-8d86f0f86a0b';

  // User flow (for sign-in/sign-up)
  static const String userFlowName = 'mba-signin-signup';

  // Authority URLs
  static String get authority =>
      'https://$tenantName.ciamlogin.com/$tenantId/$userFlowName';

  static String get discoveryUrl =>
      'https://$tenantName.ciamlogin.com/$tenantId/$userFlowName/v2.0/.well-known/openid-configuration';

  static String get authorizationEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/$userFlowName/oauth2/v2.0/authorize';

  static String get tokenEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/$userFlowName/oauth2/v2.0/token';

  static String get endSessionEndpoint =>
      'https://$tenantName.ciamlogin.com/$tenantId/$userFlowName/oauth2/v2.0/logout';

  // Redirect URIs (must match Azure AD app registration)
  static const String redirectUrl = 'com.mybartenderai.app://callback';
  static const String redirectUrlScheme = 'com.mybartenderai.app';

  // Scopes
  static const List<String> scopes = [
    'openid',
    'profile',
    'email',
    'offline_access', // For refresh tokens
  ];

  // Additional parameters for Entra External ID
  static const Map<String, String> additionalParameters = {
    'prompt': 'select_account', // Always show account picker
  };

  // Token storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String idTokenKey = 'id_token';
  static const String expiresAtKey = 'expires_at';
  static const String userProfileKey = 'user_profile';
}
