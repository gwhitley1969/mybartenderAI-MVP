import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/backend_provider.dart';

// Request models
class CocktailDraft {
  const CocktailDraft({
    required this.name,
    required this.ingredients,
    this.category,
    this.glass,
    this.alcoholic,
    this.instructions,
  });

  final String name;
  final String? category;
  final String? glass;
  final String? alcoholic;
  final List<CocktailIngredient> ingredients;
  final String? instructions;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        if (category != null) 'category': category,
        if (glass != null) 'glass': glass,
        if (alcoholic != null) 'alcoholic': alcoholic,
        if (instructions != null) 'instructions': instructions,
      };
}

class CocktailIngredient {
  const CocktailIngredient({
    required this.name,
    this.measure,
  });

  final String name;
  final String? measure;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (measure != null) 'measure': measure,
      };
}

// Response models
class RefinementResponse {
  const RefinementResponse({
    required this.overall,
    required this.suggestions,
    this.refinedRecipe,
    this.usage,
  });

  final String overall;
  final List<RefinementSuggestion> suggestions;
  final RefinedRecipe? refinedRecipe;
  final TokenUsage? usage;

  factory RefinementResponse.fromJson(Map<String, dynamic> json) {
    return RefinementResponse(
      overall: json['overall'] as String? ?? '',
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) => RefinementSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      refinedRecipe: json['refinedRecipe'] != null
          ? RefinedRecipe.fromJson(json['refinedRecipe'] as Map<String, dynamic>)
          : null,
      usage: json['usage'] != null
          ? TokenUsage.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
    );
  }
}

class RefinementSuggestion {
  const RefinementSuggestion({
    required this.category,
    required this.suggestion,
    required this.priority,
  });

  final String category;
  final String suggestion;
  final String priority; // high, medium, low

  factory RefinementSuggestion.fromJson(Map<String, dynamic> json) {
    return RefinementSuggestion(
      category: json['category'] as String? ?? 'other',
      suggestion: json['suggestion'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
    );
  }

  bool get isHighPriority => priority.toLowerCase() == 'high';
  bool get isMediumPriority => priority.toLowerCase() == 'medium';
  bool get isLowPriority => priority.toLowerCase() == 'low';
}

class RefinedRecipe {
  const RefinedRecipe({
    required this.name,
    required this.ingredients,
    required this.instructions,
    this.glass,
    this.category,
  });

  final String name;
  final List<CocktailIngredient> ingredients;
  final String instructions;
  final String? glass;
  final String? category;

  factory RefinedRecipe.fromJson(Map<String, dynamic> json) {
    return RefinedRecipe(
      name: json['name'] as String? ?? '',
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((i) => CocktailIngredient(
                    name: i['name'] as String? ?? '',
                    measure: i['measure'] as String?,
                  ))
              .toList() ??
          [],
      instructions: json['instructions'] as String? ?? '',
      glass: json['glass'] as String?,
      category: json['category'] as String?,
    );
  }
}

class TokenUsage {
  const TokenUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      promptTokens: json['promptTokens'] as int? ?? 0,
      completionTokens: json['completionTokens'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
    );
  }
}

// API Client
class CreateStudioApi {
  CreateStudioApi(this._dio);

  final Dio _dio;

  /// Get AI refinement suggestions for a cocktail draft
  Future<RefinementResponse> refineCocktail(CocktailDraft cocktail) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/create-studio/refine',
      data: cocktail.toJson(),
      options: Options(
        headers: {
          // Function key is added via FunctionKeyInterceptor in bootstrap.dart
        },
      ),
    );

    final data = response.data;
    if (data == null) {
      throw StateError('Expected response data but received null');
    }

    return RefinementResponse.fromJson(data);
  }
}

// Provider
final createStudioApiProvider = Provider<CreateStudioApi>((ref) {
  final backendService = ref.watch(backendServiceProvider);
  return CreateStudioApi(backendService.dio);
});
