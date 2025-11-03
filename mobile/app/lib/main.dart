import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/app/bootstrap.dart';
import 'src/features/ask_bartender/chat_screen.dart';
import 'src/features/ask_bartender/voice_chat_screen.dart';
import 'src/features/demo/voice_demo_screen.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/smart_scanner/smart_scanner_screen.dart';

Future<void> main() async {
  await bootstrap(
    () => const MyBartenderApp(),
    config: const EnvConfig(
      apiBaseUrl: 'https://func-mba-fresh.azurewebsites.net/api',
      // NOTE: Function key required for backend endpoints
      // TODO: Replace with actual key from secure storage/environment variables
      // For development: Copy function key from Azure Portal -> Function App -> Functions -> Keys
      functionKey: 'YOUR_FUNCTION_KEY_HERE',
    ),
  );
}

class MyBartenderApp extends ConsumerWidget {
  const MyBartenderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      routerConfig: router,
      title: 'MyBartenderAI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF16213E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }
}

/// The router configuration.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const HomeScreen();
        },
        routes: [
          GoRoute(
            path: 'ask-bartender',
            builder: (BuildContext context, GoRouterState state) {
              return const AskBartenderScreen();
            },
          ),
          GoRoute(
            path: 'voice-chat',
            builder: (BuildContext context, GoRouterState state) {
              return const VoiceChatScreen();
            },
          ),
          GoRoute(
            path: 'voice-demo',
            builder: (BuildContext context, GoRouterState state) {
              return const VoiceDemoScreen();
            },
          ),
          GoRoute(
            path: 'smart-scanner',
            builder: (BuildContext context, GoRouterState state) {
              return const SmartScannerScreen();
            },
          ),
        ],
      ),
    ],
  );
});
