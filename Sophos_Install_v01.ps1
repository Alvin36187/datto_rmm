$temp = "C:\temp\"
$SophosInstalled = Test-Path -Path "C:\Program Files\Sophos"
$InstallerSource = "your installer download link"
$destination = "$temp\SophosSetup.exe"

If ($SophosInstalled){
Write-Host "Sophos is already installed. "
Sleep 3
Exit
} Else {
Write-Host "Beginning the installation"

If (Test-Path -Path $temp -PathType Container){
Write-Host "$temp already exists" -ForegroundColor Red
} Else {
New-Item -Path $temp -ItemType directory
}

Invoke-WebRequest $InstallerSource -OutFile $destination
$WebClient = New-Object System.Net.WebClient
$webclient.DownloadFile($InstallerSource, $destination)
}

Start-Process -FilePath "$temp\SophosSetup.exe" -ArgumentList "--quiet"