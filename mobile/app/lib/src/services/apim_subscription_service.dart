import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_service.dart';
import '../config/app_config.dart';

/// Service for managing APIM subscription keys obtained via runtime token exchange
class ApimSubscriptionService {
  static const String _storageKeyPrefix = 'apim_subscription_';
  static const String _storageKeySubscription = '${_storageKeyPrefix}key';
  static const String _storageKeyExpiry = '${_storageKeyPrefix}expiry';
  static const String _storageKeyTier = '${_storageKeyPrefix}tier';
  static const String _storageKeyQuotas = '${_storageKeyPrefix}quotas';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuthService _authService;
  final Dio _dio;

  // Cached values
  String? _cachedSubscriptionKey;
  DateTime? _cachedExpiry;
  String? _cachedTier;
  Map<String, dynamic>? _cachedQuotas;

  ApimSubscriptionService({
    required AuthService authService,
  })  : _authService = authService,
        _dio = Dio(BaseOptions(
          baseUrl: AppConfig.backendBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  /// Exchange JWT for APIM subscription key
  Future<void> exchangeTokenForSubscription() async {
    try {
      print('[APIM] Starting token exchange...');

      // Get JWT access token
      final accessToken = await _authService.getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No valid JWT token available for exchange');
      }

      // Call exchange endpoint
      final response = await _dio.post(
        '/v1/auth/exchange',
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // Store subscription key and metadata securely
        _cachedSubscriptionKey = data['subscriptionKey'];
        _cachedTier = data['tier'];
        _cachedExpiry = DateTime.parse(data['expiresAt']);
        _cachedQuotas = data['quotas'];

        // Persist to secure storage
        await _secureStorage.write(
          key: _storageKeySubscription,
          value: _cachedSubscriptionKey,
        );
        await _secureStorage.write(
          key: _storageKeyExpiry,
          value: _cachedExpiry!.toIso8601String(),
        );
        await _secureStorage.write(
          key: _storageKeyTier,
          value: _cachedTier,
        );
        await _secureStorage.write(
          key: _storageKeyQuotas,
          value: json.encode(_cachedQuotas),
        );

        print('[APIM] Token exchange successful. Tier: $_cachedTier, Expires: $_cachedExpiry');
      } else {
        throw Exception('Invalid response from exchange endpoint');
      }
    } catch (e) {
      print('[APIM] Token exchange failed: $e');
      // Clear any cached values on error
      await clearSubscription();
      rethrow;
    }
  }

  /// Get current APIM subscription key, exchanging if necessary
  Future<String?> getSubscriptionKey() async {
    try {
      // Check if we have a cached key
      if (_cachedSubscriptionKey == null) {
        // Try to load from secure storage
        await _loadFromStorage();
      }

      // Check if key exists and is not expired
      if (_cachedSubscriptionKey != null && _cachedExpiry != null) {
        // Check expiry with 5-minute buffer
        final now = DateTime.now();
        final expiryBuffer = _cachedExpiry!.subtract(const Duration(minutes: 5));

        if (now.isBefore(expiryBuffer)) {
          // Key is still valid
          return _cachedSubscriptionKey;
        } else {
          print('[APIM] Subscription key expired or expiring soon, refreshing...');
        }
      }

      // Need to exchange for new key
      await exchangeTokenForSubscription();
      return _cachedSubscriptionKey;
    } catch (e) {
      print('[APIM] Failed to get subscription key: $e');
      return null;
    }
  }

  /// Get user's tier
  Future<String> getUserTier() async {
    if (_cachedTier == null) {
      await _loadFromStorage();
    }

    if (_cachedTier == null) {
      // If still null, exchange for new subscription
      await exchangeTokenForSubscription();
    }

    return _cachedTier ?? 'free';
  }

  /// Get user's quotas
  Future<Map<String, dynamic>> getUserQuotas() async {
    if (_cachedQuotas == null) {
      await _loadFromStorage();
    }

    if (_cachedQuotas == null) {
      // If still null, exchange for new subscription
      await exchangeTokenForSubscription();
    }

    return _cachedQuotas ?? {
      'tokensPerMonth': 10000,  // Free tier default
      'scansPerMonth': 2,
      'aiEnabled': true,  // Free tier now has limited AI access
    };
  }

  /// Check if user has AI features enabled
  Future<bool> hasAiAccess() async {
    final quotas = await getUserQuotas();
    return quotas['aiEnabled'] == true;
  }

  /// Handle 401/403 errors by re-exchanging
  Future<bool> handleAuthError() async {
    try {
      print('[APIM] Handling auth error, attempting re-exchange...');

      // Clear existing subscription
      await clearSubscription();

      // Re-authenticate if needed
      await _authService.refreshAccessToken();

      // Exchange for new subscription
      await exchangeTokenForSubscription();

      return _cachedSubscriptionKey != null;
    } catch (e) {
      print('[APIM] Failed to handle auth error: $e');
      return false;
    }
  }

  /// Clear stored subscription data
  Future<void> clearSubscription() async {
    _cachedSubscriptionKey = null;
    _cachedExpiry = null;
    _cachedTier = null;
    _cachedQuotas = null;

    await _secureStorage.delete(key: _storageKeySubscription);
    await _secureStorage.delete(key: _storageKeyExpiry);
    await _secureStorage.delete(key: _storageKeyTier);
    await _secureStorage.delete(key: _storageKeyQuotas);

    print('[APIM] Subscription data cleared');
  }

  /// Load subscription data from secure storage
  Future<void> _loadFromStorage() async {
    try {
      _cachedSubscriptionKey = await _secureStorage.read(key: _storageKeySubscription);

      final expiryStr = await _secureStorage.read(key: _storageKeyExpiry);
      if (expiryStr != null) {
        _cachedExpiry = DateTime.parse(expiryStr);
      }

      _cachedTier = await _secureStorage.read(key: _storageKeyTier);

      final quotasStr = await _secureStorage.read(key: _storageKeyQuotas);
      if (quotasStr != null) {
        _cachedQuotas = json.decode(quotasStr);
      }

      if (_cachedSubscriptionKey != null) {
        print('[APIM] Loaded subscription from storage. Tier: $_cachedTier');
      }
    } catch (e) {
      print('[APIM] Failed to load from storage: $e');
      // Clear corrupted data
      await clearSubscription();
    }
  }

  /// Add APIM headers to a request
  Future<Map<String, String>> getApimHeaders() async {
    final subscriptionKey = await getSubscriptionKey();
    if (subscriptionKey == null || subscriptionKey.isEmpty) {
      print('[APIM] Warning: No subscription key available');
      return {};
    }

    return {
      'Ocp-Apim-Subscription-Key': subscriptionKey,
    };
  }

  /// Add both JWT and APIM headers for protected endpoints
  Future<Map<String, String>> getAuthHeaders() async {
    final headers = <String, String>{};

    // Get JWT token
    final accessToken = await _authService.getValidAccessToken();
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    // Get APIM subscription key
    final apimHeaders = await getApimHeaders();
    headers.addAll(apimHeaders);

    return headers;
  }
}