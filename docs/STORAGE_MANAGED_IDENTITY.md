# Storage Access with Managed Identity

How `func-mba-fresh` reaches the storage account `mbacocktaildb3`, and the steps to finish moving it off the account key. This replaces `STORAGE_WRITE_FIX.md`, `MANAGED_IDENTITY_MIGRATION.md`, `STORAGE_MANAGED_IDENTITY_TODO.md` and `SAS_REENABLEMENT_NOTES.md`.

## How it works

| Code | Storage use | Auth |
|------|-------------|------|
| `snapshots-latest` → `services/snapshotStorageService.js` | Signs a 15-minute, read-only, HTTPS-only link to the latest snapshot blob for the app (`GET /api/v1/snapshots/latest`) | **User delegation SAS** from the managed identity |
| `download-images` → `services/imageDownloadService.js` | Writes drink images to `drink-images` | Managed identity |
| `auth-exchange` | Table storage | Managed identity |
| `rebuild-sqlite-snapshot.js` (repo root, run on the dev PC) | Writes the snapshot blob and the `snapshot_metadata` row | Developer's `az login` |
| Functions host (`AzureWebJobsStorage`, content share) | Platform | Unchanged; out of scope |

Until this change, `snapshots-latest` signed links with the account key from `BLOB_STORAGE_CONNECTION_STRING`. A managed-identity copy (`snapshots-latest-mi`) was deployed next to it but never used by the app, and it returned empty responses under the v4 model. The Function App no longer writes snapshots (the sync timers are disabled), so the old write errors no longer apply.

### Identity

`DefaultAzureCredential` picks the identity:

- If the app setting `AZURE_CLIENT_ID` is set, it uses that **user-assigned** identity (older notes mention `func-cocktaildb2-uami`, client ID `94d9cf74-…`).
- Otherwise it uses the Function App's **system-assigned** identity.

Whichever it is needs **Storage Blob Data Contributor** (or Owner) on `mbacocktaildb3`. That role includes `generateUserDelegationKey`, so **Storage Blob Delegator is not needed**. A user delegation SAS can grant no more than the identity's own data role allows.

### App settings

| Setting | Default in code | Notes |
|---------|-----------------|-------|
| `STORAGE_ACCOUNT_NAME` | `mbacocktaildb3` | |
| `SNAPSHOT_CONTAINER_NAME` | `snapshots` | |
| `SNAPSHOT_SAS_TTL_MINUTES` | `15` | Link lifetime |
| `AZURE_CLIENT_ID` | unset | Only for a user-assigned identity |
| `BLOB_STORAGE_CONNECTION_STRING` | not read | Remove after step 3 |

The service caches one user delegation key for 6 hours, so most requests make no extra call to Entra ID.

## Steps to finish (run on the dev PC)

1. **Check the role before deploying.**
   ```powershell
   ./scripts/Grant-StorageManagedIdentity.ps1          # report only
   ./scripts/Grant-StorageManagedIdentity.ps1 -Apply   # grant if missing (deploys infrastructure/storage/snapshot-storage-rbac.bicep)
   ```
   For a second opinion against the code that is live today, call `GET https://func-mba-fresh.azurewebsites.net/api/test/mi-access?code=<function key>` and check that `tests.userDelegationKey.success` is `true`.

2. **Deploy the backend** with the usual zip deploy (`DEPLOYMENT_STATUS.md` → Build & Deployment). The host should list 33 functions.

3. **Verify.**
   ```powershell
   $r = Invoke-RestMethod https://share.mybartenderai.com/api/v1/snapshots/latest
   $r.signedUrl -match 'skoid='                               # True: user delegation SAS (account-key links have no skoid)
   (Invoke-WebRequest $r.signedUrl -Method Head).StatusCode   # 200
   # The app downloads through the same Dio client as its API calls, so the request also carries
   # "Authorization: Bearer <Entra ID token>". Mimic that (run it once before deploying too, against
   # today's account-key link, and expect the same result):
   (Invoke-WebRequest $r.signedUrl -Method Head -Headers @{ Authorization = 'Bearer x' }).StatusCode
   ```
   Then do a fresh install (or clear app data) on one phone and let the initial sync finish.

   **Rollback:** redeploy the previous package. `BLOB_STORAGE_CONNECTION_STRING` is still there until step 4.

4. **After a few days without snapshot errors, remove the account-key setting.**
   ```powershell
   az functionapp config appsettings delete -g rg-mba-prod -n func-mba-fresh --subscription "My AI Bartender" --setting-names BLOB_STORAGE_CONNECTION_STRING
   ```
   If the value was a Key Vault reference, the secret behind it can go too. Leave `AzureWebJobsStorage` and `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` alone: the Functions host uses them.

## History

- **Oct 2025:** an attempt to disable shared-key access on `mbacocktaildb3` stopped the Function App from starting ("EPERM … lstat 'C:\home'"), because the host's content share needs the key. Shared-key access was turned back on. That remains true for the platform settings above; application code doesn't need the key.
- **Oct 2026:** `snapshots-latest` moved to a user delegation SAS. Removed: `snapshots-latest-mi`, `download-images-mi`, `test-write` (wrote junk blobs to `test-writes`), `snapshotStorageServiceMI.js`, the unused `uploadSnapshotArtifacts`, the legacy v3 copy in `apps/backend/v3-deploy/`, and `fix-storage-write-access.ps1` (replaced by `scripts/Grant-StorageManagedIdentity.ps1`).
