import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'src/app/bootstrap.dart';
import 'src/features/academy/academy_screen.dart';
import 'src/features/pro_tools/pro_tools_screen.dart';
import 'src/features/ask_bartender/chat_screen.dart';
import 'src/features/voice_ai/voice_ai_screen.dart';
import 'src/features/age_verification/age_verification_screen.dart';
import 'src/features/auth/login_screen.dart';
import 'src/features/create_studio/create_studio_screen.dart';
import 'src/features/home/home_screen.dart';
import 'src/features/initial_sync/initial_sync_screen.dart';
import 'src/features/profile/profile_screen.dart';
import 'src/features/recipe_vault/cocktail_detail_screen.dart';
import 'src/features/smart_scanner/smart_scanner_screen.dart';
import 'src/models/auth_state.dart';
import 'src/providers/auth_provider.dart';
import 'src/providers/cocktail_provider.dart';
import 'src/services/notification_service.dart';

/// Global navigator key for navigation from notification taps
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global router instance for notification navigation when app is already running
GoRouter? _globalRouter;

/// Notifier that triggers GoRouter redirect re-evaluation when auth state changes.
///
/// This pattern prevents router recreation (which loses navigation state).
/// When any watched provider changes, we call notifyListeners() which triggers
/// GoRouter to re-evaluate its redirect function WITHOUT creating a new router.
///
/// FIX for Issue #5: Today's Special notification deep link regression.
/// The previous implementation used ref.watch() directly in routerProvider,
/// which caused the entire GoRouter to be recreated on state changes,
/// losing the navigation stack (including the cocktail detail route).
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    // Listen to auth changes - notifyListeners triggers redirect re-evaluation
    ref.listen(authNotifierProvider, (_, __) {
      debugPrint('[ROUTER] Auth state changed - triggering redirect re-evaluation');
      notifyListeners();
    });

    // Listen to age verification changes
    ref.listen(ageVerificationProvider, (_, __) {
      debugPrint('[ROUTER] Age verification changed - triggering redirect re-evaluation');
      notifyListeners();
    });

    // Listen to initial sync status changes
    ref.listen(initialSyncStatusProvider, (_, __) {
      debugPrint('[ROUTER] Initial sync status changed - triggering redirect re-evaluation');
      notifyListeners();
    });
  }
}

/// Provider for the router refresh notifier.
/// This is watched by routerProvider but doesn't cause rebuilds because
/// the notifier itself is stable - it just calls notifyListeners() when state changes.
final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  return RouterRefreshNotifier(ref);
});

Future<void> main() async {
  await bootstrap(
    () => const MyBartenderApp(),
    config: const EnvConfig(
      // Azure Front Door → APIM → Functions
      apiBaseUrl: 'https://share.mybartenderai.com/api',
      // NOTE: Using JWT-only authentication (no APIM subscription keys)
      // APIM validates ID token, backend looks up user tier from database
    ),
  );
}

class MyBartenderApp extends ConsumerStatefulWidget {
  const MyBartenderApp({super.key});

  @override
  ConsumerState<MyBartenderApp> createState() => _MyBartenderAppState();
}

class _MyBartenderAppState extends ConsumerState<MyBartenderApp> {
  // Store pending cocktail ID for navigation after app is fully loaded
  static String? _pendingCocktailId;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await NotificationService.instance.initialize(
      onTap: (cocktailId) {
        // Navigate to cocktail detail when notification is tapped
        debugPrint('Notification tap callback received: $cocktailId');
        // Filter out token refresh notifications - they're not cocktail IDs
        if (cocktailId != null && cocktailId != 'TOKEN_REFRESH_TRIGGER') {
          // Use a slight delay to ensure we're not in the middle of a build
          Future.microtask(() => _navigateToCocktail(cocktailId));
        }
      },
    );

