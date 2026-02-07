# Create Studio: Custom Cocktail Photo Capture

**Status:** Completed
**Date:** February 7, 2026
**Feature:** Camera/gallery photo capture for custom cocktails with local storage and share-sheet attachment

## Overview

The Create Studio allows users to build their own cocktail recipes from scratch. Prior to this feature, custom cocktails displayed a blank 300px hero area with a small placeholder bar icon on the detail card and a generic thumbnail in the Create Studio grid. Users had no way to visually distinguish their creations.

This feature adds photo capture (camera + gallery) so users can photograph their custom cocktails. Photos are:
- Stored locally on device (no backend upload)
- Displayed on the cocktail detail card hero area, the Create Studio grid, and anywhere else `CachedCocktailImage` is used
- Included as native file attachments when sharing via the OS share sheet

Standard cocktails from TheCocktailDB are unaffected.

## Architecture

### Design Decisions

1. **No model changes**: The `Cocktail.imageUrl` field (line 15, `cocktail.dart`) already exists and is persisted to SQLite by `updateCustomCocktail`. We store a local absolute file path (e.g., `/data/user/0/.../cocktail_photos/custom-abc123.jpg`) in this field instead of null.

2. **No new packages**: All three required packages were already in `pubspec.yaml`:
   - `image_picker: ^1.1.2` — camera and gallery access
   - `path_provider: ^2.1.5` — app documents directory
   - `share_plus: ^7.2.1` — `Share.shareXFiles()` for file attachment sharing

3. **Reuse Smart Scanner pattern**: The camera picker settings (`maxWidth: 1024, maxHeight: 1024, imageQuality: 85`) match the existing `SmartScannerScreen` for consistency and reasonable file sizes.

4. **Local-only storage**: Photos are saved to `{appDocumentsDirectory}/cocktail_photos/{cocktailId}.jpg`. No Azure Blob Storage or backend API involvement.

### Data Flow

```
User captures photo (Camera or Gallery)
    |
    v
ImagePicker returns XFile (1024x1024 max, 85% quality JPEG)
    |
    v
CocktailPhotoService.savePhoto(cocktailId, bytes)
    |   Writes to: {appDocDir}/cocktail_photos/{cocktailId}.jpg
    |   Returns: absolute file path string
    v
Cocktail.imageUrl = "/data/user/0/.../cocktail_photos/custom-abc.jpg"
    |
    v
DatabaseService.updateCustomCocktail(cocktail)
    |   Persists imageUrl to SQLite `image_url` column
    v
Provider invalidation: cocktailByIdProvider + customCocktailsProvider
    |
    v
CachedCocktailImage detects local path prefix ("/") -> Image.file()
```

### File Path Convention

Local cocktail photos are identified by their `imageUrl` prefix:

| Prefix | Type | Handler |
|---|---|---|
| `/` | Local absolute path | `Image.file()` |
| `file://` | Local file URI | Strip prefix, then `Image.file()` |
| `http://` or `https://` | Network URL | `ImageCacheService` + `Image.network()` |
| `null` or empty | No image | Placeholder widget |

This convention is checked in two places:
- `CachedCocktailImage.build()` — early return for local files
- `CocktailDetailScreen._buildHeroImage()` — direct `Image.file()` for the hero area

## Implementation Details

### New File: `CocktailPhotoService`

**Path:** `lib/src/services/cocktail_photo_service.dart`

A singleton utility class centralizing all photo file operations:

| Method | Signature | Purpose |
|---|---|---|
| `savePhoto` | `Future<String> savePhoto(String cocktailId, Uint8List bytes)` | Writes JPEG bytes to disk, returns absolute path |
| `deletePhoto` | `Future<void> deletePhoto(String cocktailId)` | Deletes photo file if it exists (safe no-op if absent) |
| `getPhotoPath` | `Future<String> getPhotoPath(String cocktailId)` | Returns expected path (may or may not exist) |
| `hasPhoto` | `Future<bool> hasPhoto(String cocktailId)` | Checks file existence |

Storage location: `{appDocumentsDirectory}/cocktail_photos/{cocktailId}.jpg`

