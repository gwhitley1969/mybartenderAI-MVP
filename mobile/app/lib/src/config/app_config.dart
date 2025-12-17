/// MyBartenderAI App Configuration
///
/// Central configuration for API endpoints, keys, and app settings
///
/// SECURITY NOTE:
/// - Authentication uses JWT tokens from Entra External ID
/// - APIM validates JWT and extracts user identity
/// - Backend looks up user tier from database
/// - No subscription keys stored on device

class AppConfig {
  // Backend API Configuration - Azure Front Door → APIM → Functions
  static const String backendBaseUrl = 'https://share.mybartenderai.com/api';

  // NOTE: APIM subscription key REMOVED for security
  // Using JWT-only authentication - APIM validates JWT token
  // Backend looks up user tier from database on each request

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
