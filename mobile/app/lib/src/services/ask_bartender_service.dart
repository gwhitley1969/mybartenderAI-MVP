import 'dart:convert';
import 'package:dio/dio.dart';

/// Service for interacting with the AI Bartender API
class AskBartenderService {
  final Dio _dio;
  static const String _baseUrl = 'https://func-mba-fresh.azurewebsites.net';

  AskBartenderService() : _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  /// Send a message to the AI Bartender and get a response
  Future<String> askBartender({
    required String message,
    String? context,
  }) async {
    try {
      print('Sending message to AI Bartender: $message');
      if (context != null) {
        print('Context: $context');
      }

      final response = await _dio.post(
        '/api/v1/ask-bartender-simple',
        data: {
          'message': message,
          'context': context ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Handle different response formats
        if (data is Map) {
          return data['response'] ?? data['message'] ?? 'I received your message but couldn\'t generate a proper response.';
        } else if (data is String) {
          try {
            final parsed = json.decode(data);
            if (parsed is Map) {
              return parsed['response'] ?? parsed['message'] ?? data;
            }
          } catch (_) {
            // If it's not JSON, return the string as is
            return data;
          }
        }
        return 'I received your message but couldn\'t generate a proper response.';
      } else {
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('DioException calling ask-bartender: ${e.message}');
      if (e.response != null) {
        print('Response data: ${e.response?.data}');
        print('Response status: ${e.response?.statusCode}');
      }

      // Check if it's a timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('The AI Bartender is taking too long to respond. Please try again.');
      }

      // Check for network issues
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot connect to the AI Bartender. Please check your internet connection.');
      }

      throw Exception('Failed to communicate with the AI Bartender: ${e.message}');
    } catch (e) {
      print('Error calling ask-bartender: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }
}