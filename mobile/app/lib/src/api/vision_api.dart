import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';

class VisionApi {
  final Dio _dio;

  VisionApi(this._dio);

  Future<VisionAnalysisResponse> analyzeImage(Uint8List imageBytes) async {
    try {
      // Convert image to base64
      final base64Image = base64Encode(imageBytes);

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/vision/analyze',
        data: {
          'image': base64Image,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      return VisionAnalysisResponse.fromJson(response.data!);
    } catch (e) {
      throw Exception('Failed to analyze image: $e');
    }
  }
}

class VisionAnalysisResponse {
  final bool success;
  final List<DetectedItem> detected;
  final List<MatchedIngredient> matched;
  final double confidence;
  final RawAnalysis rawAnalysis;

  VisionAnalysisResponse({
    required this.success,
    required this.detected,
    required this.matched,
    required this.confidence,
    required this.rawAnalysis,
  });

  factory VisionAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return VisionAnalysisResponse(
      success: json['success'] ?? false,
      detected: (json['detected'] as List?)
          ?.map((item) => DetectedItem.fromJson(item))
          .toList() ?? [],
      matched: (json['matched'] as List?)
          ?.map((item) => MatchedIngredient.fromJson(item))
          .toList() ?? [],
      confidence: (json['confidence'] ?? 0).toDouble(),
      rawAnalysis: RawAnalysis.fromJson(json['rawAnalysis'] ?? {}),
    );
  }
}

class DetectedItem {
  final String type;
  final String name;
  final double confidence;

  DetectedItem({
    required this.type,
    required this.name,
    required this.confidence,
  });

  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    return DetectedItem(
      type: json['type'] ?? '',
      name: json['name'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
    );
  }
}

class MatchedIngredient {
  final String ingredientName;
  final double confidence;
  final String matchType;

  MatchedIngredient({
    required this.ingredientName,
    required this.confidence,
    required this.matchType,
  });

  factory MatchedIngredient.fromJson(Map<String, dynamic> json) {
    return MatchedIngredient(
      ingredientName: json['ingredientName'] ?? '',
      confidence: (json['confidence'] ?? 0).toDouble(),
      matchType: json['matchType'] ?? '',
    );
  }
}

class RawAnalysis {
  final String description;
  final List<dynamic> tags;
  final List<dynamic> brands;

  RawAnalysis({
    required this.description,
    required this.tags,
    required this.brands,
  });

  factory RawAnalysis.fromJson(Map<String, dynamic> json) {
    return RawAnalysis(
      description: json['description'] ?? '',
      tags: json['tags'] ?? [],
      brands: json['brands'] ?? [],
    );
  }
}
