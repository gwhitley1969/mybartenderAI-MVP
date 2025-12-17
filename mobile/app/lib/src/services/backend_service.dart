import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Backend service for API communication
///
/// AUTHENTICATION: Uses JWT ID tokens from Entra External ID
/// - ID Token audience: client app ID (f9f7f159-b847-4211-98c9-18e5b8193045)
/// - APIM validates the JWT and extracts user identity
/// - Backend looks up user tier from database on each request
/// - NO APIM subscription keys (removed for security)
class BackendService {
  late final Dio _dio;
  final String baseUrl;
  final Future<String?> Function()? getIdToken;

  /// Expose Dio instance for services that need direct access
  Dio get dio => _dio;

  BackendService({
    required this.baseUrl,
    this.getIdToken,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add JWT authorization header using ID token
    // ID token has audience = client app ID, which APIM validates
    if (getIdToken != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final requestPath = options.path;
            final fullUrl = options.uri.toString();
            print('BackendService: ========== REQUEST START ==========');
            print('BackendService: Path: $requestPath');
            print('BackendService: Full URL: $fullUrl');
            print('BackendService: Method: ${options.method}');

            // Skip auth for public endpoints that don't need it
            final publicEndpoints = ['/v1/snapshots/latest', '/health'];
            final isPublicEndpoint = publicEndpoints.any((ep) => requestPath.contains(ep));
            print('BackendService: Is public endpoint: $isPublicEndpoint');

            if (isPublicEndpoint) {
              print('BackendService: PUBLIC endpoint - skipping auth token');
              print('BackendService: ========== REQUEST END (no auth) ==========');
              handler.next(options);
              return;
            }

            try {
              print('BackendService: Getting ID token for APIM validation...');
              // Add timeout to prevent hanging forever
              final token = await getIdToken!().timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  print('BackendService: Token retrieval TIMEOUT after 10s');
                  return null;
                },
              );
              print('BackendService: ID token retrieved: ${token != null ? '${token.length} chars' : 'NULL'}');

              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
            } catch (e) {
              print('BackendService: Error getting ID token: $e');
              // Continue without token rather than failing
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            print('BackendService: ========== RESPONSE ==========');
            print('BackendService: Status: ${response.statusCode}');
            print('BackendService: Path: ${response.requestOptions.path}');
            handler.next(response);
          },
          onError: (error, handler) {
            print('BackendService: ========== ERROR ==========');
            print('BackendService: Error type: ${error.type}');
            print('BackendService: Error message: ${error.message}');
            print('BackendService: Response status: ${error.response?.statusCode}');
            print('BackendService: Response data: ${error.response?.data}');
            print('BackendService: Path: ${error.requestOptions.path}');
            handler.next(error);
          },
        ),
      );
    }

    // NOTE: APIM subscription key interceptor REMOVED
    // Using JWT-only authentication for security
    // APIM validates JWT, backend looks up user tier from database

    // Add logging interceptor for debugging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
  }

  /// Check if the backend is healthy
  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'ok';
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }

  /// Get the latest snapshot metadata
  /// Includes retry logic for transient network errors
  Future<SnapshotMetadata> getLatestSnapshot() async {
    const maxRetries = 3;
    const retryDelayMs = 1000;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('BackendService: Getting snapshot metadata (attempt $attempt/$maxRetries)');
        final response = await _dio.get('/v1/snapshots/latest');
        print('BackendService: Snapshot metadata received successfully');
        return SnapshotMetadata.fromJson(response.data);
      } on DioException catch (e) {
        print('BackendService: Attempt $attempt failed: ${e.type} - ${e.message}');

        // Don't retry for non-transient errors
        if (e.type == DioExceptionType.badResponse) {
          // Server returned an error response (4xx, 5xx)
          throw Exception('Failed to get snapshot metadata: Server error ${e.response?.statusCode}');
        }

        // Retry for connection errors, timeouts, etc.
        if (attempt < maxRetries) {
          print('BackendService: Retrying in ${retryDelayMs}ms...');
          await Future.delayed(Duration(milliseconds: retryDelayMs * attempt));
        } else {
          throw Exception('Failed to get snapshot metadata after $maxRetries attempts: $e');
        }
      } catch (e) {
        print('BackendService: Unexpected error on attempt $attempt: $e');
        if (attempt >= maxRetries) {
          throw Exception('Failed to get snapshot metadata: $e');
        }
        await Future.delayed(Duration(milliseconds: retryDelayMs * attempt));
      }
    }

    throw Exception('Failed to get snapshot metadata: Unknown error');
  }

  /// Download the snapshot data
  Future<Uint8List> downloadSnapshot(String signedUrl) async {
    try {
      final response = await _dio.get(
        signedUrl,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {
            'Accept': 'application/octet-stream',
          },
        ),
      );
      return Uint8List.fromList(response.data);
    } catch (e) {
      throw Exception('Failed to download snapshot: $e');
    }
  }

  /// Verify snapshot SHA256
  bool verifySnapshot(Uint8List data, String expectedSha256) {
    final digest = sha256.convert(data);
    final actualSha256 = digest.toString();
    return actualSha256 == expectedSha256;
  }

  /// Ask the bartender a question
  Future<AskBartenderResponse> askBartender(String message, {Map<String, dynamic>? context}) async {
    try {
      final response = await _dio.post(
        '/v1/ask-bartender-simple',
        data: {
          'message': message,
          'context': context ?? {},
        },
      );
      return AskBartenderResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to ask bartender: $e');
    }
  }

  /// Get a token for OpenAI Realtime API
  Future<RealtimeToken> getRealtimeToken() async {
    try {
      final response = await _dio.post('/v1/realtime/token-simple', data: {});
      return RealtimeToken.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get realtime token: $e');
    }
  }

  /// Get cocktail recommendations
  Future<RecommendationResponse> getRecommendations({
    List<String>? availableIngredients,
    String? occasion,
    String? mood,
  }) async {
    try {
      final response = await _dio.post(
        '/v1/recommend',
        data: {
          'availableIngredients': availableIngredients ?? [],
          'occasion': occasion,
          'mood': mood,
        },
      );
      return RecommendationResponse.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get recommendations: $e');
    }
  }
}

