# Authentication Implementation - MyBartenderAI Mobile App

**Status**: Foundation Complete - Ready for Testing (2025-11-03)

## Overview

Entra External ID authentication has been integrated into the MyBartenderAI mobile app, providing secure sign-in/sign-up with Email, Google, and Facebook. The backend age verification (21+) is fully operational and will automatically block underage users during signup.

## What's Been Implemented

### 1. Azure Configuration ✅

**App Registration Created:**
- **Display Name**: MyBartenderAI Mobile
- **Client ID**: `0a9decfb-ba92-400d-8d8d-8d86f0f86a0b`
- **Object ID**: `12949f94-29d1-41fa-918c-2afabe86360f`
- **Redirect URIs**:
  - `com.mybartenderai.app://callback`
  - `msauth.com.mybartenderai.app://auth`
- **Public Client**: Enabled
- **Sign-in Audience**: AzureADandPersonalMicrosoftAccount
- **Token Issuance**: Access tokens and ID tokens enabled

**Tenant Configuration (Already Configured):**
- **Tenant Name**: mybartenderai
- **Tenant ID**: a82813af-1054-4e2d-a8ec-c6b9c2908c91
- **CIAM Domain**: mybartenderai.ciamlogin.com
- **User Flow**: mba-signin-signup
- **Identity Providers**: Email, Google, Facebook
- **Age Verification**: validate-age function with OAuth 2.0

### 2. Flutter Dependencies ✅

Added to `pubspec.yaml`:
```yaml
dependencies:
  flutter_appauth: ^6.0.2      # OAuth 2.0 / OpenID Connect
  flutter_secure_storage: ^9.2.2  # Secure token storage
  jwt_decoder: ^2.0.1          # JWT token decoding
```

### 3. Configuration ✅

**File**: `mobile/app/lib/src/config/auth_config.dart`

Contains all Entra External ID configuration:
- Tenant name and ID
- Client ID
- User flow name
- Authority and endpoint URLs
- Redirect URIs
- OAuth scopes
- Token storage keys

### 4. Data Models ✅

**User Model** (`mobile/app/lib/src/models/user.dart`):
- User profile data
- Age verification status
- Factory method to create from JWT token claims
- Freezed for immutability
- JSON serialization

**AuthState Model** (`mobile/app/lib/src/models/auth_state.dart`):
- `initial` - App startup
- `loading` - Authentication in progress
- `authenticated(User)` - User signed in
- `unauthenticated` - User signed out
- `error(String)` - Authentication error

### 5. Services ✅

**TokenStorageService** (`mobile/app/lib/src/services/token_storage_service.dart`):
- Secure storage for access tokens, refresh tokens, ID tokens
- Uses `flutter_secure_storage` with Android encrypted shared preferences
- Token expiration tracking
- User profile persistence
- Clear methods for logout

**AuthService** (`mobile/app/lib/src/services/auth_service.dart`):
- Sign in with Entra External ID
- Sign up (uses same flow - Entra handles both)
- Sign out with end session
- Token refresh using refresh tokens
- Get current user from stored tokens
- Automatic token expiration handling
- JWT token decoding to extract user claims

### 6. State Management ✅

**File**: `mobile/app/lib/src/providers/auth_provider.dart`

**Providers Created:**
- `tokenStorageServiceProvider` - Token storage service instance
- `authServiceProvider` - Auth service instance
- `authNotifierProvider` - Auth state notifier (main provider)
- `currentUserProvider` - Current authenticated user (or null)
- `isAuthenticatedProvider` - Boolean auth status
- `accessTokenProvider` - Valid access token for API calls

**AuthNotifier Class:**
- Manages authentication state
- Auto-checks auth status on app start
- Sign in, sign up, sign out methods
- Token refresh logic
- State transitions (loading → authenticated/unauthenticated/error)

### 7. Android Configuration ✅

**File**: `mobile/app/android/app/src/main/AndroidManifest.xml`

Added OAuth redirect activity:
```xml
<activity
    android:name="net.openid.appauth.RedirectUriReceiverActivity"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.mybartenderai.app" />
    </intent-filter>
</activity>
```

This allows the app to receive the OAuth callback from Entra External ID after authentication.

### 8. UI Screens ✅

**LoginScreen** (`mobile/app/lib/src/features/auth/login_screen.dart`):
- Clean, branded login interface
- Single "Sign In / Sign Up" button (Entra handles both flows)
- Loading state during authentication
- Error display with retry option
- Age restriction notice (21+ requirement)
- Responsive to authentication state changes

## What Still Needs to Be Done

### 1. Routing Integration 🔄

**File to Update**: `mobile/app/lib/src/main.dart`

