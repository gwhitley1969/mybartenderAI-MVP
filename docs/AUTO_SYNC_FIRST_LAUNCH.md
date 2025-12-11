# Auto-Sync Cocktail Database on First Launch

**Last Updated:** December 2025
**Status:** Implemented and Tested

## Overview

When a user installs MyBartenderAI for the first time, the cocktail database (621 recipes) is now automatically downloaded after they sign in. Previously, users had to manually navigate to Recipe Vault and tap the sync button to populate their local database.

## Problem

- New users would see an empty Recipe Vault after installation
- Users had to discover the sync button manually
- Poor first-time user experience

## Solution

Implemented an automatic first-launch sync that:
1. Detects when the database is empty (no cocktails)
2. Shows a friendly "Setting Up Your Cocktail Library" screen
3. Automatically downloads all 621 cocktail recipes
4. Displays progress indicator during download
5. Navigates to Home screen when complete

## User Flow

### First Launch (New Install)
```
App Install
    ↓
Age Verification Screen
    ↓
Login Screen → Sign In
    ↓
Router detects: authenticated + empty database
    ↓
┌─────────────────────────────────┐
│                                 │
│      [Cocktail Glass Icon]      │
│                                 │
│    Setting Up Your              │
│    Cocktail Library             │
│                                 │
│    Downloading 621 cocktail     │
│    recipes for offline access   │
│                                 │
│    ████████████░░░░░░  65%      │
│                                 │
│    This only happens once       │
│                                 │
└─────────────────────────────────┘
    ↓
Sync Complete → Home Screen
```

### Subsequent Opens
```
Open App
    ↓
Router detects: authenticated + has cocktails (621)
    ↓
Go directly to Home Screen (no sync screen)
```

## Implementation Details

### Architecture

Uses the same pattern as Age Verification - a StateNotifier provider that the router watches to determine where to redirect.

### Files Modified/Created

| File | Purpose |
|------|---------|
| `lib/src/features/initial_sync/initial_sync_screen.dart` | **New** - UI for sync progress |
| `lib/src/providers/cocktail_provider.dart` | Added `InitialSyncStatusNotifier` and provider |
| `lib/main.dart` | Added route guard and `/initial-sync` route |

### Key Components

#### 1. InitialSyncStatusNotifier (`cocktail_provider.dart`)

```dart
class InitialSyncStatusNotifier extends StateNotifier<InitialSyncStatus> {
  InitialSyncStatusNotifier(this._databaseService)
      : super(const InitialSyncStatus.checking()) {
    _checkDatabase();
  }

  Future<void> _checkDatabase() async {
    final count = await _databaseService.getCocktailCount();
    if (count > 0) {
      state = const InitialSyncStatus.hasData();
    } else {
      state = const InitialSyncStatus.needsSync();
    }
  }

  void markSyncCompleted() {
    state = const InitialSyncStatus.hasData();
  }
}
```

**States:**
- `checking` - Initial state while querying database
- `needsSync` - Database is empty, needs sync
- `hasData` - Database has cocktails, no sync needed

#### 2. Router Guard (`main.dart`)

```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final isAgeVerified = ref.watch(ageVerificationProvider);
  final initialSyncStatus = ref.watch(initialSyncStatusProvider);

  return GoRouter(
    redirect: (context, state) {
      // ... age verification and auth checks ...

      // Check if initial sync is needed (only for authenticated users)
      if (isAuthenticated && !isInitialSyncRoute && !initialSyncStatus.isChecking) {
        if (initialSyncStatus.needsSync) {
          return '/initial-sync';
        }
      }

      return null;
    },
    routes: [
      // ... other routes ...
      GoRoute(
        path: '/initial-sync',
        builder: (context, state) => const InitialSyncScreen(),
      ),
    ],
  );
});
```

#### 3. InitialSyncScreen (`initial_sync_screen.dart`)

- Auto-starts sync on mount via `WidgetsBinding.instance.addPostFrameCallback`
- Uses existing `snapshotSyncProvider` for download progress
- Shows progress bar with percentage
- Displays error state with retry button
- Navigates to home on completion

### Error Handling

If the sync fails:
- Error message is displayed
- "Try Again" button allows retry
- No way to skip (per requirements)
- User must complete sync before accessing app

## Manual Sync (Preserved)

The manual sync button in Recipe Vault (`recipe_vault_screen.dart`) remains available for:
- Troubleshooting
- Re-downloading if database is corrupted
- Checking for updates

## Testing

### Test Fresh Install
1. Install debug APK
2. Clear app data: Settings > Apps > MyBartenderAI > Clear Data
3. Open app
4. Complete age verification
5. Sign in
6. **Expected:** See "Setting Up Your Cocktail Library" screen
7. Wait for download to complete
8. **Expected:** Navigate to Home screen

### Test Existing User
1. With app already synced, open app
2. Complete age verification (if needed)
3. Sign in (if needed)
4. **Expected:** Go directly to Home (no sync screen)

### Test Network Error
1. Fresh install with cleared data
2. Turn off WiFi/data
3. Sign in
4. **Expected:** See error message with "Try Again" button
5. Turn on WiFi/data
6. Tap "Try Again"
7. **Expected:** Sync completes successfully

## Related Files

- `lib/src/services/snapshot_service.dart` - Core sync logic
- `lib/src/services/database_service.dart` - SQLite database operations
- `lib/src/features/recipe_vault/recipe_vault_screen.dart` - Manual sync button

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall app architecture
- [AUTHENTICATION_IMPLEMENTATION.md](./AUTHENTICATION_IMPLEMENTATION.md) - Auth flow details
