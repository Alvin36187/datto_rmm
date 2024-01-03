# Acronis cloud URL (required)
$CloudUrl = $env:registrationURL

# Acronis registration token (required)
$RegistrationToken = $env:acronisToken

# Task Type (install/uninstall/upgrade)
$TaskType = $env:Action

# Installer options (none/domain)
$InstallerOptions = $env:InstallerOptions

# $AgentAccountLogin    - Domain Controller username (optional)
$AgentAccountLogin = $env:DomainUsername

# $AgentAccountPassword - Domain Controller password (optional)
$AgentAccountPassword = $env:DomainPassword


$ErrorActionPreference = "Stop"

$acronisRegistryPath = "HKLM:\SOFTWARE\Acronis\BackupAndRecovery\Settings\MachineManager"

[string] $aAkorePath = "${env:CommonProgramFiles}\Acronis\Agent\aakore.exe"

# Register WebClient with 1 hour timeout
$timeoutWebClientCode = @"
public class TimeoutWebClient : System.Net.WebClient
{
    protected override System.Net.WebRequest GetWebRequest(System.Uri address)
    {
        System.Net.WebRequest request = base.GetWebRequest(address);

        if (request != null)
        {
            request.Timeout = System.Convert.ToInt32(System.TimeSpan.FromHours(1).TotalMilliseconds);
        }
        return request;
    }
}
"@;
Add-Type -TypeDefinition $timeoutWebclientCode -Language CSharp -WarningAction SilentlyContinue

function Test-AgentInstalled {
    return Test-Path -Path ($aAkorePath)
}

function Get-ResourceId {
    return Get-ItemProperty -Path $acronisRegistryPath | Select-Object -ExpandProperty InstanceID
}

function Get-AgentInstallerUrl {
    param ([string] $cloudUrl)
    
    $response = Invoke-RestMethod -Uri "${cloudUrl}/bc/api/ams/links/list" -Method Get
    foreach ($agent in $response.agents) {
        if ($agent.system -eq "exe" -and $agent.architecture -eq (32, 64)[[System.Environment]::Is64BitOperatingSystem]) {
            return $agent.url
        }
    }
}

function Get-AccessToken {
    param ([string] $cloudUrl, [string] $registrationToken)
    
    $headers = @{ "Content-Type" = "application/x-www-form-urlencoded" }
    $body = @{
        "grant_type" = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        "assertion"  = $registrationToken
    }
    $response = Invoke-RestMethod -Uri "${cloudUrl}/bc/idp/token" `
        -Method Post `
        -Headers $headers `
        -Body $body
    
    return $response.access_token
}

function Get-AakoreAccessToken {
    param ([string] $aakoreProxyLocation, [string] $clientId, [string] $clientSecret, $aakoreSession)
    
    $clientIdSecretBytes = [System.Text.Encoding]::ASCII.GetBytes("${clientId}:${clientSecret}")
    $clientIdSecretBase64 = [System.Convert]::ToBase64String($clientIdSecretBytes)
    $headers = @{
        "Authorization" = "Basic $clientIdSecretBase64"
        "Content-Type"  = "application/x-www-form-urlencoded"
    }
    $body = @{ grant_type = "client_credentials" }
    $response = Invoke-RestMethod -Uri "${aakoreProxyLocation}/idp/token" `
        -Method Post `
        -Headers $headers `
        -Body $body `
        -WebSession $aakoreSession

    return $response.access_token
}

function Invoke-Plan {
    param ([string] $cloudUrl, [string] $accessToken, [string] $resourceId)
    
    $headers = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $accessToken"
    }
    $body = @{
        "context" = @{
            "items" = @($resourceId)
        }
    } | ConvertTo-Json
    Invoke-RestMethod -Uri "${cloudUrl}/api/policy_management/v4/applications" `
        -Method Post `
        -Headers $headers `
        -Body $body
}

