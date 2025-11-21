import 'dart:convert';
import 'package:dio/dio.dart';

import 'auth_service.dart';
import '../config/app_config.dart';

/// Debug version of AskBartenderService with extensive logging
class DebugAskBartenderService {
  final Dio _dio;
  final AuthService _authService;

  DebugAskBartenderService({
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

  /// Send a message to the AI Bartender with detailed debugging
  Future<String> askBartender({
    required String message,
    String? context,
  }) async {
    try {
      print('===== DEBUG: Starting AI Bartender Request =====');
      print('Message: $message');
      print('Base URL: ${AppConfig.backendBaseUrl}');
      print('Endpoint: ${AppConfig.askBartenderEndpoint}');
      print('Full URL: ${AppConfig.backendBaseUrl}${AppConfig.askBartenderEndpoint}');

      // Get JWT access token for user authentication
      print('\n--- Retrieving JWT Token ---');
      final accessToken = await _authService.getValidAccessToken();

      if (accessToken == null) {
        print('ERROR: Token is NULL');
        throw Exception('Not authenticated. Please sign in to use AI Bartender.');
      }

      if (accessToken.isEmpty) {
        print('ERROR: Token is EMPTY');
        throw Exception('Not authenticated. Please sign in to use AI Bartender.');
      }

      print('Token retrieved successfully');
      print('Token length: ${accessToken.length}');
      print('Token preview: ${accessToken.substring(0, 50)}...');

      // Get APIM subscription key
      final subscriptionKey = AppConfig.functionKey;
      if (subscriptionKey == null || subscriptionKey.isEmpty) {
        print('ERROR: Missing APIM subscription key');
        throw Exception('App is not configured with API credentials. Please reinstall or contact support.');
      }
      print('\n--- Headers Being Sent ---');
      print('Authorization: Bearer [${accessToken.length} chars]');
      print('Ocp-Apim-Subscription-Key: ${subscriptionKey.substring(0, 10)}...');
      print('Content-Type: application/json');

      print('\n--- Request Body ---');
      final requestBody = {
        'message': message,
        'context': context ?? '',
      };
      print('Body: ${jsonEncode(requestBody)}');

      print('\n--- Sending Request ---');
      final response = await _dio.post(
        AppConfig.askBartenderEndpoint,
        data: requestBody,
        options: Options(
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Ocp-Apim-Subscription-Key': subscriptionKey,
          },
        ),
      );

      print('\n--- Response Received ---');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      print('Response Data Type: ${response.data.runtimeType}');
      print('Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final result = data['response'] ?? data['message'] ?? 'No response field found';
          print('Extracted response: $result');
          return result;
        } else if (data is String) {
          try {
            final parsed = json.decode(data);
            if (parsed is Map) {
              final result = parsed['response'] ?? parsed['message'] ?? data;
              print('Parsed response: $result');
              return result;
            }
          } catch (_) {
            print('Response is plain string: $data');
            return data;
          }
        }
        return 'Unexpected response format';
      } else {
        print('ERROR: Non-200 status code: ${response.statusCode}');
        throw Exception('Failed to get response: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('\n===== DIO EXCEPTION =====');
      print('Type: ${e.type}');
      print('Message: ${e.message}');
      print('Error: ${e.error}');

      if (e.response != null) {
        print('\n--- Error Response ---');
        print('Status Code: ${e.response?.statusCode}');
        print('Status Message: ${e.response?.statusMessage}');
        print('Headers: ${e.response?.headers}');
        print('Data: ${e.response?.data}');

        // Check for specific error messages
        if (e.response?.statusCode == 401) {
          final errorData = e.response?.data;
          if (errorData is Map) {
            print('Error details: ${errorData['message'] ?? errorData['error'] ?? 'Unknown'}');
          }
        }
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('The AI Bartender is taking too long to respond. Please try again.');
      }

      if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot connect to the AI Bartender. Please check your internet connection.');
      }

      throw Exception('Failed to communicate with the AI Bartender: ${e.message}');
    } catch (e, stackTrace) {
      print('\n===== GENERAL EXCEPTION =====');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('An unexpected error occurred: $e');
    }
  }
}
