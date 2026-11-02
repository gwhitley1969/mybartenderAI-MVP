import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybartenderai/src/services/subscription_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The method channel purchases_flutter talks to the native SDK on.
  const channel = MethodChannel('purchases_flutter');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> calls;

  setUp(() => calls = []);
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('enableAppleAdsAttribution', () {
    test('on iOS, enables AdServices token collection', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });

      await SubscriptionService.enableAppleAdsAttribution(isIOS: true);

      expect(calls, ['enableAdServicesAttributionTokenCollection']);
    });

    test('on Android, makes no SDK call', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });

      await SubscriptionService.enableAppleAdsAttribution(isIOS: false);

      expect(calls, isEmpty);
    });

    // Sign-in must not fail because attribution did.
    test('swallows a native error', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: '0', message: 'AdServices unavailable');
      });

      await expectLater(
        SubscriptionService.enableAppleAdsAttribution(isIOS: true),
        completes,
      );
    });

    test('swallows a missing plugin', () async {
      // No handler: invokeMethod throws MissingPluginException.
      await expectLater(
        SubscriptionService.enableAppleAdsAttribution(isIOS: true),
        completes,
      );
    });
  });
}
