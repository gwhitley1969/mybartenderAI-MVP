import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybartenderai/src/utils/cocktail_links.dart';

void main() {
  group('cocktailDeepLinkRedirect', () {
    const mapped = <String, String>{
      // The custom scheme puts "cocktail" in the host, so the path is "/17005".
      'mybartender://cocktail/17005': '/cocktail/17005',
      'mybartender://cocktail/17005/': '/cocktail/17005',
      // Share URL the app used up to v1.2.2.
      'https://share.mybartenderai.com/api/cocktail/17005': '/cocktail/17005',
      // Facebook appends fbclid to outbound links.
      'https://share.mybartenderai.com/api/cocktail/17005?fbclid=IwAR0x':
          '/cocktail/17005',
      // An encoded slash stays inside the id instead of adding a segment.
      'mybartender://cocktail/a%2Fb': '/cocktail/a%2Fb',
    };
    mapped.forEach((link, location) {
      test('maps $link to $location', () {
        expect(cocktailDeepLinkRedirect(Uri.parse(link)), location);
      });
    });

    const unmapped = <String>[
      // In-app locations: returning anything here would hijack navigation.
      '/',
      '/cocktail/17005',
      // Not a shared-cocktail link.
      'mybartender://recipe/17005',
      'https://example.com/api/cocktail/17005',
      // Malformed.
      'mybartender://cocktail',
      'https://share.mybartenderai.com/api/cocktail/',
      'https://share.mybartenderai.com/api/cocktail/17005/extra',
    ];
    for (final link in unmapped) {
      test('leaves $link alone', () {
        expect(cocktailDeepLinkRedirect(Uri.parse(link)), isNull);
      });
    }
  });

  // The platform hands go_router the full link (scheme and host included),
  // and go_router matches routes on the path alone. These run a link through
  // a router built like the app's to check the redirect sees the whole URI.
  group('platform deep links', () {
    GoRouter buildRouter() => GoRouter(
          initialLocation: '/',
          redirect: (_, state) => cocktailDeepLinkRedirect(state.uri),
          routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('home')),
            GoRoute(
              path: '/cocktail/:id',
              builder: (_, state) =>
                  Text('cocktail ${state.pathParameters['id']}'),
            ),
          ],
        );

    testWidgets('a custom-scheme link opens the cocktail on cold start',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          'mybartender://cocktail/17005';
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
      await tester.pumpAndSettle();

      expect(find.text('cocktail 17005'), findsOneWidget);
    });

    testWidgets('a v1.2.2 share link opens the cocktail while the app runs',
        (tester) async {
      await tester.pumpWidget(MaterialApp.router(routerConfig: buildRouter()));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);

      await _pushPlatformRoute(
          tester, 'https://share.mybartenderai.com/api/cocktail/17005');

      expect(find.text('cocktail 17005'), findsOneWidget);
    });
  });
}

/// Sends a link the way the Android and iOS embeddings do when the app is
/// already running (`pushRouteInformation` on the navigation channel).
Future<void> _pushPlatformRoute(WidgetTester tester, String location) async {
  final message = const JSONMethodCodec().encodeMethodCall(
    MethodCall('pushRouteInformation', <String, dynamic>{'location': location}),
  );
  await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage('flutter/navigation', message, (_) {});
  await tester.pumpAndSettle();
}
