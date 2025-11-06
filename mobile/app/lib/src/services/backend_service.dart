import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class BackendService {
  late final Dio _dio;
  final String baseUrl;
  final String? functionKey;
  final Future<String?> Function()? getAccessToken;

  /// Expose Dio instance for services that need direct access
  Dio get dio => _dio;

  BackendService({
    required this.baseUrl,
    this.functionKey,
    this.getAccessToken,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    // Add JWT authorization header if token provider is available
    if (getAccessToken != null) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await getAccessToken!();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            handler.next(options);
          },
        ),
      );
    }

    // Add function key if provided (for endpoints that still use it)
    if (functionKey != null && functionKey!.isNotEmpty) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            options.headers['x-functions-key'] = functionKey;
            handler.next(options);
          },
        ),
      );
    }

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
  Future<SnapshotMetadata> getLatestSnapshot() async {
    try {
      final response = await _dio.get('/v1/snapshots/latest');
      return SnapshotMetadata.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get snapshot metadata: $e');
    }
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
