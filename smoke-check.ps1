# Example: .\smoke-check.ps1 -ResourceGroup rg-mba-prod -FunctionApp func-cocktaildb2 -TailLogs
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]$FunctionApp,
    [string]$BaseUrl,
    [string]$AdminBaseUrl,
    [string]$TimerFunctionName = 'sync-cocktaildb',
    [string]$SnapshotPath = '/api/v1/snapshots/latest',
    [int]$TimeoutSec = 600,
    [int]$PollSec = 5,
    [switch]$TailLogs
)

Set-StrictMode -Version 3
$ErrorActionPreference = 'Stop'

try {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
} catch {
    # Ignore if not supported
}

$script:SupportsUseBasicParsing = (Get-Command Invoke-WebRequest).Parameters.ContainsKey('UseBasicParsing')

function Get-PlainText {
    param($Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [string]) {
        return $Value
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return ($Value | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                $_.ToString()
            } else {
                [string]$_
            }
        }) -join [Environment]::NewLine
    }

    return $Value.ToString()
}

function Invoke-WebRequestCompat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Uri]$Uri,
        [Microsoft.PowerShell.Commands.WebRequestMethod]$Method = [Microsoft.PowerShell.Commands.WebRequestMethod]::Get,
        [hashtable]$Headers,
        [string]$ContentType,
        $Body
    )

    $requestParams = @{
        Uri    = $Uri
        Method = $Method
    }

    if ($PSBoundParameters.ContainsKey('Headers')) {
        $requestParams.Headers = $Headers
    }
    if ($PSBoundParameters.ContainsKey('ContentType')) {
        $requestParams.ContentType = $ContentType
    }
    if ($PSBoundParameters.ContainsKey('Body')) {
        $requestParams.Body = $Body
    }
    if ($script:SupportsUseBasicParsing) {
        $requestParams.UseBasicParsing = $true
    }

    return Invoke-WebRequest @requestParams
}

function Flush-LogJob {
    param(
        [System.Management.Automation.Job]$Job
    )

    if ($null -eq $Job) {
        return
    }

    $logLines = Receive-Job -Job $Job -Keep -ErrorAction SilentlyContinue
    if ($logLines) {
        foreach ($line in $logLines) {
            if ($null -ne $line) {
                Write-Host $line
            }
        }
    }

    if ($Job.State -eq 'Failed') {
        $jobErrors = $Job.ChildJobs | ForEach-Object { $_.Error }
        if ($jobErrors) {
            foreach ($errorRecord in $jobErrors) {
                if ($null -ne $errorRecord) {
                    Write-Warning ("Log tail job error: {0}" -f $errorRecord.ToString())
                }
            }
        }
    }
}

