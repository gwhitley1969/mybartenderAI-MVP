# Profile Screen Cleanup (Release Candidate)

## Overview

The Profile screen was cleaned up to remove developer/debug features and sensitive information in preparation for the release candidate. End users should not see internal development tools or system-generated email addresses.

## Changes Made (December 2025)

### 1. Removed Email Display

**Before:** The "Account Information" section displayed the user's email address, which was a long GUID-based identifier from Entra External ID (e.g., `55aa5f74-71c8-4af4-9e5b-c21...@mybartenderai.onmicrosoft.com`).

**After:** Email is no longer displayed. Account Information now only shows:
- Name (display name)
- Full Name (if given name/family name are available)

**Reason:** The system-generated email addresses are not meaningful to users and could cause confusion.

### 2. Removed Developer Tools Section

The entire "Developer Tools" section was removed, which included:

#### JWT Token
- "Copy JWT Token" button - allowed copying the authentication token for API testing
- Used `Clipboard.setData()` to copy token to clipboard

#### Auth Debug
- "Force Token Expiration" button - simulated token expiration to test silent refresh
- "Test Background Refresh" button - triggered background token refresh for testing

**Reason:** These are developer-only features that should not be exposed to end users. They could cause confusion or unintended behavior if used incorrectly.

## Current Profile Screen Structure

After cleanup, the Profile screen contains:

```
┌─────────────────────────────────┐
│         Profile Header          │
│    (Avatar + Display Name)      │
├─────────────────────────────────┤
│     Account Information         │
│  • Name                         │
│  • Full Name (if available)     │
├─────────────────────────────────┤
│     Verification Status         │
│  • Age Verification badge       │
├─────────────────────────────────┤
│        Notifications            │
│  • Today's Special Reminder     │
│  • Reminder Time picker         │
│  • Test Notification button     │
├─────────────────────────────────┤
│         Preferences             │
│  • Measurement Units (oz/ml)    │
├─────────────────────────────────┤
│       [Sign Out Button]         │
├─────────────────────────────────┤
│     MyBartenderAI v1.0.0        │
└─────────────────────────────────┘
```

## Code Changes

### File Modified
`mobile/app/lib/src/features/profile/profile_screen.dart`

### Removed Imports
```dart
import 'package:flutter/services.dart';  // Clipboard
import '../../services/background_token_service.dart';
import '../../services/token_storage_service.dart';
```

### Removed UI Elements
- Email row from `_buildInfoCard()` in Account Information section
- "Developer Tools" section title
- `_buildJwtTokenCard()` method call

### Removed Methods
- `_buildJwtTokenCard()` - ~250 lines of code for JWT token copy and auth debug features

## Re-enabling Developer Tools (If Needed)

If developer tools are needed for debugging in the future, consider:

1. **Environment-based toggle**: Only show in debug builds
   ```dart
   if (kDebugMode) {
     // Show developer tools
   }
   ```

2. **Hidden gesture**: Tap version number 7 times to reveal developer options

3. **Separate debug screen**: Create a dedicated debug screen accessible only via deep link or hidden route

## Related Files

- `lib/src/services/token_storage_service.dart` - Still exists, used elsewhere for token management
- `lib/src/services/background_token_service.dart` - Still exists, handles background token refresh
- `lib/src/providers/auth_provider.dart` - Contains `debugForceTokenExpiration()` method (kept for potential future use)

---

**Last Updated:** December 19, 2025
**Author:** Claude Code
**Related:** Release candidate preparation
