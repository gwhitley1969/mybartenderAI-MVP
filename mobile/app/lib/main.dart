import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/app/bootstrap.dart';
import 'src/features/ask_bartender/chat_screen.dart';
import 'src/features/age_verification/age_verification_screen.dart';
import 'src/features/auth/login_screen.dart';
import 'src/features/create_studio/create_studio_screen.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/profile/profile_screen.dart';
import 'src/features/smart_scanner/smart_scanner_screen.dart';
import 'src/features/voice_bartender/voice_bartender_screen.dart';
import 'src/models/auth_state.dart';
import 'src/providers/auth_provider.dart';

Future<void> main() async {
  await bootstrap(
    () => const MyBartenderApp(),
    config: const EnvConfig(
      apiBaseUrl: 'https://func-mba-fresh.azurewebsites.net/api',
      // NOTE: Function key required for backend endpoints
      // TODO: Move to secure storage/environment variables for production
      // For development: Set AZURE_FUNCTION_KEY environment variable or use secure storage
      functionKey: String.fromEnvironment('AZURE_FUNCTION_KEY', defaultValue: 'YOUR_FUNCTION_KEY_HERE'),
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

/// The router configuration with authentication guards.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final isAgeVerified = ref.watch(ageVerificationProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      // Get authentication status
      final isAuthenticated = authState is AuthStateAuthenticated;
      final isAuthenticating = authState is AuthStateLoading || authState is AuthStateInitial;
      final isLoginRoute = state.matchedLocation == '/login';
      final isAgeRoute = state.matchedLocation == '/age-verification';

      // Don't redirect while checking authentication status
      if (isAuthenticating) {
        return null;
      }

      // Check age verification first (unless already on age verification page)
      if (!isAgeVerified && !isAgeRoute) {
        return '/age-verification';
      }

      // Skip these checks if on age verification page
      if (isAgeRoute) {
        return null;
      }

      // Redirect to login if not authenticated and trying to access protected routes
      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      // Redirect to home if authenticated and on login page
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: <RouteBase>[
      // Age verification route (first screen)
      GoRoute(
        path: '/age-verification',
        builder: (BuildContext context, GoRouterState state) {
          return const AgeVerificationScreen();
        },
      ),
      // Login route (public)
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      // Home route (protected)
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
            path: 'voice-bartender',
            builder: (BuildContext context, GoRouterState state) {
              return const VoiceBartenderScreen();
            },
          ),
          GoRoute(
            path: 'smart-scanner',
            builder: (BuildContext context, GoRouterState state) {
              return const SmartScannerScreen();
            },
          ),
          GoRoute(
            path: 'create-studio',
            builder: (BuildContext context, GoRouterState state) {
              return const CreateStudioScreen();
            },
          ),
          GoRoute(
            path: 'profile',
            builder: (BuildContext context, GoRouterState state) {
              return const ProfileScreen();
            },
          ),
        ],
      ),
    ],
  );
});
