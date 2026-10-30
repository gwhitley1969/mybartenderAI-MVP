<#
.SYNOPSIS
    Checks (and with -Apply, grants) the storage role func-mba-fresh needs to sign snapshot links.

.DESCRIPTION
    snapshots-latest signs snapshot download links with a user delegation SAS, and
    download-images writes blobs, both with the Function App's managed identity.
    That identity needs Storage Blob Data Contributor (or Owner) on mbacocktaildb3.

    The script finds the identity DefaultAzureCredential will use: the user-assigned
    identity named by the AZURE_CLIENT_ID app setting if there is one, otherwise the
    system-assigned identity. It reports that identity's roles on the storage account
    and, with -Apply, deploys infrastructure/storage/snapshot-storage-rbac.bicep to
    add the missing role. Without -Apply it changes nothing.

    See docs/STORAGE_MANAGED_IDENTITY.md.

.EXAMPLE
    ./scripts/Grant-StorageManagedIdentity.ps1
    ./scripts/Grant-StorageManagedIdentity.ps1 -Apply
#>
param(
    [switch]$Apply,
    [string]$Subscription = 'My AI Bartender'
)

$ErrorActionPreference = 'Stop'

$resourceGroup = 'rg-mba-prod'
$functionApp = 'func-mba-fresh'
$storageAccount = 'mbacocktaildb3'
$sufficientRoles = @('Storage Blob Data Contributor', 'Storage Blob Data Owner')

function Invoke-Az {
    $output = & az @args --subscription $Subscription --output json
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') failed" }
    if ($output) { $output | ConvertFrom-Json }
}

Write-Host "=== Storage access for $functionApp ===" -ForegroundColor Cyan

# 1. Which identity will DefaultAzureCredential use?
$settings = Invoke-Az functionapp config appsettings list --name $functionApp --resource-group $resourceGroup
$clientId = ($settings | Where-Object name -eq 'AZURE_CLIENT_ID').value
$hasConnectionString = [bool]($settings | Where-Object name -eq 'BLOB_STORAGE_CONNECTION_STRING')

if ($clientId) {
    $identity = Invoke-Az identity list --query "[?clientId=='$clientId'] | [0]"
    if (-not $identity) { throw "AZURE_CLIENT_ID is $clientId, but no user-assigned identity with that client ID was found." }
    $principalId = $identity.principalId
    Write-Host "Identity: user-assigned '$($identity.name)' (AZURE_CLIENT_ID), principal $principalId"
} else {
    $principalId = (Invoke-Az functionapp identity show --name $functionApp --resource-group $resourceGroup).principalId
    if (-not $principalId) { throw "$functionApp has no system-assigned identity and AZURE_CLIENT_ID is not set." }
    Write-Host "Identity: system-assigned, principal $principalId"
}

# 2. Does it hold a sufficient role on the storage account?
$storageId = (Invoke-Az storage account show --name $storageAccount --resource-group $resourceGroup).id
$roles = @(Invoke-Az role assignment list --assignee $principalId --scope $storageId --include-inherited --query '[].roleDefinitionName')
Write-Host "Roles on ${storageAccount}: $(if ($roles) { $roles -join ', ' } else { '(none)' })"

$hasRole = [bool]($roles | Where-Object { $sufficientRoles -contains $_ })
if ($hasRole) {
    Write-Host 'OK: the identity can read and write blobs and request a user delegation key.' -ForegroundColor Green
} elseif ($Apply) {
    Write-Host 'Granting Storage Blob Data Contributor...' -ForegroundColor Yellow
    $template = Join-Path $PSScriptRoot '..\infrastructure\storage\snapshot-storage-rbac.bicep'
    Invoke-Az deployment group create --resource-group $resourceGroup --template-file $template `
        --parameters storageAccountName=$storageAccount principalId=$principalId | Out-Null
    Write-Host 'Granted. Role assignments can take a few minutes to apply; restart the Function App before testing.' -ForegroundColor Green
} else {
    Write-Host 'MISSING: Storage Blob Data Contributor. Run again with -Apply to grant it.' -ForegroundColor Red
}

# 3. Leftover account-key setting
if ($hasConnectionString) {
    Write-Host 'BLOB_STORAGE_CONNECTION_STRING is still set. Once /v1/snapshots/latest is verified on the managed identity, remove it (docs/STORAGE_MANAGED_IDENTITY.md, step 4).' -ForegroundColor Yellow
}
