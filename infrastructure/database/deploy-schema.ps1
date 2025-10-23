# Deploy PostgreSQL Database Schema for MyBartenderAI
# This script deploys the complete database schema to Azure PostgreSQL

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "pg-mybartenderdb.postgres.database.azure.com",

    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "mybartender",

    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "pgadmin",

    [Parameter(Mandatory=$false)]
    [string]$SchemaFile = "schema.sql",

    [Parameter(Mandatory=$false)]
    [switch]$UseKeyVault = $true,

    [Parameter(Mandatory=$false)]
    [string]$KeyVaultName = "kv-mybartenderai-prod",

    [Parameter(Mandatory=$false)]
    [string]$SecretName = "POSTGRES-CONNECTION-STRING"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MyBartenderAI - Database Schema Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if schema file exists
if (-not (Test-Path $SchemaFile)) {
    Write-Host "❌ Schema file not found: $SchemaFile" -ForegroundColor Red
    Write-Host "Please ensure you're running this script from the infrastructure/database directory" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Found schema file: $SchemaFile" -ForegroundColor Green
Write-Host ""

# Get password
$password = $null

if ($UseKeyVault) {
    Write-Host "Retrieving connection string from Key Vault: $KeyVaultName" -ForegroundColor Yellow

    try {
        # Check if logged in to Azure
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "Not logged in to Azure. Please run 'Connect-AzAccount'" -ForegroundColor Red
            exit 1
        }

        # Get secret from Key Vault
        $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $SecretName -AsPlainText

        if ($secret) {
            Write-Host "✓ Retrieved connection string from Key Vault" -ForegroundColor Green

            # Parse connection string to extract password
            # Format: Host=...;Database=...;Username=...;Password=...
            if ($secret -match "Password=([^;]+)") {
                $password = $Matches[1]
            }
        } else {
            Write-Host "❌ Secret not found in Key Vault" -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "❌ Error retrieving secret from Key Vault: $_" -ForegroundColor Red
        Write-Host "Falling back to manual password entry" -ForegroundColor Yellow
        $UseKeyVault = $false
    }
}

if (-not $password) {
    Write-Host "Enter PostgreSQL admin password:" -ForegroundColor Yellow
    $securePassword = Read-Host -AsSecureString
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )
}

Write-Host ""

# Check if psql is available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if (-not $psqlPath) {
    Write-Host "❌ psql command not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install PostgreSQL client tools:" -ForegroundColor Yellow
    Write-Host "  Windows: https://www.postgresql.org/download/windows/" -ForegroundColor Cyan
    Write-Host "  macOS: brew install postgresql" -ForegroundColor Cyan
    Write-Host "  Linux: sudo apt-get install postgresql-client" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

Write-Host "✓ Found psql client" -ForegroundColor Green
Write-Host ""

# Set environment variable for password
$env:PGPASSWORD = $password

# Deploy schema
Write-Host "Deploying schema to: $ServerName/$DatabaseName" -ForegroundColor Yellow
Write-Host ""

try {
    # Test connection first
    Write-Host "Testing database connection..." -ForegroundColor Yellow
    $testQuery = "SELECT version();"
    $result = & psql -h $ServerName -U $AdminUsername -d $DatabaseName -c $testQuery 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Connection successful" -ForegroundColor Green
        Write-Host ""

        # Deploy schema
        Write-Host "Deploying schema..." -ForegroundColor Yellow
        Write-Host "----------------------------------------" -ForegroundColor Cyan

        $deployResult = & psql -h $ServerName -U $AdminUsername -d $DatabaseName -f $SchemaFile 2>&1

        Write-Host "----------------------------------------" -ForegroundColor Cyan
        Write-Host ""

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Schema deployed successfully!" -ForegroundColor Green
            Write-Host ""

            # Verify deployment
            Write-Host "Verifying deployment..." -ForegroundColor Yellow
            $verifyQuery = @"
SELECT
    'Tables' as type,
    COUNT(*) as count
FROM information_schema.tables
WHERE table_schema = 'public'
UNION ALL
SELECT
    'Functions' as type,
    COUNT(*) as count
FROM information_schema.routines
WHERE routine_schema = 'public';
"@

            $verification = & psql -h $ServerName -U $AdminUsername -d $DatabaseName -c $verifyQuery 2>&1
            Write-Host $verification
            Write-Host ""

            Write-Host "========================================" -ForegroundColor Green
            Write-Host "Deployment Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Database: $ServerName/$DatabaseName" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Next Steps:" -ForegroundColor Cyan
            Write-Host "1. Review tables: \dt in psql" -ForegroundColor White
            Write-Host "2. Check functions: \df in psql" -ForegroundColor White
            Write-Host "3. Test quota function: SELECT * FROM check_user_quota(...);" -ForegroundColor White
            Write-Host "4. Update Function App connection string if needed" -ForegroundColor White
            Write-Host ""

        } else {
            Write-Host "❌ Schema deployment failed" -ForegroundColor Red
            Write-Host "Error output:" -ForegroundColor Yellow
            Write-Host $deployResult
            exit 1
        }

    } else {
        Write-Host "❌ Connection failed" -ForegroundColor Red
        Write-Host "Error: $result" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Cyan
        Write-Host "1. Check PostgreSQL firewall rules allow your IP" -ForegroundColor White
        Write-Host "2. Verify server name is correct" -ForegroundColor White
        Write-Host "3. Ensure database exists" -ForegroundColor White
        Write-Host "4. Check admin credentials" -ForegroundColor White
        exit 1
    }

} catch {
    Write-Host "❌ Deployment error: $_" -ForegroundColor Red
    exit 1
} finally {
    # Clear password from environment
    Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue
}

Write-Host ""