The `cocktail_photos` subdirectory is created on first use via `Directory.create(recursive: true)`.

### Modified: Edit Cocktail Screen

**Path:** `lib/src/features/create_studio/edit_cocktail_screen.dart`

**State variables added:**
- `ImagePicker _picker` — picker instance
- `Uint8List? _imageBytes` — newly captured photo bytes (in-memory before save)
- `String? _existingPhotoPath` — local file path of an existing photo (edit mode)
- `bool _photoRemoved` — tracks explicit photo removal by the user

**UI: Photo section** (inserted at the top of the form, before "Cocktail Name"):
- 200px container with rounded corners showing either:
  - The captured photo (`Image.memory` from `_imageBytes`)
  - An existing photo (`Image.file` from `_existingPhotoPath`)
  - A placeholder with camera icon and "Add Photo" text (tappable)
- Overlay "X" remove button when a photo is present
- Row of Camera and Gallery outlined buttons below the preview
- Bottom sheet picker (camera/gallery) when tapping the placeholder

**Save logic:**
```
if _imageBytes != null:
    save to disk via CocktailPhotoService -> set imageUrl
else if _photoRemoved:
    imageUrl = null (photo explicitly removed)
else:
    imageUrl = existing path or original cocktail's imageUrl
```

The `_photoRemoved` flag is critical because the `Cocktail` constructor accepts `null` for `imageUrl` directly — unlike `copyWith()` which uses `??` and cannot set a field to null.

**Save As New (refinement):** When the AI Refine feature creates a new cocktail from an edited one, the photo is copied to the new cocktail's ID:
- If `_imageBytes` exists, save directly with the new ID
- If `_existingPhotoPath` exists, read the file and save a copy with the new ID

### Modified: Cocktail Detail Screen

**Path:** `lib/src/features/recipe_vault/cocktail_detail_screen.dart`

**Widget conversion:** `ConsumerWidget` -> `ConsumerStatefulWidget`

This was necessary because the `ImagePicker` interaction requires mutable state and the `_picker` instance needs to persist across rebuilds.

**Hero image behavior** (the 300px `SliverAppBar.flexibleSpace`):

| Cocktail Type | Has Photo? | Behavior |
|---|---|---|
| Standard (TheCocktailDB) | N/A | `CachedCocktailImage` — no changes |
| Custom | Yes | `Image.file()` with "Change" overlay button (bottom-right) |
| Custom | No | Tappable placeholder: camera icon + "Tap to add photo" text |

**Photo capture flow:**
1. User taps placeholder or "Change" button
2. Bottom sheet shows "Take Photo" and "Choose from Gallery" options
3. `ImagePicker.pickImage()` with standard settings
4. `CocktailPhotoService.savePhoto()` writes to disk
5. `cocktail.copyWith(imageUrl: photoPath)` creates updated cocktail
6. `DatabaseService.updateCustomCocktail()` persists to SQLite
7. Both `cocktailByIdProvider` and `customCocktailsProvider` are invalidated
8. "Photo saved!" snackbar confirmation

