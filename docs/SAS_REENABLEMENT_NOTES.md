# SAS Re-enablement Notes

**Date**: October 20, 2025

## Summary

We attempted to run Azure Functions on a Windows Consumption plan with SAS completely disabled on the storage account. While we successfully migrated all application code to use Managed Identity, we discovered that the Azure Functions runtime itself requires SAS for fundamental operations.

## What We Tried

1. **Initial Goal**: Disable SAS entirely on storage account `mbacocktaildb3`
2. **Implementation**: 
   - Migrated all code to use Managed Identity
   - Removed all SAS key-based authentication from our services
   - Implemented User Delegation SAS (MI-based) for client access
3. **Result**: Function App failed to start with "EPERM: operation not permitted, lstat 'C:\home'" errors

## Root Cause

Windows Consumption plans have a hard requirement for connection strings with storage account keys for:
- `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` - Where Function App code is deployed
- The Azure Files share that contains the function code

This is a platform limitation that cannot be worked around with current Azure Functions architecture.

## Resolution

We re-enabled SAS on the storage account `mbacocktaildb3` to allow the Function App runtime to operate.

## Important Distinctions

1. **Platform Use of SAS**: Only the Azure Functions runtime uses SAS for mounting file shares
2. **Application Use of MI**: All our application code uses Managed Identity for:
   - Reading/writing blobs
   - Generating User Delegation SAS tokens
   - All data operations

## Security Posture

- ✅ No storage account keys in application code
- ✅ All data access uses Managed Identity with RBAC
- ✅ User Delegation SAS for temporary client access
- ⚠️ SAS enabled on storage account (required for Function App runtime)

## Alternative Options

If complete SAS elimination is required:
1. **Premium Plan**: Supports Managed Identity for file shares (more expensive)
2. **Container Apps**: Full MI support, different deployment model
3. **App Service Plan**: Better MI support than Consumption

## Lessons Learned

- Windows Consumption plans have inherent limitations with Managed Identity
- Platform requirements sometimes conflict with security best practices
- Always test in the target hosting environment before committing to architecture decisions
