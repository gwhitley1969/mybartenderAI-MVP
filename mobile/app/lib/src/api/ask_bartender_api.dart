import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/bootstrap.dart';

class AskBartenderRequest {
  const AskBartenderRequest({
    required this.message,
    this.context,
  });

  final String message;
  final AskBartenderContext? context;

  Map<String, dynamic> toJson() => {
        'message': message,
        if (context != null) 'context': context!.toJson(),
      };
}

class AskBartenderContext {
  const AskBartenderContext({
    this.inventory,
    this.preferences,
    this.conversationId,
  });

  final BartenderInventory? inventory;
  final BartenderPreferences? preferences;
  final String? conversationId;

  Map<String, dynamic> toJson() => {
        if (inventory != null) 'inventory': inventory!.toJson(),
        if (preferences != null) 'preferences': preferences!.toJson(),
        if (conversationId != null) 'conversationId': conversationId,
      };
}

class BartenderInventory {
  const BartenderInventory({
    this.spirits,
    this.mixers,
  });

  final List<String>? spirits;
  final List<String>? mixers;

  Map<String, dynamic> toJson() => {
        if (spirits != null) 'spirits': spirits,
        if (mixers != null) 'mixers': mixers,
      };
}

class BartenderPreferences {
  const BartenderPreferences({
    this.preferredFlavors,
    this.dislikedFlavors,
    this.abvRange,
  });

  final List<String>? preferredFlavors;
  final List<String>? dislikedFlavors;
  final String? abvRange;

  Map<String, dynamic> toJson() => {
        if (preferredFlavors != null) 'preferredFlavors': preferredFlavors,
        if (dislikedFlavors != null) 'dislikedFlavors': dislikedFlavors,
        if (abvRange != null) 'abvRange': abvRange,
      };
}

class AskBartenderResponse {
  const AskBartenderResponse({
    required this.response,
    required this.conversationId,
    this.usage,
  });

  final String response;
  final String conversationId;
  final TokenUsage? usage;

  factory AskBartenderResponse.fromJson(Map<String, dynamic> json) {
    return AskBartenderResponse(
      response: json['response'] as String,
      conversationId: json['conversationId'] as String,
      usage: json['usage'] != null
          ? TokenUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TokenUsage {
  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
  });

  final int promptTokens;
  final int completionTokens;

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      promptTokens: json['promptTokens'] as int,
      completionTokens: json['completionTokens'] as int,
    );
  }
}

class AskBartenderApi {
  AskBartenderApi(this._dio);

  final Dio _dio;

  Future<AskBartenderResponse> ask({
    required String message,
    BartenderInventory? inventory,
    BartenderPreferences? preferences,
    String? conversationId,
  }) async {
    final request = AskBartenderRequest(
      message: message,
      context: (inventory != null || preferences != null || conversationId != null)
          ? AskBartenderContext(
              inventory: inventory,
              preferences: preferences,
              conversationId: conversationId,
            )
          : null,
    );

    // Function key is added via interceptor from EnvConfig
    // Headers can be explicitly added here if needed for debugging
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/ask-bartender-simple',
      data: request.toJson(),
      options: Options(
        headers: {
          // Function key is added via FunctionKeyInterceptor in bootstrap.dart
          // from the EnvConfig passed in main.dart
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Expected response data but received null');
    }

    return AskBartenderResponse.fromJson(data);
  }
}

final askBartenderApiProvider = Provider<AskBartenderApi>((ref) {
  final dio = ref.watch(dioProvider);
  return AskBartenderApi(dio);
});
