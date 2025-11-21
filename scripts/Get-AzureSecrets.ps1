<#
.SYNOPSIS
    Secure helper module for retrieving secrets from Azure Key Vault

.DESCRIPTION
    This script provides functions to securely retrieve secrets from Azure Key Vault
    without hardcoding them in test scripts or configuration files.

    All secrets are retrieved at runtime from kv-mybartenderai-prod Key Vault.

.EXAMPLE
    . .\scripts\Get-AzureSecrets.ps1
    $functionKey = Get-FunctionKey
    $apimKey = Get-ApimSubscriptionKey
#>

# Key Vault configuration
$script:KeyVaultName = "kv-mybartenderai-prod"
$script:ResourceGroup = "rg-mba-dev"

# Cache for secrets (in-memory only, never persisted)
$script:SecretCache = @{}

function Get-AzureSecret {
    <#
    .SYNOPSIS
        Retrieve a secret from Azure Key Vault
    .PARAMETER SecretName
        The name of the secret in Key Vault
    .PARAMETER NoCache
        Skip caching and always fetch from Key Vault
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$SecretName,

        [Parameter(Mandatory=$false)]
        [switch]$NoCache
    )

    # Check cache first (unless NoCache is specified)
    if (-not $NoCache -and $script:SecretCache.ContainsKey($SecretName)) {
        return $script:SecretCache[$SecretName]
    }

    try {
        Write-Verbose "Retrieving secret '$SecretName' from Key Vault '$script:KeyVaultName'"

        $secret = az keyvault secret show `
            --vault-name $script:KeyVaultName `
            --name $SecretName `
            --query "value" `
            -o tsv `
            2>$null

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($secret)) {
            throw "Failed to retrieve secret '$SecretName' from Key Vault"
        }

        # Cache the secret
        $script:SecretCache[$SecretName] = $secret

        return $secret
    }
    catch {
        Write-Error "Error retrieving secret '$SecretName': $_"
        throw
    }
}

function Get-FunctionKey {
    <#
    .SYNOPSIS
        Get the Azure Function host key
    #>
    return Get-AzureSecret -SecretName "AZURE-FUNCTION-KEY"
}

function Get-ApimSubscriptionKey {
    <#
    .SYNOPSIS
        Get the APIM subscription key
    #>
    return Get-AzureSecret -SecretName "APIM-SUBSCRIPTION-KEY"
}

function Get-StorageConnectionString {
    <#
    .SYNOPSIS
        Get the Storage Account connection string
    #>
    return Get-AzureSecret -SecretName "STORAGE-CONNECTION-STRING"
}

function Get-PostgresConnectionString {
    <#
    .SYNOPSIS
        Get the PostgreSQL connection string
    #>
    return Get-AzureSecret -SecretName "POSTGRES-CONNECTION-STRING"
}

function Get-OpenAIKey {
    <#
    .SYNOPSIS
        Get the Azure OpenAI API key
    #>
    return Get-AzureSecret -SecretName "AZURE-OPENAI-API-KEY"
}

function Get-OpenAIEndpoint {
    <#
    .SYNOPSIS
        Get the Azure OpenAI endpoint URL
    #>
    return Get-AzureSecret -SecretName "AZURE-OPENAI-ENDPOINT"
}

function Clear-SecretCache {
    <#
    .SYNOPSIS
        Clear the in-memory secret cache
    #>
    $script:SecretCache.Clear()
    Write-Verbose "Secret cache cleared"
}

function Test-AzureLogin {
    <#
    .SYNOPSIS
        Verify that the user is logged into Azure CLI
    #>
    $account = az account show 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Not logged into Azure CLI. Run 'az login' first."
        return $false
    }
    return $true
}

# Auto-verify Azure login when module is loaded
if (-not (Test-AzureLogin)) {
    Write-Warning "Please run 'az login' to authenticate with Azure before using this module"
}

# Export functions
Export-ModuleMember -Function @(
    'Get-AzureSecret',
    'Get-FunctionKey',
    'Get-ApimSubscriptionKey',
    'Get-StorageConnectionString',
    'Get-PostgresConnectionString',
    'Get-OpenAIKey',
    'Get-OpenAIEndpoint',
    'Clear-SecretCache',
    'Test-AzureLogin'
)
