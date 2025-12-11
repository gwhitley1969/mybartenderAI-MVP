# UI Updates - November 2025

**Last Updated**: November 10, 2025

## Summary

Major home screen reorganization, voice feature removal, and Today's Special feature implementation.

## Changes Made

### November 10, 2025 Updates

#### 3. Today's Special Feature ✅

**Implementation**: Random daily cocktail selection on home screen

**New Files Created:**

- `mobile/app/lib/src/features/home/providers/todays_special_provider.dart`
- `mobile/app/lib/src/services/notification_service.dart` (temporarily disabled)

**Core Features:**

- Random cocktail selected daily from local database
- Automatic midnight refresh using Timer
- SharedPreferences caching for daily persistence
- Prominent card display on home screen
- Tap to view full cocktail details

**UI Changes** (`home_screen.dart`):

- Added Today's Special card (lines 465-600)
- Displays cocktail image, name, and details
- Shows "Check back soon" message when no cocktail available
- Integrated with FutureProvider for state management

**Backend Logic** (`todays_special_provider.dart`):

- FutureProvider implementation
- Midnight refresh timer
- Date-based cache key (`YYYY-MM-DD` format)
- Integration with SQLite database
- Notification scheduling (currently disabled)

**Build Configuration** (`build.gradle.kts`):

- Added core library desugaring support (line 16)
- Added desugaring dependency (line 51)

**Notifications Status**: ⏳ Temporarily disabled due to plugin compatibility

- `flutter_native_timezone` build errors
- Notification dependencies commented out in `pubspec.yaml`
- Notification service calls disabled in provider
- Will be re-enabled when compatible plugin found

### November 6, 2025 Updates

#### 1. Voice Feature Removal ❌

**Reason**: Tap-to-record UX did not meet user expectations for conversational interaction.

**Files Removed:**

- `mobile/app/lib/src/features/voice_bartender/voice_bartender_screen.dart`
- `mobile/app/lib/src/services/voice_service.dart`
- `mobile/app/lib/src/providers/voice_bartender_provider.dart`

**Dependencies Removed from `pubspec.yaml`:**

- `record: ^6.1.2` (audio recording)
- `just_audio: ^0.9.46` (audio playback)
- `permission_handler: ^11.4.0` (microphone permissions)

**Permissions Removed from `AndroidManifest.xml`:**

- `RECORD_AUDIO`

**Routing Changes (`main.dart`):**

- Removed `voice_bartender_screen.dart` import
- Removed `/voice-bartender` route
- Removed `voice_bartender_provider.dart` export from `providers.dart`

### 2. Home Screen Reorganization 🎨

#### AI Cocktail Concierge Section

**Before**: 2 buttons (Chat, Scanner)
**After**: 3 buttons in a row (Chat, Scanner, Create)

```
┌─────────────────────────────────────┐
│   AI Cocktail Concierge             │
│  ┌──────┐ ┌──────┐ ┌──────┐        │
│  │ Chat │ │Scanner│ │Create│        │
│  └──────┘ └──────┘ └──────┘        │
└─────────────────────────────────────┘
```

**Changes** (mobile/app/lib/src/features/home/home_screen.dart:168-204):

- Removed Voice button
- Added Create button (moved from Lounge Essentials)
- Icon: `Icons.auto_fix_high`
- Color: Purple (`AppColors.iconCirclePurple`)
- Subtitle: "Design cocktails"

#### Lounge Essentials Section

**Before**: 4 cards in 2x2 grid (Create Studio, Recipe Vault, My Bar, Favorites)
**After**: Recipe Vault as full-width card + 2-column grid below

```
┌─────────────────────────────────────┐
│   Lounge Essentials                 │
│  ┌─────────────────────────────────┐│
│  │ [📖] Recipe Vault               ││
│  │      Curated cocktail collection││
│  └─────────────────────────────────┘│
│                                     │
│  ┌──────────────┐ ┌──────────────┐ │
│  │  My Bar      │ │  Favorites   │ │
│  │  Track your  │ │  Saved       │ │
│  │  collection  │ │  cocktails   │ │
│  └──────────────┘ └──────────────┘ │
└─────────────────────────────────────┘
```

**Changes** (mobile/app/lib/src/features/home/home_screen.dart:266-373):

- Removed Create Studio from this section (moved to Concierge)
- Recipe Vault redesigned as full-width horizontal card (like Today's Special)
  - Orange icon circle on left
  - Title and subtitle on right
  - Tappable container navigates to Recipe Vault screen
- My Bar and Favorites remain as 2-column grid below

## Files Modified

### Core Changes:

1. **mobile/app/lib/src/features/home/home_screen.dart**
   
   - AI Cocktail Concierge section (lines 168-204)
   - Lounge Essentials section (lines 266-373)

2. **mobile/app/lib/main.dart**
   
   - Removed voice_bartender_screen import (line 13)
   - Removed /voice-bartender route (lines 124-129)

3. **mobile/app/lib/src/providers/providers.dart**
   
   - Removed voice_bartender_provider export (line 8)

4. **mobile/app/pubspec.yaml**
   
   - Removed audio dependencies (lines 51-56)

5. **mobile/app/android/app/src/main/AndroidManifest.xml**
   
   - Removed RECORD_AUDIO permission (lines 9-10)

## Build Information

**Current APK**: `MyBartenderAI-TodaysSpecial-FIXED-nov10.apk` (54MB) ✅ WORKING
**Build Date**: November 10, 2025
**Previous APK**: `mybartenderai-secure.apk` (53MB, Nov 6)

**Build Command**:

```bash
flutter clean
flutter build apk --release --dart-define="AZURE_FUNCTION_KEY=<key>"
```

## Testing Notes

### November 10, 2025

- ✅ Today's Special displays random cocktail (VERIFIED WORKING)
- ✅ Daily caching working correctly
- ✅ Midnight refresh timer implemented
- ✅ UI displays cocktail name and details
- ✅ Tap navigation to detail screen working
- ✅ Database snapshot download required for initial use
- ⏳ Push notifications disabled (plugin compatibility)

### November 6, 2025

- Voice feature tested and rejected due to poor UX
- New layout improves visibility of primary AI features
- Recipe Vault now has prominent display as full-width card
- All features accessible and functional

## Next Steps

### Immediate

1. ✅ Implement Today's Special feature (completed Nov 10)
2. ⏳ Resolve notification plugin compatibility
3. Test Smart Scanner feature thoroughly
4. Test Create Studio feature thoroughly

### Future

1. Consider voice feature for future Pro tier ($49.99/month) with OpenAI Realtime API
2. Gather user feedback on new home screen layout
3. Monitor usage patterns for Chat, Scanner, and Create features
4. Add notification customization (time preference, enable/disable)
5. Track Today's Special engagement metrics

## Backend Status

- Voice backend endpoint remains deployed at `/api/v1/voice-bartender`
- Azure Speech Services configuration intact
- Can be re-enabled for Pro tier in future

---

**Updated By**: AI Assistant (Sonnet 4.5)
**Last Updated**: November 10, 2025