**Changes Needed:**
- Add `/login` route for LoginScreen
- Add redirect logic in GoRouter:
  - If unauthenticated → redirect to `/login`
  - If authenticated → allow access to app
- Implement route guards for protected screens

**Example**:
```dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isAuthenticated = authState is AuthStateAuthenticated;
      final isLoginRoute = state.location == '/login';

      // Redirect to login if not authenticated
      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }

      // Redirect to home if authenticated and on login page
      if (isAuthenticated && isLoginRoute) {
        return '/';
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          // ... existing routes
        ],
      ),
    ],
  );
});
```

### 2. API Client Updates 🔄

**Files to Update**:
- `mobile/app/lib/src/api/ask_bartender_api.dart`
- `mobile/app/lib/src/services/backend_service.dart`
- Any other API clients

**Changes Needed:**
- Add JWT access token to all authenticated API requests
- Use `accessTokenProvider` to get current token
- Add `Authorization: Bearer <token>` header

**Example**:
```dart
final accessToken = await ref.read(accessTokenProvider.future);
if (accessToken != null) {
  _dio.options.headers['Authorization'] = 'Bearer $accessToken';
}
```

### 3. User Profile Screen 🔄

**File to Create**: `mobile/app/lib/src/features/profile/profile_screen.dart`

**Features Needed:**
- Display user information (name, email)
- Age verification status badge
- Account created date
- Sign out button
- Navigation from home screen

### 4. Testing 🔄

**Test Scenarios:**

1. **New User Sign-Up (Email)**:
   - Tap "Sign In / Sign Up"
   - Select "Sign up now"
   - Enter email, password, name, birthdate (21+)
   - Verify age verification passes
   - Verify redirect to home screen
   - Verify user is authenticated

2. **New User Sign-Up (Google)**:
   - Tap "Sign In / Sign Up"
   - Select "Continue with Google"
   - Authenticate with Google
   - Enter birthdate (21+)
   - Verify age verification passes
   - Verify user is authenticated

3. **New User Sign-Up (Facebook)**:
   - Same as Google flow

4. **Under-21 Sign-Up (Should Fail)**:
   - Attempt signup with birthdate < 21 years ago
   - Verify account creation is blocked
   - Verify error message displayed

5. **Existing User Sign-In**:
   - Tap "Sign In / Sign Up"
   - Enter credentials
   - Verify redirect to home screen
   - Verify user data loaded from token

6. **Token Persistence**:
   - Sign in
   - Close app completely
   - Reopen app
   - Verify still authenticated (no login required)

7. **Token Refresh**:
   - Sign in
   - Wait for token to expire (~1 hour)
   - Make API call
   - Verify token auto-refreshes
   - Verify API call succeeds

8. **Sign Out**:
   - While authenticated, tap sign out
   - Verify redirect to login screen
   - Verify tokens cleared
   - Verify cannot access protected screens

### 5. Error Handling Improvements 🔄

**Areas to Enhance:**
- Network connectivity errors
- Token refresh failures (redirect to login)
- Entra External ID service errors
- User-friendly error messages
- Retry mechanisms

### 6. Optional Enhancements 📋

