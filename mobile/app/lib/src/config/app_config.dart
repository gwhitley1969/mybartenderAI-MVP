/// MyBartenderAI App Configuration
///
/// Central configuration for API endpoints, keys, and app settings

class AppConfig {
  // Backend API Configuration
  static const String backendBaseUrl = 'https://func-mba-fresh.azurewebsites.net/api';

  // Function keys (in production, these should come from secure storage or environment variables)
  // For now, we'll access public endpoints and add authentication later
  static const String? functionKey = null; // Add if needed for protected endpoints

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
