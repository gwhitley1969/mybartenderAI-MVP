# SQLite Snapshot Fix - user_version PRAGMA Issue

**Date**: 2025-10-28
**Status**: Fixed
**Affected Components**: Backend snapshot generation, Mobile app Recipe Vault

## Problem

The Recipe Vault in the mobile app was failing to load cocktails with the error:
```
DatabaseException(table drinks already exists (code 1 SQLITE_ERROR))
```

Despite downloading the SQLite snapshot successfully (173KB compressed, 553KB decompressed), the app couldn't use the database.

## Root Cause

The backend's SQLite snapshot builder (`apps/backend/v3-deploy/services/sqliteSnapshotBuilder.js`) was using:

```javascript
db.run('PRAGMA user_version = 1');
```

However, **sql.js** (the pure JavaScript SQLite implementation used in Azure Functions) requires the `exec()` method for PRAGMA statements to take effect before exporting the database. Using `run()` doesn't persist the pragma value to the exported binary.

This caused the exported SQLite database to have `user_version = 0`, which made Flutter's sqflite think the database was uninitialized. sqflite then attempted to create tables via `onCreate()`, causing conflicts with the existing tables in the downloaded snapshot.

## Solution

Changed line 182 in `apps/backend/v3-deploy/services/sqliteSnapshotBuilder.js`:

```javascript
// Before (BROKEN)
db.run('PRAGMA user_version = 1');

// After (FIXED)
db.exec('PRAGMA user_version = 1');
```

### Why This Works

- `db.exec()` in sql.js immediately applies the statement to the in-memory database
- `db.run()` only executes the statement but doesn't guarantee persistence before export
- The `user_version` pragma is now correctly set to `1` in the exported binary
- sqflite recognizes the database as initialized and skips `onCreate()`
- No table conflicts occur

## Technical Details

### sql.js vs better-sqlite3

The project switched from `better-sqlite3` to `sql.js` because:
- `better-sqlite3` requires native compilation (not compatible with Azure Functions)
- `sql.js` is pure JavaScript and runs in Azure Functions Windows Consumption plan
- However, sql.js has different API semantics for PRAGMA statements

### sqflite Database Versioning

sqflite uses SQLite's `user_version` pragma to track schema versions:
- `user_version = 0`: Database is uninitialized, run `onCreate()`
- `user_version >= 1`: Database is initialized, skip `onCreate()`

## Files Modified

1. **`apps/backend/v3-deploy/services/sqliteSnapshotBuilder.js`** (Line 182)
   - Changed `db.run()` to `db.exec()` for PRAGMA user_version

## Verification

After the fix:
- ✅ Snapshot generates successfully (173KB compressed, 553KB decompressed)
- ✅ Mobile app downloads snapshot without errors
- ✅ Database loads successfully with no table conflicts
- ✅ Recipe Vault displays all 621 cocktails correctly
- ✅ Search functionality works (tested with "old fashion")
- ✅ Cocktail details display with images, ingredients, and instructions

## Testing

To test the snapshot generation:

```bash
# Deploy backend
cd apps/backend/v3-deploy
func azure functionapp publish func-mba-fresh --javascript

# Trigger sync manually
az functionapp keys list --name func-mba-fresh --resource-group rg-mba-prod
# Use master key to trigger
curl -X POST https://func-mba-fresh.azurewebsites.net/admin/functions/sync-cocktaildb \
  -H "x-functions-key: <MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d "{}"

# Verify snapshot metadata
curl https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest
```

To verify in mobile app:
1. Clear app data: `adb shell pm clear ai.mybartender.mybartenderai`
2. Launch app and navigate to Recipe Vault
3. Tap sync button or wait for automatic sync
4. Verify cocktails load and search works

## Related Documentation

- ADR 0008: CocktailDB V2 Mirror & On-Device SQLite
- `apps/backend/v3-deploy/README.md`: Backend deployment guide
- `mobile/app/lib/src/services/snapshot_service.dart`: Mobile snapshot sync

## Lessons Learned

1. **API Differences Matter**: Different SQLite libraries have different semantics for the same operations
2. **Test Edge Cases**: PRAGMA statements are easy to overlook but critical for compatibility
3. **Version Checking**: Always verify database version pragmas are correctly set in exported binaries
4. **Debugging Strategy**: Use `adb` to clear app data when troubleshooting persistent database issues

## Future Considerations

- Consider adding automated tests for snapshot generation
- Verify `user_version` in generated snapshots before upload
- Add health check that downloads and validates snapshot structure
