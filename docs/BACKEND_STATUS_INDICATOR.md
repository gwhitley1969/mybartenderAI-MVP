# Backend Status Indicator

## Overview

The backend connection status is displayed on the profile icon in the home screen header, providing a subtle but clear visual indicator of connectivity without cluttering the UI.

## Implementation

**Location:** `mobile/app/lib/src/features/home/home_screen.dart`

### Visual Design

The profile icon (upper right corner of home screen) shows connection status through:

1. **Colored circular border** around the profile icon
2. **Small status dot** in the bottom-right corner of the icon

### Status Colors

| Backend Status | Border Color | Dot Color | Meaning |
|----------------|--------------|-----------|---------|
| Connected | Green (`AppColors.success`) | Green | Backend is healthy and responsive |
| Disconnected | Red (`AppColors.error`) | Red | Backend is offline or unreachable |
| Loading | Gray (`AppColors.textTertiary`) | Gray | Checking connection status |
| Error | Red (`AppColors.error`) | Red | Connection error occurred |

### Technical Details

The status is determined by the `healthCheckProvider` from `backend_provider.dart`, which performs a health check against the Azure backend API.

```dart
final healthCheck = ref.watch(healthCheckProvider);

Color indicatorColor = healthCheck.when(
  data: (isHealthy) => isHealthy ? AppColors.success : AppColors.error,
  loading: () => AppColors.textTertiary,
  error: (_, __) => AppColors.error,
);
```

### UI Structure

```
Stack
├── Container (40x40, circular border with status color)
│   └── Icon (person_outline)
└── Positioned (bottom-right)
    └── Container (12x12 status dot with background border)
```

## Historical Context

### Previous Implementation (Removed Dec 2025)

Previously, the backend status was shown as a separate "Backend Connected" pill badge below the app header:

- Green pill with cloud icon: "Backend Connected"
- Red pill with cloud-off icon: "Backend Offline" or "Connection Error"
- Gray pill with cloud-queue icon: "Connecting..."

This was implemented in `widgets/backend_status.dart` using the `BackendStatus` widget.

### Reason for Change

The pill badge was removed to:
1. Clean up the UI and reduce visual clutter
2. Provide status information in a more subtle, integrated way
3. Make better use of existing UI elements (the profile icon)

The `BackendStatus` widget still exists in the codebase and can be reused elsewhere if needed.

## Files Modified

| File | Change |
|------|--------|
| `home_screen.dart` | Added `backend_provider.dart` import, modified `_buildAppHeader()` to accept `ref`, removed `BackendStatus()` widget, added `_buildProfileButtonWithStatus()` method |

## Related Files

- `lib/src/providers/backend_provider.dart` - Contains `healthCheckProvider`
- `lib/src/widgets/backend_status.dart` - Original status widget (still available)
- `lib/src/theme/app_colors.dart` - Color definitions (`success`, `error`, `textTertiary`)

---

**Last Updated:** December 19, 2025
**Author:** Claude Code
