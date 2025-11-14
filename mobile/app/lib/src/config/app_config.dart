/// MyBartenderAI App Configuration
///
/// Central configuration for API endpoints, keys, and app settings
///
/// SECURITY NOTE:
/// - Function keys are retrieved from Azure Key Vault at build time
/// - Pass key via: --dart-define=AZURE_FUNCTION_KEY=<key>
/// - See build-secure.ps1 for automated secure build process

class AppConfig {
  // Backend API Configuration - APIM Gateway
  static const String backendBaseUrl = 'https://apim-mba-001.azure-api.net/api';

  // APIM Subscription Key is now obtained via runtime token exchange
  // This provides better security through per-user, revocable keys
  // Keys are exchanged on login and stored in secure storage
  // Build-time injection has been replaced with runtime exchange
  @Deprecated('Use ApimSubscriptionService.getSubscriptionKey() instead')
  static const String? functionKey = null;

  // API Endpoints
  static const String healthEndpoint = '/health';
  static const String snapshotsEndpoint = '/v1/snapshots/latest';
  static const String askBartenderEndpoint = '/v1/ask-bartender-simple';
  static const String realtimeTokenEndpoint = '/v1/realtime/token-simple';
  static const String recommendEndpoint = '/v1/recommend';

  // App Settings
  static const String appName = 'MyBartenderAI';
  static const String appVersion = '1.0.0';

  // Feature Flags
  static const bool enableVoiceChat = true;
  static const bool enableRecommendations = true;
  static const bool enableOfflineMode = false;

  // Cache Settings
  static const Duration snapshotCacheDuration = Duration(hours: 24);
  static const Duration apiTimeout = Duration(seconds: 30);
}
