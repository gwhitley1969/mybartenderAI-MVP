import 'dart:convert';
import 'package:dio/dio.dart';

import 'auth_service.dart';
import 'apim_subscription_service.dart';
import '../config/app_config.dart';

/// Service for interacting with the AI Bartender API
class AskBartenderService {
  final Dio _dio;
  final AuthService _authService;
  final ApimSubscriptionService _apimService;

  AskBartenderService({
    required AuthService authService,
    required ApimSubscriptionService apimService,
  }) : _authService = authService,
       _apimService = apimService,
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

      // Check if user has AI access (all tiers now have AI access)
      final hasAiAccess = await _apimService.hasAiAccess();
      if (!hasAiAccess) {
        throw Exception('Unable to access AI features. Please check your subscription.');
      }

      // Get both JWT and APIM subscription key for dual authentication
      final headers = await _apimService.getAuthHeaders();
      headers['Content-Type'] = 'application/json';

      print('Has Authorization header: ${headers.containsKey('Authorization')}');
      print('Has APIM subscription key: ${headers.containsKey('Ocp-Apim-Subscription-Key')}');

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
      print('=== DioException Details ===');
      print('DioException Type: ${e.type}');
      print('DioException Status Code: ${e.response?.statusCode}');
      print('DioException Response Data: ${e.response?.data}');
      print('=== End DioException Details ===');

      // Handle 401/403 with token re-exchange
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        print('Authentication error detected, attempting re-exchange...');

        // Try to re-exchange tokens
        final success = await _apimService.handleAuthError();

        if (success) {
          print('Re-exchange successful, retrying request...');

          // Retry the request with new credentials
          try {
            final retryHeaders = await _apimService.getAuthHeaders();
            retryHeaders['Content-Type'] = 'application/json';

            final retryResponse = await _dio.post(
              AppConfig.askBartenderEndpoint,
              data: {
                'message': message,
                'context': context ?? '',
              },
              options: Options(headers: retryHeaders),
            );

            if (retryResponse.statusCode == 200) {
              final data = retryResponse.data;
              if (data is Map) {
                return data['response'] ?? data['message'] ?? 'I received your message but couldn\'t generate a proper response.';
              } else if (data is String) {
                try {
                  final parsed = json.decode(data);
                  if (parsed is Map) {
                    return parsed['response'] ?? parsed['message'] ?? data;
                  }
                } catch (_) {
                  return data;
                }
              }
              return 'I received your message but couldn\'t generate a proper response.';
            }
          } catch (retryError) {
            print('Retry failed: $retryError');
            // Fall through to original error handling
          }
        }

        // If re-exchange failed or retry failed
        if (e.response?.statusCode == 403) {
          throw Exception('Your subscription may not include AI features. Please check your subscription status.');
        } else {
          throw Exception('Authentication failed. Please sign in again.');
        }
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

      // Handle rate limit (429)
      if (e.response?.statusCode == 429) {
        throw Exception('You\'ve reached your monthly limit. Please upgrade your plan or wait until next month.');
      }

      // Extract error message
      String errorMessage = 'Service temporarily unavailable';
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          final errorMap = e.response!.data as Map;
          errorMessage = errorMap['message'] ?? errorMap['error'] ?? errorMessage;

          // Check for specific error codes
          final errorCode = errorMap['code'];
          if (errorCode == 'RATE_LIMIT_EXCEEDED') {
            errorMessage = 'Rate limit exceeded. Please upgrade your plan or try again later.';
          } else if (errorCode == 'INSUFFICIENT_PERMISSIONS') {
            errorMessage = 'This feature requires a Premium or Pro subscription.';
          }
        }
      }

      throw Exception(errorMessage);
    } catch (e) {
      print('=== Unexpected Error ===');
      print('Error type: ${e.runtimeType}');
      print('Error calling ask-bartender: $e');
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }
}
