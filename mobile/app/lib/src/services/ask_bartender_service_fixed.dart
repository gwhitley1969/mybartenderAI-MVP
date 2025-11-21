import 'dart:convert';
import 'package:dio/dio.dart';

import 'auth_service.dart';
import '../config/app_config.dart';

/// Service for interacting with the AI Bartender API
class AskBartenderService {
  final Dio _dio;
  final AuthService _authService;

  AskBartenderService({
    required AuthService authService,
  }) : _authService = authService,
       _dio = Dio(BaseOptions(
    baseUrl: AppConfig.backendBaseUrl,
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
      print('=== AI Bartender Request Debug ===');
      print('Base URL: ${AppConfig.backendBaseUrl}');
      print('Endpoint: ${AppConfig.askBartenderEndpoint}');
      print('Full URL: ${AppConfig.backendBaseUrl}${AppConfig.askBartenderEndpoint}');
      print('Message: $message');
      if (context != null) {
        print('Context: $context');
      }

      // Get JWT access token for user authentication
      final accessToken = await _authService.getValidAccessToken();
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Please sign in to use the AI Bartender.');
      }
      print('Has access token: ${accessToken.length > 0}');

      // APIM subscription key is provided at build time via --dart-define
      final subscriptionKey = AppConfig.functionKey;
      if (subscriptionKey == null || subscriptionKey.isEmpty) {
        // For debugging, use the hardcoded key temporarily
        // TODO: Remove this after fixing build process
        final fallbackKey = 'a4f267a3dd1b4cdba4e9cb4d29e565c0';
        print('WARNING: Using fallback subscription key for debugging');

        final headers = <String, String>{
          'Ocp-Apim-Subscription-Key': fallbackKey,
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        };

        print('Request headers (keys only): ${headers.keys.toList()}');

        // Match PowerShell test exactly
        final requestBody = {
          'message': message,
          'context': context ?? '',
        };

        print('Request body: ${json.encode(requestBody)}');

        final response = await _dio.post(
          AppConfig.askBartenderEndpoint,
          data: requestBody,
          options: Options(
            headers: headers,
          ),
        );

        print('Response status: ${response.statusCode}');
        print('Response data type: ${response.data.runtimeType}');

        if (response.statusCode == 200) {
          final data = response.data;
          // Handle different response formats
          if (data is Map) {
            print('Response is Map with keys: ${data.keys.toList()}');
            return data['response'] ?? data['message'] ?? 'I received your message but couldn\'t generate a proper response.';
          } else if (data is String) {
            print('Response is String, attempting JSON parse');
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
      }

      final headers = <String, String>{
        'Ocp-Apim-Subscription-Key': subscriptionKey,
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

      print('Request headers (keys only): ${headers.keys.toList()}');

      // Match PowerShell test exactly
      final requestBody = {
        'message': message,
        'context': context ?? '',
      };

      print('Request body: ${json.encode(requestBody)}');

      final response = await _dio.post(
        AppConfig.askBartenderEndpoint,
        data: requestBody,
        options: Options(
          headers: headers,
        ),
      );

      print('Response status: ${response.statusCode}');
      print('Response data type: ${response.data.runtimeType}');

      if (response.statusCode == 200) {
        final data = response.data;
        // Handle different response formats
        if (data is Map) {
          print('Response is Map with keys: ${data.keys.toList()}');
          return data['response'] ?? data['message'] ?? 'I received your message but couldn\'t generate a proper response.';
        } else if (data is String) {
          print('Response is String, attempting JSON parse');
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
      // ENHANCED ERROR HANDLING - Show real errors
      print('=== DioException Details ===');
      print('DioException Type: ${e.type}');
      print('DioException Message: ${e.message}');
      print('DioException Status Code: ${e.response?.statusCode}');
      print('DioException Status Message: ${e.response?.statusMessage}');
      print('DioException Headers: ${e.response?.headers}');
      print('DioException Response Data: ${e.response?.data}');
      print('DioException Request URI: ${e.requestOptions.uri}');
      print('DioException Request Headers: ${e.requestOptions.headers}');
      print('DioException Full Error: ${e.toString()}');
      print('=== End DioException Details ===');

      // Check if it's a timeout
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('The AI Bartender is taking too long to respond. Please try again.');
      }

      // Check for network issues
      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot connect to the AI Bartender. Please check your internet connection.');
      }

      // For debugging, throw detailed error
      // In production, you'd want to sanitize this
      final statusCode = e.response?.statusCode ?? 'Unknown';
      final errorData = e.response?.data ?? 'No error details';

      // Try to extract meaningful error message
      String errorMessage = 'API Error (Status $statusCode)';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          final errorMap = e.response!.data as Map;
          errorMessage = errorMap['message'] ?? errorMap['error'] ?? errorMessage;
        } else if (e.response!.data is String) {
          errorMessage = e.response!.data as String;
        }
      }

      print('Throwing error: $errorMessage');
      throw Exception('$errorMessage\nStatus: $statusCode\nDetails: $errorData');
    } catch (e) {
      print('=== Unexpected Error ===');
      print('Error type: ${e.runtimeType}');
      print('Error calling ask-bartender: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }
}