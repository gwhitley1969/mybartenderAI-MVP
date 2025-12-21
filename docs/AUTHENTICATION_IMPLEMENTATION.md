# Authentication Implementation - MyBartenderAI Mobile App

**Status**: Fully Operational (December 2025)

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

## Implementation Status (All Complete)

### 1. Routing Integration ✅

- GoRouter with authentication guards implemented
- `/login` route for LoginScreen
- Automatic redirect to `/login` when unauthenticated
- Redirect to home when authenticated user visits login

### 2. API Client Updates ✅

- JWT access token added to all authenticated API requests
- APIM subscription key added (dual authentication)
- `Authorization: Bearer <token>` header on all requests
- `Ocp-Apim-Subscription-Key` header for APIM validation

### 3. User Profile Screen ✅

- Displays user information (name)
- Age verification status badge
- Sign out button with confirmation dialog
- Notification settings (Today's Special Reminder)
- Measurement unit preferences (oz/ml)

### 4. Testing ✅

All test scenarios have been validated:
- Email sign-up/sign-in
- Google sign-in
- Facebook sign-in
- Under-21 blocking (age verification)
- Token persistence across app restarts
- Token refresh (automatic)
- Sign out flow

### 5. Error Handling ✅

- Network connectivity error handling
- Token refresh failures trigger re-authentication
- User-friendly error messages
- Retry mechanisms implemented

### 6. Future Enhancements 📋

**Planned Improvements:**
- Biometric authentication (fingerprint/face ID)
- Account deletion flow
- Profile picture from social providers

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

## API Integration Flow (JWT-Only Authentication)

The mobile app uses JWT-only authentication. No APIM subscription keys are sent from the client.

```
┌─────────────────────────────────────────────────────────────┐
│        Mobile App Needs to Call Backend API                  │
│     (e.g., ask-bartender, recommend, etc.)                   │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│    Get Access Token from accessTokenProvider                 │
│    (Auto-refreshes via silent refresh if expired)           │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Add Authorization Header                                │
│   Authorization: Bearer <JWT>                                │
│   (No APIM subscription key - removed for security)         │
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
│      APIM Validates JWT (validate-jwt policy)               │
│      - Signature verification via OpenID Connect            │
│      - Expiration check                                      │
│      - Audience validation (client ID)                      │
│      - Extracts X-User-Id header for backend                │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Request Forwarded to Azure Function                     │
│      Function receives X-User-Id from APIM                  │
│      Function checks user tier in PostgreSQL                │
│      Response Returned to Mobile App                         │
└─────────────────────────────────────────────────────────────┘
```

### On 401 Response (Token Expired)

```
┌─────────────────────────────────────────────────────────────┐
│      API Returns 401 Unauthorized                            │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      AuthInterceptor Catches 401                             │
│      Triggers silent token refresh                          │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Refresh Token sent to Entra External ID                │
│      New Access Token obtained                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│      Original Request Retried with New Token                │
│      (Automatic, transparent to user)                        │
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

## Background Token Refresh

The app includes a background token refresh service to maintain authentication.

### How It Works

- **BackgroundTokenService**: Monitors token expiration
- **Silent Refresh**: Automatically refreshes tokens before expiration
- **401 Handling**: AuthInterceptor catches 401 responses and triggers refresh
- **Retry Logic**: Failed requests are retried with fresh token (max 1 retry)
- **Logout on Failure**: If refresh fails, user is logged out gracefully

### Token Lifecycle

1. **Access Token**: Short-lived (~1 hour), used for API calls
2. **Refresh Token**: Long-lived, used to obtain new access tokens
3. **ID Token**: Contains user claims, decoded for profile info

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

**Status**: Fully Operational ✅
**Last Updated**: December 2025
