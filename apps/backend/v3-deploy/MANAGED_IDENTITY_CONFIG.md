# Managed Identity Configuration for Azure Functions

## Current Status (Updated 2025-10-20)
**IMPORTANT UPDATE**: We had to re-enable SAS on the storage account due to Windows Consumption plan limitations. While the application code uses Managed Identity for all data operations, the Azure Functions runtime requires SAS for mounting the file share where the code is deployed.

## Required Configuration for Windows Consumption Plan

For Windows Consumption plan, you need to configure the following in the Azure Portal:

### 1. Storage Account Configuration
In the Function App Configuration settings, add/update:

```
AzureWebJobsStorage__accountName = cocktaildbfun
AzureWebJobsStorage__blobServiceUri = https://cocktaildbfun.blob.core.windows.net
AzureWebJobsStorage__queueServiceUri = https://cocktaildbfun.queue.core.windows.net
AzureWebJobsStorage__tableServiceUri = https://cocktaildbfun.table.core.windows.net
```

### 2. Remove Old Settings
Delete these settings if they exist:
- `AzureWebJobsStorage` (the connection string)
- `AzureWebJobsDashboard`

### 3. Content Share Configuration
For the file share, you may need to keep:
- `WEBSITE_CONTENTSHARE = func-mba-freshdb27a2866c3f`
- `WEBSITE_CONTENTAZUREFILECONNECTIONSTRING` - This is tricky with SAS disabled

## Alternative: Use System-Assigned Identity

Since the Function App has a System-Assigned Identity, you might need to:
1. Use the System-Assigned Identity for runtime operations
2. Use the User-Assigned Identity for your application code

## Portal Configuration Steps

1. Go to Function App > Configuration > Application settings
2. Add the settings listed above
3. Remove the old connection string settings
4. Save and restart the Function App

## Note on Windows Consumption Plan Limitations

Windows Consumption plans have limitations with Managed Identity for file shares. 

**Update (2025-10-20)**: We had to re-enable SAS on the storage account for the Function App to work properly. This is a known limitation of Windows Consumption plans. The important distinction is:
- The Azure Functions runtime uses SAS for mounting the file share (platform requirement)
- All application code uses Managed Identity for data operations (our implementation)
- This provides the best balance of functionality and security given the platform constraints
