# Programm: XY
# Author: Alvin Huwiler
# Datum : XX.XX.XXXX
# Version : 1.0

# Definiere den temporären Speicherpfad
$temp = "C:\temp\"

# Überprüfe, ob Sophos bereits installiert ist
$SophosInstalled = Test-Path -Path "C:\Program Files\Sophos"

# Definiere den Download-Link für den Sophos-Installer
$InstallerSource = "https://api-cloudstation-eu-central-1.prod.hydra.sophos.com/api/download/09b298b5f3ff9d2a1ed82c6793b7204a/SophosSetup.exe"

# Definiere den Ziel-Speicherort für den heruntergeladenen Installer
$destination = "$temp\SophosSetup.exe"

# Wenn Sophos bereits installiert ist, zeige eine Nachricht und beende das Skript
If ($SophosInstalled){
    Write-Host "Sophos is already installed."
    Start-Sleep 3
    Exit
} Else {
    # Wenn Sophos nicht installiert ist, beginne mit der Installation
    Write-Host "Beginning the installation"

    # Überprüfe, ob der temporäre Speicherpfad bereits vorhanden ist
    If (Test-Path -Path $temp -PathType Container){
        Write-Host "$temp already exists" -ForegroundColor Red
    } Else {
        # Wenn der temporäre Speicherpfad nicht vorhanden ist, erstelle ihn
        New-Item -Path $temp -ItemType directory
    }

    # Lade den Sophos-Installer herunter
    Invoke-WebRequest $InstallerSource -OutFile $destination

    # Alternative Möglichkeit, den Sophos-Installer herunterzuladen (verwendet WebClient)
    # $WebClient = New-Object System.Net.WebClient
    # $webclient.DownloadFile($InstallerSource, $destination)
}

# Starte den Sophos-Installer im stillen Modus
Start-Process -FilePath "$temp\SophosSetup.exe" -ArgumentList "--quiet"