function Install-Agent {
    Write-Host "Resolving distributive on url = $CloudUrl"

    $agentUrl = Get-AgentInstallerUrl $CloudUrl

    Write-Host "Download distributive: $agentUrl"

    # Resolve agent installer name and download path
    $installerRequest = [System.Net.WebRequest]::Create($agentUrl)
    $installerRequest.AllowAutoRedirect = $false
    $installerRequest.Method = "HEAD"
    $installerName = [System.IO.Path]::GetFileName($installerRequest.GetResponse().Headers["Location"])

    $installerDir = Join-Path -Path $env:TMP -ChildPath "Acronis"
    New-Item -ItemType Directory -Path $installerDir -Force | Out-Null
    Set-Location -Path $installerDir

    $installerPath = Join-Path -Path $installerDir -ChildPath $installerName
    Remove-Item -Path $installerPath -ErrorAction SilentlyContinue

    Write-Host "  to: $installerPath"

    # Download agent installer
    $webClient = New-Object TimeoutWebClient
    try {
        $webClient.DownloadFile($agentUrl, $installerPath)
    }
    finally {
        $webClient.Dispose()
    }

    # Install agent
    $logDir = Join-Path -Path $installerDir -ChildPath "Cyber_Protect_Agent_logs"
    $reportFile = Join-Path -Path $installerDir -ChildPath "Cyber_Protect_Agent_report.txt"
    $processStartArgs = @(
        "--add-components=commandLine,agentForWindows,trayMonitor",
        "--reg-address=$cloudUrl",
        "--registration=by-token",
        "--reg-token=$registrationToken",
        "--log-dir=$logDir",
        "--report-file=$reportFile",
        "--quiet"
    )


    if($InstallerOptions -eq "domain")  {
        $processStartArgs += @(
            "--agent-account-login=$AgentAccountLogin",
            "--agent-account-password=$AgentAccountPassword")
    }

    Write-Host "Install agent: $processStartArgs"

    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo -Property @{
        WorkingDirectory       = $installerDir
        FileName               = $installerPath
        RedirectStandardError  = $true
        RedirectStandardOutput = $true
        UseShellExecute        = $false
        CreateNoWindow         = $true
        Arguments              = $processStartArgs
    }
    $process = New-Object System.Diagnostics.Process -Property @{
        StartInfo = $processStartInfo
    }
    $process.Start() | Out-Null
    $process.WaitForExit()

    Remove-Item -Path $installerPath -ErrorAction SilentlyContinue

    # 6452541 - reboot required
    if(-not ($process.ExitCode -eq 0 -or $process.ExitCode -eq 6452541)) {
        Write-Error "Failed to install Cyber Protect Agent" -ErrorAction:Continue
        Write-Error "Exit code: $($process.ExitCode)" -ErrorAction:Continue
        Write-Error "Report: $reportFile" -ErrorAction:Continue
        Write-Error "Logs: $logDir" -ErrorAction:Continue
        $stdout = $process.StandardOutput.ReadToEnd()
        Write-Error "Stdout: $stdout" -ErrorAction:Continue
        $stderr = $process.StandardError.ReadToEnd()
        Write-Error "Stderr: $stderr" -ErrorAction:Stop
        exit 1
    }

    Start-Sleep -s 60
    Write-Host "Get access token..."

    # Exchange registration token to access token and try to apply protection plan
    $accessToken = Get-AccessToken $CloudUrl $RegistrationToken
    if ($accessToken) {
        $resourceId = Get-ItemProperty -Path $acronisRegistryPath | Select-Object -ExpandProperty InstanceID
        try
        {
            Invoke-Plan $CloudUrl $accessToken $resourceId
        }
        catch
        {
            Write-Host "No protection plan can be assigned using this registration token"
        }
    }

    Write-Host "Cyber Protect Agent was successfully installed"
}

function Uninstall-Agent {

    # Uninstall Cyber Protect Agent

    $ErrorActionPreference = "Stop"

    function Get-UpgradeCode {
        if ([System.Environment]::Is64BitOperatingSystem) {
            '{DAC56B69-1A5E-494D-92AE-A462FFB2A281}'
        }
        else {
            '{48557248-4EE3-49E4-9450-BAADC7CD1A88}'
        } 
    }

    function Get-ProductCode {
        param ([string] $upgradeCode)
    
        return Get-CimInstance -ClassName Win32_Property -Filter "Property='UpgradeCode' AND Value='$upgradeCode'" |
            Select-Object -First 1 -ExpandProperty ProductCode
    }

    function Get-Product {
        param ([string] $productCode)
    
        return Get-WmiObject -Class Win32_Product | Where-Object { $_.IdentifyingNumber -match $productCode }
    }

    $upgradeCode = Get-UpgradeCode
    $productCode = Get-ProductCode $upgradeCode
    $product = Get-Product $productCode
    if ($product) {
        try {
            $product.Uninstall()
        }
        catch {
        
        }
        if (Get-Product $productCode) {
            Write-Error "Failed to uninstall Cyber Protect Agent"
        }
        else {
            Write-Output "Cyber Protect Agent was uninstalled successfully"
        }
    }
    else
    {
        Write-Output "Cyber Protect Agent is not installed"
    }
}


