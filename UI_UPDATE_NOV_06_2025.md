# UI Updates - November 6, 2025

## Summary
Major home screen reorganization and voice feature removal based on UX testing feedback.

## Changes Made

### 1. Voice Feature Removal ❌

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
- Recipe Vault redesigned as full-width horizontal card (like Tonight's Special)
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

**APK Location**: `mybartenderai-latest.apk` (53.0MB)
**Build Date**: November 6, 2025
**Build Command**:
```bash
flutter clean
flutter build apk --release --dart-define="AZURE_FUNCTION_KEY=<key>"
```

## Testing Notes

- Voice feature tested and rejected due to poor UX
- New layout improves visibility of primary AI features
- Recipe Vault now has prominent display as full-width card
- All features accessible and functional

## Next Steps

1. Consider voice feature for future Pro tier ($49.99/month) with OpenAI Realtime API
2. Gather user feedback on new home screen layout
3. Monitor usage patterns for Chat, Scanner, and Create features

## Backend Status

- Voice backend endpoint remains deployed at `/api/v1/voice-bartender`
- Azure Speech Services configuration intact
- Can be re-enabled for Pro tier in future

---

**Updated By**: AI Assistant (Sonnet 4.5)
**Last Updated**: November 6, 2025
