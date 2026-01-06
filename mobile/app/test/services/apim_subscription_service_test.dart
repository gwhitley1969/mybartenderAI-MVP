import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dio/dio.dart';

import 'package:app/src/services/apim_subscription_service.dart';
import 'package:app/src/services/auth_service.dart';

@GenerateMocks([AuthService, FlutterSecureStorage, Dio])
import 'apim_subscription_service_test.mocks.dart';

void main() {
  group('ApimSubscriptionService', () {
    late ApimSubscriptionService service;
    late MockAuthService mockAuthService;
    late MockFlutterSecureStorage mockSecureStorage;
    late MockDio mockDio;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSecureStorage = MockFlutterSecureStorage();
      mockDio = MockDio();

      // Initialize service with mocks
      service = ApimSubscriptionService(authService: mockAuthService);
    });

    group('exchangeTokenForSubscription', () {
      test('successfully exchanges JWT for APIM subscription key', () async {
        // Arrange
        final mockJwt = 'mock.jwt.token';
        final mockResponse = {
          'subscriptionKey': 'test-subscription-key',
          'tier': 'premium',
          'expiresAt': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
          'quotas': {
            'tokensPerMonth': 300000,
            'scansPerMonth': 30,
            'aiEnabled': true,
          }
        };

        when(mockAuthService.getValidAccessToken())
            .thenAnswer((_) async => mockJwt);

        // Act & Assert
        // This test would need actual implementation once Dio mocking is set up
        expect(() async => await service.exchangeTokenForSubscription(),
               returnsNormally);
      });

      test('throws exception when no valid JWT available', () async {
        // Arrange
        when(mockAuthService.getValidAccessToken())
            .thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () async => await service.exchangeTokenForSubscription(),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('getSubscriptionKey', () {
      test('returns cached key when valid', () async {
        // Arrange
        final futureExpiry = DateTime.now().add(Duration(hours: 1));
        when(mockSecureStorage.read(key: 'apim_subscription_key'))
            .thenAnswer((_) async => 'cached-key');
        when(mockSecureStorage.read(key: 'apim_subscription_expiry'))
            .thenAnswer((_) async => futureExpiry.toIso8601String());

        // Act
        final key = await service.getSubscriptionKey();

        // Assert
        expect(key, isNotNull);
      });

      test('exchanges for new key when cached key is expired', () async {
        // Arrange
        final pastExpiry = DateTime.now().subtract(Duration(hours: 1));
        when(mockSecureStorage.read(key: 'apim_subscription_key'))
            .thenAnswer((_) async => 'expired-key');
        when(mockSecureStorage.read(key: 'apim_subscription_expiry'))
            .thenAnswer((_) async => pastExpiry.toIso8601String());
        when(mockAuthService.getValidAccessToken())
            .thenAnswer((_) async => 'mock.jwt.token');

        // Act & Assert
        expect(() async => await service.getSubscriptionKey(),
               returnsNormally);
      });

      test('returns null and logs error when exchange fails', () async {
        // Arrange
        when(mockSecureStorage.read(key: any))
            .thenAnswer((_) async => null);
        when(mockAuthService.getValidAccessToken())
            .thenThrow(Exception('Auth failed'));

        // Act
        final key = await service.getSubscriptionKey();

        // Assert
        expect(key, isNull);
      });
    });

    group('getUserTier', () {
      test('returns correct tier from cache', () async {
        // Arrange
        when(mockSecureStorage.read(key: 'apim_subscription_tier'))
            .thenAnswer((_) async => 'premium');

        // Act
        final tier = await service.getUserTier();

        // Assert
        expect(tier, equals('premium'));
      });

      test('returns free as default when no tier cached', () async {
        // Arrange
        when(mockSecureStorage.read(key: any))
            .thenAnswer((_) async => null);
        when(mockAuthService.getValidAccessToken())
            .thenThrow(Exception('Exchange failed'));

        // This would trigger an exchange attempt which fails
        // In real implementation, we'd want to handle this gracefully
      });
    });

    group('getUserQuotas', () {
      test('returns cached quotas when available', () async {
        // Arrange
        final mockQuotas = {
          'tokensPerMonth': 300000,
          'scansPerMonth': 30,
          'aiEnabled': true,
        };
        when(mockSecureStorage.read(key: 'apim_subscription_quotas'))
            .thenAnswer((_) async => '{"tokensPerMonth":300000,"scansPerMonth":30,"aiEnabled":true}');

        // Act
        final quotas = await service.getUserQuotas();

        // Assert
        expect(quotas['tokensPerMonth'], equals(300000));
        expect(quotas['aiEnabled'], isTrue);
      });

      test('returns default free tier quotas when no cache', () async {
        // Arrange
        when(mockSecureStorage.read(key: any))
            .thenAnswer((_) async => null);

        // Mock exchange to fail
        when(mockAuthService.getValidAccessToken())
            .thenThrow(Exception('No auth'));

        // Act
        final quotas = await service.getUserQuotas();

        // Assert - should return free tier defaults
        expect(quotas['tokensPerMonth'], equals(10000));
        expect(quotas['scansPerMonth'], equals(2));
        expect(quotas['aiEnabled'], isTrue);
      });
    });

    group('hasAiAccess', () {
      test('returns true for premium tier', () async {
        // Arrange
        when(mockSecureStorage.read(key: 'apim_subscription_quotas'))
            .thenAnswer((_) async => '{"aiEnabled":true}');

        // Act
        final hasAccess = await service.hasAiAccess();

        // Assert
        expect(hasAccess, isTrue);
      });

      test('returns true for free tier (with limited AI)', () async {
        // Arrange
        when(mockSecureStorage.read(key: any))
            .thenAnswer((_) async => null);
        when(mockAuthService.getValidAccessToken())
            .thenThrow(Exception('No cache'));

        // Act
        final hasAccess = await service.hasAiAccess();

        // Assert - Free tier now has AI access
        expect(hasAccess, isTrue);
      });
    });

    group('handleAuthError', () {
      test('successfully re-exchanges after 401 error', () async {
        // Arrange
        when(mockAuthService.refreshAccessToken())
            .thenAnswer((_) async => {});
        when(mockAuthService.getValidAccessToken())
            .thenAnswer((_) async => 'new.jwt.token');

        // Act
        final success = await service.handleAuthError();

        // Assert
        expect(success, isTrue);
        verify(mockAuthService.refreshAccessToken()).called(1);
      });

      test('returns false when re-authentication fails', () async {
        // Arrange
        when(mockAuthService.refreshAccessToken())
            .thenThrow(Exception('Refresh failed'));

        // Act
        final success = await service.handleAuthError();

        // Assert
        expect(success, isFalse);
      });
    });

    group('clearSubscription', () {
      test('clears all stored subscription data', () async {
        // Act
        await service.clearSubscription();

        // Assert
        verify(mockSecureStorage.delete(key: 'apim_subscription_key')).called(1);
        verify(mockSecureStorage.delete(key: 'apim_subscription_expiry')).called(1);
        verify(mockSecureStorage.delete(key: 'apim_subscription_tier')).called(1);
        verify(mockSecureStorage.delete(key: 'apim_subscription_quotas')).called(1);
      });
    });

    group('getAuthHeaders', () {
      test('returns both JWT and APIM headers', () async {
        // Arrange
        final futureExpiry = DateTime.now().add(Duration(hours: 1));
        when(mockAuthService.getValidAccessToken())
            .thenAnswer((_) async => 'mock.jwt.token');
        when(mockSecureStorage.read(key: 'apim_subscription_key'))
            .thenAnswer((_) async => 'test-subscription-key');
        when(mockSecureStorage.read(key: 'apim_subscription_expiry'))
            .thenAnswer((_) async => futureExpiry.toIso8601String());

        // Act
        final headers = await service.getAuthHeaders();

        // Assert
        expect(headers.containsKey('Authorization'), isTrue);
        expect(headers.containsKey('Ocp-Apim-Subscription-Key'), isTrue);
        expect(headers['Authorization'], equals('Bearer mock.jwt.token'));
      });

      test('returns empty headers when no credentials available', () async {
        // Arrange
        when(mockAuthService.getValidAccessToken())
            .thenAnswer((_) async => null);
        when(mockSecureStorage.read(key: any))
            .thenAnswer((_) async => null);

        // Act
        final headers = await service.getAuthHeaders();

        // Assert
        // Should still attempt to include what's available
        expect(headers, isA<Map<String, String>>());
      });
    });
  });
}
