/// MyBartenderAI App Configuration
///
/// Central configuration for API endpoints, keys, and app settings
///
/// SECURITY NOTE:
/// - Function keys are retrieved from Azure Key Vault at build time
/// - Pass key via: --dart-define=AZURE_FUNCTION_KEY=<key>
/// - See build-secure.ps1 for automated secure build process

class AppConfig {
  // Backend API Configuration - Azure Front Door → APIM → Functions
  static const String backendBaseUrl = 'https://share.mybartenderai.com/api';

  // APIM Subscription Key - Currently using master key for all requests
  // TODO: Implement runtime token exchange via ApimSubscriptionService for per-user keys
  // For now, using master subscription key for development/testing
  static const String? functionKey = 'f23ebc87cecc4f909e94ecfa2d85d856';

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
