# Changelog

All notable changes to the MyBartenderAI mobile app will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Favorites Feature**: Complete cocktail bookmarking system
  - Heart icon toggle in cocktail detail screens to favorite/unfavorite cocktails
  - Dedicated Favorites screen showing all favorited cocktails in a grid layout
  - Favorites filter chip in Recipe Vault to show only favorited cocktails
  - Favorites card on home screen for quick access
  - SQLite database table (`favorite_cocktails`) for persistent storage
  - Riverpod state management for reactive favorites updates
  - Support for optional notes on favorited cocktails (future enhancement)

- **Offline Image Caching**: Local storage for all cocktail images
  - Automatic download of all 621 cocktail images during snapshot sync
  - Images stored locally using MD5-hashed filenames for safety
  - Batch downloading in groups of 5 to prevent network overload
  - `CachedCocktailImage` widget automatically uses local files first
  - Graceful fallback to network if local image unavailable
  - Instant image loading for offline-first experience
  - Significant performance improvement in Recipe Vault grid scrolling

### Changed
- Updated home screen layout: replaced "Taste Profile" with "Favorites" feature card
- Database schema upgraded from version 2 to version 3 to fix missing user_inventory table
- Enhanced Recipe Vault with additional filtering capabilities
- Optimized database queries - eliminated N+1 query problem in getCocktails() (622 queries → 1 query)
- All cocktail images now load from local storage instead of network requests
- Improved Recipe Vault thumbnail images: increased card width from 160px to 200px with wider aspect ratio (200px × 160px)

### Fixed
- Fixed typography references in My Bar screens (updated to use proper AppTypography style names)
- Added missing `AppColors.accentRed` color definition for heart icon
- Corrected database service provider imports in state management layer
- Fixed missing `user_inventory` table errors after database version migrations
- Fixed snapshot sync overwriting user-specific database tables

### Technical
- Added `FavoriteCocktail` data model with serialization methods
- Implemented 7 new database operations for favorites CRUD
- Created comprehensive Riverpod provider architecture:
  - `favoritesProvider`: List of all favorite cocktails
  - `favoritesCountProvider`: Count of favorites
  - `isFavoriteProvider`: Check if specific cocktail is favorited
  - `favoriteCocktailIdsProvider`: List of favorite cocktail IDs
  - `favoritesNotifierProvider`: State management for mutations
- Added database indexes on `cocktail_id` (unique) and `added_at` (descending)
- Created `ImageCacheService` for local image storage and retrieval
- Created `CachedCocktailImage` widget for transparent local/network image loading
- Added `ensureUserTablesExist()` method to recreate user tables after snapshot import
- Refactored `getCocktails()` to use JOIN queries instead of N+1 pattern

## [0.1.0] - 2025-10-29

### Initial Release
- Voice assistant integration with OpenAI Realtime API
- Recipe Vault with 621 cocktails
- My Bar inventory tracking
- Ask the Bartender AI chat
- Offline-first architecture with SQLite database
- Snapshot sync for cocktail database updates
