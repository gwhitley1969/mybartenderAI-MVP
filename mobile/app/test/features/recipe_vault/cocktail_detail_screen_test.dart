import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mybartenderai/src/features/recipe_vault/cocktail_detail_screen.dart';
import 'package:mybartenderai/src/models/models.dart';
import 'package:mybartenderai/src/providers/cocktail_provider.dart';

void main() {
  // A link opens the detail screen as the only page on the stack, so there is
  // nothing for the back arrow to pop.
  final cases = <String, Future<Cocktail?> Function()>{
    // Not in the local database (for example, before the first sync).
    'Cocktail not found': () async => null,
    'Error loading cocktail': () async => throw StateError('database closed'),
  };
  cases.forEach((message, lookup) {
    testWidgets('back from a linked cocktail showing "$message" goes home',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          'https://share.mybartenderai.com/cocktail/17005';
      addTearDown(
          tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('home')),
          GoRoute(
            path: '/cocktail/:id',
            builder: (_, state) =>
                CocktailDetailScreen(cocktailId: state.pathParameters['id']!),
          ),
        ],
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [cocktailByIdProvider.overrideWith((ref, id) => lookup())],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });
}
