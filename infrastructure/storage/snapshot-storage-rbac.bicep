// Grants the identity that func-mba-fresh signs in with data access to mbacocktaildb3.
// Storage Blob Data Contributor covers what the app needs: reading and writing blobs
// (download-images) and requesting a user delegation key (snapshots-latest signs
// snapshot download links with it). Deploy to rg-mba-prod; run
// scripts/Grant-StorageManagedIdentity.ps1 rather than deploying this by hand.

@description('Storage account that holds the snapshots and drink-images containers')
param storageAccountName string = 'mbacocktaildb3'

@description('Object (principal) ID of the managed identity func-mba-fresh uses')
param principalId string

var storageBlobDataContributor = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource blobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, principalId, storageBlobDataContributor)
  scope: storage
  properties: {
    roleDefinitionId: storageBlobDataContributor
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