    // Check if app was launched from a notification
    final launchDetails = await NotificationService.instance.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      // Filter out token refresh notifications - they're not cocktail IDs
      if (payload != null && payload != 'TOKEN_REFRESH_TRIGGER') {
        _pendingCocktailId = payload;
        // Delay navigation to ensure router is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToCocktail(payload);
        });
      }
    }
  }

  void _navigateToCocktail(String cocktailId) {
    debugPrint('Attempting to navigate to cocktail: $cocktailId');

    // Method 1: Use the global router directly (most reliable when app is running)
    if (_globalRouter != null) {
      debugPrint('Using global router to navigate');
      _globalRouter!.push('/cocktail/$cocktailId');
      debugPrint('Navigation pushed via global router');
      return;
    }

    // Method 2: Try using the navigator key's current state
    final navigatorState = _rootNavigatorKey.currentState;
    if (navigatorState != null) {
      debugPrint('Using navigator state to push route');
      final context = _rootNavigatorKey.currentContext;
      if (context != null) {
        GoRouter.of(context).push('/cocktail/$cocktailId');
        debugPrint('Navigation pushed successfully');
        return;
      }
    }

    // Method 3: Fallback - try context directly
    final context = _rootNavigatorKey.currentContext;
    if (context != null) {
      debugPrint('Using context.push fallback');
      context.push('/cocktail/$cocktailId');
    } else {
      // Store for later if context not ready
      debugPrint('Context not ready, storing for later');
      _pendingCocktailId = cocktailId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Store router globally for notification navigation when app is already running
    _globalRouter = router;

    // FIX: Check for pending navigation after router is ready
    if (_pendingCocktailId != null) {
      final cocktailId = _pendingCocktailId!;
      _pendingCocktailId = null;
      debugPrint('Processing pending cocktail navigation: $cocktailId');
      // Use microtask to avoid building during build
      Future.microtask(() => _navigateToCocktail(cocktailId));
    }

    return MaterialApp.router(
      routerConfig: router,
      title: 'My AI Bartender',
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
      // Limit text scaling to prevent layout overflow with accessibility fonts
      // Max 1.3x still provides accessibility while preventing UI breakage
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final constrainedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: constrainedTextScaler),
          child: child!,
        );
      },
    );
  }
}

/// The router configuration with authentication guards.
///
/// Uses refreshListenable pattern to prevent router recreation on state changes.
/// This is the GoRouter best practice for Riverpod integration.
///
/// FIX for Issue #5: The previous implementation used ref.watch() on state
/// providers, which caused the entire GoRouter to be recreated when state
/// changed. This lost the navigation stack, breaking notification deep links.
final routerProvider = Provider<GoRouter>((ref) {
  // Get the refresh notifier - this does NOT cause rebuilds because
  // the notifier itself is stable (it just calls notifyListeners on changes)
  final refreshNotifier = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    // KEY FIX: Use refreshListenable instead of ref.watch() on state providers
    // This re-evaluates redirects WITHOUT recreating the router, preserving nav stack
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      // Use ref.read() inside redirect - reads current state without subscribing
      // This is called whenever refreshNotifier.notifyListeners() is triggered
      final authState = ref.read(authNotifierProvider);
      final isAgeVerified = ref.read(ageVerificationProvider);
      final initialSyncStatus = ref.read(initialSyncStatusProvider);

      // Get authentication status
      final isAuthenticated = authState is AuthStateAuthenticated;
      final isAuthenticating = authState is AuthStateLoading || authState is AuthStateInitial;
      final isLoginRoute = state.matchedLocation == '/login';
      final isAgeRoute = state.matchedLocation == '/age-verification';
      final isInitialSyncRoute = state.matchedLocation == '/initial-sync';
      // FIX: Allow cocktail detail route to bypass redirects (for notification deep linking)
      final isCocktailRoute = state.matchedLocation.startsWith('/cocktail/');

      // Don't redirect while checking authentication status
      if (isAuthenticating) {
        return null;
      }

      // FIX: Allow cocktail routes through without age/auth checks
      // This ensures notification deep links work properly
      if (isCocktailRoute) {
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

      // Check if initial sync is needed (only for authenticated users)
      // Don't redirect if already on initial-sync page, cocktail route (deep link), or still checking
      if (isAuthenticated && !isInitialSyncRoute && !isCocktailRoute && !initialSyncStatus.isChecking) {
        if (initialSyncStatus.needsSync) {
          return '/initial-sync';
        }
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
      // Initial sync route (shown after first login when database is empty)
      GoRoute(
        path: '/initial-sync',
        builder: (BuildContext context, GoRouterState state) {
          return const InitialSyncScreen();
        },
      ),
      // Cocktail detail route (for deep linking from notifications)
      GoRoute(
        path: '/cocktail/:id',
        builder: (BuildContext context, GoRouterState state) {
          final cocktailId = state.pathParameters['id']!;
          return CocktailDetailScreen(cocktailId: cocktailId);
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
          GoRoute(
            path: 'academy',
            builder: (BuildContext context, GoRouterState state) {
              return const AcademyScreen();
            },
          ),
          GoRoute(
            path: 'pro-tools',
            builder: (BuildContext context, GoRouterState state) {
              return const ProToolsScreen();
            },
          ),
          GoRoute(
            path: 'voice-ai',
            builder: (BuildContext context, GoRouterState state) {
              return const VoiceAIScreen();
            },
          ),
        ],
      ),
    ],
  );
});