**Enhanced sharing:**
- Custom cocktails with a local photo use `Share.shareXFiles([XFile(photoPath)])` to send the image as a native file attachment through the OS share sheet
- Custom cocktails without a photo use text-only `Share.shareWithResult()`
- Custom cocktails skip the `share.mybartenderai.com` URL (custom recipes don't exist on the server)
- Standard cocktails retain existing sharing behavior (text + URL)
- If the photo file is missing at share time, falls back gracefully to text-only with a debug log

### Modified: CachedCocktailImage

**Path:** `lib/src/widgets/cached_cocktail_image.dart`

A single early-return check added at the top of `build()`:

```dart
if (imageUrl!.startsWith('/') || imageUrl!.startsWith('file://')) {
  final path = imageUrl!.startsWith('file://') ? imageUrl!.substring(7) : imageUrl!;
  return Image.file(
    File(path),
    width: double.infinity,
    height: double.infinity,
    fit: fit,
    errorBuilder: errorBuilder ?? _defaultErrorBuilder,
  );
}
```

The `width: double.infinity` and `height: double.infinity` parameters are critical — without them, `Image.file()` renders at the image's intrinsic pixel size instead of expanding to fill the parent container. With these constraints, the image fills all available space and `BoxFit.cover` properly scales and crops the photo to fit the thumbnail area (e.g., Create Studio grid cards).

This bypasses the entire `FutureBuilder<String>` + `ImageCacheService` pipeline for local files. Every widget in the app that uses `CachedCocktailImage` — including the Create Studio grid, search results, favorites — will automatically display custom cocktail photos without any further changes.

### Modified: Create Studio Screen

**Path:** `lib/src/features/create_studio/create_studio_screen.dart`

In `_deleteCocktail()`, after `db.deleteCustomCocktail(cocktail.id)`:

```dart
await CocktailPhotoService.instance.deletePhoto(cocktail.id);
```

This prevents orphaned photo files from accumulating in local storage when users delete custom cocktails.

## Provider Invalidation Strategy

After any photo change, the following providers must be invalidated:

| Provider | Purpose | When |
|---|---|---|
| `cocktailByIdProvider(id)` | Refreshes the detail screen | After save in detail screen |
| `customCocktailsProvider` | Refreshes the Create Studio grid | After save in detail screen |

The edit cocktail screen does not need explicit invalidation because it returns `true` to the caller (`Navigator.pop(context, true)`), which triggers a refresh in the Create Studio screen's navigation callback.

## Testing Checklist

| Scenario | Expected Result |
|---|---|
| Create new cocktail with camera photo | Photo appears on detail card hero area and Create Studio grid |
| Create new cocktail with gallery photo | Same as above |
| Create new cocktail without photo | Placeholder shown with "Tap to add photo" on detail card |
| Edit existing cocktail, add photo | Photo persists after save, visible on detail and grid |
| Edit existing cocktail, remove photo | Hero area reverts to placeholder, grid shows default icon |
| Edit existing cocktail, replace photo | New photo replaces old on detail and grid |
| Tap hero area on custom cocktail (no photo) | Camera/gallery bottom sheet opens |
| Tap "Change" on custom cocktail (has photo) | Camera/gallery bottom sheet opens, new photo replaces old |
| Share custom cocktail with photo | Native share sheet shows image attachment + recipe text |
| Share custom cocktail without photo | Text-only share (no image attachment) |
| Share standard cocktail | Unchanged behavior (text + share.mybartenderai.com URL) |
| Delete custom cocktail with photo | Photo file removed from `cocktail_photos/` directory |
| View Create Studio grid after adding photo | Thumbnail shows the photo instead of placeholder |
| AI Refine "Save As New" with photo | New cocktail gets a copy of the original's photo |

## Files Summary

| File | Action | Lines Changed |
|---|---|---|
| `lib/src/services/cocktail_photo_service.dart` | NEW | ~55 lines |
| `lib/src/features/create_studio/edit_cocktail_screen.dart` | MODIFIED | ~170 lines added (photo section, picker, state) |
| `lib/src/features/recipe_vault/cocktail_detail_screen.dart` | MODIFIED | ~120 lines added (hero image, capture, sharing) |
| `lib/src/widgets/cached_cocktail_image.dart` | MODIFIED | ~7 lines added (local file check) |
| `lib/src/features/create_studio/create_studio_screen.dart` | MODIFIED | ~3 lines added (photo cleanup) |

## Known Limitations

1. **No cloud backup**: Photos exist only on the device. If the user clears app data or reinstalls, photos are lost while the cocktail recipes (in SQLite) may be recoverable.
2. **Single photo per cocktail**: The design supports one photo per cocktail. Multiple photos would require a different data model.
3. **No photo cropping/editing**: The captured photo is used as-is (scaled down to 1024x1024 max). No built-in crop or filter UI.
4. **`copyWith` cannot null out `imageUrl`**: The `Cocktail.copyWith()` method uses `??` for all fields. To set `imageUrl` to null, you must construct a new `Cocktail()` directly. This is handled correctly in `_handleSave()` but is worth noting for future development.
