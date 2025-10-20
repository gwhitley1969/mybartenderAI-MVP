# Managed Identity Migration Plan for MyBartenderAI

## Overview
This document outlines the migration plan from connection string/SAS token authentication to Azure Managed Identity for all blob storage operations.

## Current State
- **Storage Account**: `cocktaildbfun`
- **Managed Identity**: `func-cocktaildb2-uami`
  - Object ID: `513f112a-7c28-4b8d-8482-f9d22d7cb631`
  - Client ID: `94d9cf74-99a3-49d5-9be4-98ce2eae1d33`
- **Current Roles**: 
  - ✅ Storage Blob Data Owner
  - ✅ Storage Blob Data Contributor
  - ❌ Storage Blob Delegator (needed for User Delegation SAS)

## Migration Steps

### Phase 1: Prerequisites ✅ COMPLETED
1. Created new MI-enabled storage service (`snapshotStorageServiceMI.js`)
2. Created test endpoint (`/v1/snapshots/latest-mi`)
3. Documented required roles

### Phase 2: Add Missing Role 🚀 NEXT
```bash
# Add Storage Blob Delegator role
az role assignment create \
  --assignee "94d9cf74-99a3-49d5-9be4-98ce2eae1d33" \
  --role "Storage Blob Delegator" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/rg-mba-prod/providers/Microsoft.Storage/storageAccounts/cocktaildbfun"
```

### Phase 3: Update Environment Variables
1. **Add new variables**:
   ```bash
   az functionapp config appsettings set \
     --name func-mba-fresh \
     --resource-group rg-mba-prod \
     --settings "STORAGE_ACCOUNT_NAME=cocktaildbfun"
   ```

2. **Keep existing** (for now):
   - `BLOB_STORAGE_CONNECTION_STRING` - For backward compatibility
   - `SNAPSHOT_CONTAINER_NAME` - Still needed

### Phase 4: Migrate Services

#### 4.1 Image Download Service
**File**: `apps/backend/v3-deploy/services/imageDownloadService.js`
**Changes**:
- Replace `BlobServiceClient.fromConnectionString()` with MI-enabled client
- Update container client initialization

#### 4.2 Sync Service  
**File**: `apps/backend/v3-deploy/services/cocktailDbSyncService.js`
**Changes**:
- Update snapshot upload to use MI-enabled `uploadSnapshotArtifacts`

#### 4.3 All Endpoints Using Blob Storage
- `sync-cocktaildb` - Update to use new storage service
- `download-images` - Update to use MI for blob uploads
- `snapshots-latest` - Switch from legacy to MI version

### Phase 5: Testing Plan

1. **Local Testing** (with Azure CLI auth):
   ```bash
   # Login to Azure CLI
   az login
   
   # Set environment variables
   export STORAGE_ACCOUNT_NAME=cocktaildbfun
   export SNAPSHOT_CONTAINER_NAME=snapshots
   
   # Run functions locally
   func start
   ```

2. **Staged Rollout**:
   - Deploy MI version alongside existing version
   - Test with `/v1/snapshots/latest-mi` endpoint
   - Monitor for errors
   - Switch traffic gradually

3. **Validation Tests**:
   - ✅ Snapshot generation and upload
   - ✅ SAS token generation with User Delegation
   - ✅ Image download and storage
   - ✅ Blob container operations

### Phase 6: Cleanup
1. Remove `BLOB_STORAGE_CONNECTION_STRING` from Key Vault
2. Remove legacy storage service code
3. Update documentation

## Implementation Files

### 1. Updated Image Download Service
Create `imageDownloadServiceMI.js`:
```javascript
const { DefaultAzureCredential } = require("@azure/identity");
const { BlobServiceClient } = require("@azure/storage-blob");

// Use MI for blob operations
const getBlobServiceClient = () => {
    const accountName = process.env.STORAGE_ACCOUNT_NAME || 'cocktaildbfun';
    const credential = new DefaultAzureCredential();
    return new BlobServiceClient(
        `https://${accountName}.blob.core.windows.net`,
        credential
    );
};
```

### 2. Updated Sync Service Integration
Update snapshot uploads in sync service to use the new MI-enabled service.

## Benefits
1. **Enhanced Security**: No storage keys in configuration
2. **Simplified Key Management**: No key rotation needed
3. **Better Auditability**: All access through Azure AD
4. **Reduced Attack Surface**: No long-lived secrets

## Rollback Plan
If issues occur:
1. Endpoints can fall back to `generateSnapshotSasLegacy()`
2. Connection string remains available during transition
3. Original endpoints remain unchanged until validation complete

## Monitoring
- Monitor Application Insights for authentication errors
- Check for "AuthenticationFailed" errors in logs
- Validate SAS token generation success rate

## Timeline
- **Week 1**: Add roles, test MI endpoint
- **Week 2**: Migrate services, test thoroughly  
- **Week 3**: Deploy to production, monitor
- **Week 4**: Remove legacy code and connection strings