function Stop-LogJob {
    param(
        [System.Management.Automation.Job]$Job
    )

    if ($null -eq $Job) {
        return
    }

    try {
        if ($Job.State -eq 'Running' -or $Job.State -eq 'NotStarted') {
            Stop-Job -Job $Job -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {
        Write-Warning ("Failed to stop log tail job: {0}" -f $_.Exception.Message)
    }

    Flush-LogJob $Job

    try {
        Remove-Job -Job $Job -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Warning ("Failed to remove log tail job: {0}" -f $_.Exception.Message)
    }
}

$exitCode = 0
$logJob = $null

try {
    if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
        Write-Error "Parameter -ResourceGroup cannot be empty."
        $exitCode = 1
        return
    }

    if ([string]::IsNullOrWhiteSpace($FunctionApp)) {
        Write-Error "Parameter -FunctionApp cannot be empty."
        $exitCode = 1
        return
    }

    if ([string]::IsNullOrWhiteSpace($TimerFunctionName)) {
        Write-Error "Parameter -TimerFunctionName cannot be empty."
        $exitCode = 1
        return
    }

    if ([string]::IsNullOrWhiteSpace($SnapshotPath)) {
        Write-Error "Parameter -SnapshotPath cannot be empty."
        $exitCode = 1
        return
    }

    if ($TimeoutSec -le 0) {
        Write-Error "Parameter -TimeoutSec must be greater than zero."
        $exitCode = 1
        return
    }

    if ($PollSec -le 0) {
        Write-Error "Parameter -PollSec must be greater than zero."
        $exitCode = 1
        return
    }

    $ResourceGroup = $ResourceGroup.Trim()
    $FunctionApp = $FunctionApp.Trim()
    $TimerFunctionName = $TimerFunctionName.Trim()
    $SnapshotPath = $SnapshotPath.Trim()

    $baseUrlProvided = $PSBoundParameters.ContainsKey('BaseUrl') -and -not [string]::IsNullOrWhiteSpace($BaseUrl)

    if (-not $baseUrlProvided) {
        $BaseUrl = "https://$FunctionApp.azurewebsites.net"
    }

    $BaseUrl = $BaseUrl.Trim()
    if (-not $BaseUrl) {
        Write-Error "Resolved base URL is empty."
        $exitCode = 1
        return
    }

    if (-not $BaseUrl.EndsWith('/')) {
        $BaseUrl = "$BaseUrl/"
    }

    try {
        $baseUri = [System.Uri]$BaseUrl
    } catch {
        Write-Error ("BaseUrl '{0}' is not a valid absolute URI." -f $BaseUrl)
        $exitCode = 1
        return
    }

    $normalizedSnapshotPath = $SnapshotPath.TrimStart('/')
    $snapshotUri = [System.Uri]::new($baseUri, $normalizedSnapshotPath)

    $adminBaseProvided = $PSBoundParameters.ContainsKey('AdminBaseUrl') -and -not [string]::IsNullOrWhiteSpace($AdminBaseUrl)

    if ($adminBaseProvided) {
        $AdminBaseUrl = $AdminBaseUrl.Trim()
    } elseif ($baseUrlProvided) {
        $AdminBaseUrl = $BaseUrl
    } else {
        $AdminBaseUrl = "https://$FunctionApp.azurewebsites.net"
    }

    $AdminBaseUrl = $AdminBaseUrl.Trim()
    if (-not $AdminBaseUrl) {
        Write-Error "Resolved admin base URL is empty."
        $exitCode = 1
        return
    }

    if (-not $AdminBaseUrl.EndsWith('/')) {
        $AdminBaseUrl = "$AdminBaseUrl/"
    }

    try {
        $adminBaseUri = [System.Uri]$AdminBaseUrl
    } catch {
        Write-Error ("AdminBaseUrl '{0}' is not a valid absolute URI." -f $AdminBaseUrl)
        $exitCode = 1
        return
    }

    try {
        Get-Command az -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Azure CLI (az) is not available on PATH. Install Azure CLI before running this script."
        $exitCode = 1
        return
    }

    $accountCheckOutput = az account show --query "name" -o tsv 2>&1
    $accountCheckOutputText = Get-PlainText $accountCheckOutput
    $accountNameLine = ($accountCheckOutputText -split [Environment]::NewLine | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith('WARNING:') }) | Select-Object -First 1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($accountNameLine)) {
        Write-Error "Azure CLI is not authenticated. Run 'az login' and re-run this script."
        if ($accountCheckOutputText -and $LASTEXITCODE -ne 0) {
            Write-Error $accountCheckOutputText
        }
        $exitCode = 1
        return
    }

    $accountName = $accountNameLine.Trim()
    Write-Host ("Azure CLI authenticated (subscription: {0})." -f $accountName)

    $functionCheckOutput = az functionapp show --only-show-errors -g $ResourceGroup -n $FunctionApp 2>&1
    $functionCheckOutputText = Get-PlainText $functionCheckOutput
    if ($LASTEXITCODE -ne 0) {
        Write-Error ("Azure Function App '{0}' in resource group '{1}' could not be found or accessed." -f $FunctionApp, $ResourceGroup)
        if ($functionCheckOutputText) {
            Write-Error $functionCheckOutputText
        }
        $exitCode = 1
        return
    }
    Write-Host ("Verified Function App '{0}' in resource group '{1}'." -f $FunctionApp, $ResourceGroup)

    $hostMasterKeyRaw = az functionapp keys list --only-show-errors -g $ResourceGroup -n $FunctionApp --query masterKey -o tsv 2>&1
    $hostMasterKeyText = Get-PlainText $hostMasterKeyRaw
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to retrieve the host master key."
        if ($hostMasterKeyText) {
            Write-Error $hostMasterKeyText
        }
        $exitCode = 1
        return
    }

    $hostMasterKey = $hostMasterKeyText.Trim()
    if ([string]::IsNullOrWhiteSpace($hostMasterKey)) {
        Write-Error "Received empty host master key."
        $exitCode = 1
        return
    }

    if ($TailLogs.IsPresent) {
        Write-Host "Starting live log tail (Ctrl+C to stop script will also stop log tail)."
        try {
            $logJob = Start-Job -Name ("log-tail-{0}" -f $FunctionApp) -ArgumentList $ResourceGroup, $FunctionApp -ScriptBlock {
                param($rgParam, $appParam)
                az webapp log tail --resource-group $rgParam --name $appParam
            }
            Start-Sleep -Milliseconds 200
            Flush-LogJob $logJob
        } catch {
            Write-Warning ("Unable to start log tail job: {0}" -f $_.Exception.Message)
            $logJob = $null
        }
    }

    $encodedHostKey = [System.Uri]::EscapeDataString($hostMasterKey)
    $adminRelativePath = ("admin/functions/{0}?code={1}" -f [System.Uri]::EscapeDataString($TimerFunctionName), $encodedHostKey)
    $adminUri = [System.Uri]::new($adminBaseUri, $adminRelativePath)

    Write-Host ("Triggering timer function '{0}'..." -f $TimerFunctionName)

    try {
        $triggerResponse = Invoke-WebRequestCompat -Uri $adminUri -Method ([Microsoft.PowerShell.Commands.WebRequestMethod]::Post) -ContentType 'application/json' -Body '{"input": ""}'
        $triggerStatusCode = [int]$triggerResponse.StatusCode
        if ($triggerStatusCode -ne 200 -and $triggerStatusCode -ne 202) {
            Write-Error ("Timer trigger returned unexpected status code {0}." -f $triggerStatusCode)
            $exitCode = 1
            return
        }
        Write-Host ("Timer function triggered successfully (HTTP {0})." -f $triggerStatusCode)
    } catch {
        Write-Error ("Failed to trigger timer function '{0}': {1}" -f $TimerFunctionName, $_.Exception.Message)
        $exitCode = 1
        return
    }

    Write-Host ("Polling snapshot endpoint '{0}' every {1}s (timeout {2}s)..." -f $snapshotUri.AbsoluteUri, $PollSec, $TimeoutSec)

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    $attempt = 0
    $success = $false
    $jsonText = $null
    $payload = $null

    while ($true) {
        $attempt++

        try {
            $response = Invoke-WebRequestCompat -Uri $snapshotUri -Method ([Microsoft.PowerShell.Commands.WebRequestMethod]::Get) -Headers @{ Accept = 'application/json' }
            $statusCode = [int]$response.StatusCode

            if ($statusCode -eq 200) {
                $jsonCandidate = if ($null -ne $response.Content) { $response.Content.Trim() } else { "" }

                if ([string]::IsNullOrWhiteSpace($jsonCandidate)) {
                    Write-Host ("Attempt {0}: HTTP 200 but response body is empty. Waiting..." -f $attempt)
                } else {
                    try {
                        $payload = $jsonCandidate | ConvertFrom-Json -ErrorAction Stop
                        $jsonText = $jsonCandidate
                        $success = $true
                        Write-Host ("Attempt {0}: Snapshot endpoint returned HTTP 200 with valid JSON." -f $attempt)
                    } catch {
                        Write-Host ("Attempt {0}: HTTP 200 but response was not valid JSON. Waiting..." -f $attempt)
                    }
                }
            } else {
                Write-Host ("Attempt {0}: Snapshot endpoint returned HTTP {1}. Waiting..." -f $attempt, $statusCode)
            }
        } catch {
            $message = $_.Exception.Message
            $statusCode = $null
            if ($_.Exception -is [System.Net.WebException] -and $_.Exception.Response) {
                try {
                    $statusCode = [int]($_.Exception.Response.StatusCode)
                } catch {
                    $statusCode = $null
                }
            }

            if ($statusCode) {
                Write-Host ("Attempt {0}: Snapshot endpoint returned HTTP {1}. Waiting..." -f $attempt, $statusCode)
            } else {
                Write-Host ("Attempt {0}: Snapshot request failed: {1}" -f $attempt, $message)
            }
        }

        Flush-LogJob $logJob

        if ($success) {
            break
        }

        if ([DateTime]::UtcNow -ge $deadline) {
            break
        }

        Start-Sleep -Seconds $PollSec
    }

    Flush-LogJob $logJob

    if (-not $success) {
        Write-Error ("Timed out after {0} seconds waiting for {1} to return HTTP 200 with JSON." -f $TimeoutSec, $snapshotUri.AbsoluteUri)
        $exitCode = 2
        return
    }

    $summaryParts = @()

    if ($payload -is [System.Management.Automation.PSCustomObject]) {
        $properties = $payload.PSObject.Properties
        if ($properties.Name -contains 'generatedAt') {
            $summaryParts += ("generatedAt={0}" -f $payload.generatedAt)
        }
        if ($properties.Name -contains 'version') {
            $summaryParts += ("version={0}" -f $payload.version)
        }
        if ($properties.Name -contains 'count') {
            $summaryParts += ("count={0}" -f $payload.count)
        }
    } elseif ($payload -is [System.Object[]] -and $payload.Length -gt 0 -and $payload[0] -is [System.Management.Automation.PSCustomObject]) {
        $first = $payload[0]
        $properties = $first.PSObject.Properties
        if ($properties.Name -contains 'generatedAt') {
            $summaryParts += ("generatedAt={0}" -f $first.generatedAt)
        }
        if ($properties.Name -contains 'version') {
            $summaryParts += ("version={0}" -f $first.version)
        }
        if ($properties.Name -contains 'count') {
            $summaryParts += ("count={0}" -f $first.count)
        }
        $summaryParts += ("items={0}" -f $payload.Length)
    }

    if ($summaryParts.Count -gt 0) {
        Write-Host ("Snapshot summary: {0}" -f ($summaryParts -join ', '))
    } else {
        Write-Host "Snapshot retrieved successfully."
    }

    if (-not $jsonText) {
        $jsonText = $payload | ConvertTo-Json -Depth 32
    }

    Write-Output $jsonText

    $exitCode = 0
    return
} catch {
    if ($exitCode -eq 0) {
        $exitCode = 1
    }
    Write-Error ("Unexpected error: {0}" -f $_.Exception.Message)
} finally {
    Stop-LogJob $logJob
}

exit $exitCode