**Future Improvements:**
- Biometric authentication (fingerprint/face ID) for quick re-authentication
- Remember device option
- Multi-device session management
- Account deletion flow
- Password reset flow (handled by Entra, just need to link to it)
- Profile picture from social providers
- Link/unlink social accounts

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        User Taps                             │
│                   "Sign In / Sign Up"                        │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│            AuthNotifier.signIn() called                      │
│        (via authNotifierProvider.notifier)                   │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│         AuthService.signIn() called                          │
│   Uses flutter_appauth to start OAuth flow                  │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Browser/WebView Opens Entra External ID                │
│    https://mybartenderai.ciamlogin.com/...                  │
│                                                               │
│    User sees sign-in options:                                │
│    - Email + Password                                        │
│    - Continue with Google                                    │
│    - Continue with Facebook                                  │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│             User Authenticates                               │
│   (Email or Social Provider)                                 │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│    Entra Collects User Attributes                           │
│    (Name, Email, Date of Birth)                              │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│    Custom Auth Extension Triggered                           │
│    validate-age function called with OAuth token             │
│                                                               │
│    IF under 21:                                              │
│      - Show block page                                       │
│      - Account NOT created                                   │
│                                                               │
│    IF 21+:                                                   │
│      - Continue with account creation                        │
│      - Set age_verified = true                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Entra Redirects to App                                  │
│   com.mybartenderai.app://callback?code=...                 │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│     flutter_appauth Exchanges Code for Tokens               │
│     - Access Token                                           │
│     - Refresh Token                                          │
│     - ID Token (contains user claims)                        │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      AuthService Stores Tokens Securely                      │
│   (TokenStorageService → flutter_secure_storage)             │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Decode ID Token → Extract User Claims                   │
│      Create User object                                      │
│      Update AuthState → authenticated(user)                  │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      GoRouter Detects Auth Change                            │
│      Redirects to Home Screen                                │
│      User is now authenticated!                              │
└─────────────────────────────────────────────────────────────┘
```

## API Integration Flow

```
┌─────────────────────────────────────────────────────────────┐
│        Mobile App Needs to Call Backend API                  │
│     (e.g., ask-bartender, recommend, etc.)                   │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│    Get Access Token from accessTokenProvider                 │
│    (Auto-refreshes if expired)                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Add Authorization Header                                │
│   Authorization: Bearer eyJ0eXAiOiJKV1Q...                  │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Make API Request via Dio                                │
│   POST /api/v1/ask-bartender                                 │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      APIM Validates JWT Token                                │
│      - Signature verification                                │
│      - Expiration check                                      │
│      - Audience validation                                   │
│      - age_verified claim check                              │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Request Forwarded to Azure Function                     │
│      Function Processes Request                              │
│      Response Returned to Mobile App                         │
└─────────────────────────────────────────────────────────────┘
```

## Files Created/Modified

### New Files Created (10):
1. `mobile/app/lib/src/config/auth_config.dart` - Auth configuration
2. `mobile/app/lib/src/models/user.dart` - User model
3. `mobile/app/lib/src/models/auth_state.dart` - Auth state model
4. `mobile/app/lib/src/services/token_storage_service.dart` - Secure token storage
5. `mobile/app/lib/src/services/auth_service.dart` - Authentication service
6. `mobile/app/lib/src/providers/auth_provider.dart` - Riverpod providers
7. `mobile/app/lib/src/features/auth/login_screen.dart` - Login UI
8. Generated: `mobile/app/lib/src/models/user.freezed.dart`
9. Generated: `mobile/app/lib/src/models/user.g.dart`
10. Generated: `mobile/app/lib/src/models/auth_state.freezed.dart`

### Files Modified (3):
1. `mobile/app/pubspec.yaml` - Added auth dependencies
2. `mobile/app/lib/src/models/models.dart` - Exported new models
3. `mobile/app/android/app/src/main/AndroidManifest.xml` - OAuth redirect config

### Azure Resources Created (1):
1. App Registration: "MyBartenderAI Mobile" (Client ID: 0a9decfb-ba92-400d-8d8d-8d86f0f86a0b)

## Next Steps (Priority Order)

1. **Update GoRouter with auth guards** (30 minutes)
   - Add redirect logic based on auth state
   - Add `/login` route
   - Test navigation flow

2. **Update API clients with JWT tokens** (20 minutes)
   - Modify `ask_bartender_api.dart`
   - Modify `backend_service.dart`
   - Add authorization headers

3. **Test authentication flows** (1-2 hours)
   - Email sign-up/sign-in
   - Google sign-in
   - Facebook sign-in
   - Under-21 blocking
   - Token persistence
   - Token refresh
   - Sign out

4. **Create user profile screen** (45 minutes)
   - Display user info
   - Sign out button
   - Navigate from home

5. **Production polish** (ongoing)
   - Error handling improvements
   - Loading states
   - User feedback
   - Edge case handling

## Security Notes

- **Tokens stored securely**: Using `flutter_secure_storage` with Android encrypted shared preferences
- **No hardcoded secrets**: Client ID is public (OAuth standard), secrets are server-side only
- **Age verification server-side**: Cannot be bypassed (validate-age function with OAuth 2.0)
- **Token expiration**: Access tokens expire, auto-refresh using refresh tokens
- **HTTPS only**: All communication encrypted
- **OAuth 2.0 PKCE**: flutter_appauth uses PKCE for additional security

## Known Limitations

1. **iOS not configured**: Need to add URL scheme to Info.plist for iOS support
2. **No biometric auth yet**: Could add for better UX
3. **No offline auth**: Requires network for initial sign-in
4. **Single session**: No multi-device session management yet

## Documentation References

- Entra External ID Setup: `docs/AUTHENTICATION_SETUP.md`
- Age Verification Details: `infrastructure/apim/ENTRA_EXTERNAL_ID_API_CONNECTOR_SETUP.md`
- Deployment Status: `docs/DEPLOYMENT_STATUS.md`

---

**Status**: Foundation Complete ✅
**Next Milestone**: Integration & Testing 🔄
**Estimated Completion**: 2-3 hours additional work