# For debug
function Write-Json {
    param ($json)
    write-host ($json | ConvertTo-Json -Depth 40)
}


# return 'http://127.0.0.1:<port>
function Get-AakoreUrl {
    $aakoreCmdOutput = &"${aAkorePath}" "info" "--raw" | Out-String
    $aakoreCmdOutput = $aakoreCmdOutput.Replace([System.Environment]::NewLine, '').Replace("}{", "},{")
    $aakoreCmdOutput = "[${aakoreCmdOutput}]"
    $aakoreInfo = $aakoreCmdOutput | ConvertFrom-Json
    return $aakoreInfo[0].location
}

function  Upgrade-Agent {
    $aakoreUrl = Get-AakoreUrl 

    # Get client ID and client secret using aakore
    $aakoreClient = Invoke-RestMethod -Uri "${aaKoreUrl}/idp/clients" `
        -Method Post `
        -UseDefaultCredentials `
        -SessionVariable aakoreSession
    $clientId = $aakoreClient.client_id
    $clientSecret = $aakoreClient.client_secret

    # Get access token using aakore
    $accessToken = Get-AakoreAccessToken $aakoreUrl $clientId $clientSecret $aakoreSession
    $resourceId = Get-ResourceId

    $uri = "$aakoreUrl/api/resource_manager/v1/epm/resources?id=$resourceId&embed=agent&embed=details&embed=attributes"
    $response = Invoke-RestMethod `
        -Uri "${uri}" `
        -Method Get `
        -Headers @{ "Authorization" = "Bearer $accessToken" } `
        -WebSession $aakoreSession

    
    $agentId = $response.items[0].agent.id
    $hostName = $response.items[0].name

    $uri = "$aakoreUrl/api/agent_manager/v2/agents?hostname=hlike($hostName)"
    $response = Invoke-RestMethod `
        -Uri "${uri}" `
        -Method Get `
        -Headers @{ "Authorization" = "Bearer $accessToken" } `
        -WebSession $aakoreSession

    $installerVersion = $response.items[0].installer_version

    if($installerVersion.latest) {
        $latest  = $installerVersion.latest
        $current = $installerVersion.current

        if($latest.build -eq $current.build) {
            Write-Host "Latest version already installed"
            exit 1
        }

       
        $uri = "$aakoreUrl/api/agent_manager/v2/agents/update:force"
        $body = ('{"agent_ids":["' + ${agentId} + '"]}')

        $response = Invoke-WebRequest `
            -UseBasicParsing `
            -Uri "${uri}" `
            -ContentType "application/json" `
            -Method POST `
            -UseDefaultCredentials `
            -Body $body

        if( $response.StatusCode -eq "202" ) {
            Write-Host "Upgrade scheduled"
            return 0
        }else {
            Write-Host "Unable to start upgrade"
            return 1
        }
        
    } else {
        Write-Host "Latest version already installed"
        exit 0
    }
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
catch {
    Write-Error "The host doesn't support TLS v1.2. It's required to proceed. The recomennded minumum version of PowerShell is 4.0."
    exit 1
}

if ($TaskType -eq "install") {
    if(Test-AgentInstalled) {
        Write-Host "Cyber Protect Agent already installed"
        exit 1
    }

    Install-Agent
    exit 0
} elseif ($TaskType -eq "uninstall" ) {
    if(-Not (Test-AgentInstalled)) {
        Write-Host "Cyber Protect Agent not installed"
        exit 1
    }

    UnInstall-Agent
    exit 0
} 
elseif ($TaskType -eq "upgrade" ) {
    if(-Not (Test-AgentInstalled)) {
        Write-Host "Cyber Protect Agent not installed"
        exit 1
    }

    Upgrade-Agent
    exit 0 
}else {
    Write-Host "Unknown task '$TaskType'"
    exit 1
}