// Data Models

class SnapshotMetadata {
  final String schemaVersion;
  final String snapshotVersion;
  final int sizeBytes;
  final String sha256;
  final String signedUrl;
  final DateTime createdAtUtc;
  final Map<String, int> counts;

  SnapshotMetadata({
    required this.schemaVersion,
    required this.snapshotVersion,
    required this.sizeBytes,
    required this.sha256,
    required this.signedUrl,
    required this.createdAtUtc,
    required this.counts,
  });

  factory SnapshotMetadata.fromJson(Map<String, dynamic> json) {
    return SnapshotMetadata(
      schemaVersion: json['schemaVersion'],
      snapshotVersion: json['snapshotVersion'],
      sizeBytes: json['sizeBytes'],
      sha256: json['sha256'],
      signedUrl: json['signedUrl'],
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      counts: Map<String, int>.from(json['counts']),
    );
  }
}

class AskBartenderResponse {
  final String response;
  final String? debugPrompt;
  final Map<String, dynamic>? usage;

  AskBartenderResponse({
    required this.response,
    this.debugPrompt,
    this.usage,
  });

  factory AskBartenderResponse.fromJson(Map<String, dynamic> json) {
    return AskBartenderResponse(
      response: json['response'],
      debugPrompt: json['debugPrompt'],
      usage: json['usage'],
    );
  }
}

class RealtimeToken {
  final String token;
  final String model;
  final int expiresIn;

  RealtimeToken({
    required this.token,
    required this.model,
    required this.expiresIn,
  });

  factory RealtimeToken.fromJson(Map<String, dynamic> json) {
    return RealtimeToken(
      token: json['token'],
      model: json['model'] ?? 'gpt-4o-realtime-preview-2024-10-01',
      expiresIn: json['expires_in'] ?? 3600,
    );
  }
}

class RecommendationResponse {
  final List<Recommendation> recommendations;
  final String? explanation;

  RecommendationResponse({
    required this.recommendations,
    this.explanation,
  });

  factory RecommendationResponse.fromJson(Map<String, dynamic> json) {
    return RecommendationResponse(
      recommendations: (json['recommendations'] as List)
          .map((r) => Recommendation.fromJson(r))
          .toList(),
      explanation: json['explanation'],
    );
  }
}

class Recommendation {
  final String drinkId;
  final String drinkName;
  final double matchScore;
  final String reason;
  final List<String> missingIngredients;

  Recommendation({
    required this.drinkId,
    required this.drinkName,
    required this.matchScore,
    required this.reason,
    required this.missingIngredients,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      drinkId: json['drinkId'],
      drinkName: json['drinkName'],
      matchScore: json['matchScore'].toDouble(),
      reason: json['reason'],
      missingIngredients: List<String>.from(json['missingIngredients'] ?? []),
    );
  }
}
