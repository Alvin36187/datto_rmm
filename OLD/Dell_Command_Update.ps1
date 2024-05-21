# Definiere die URL, von der die Datei heruntergeladen werden soll
$DownloadURL = "https://dl.dell.com/FOLDER05944445M/1/Dell-Command-Update_V104D_WIN_3.1.0_A00.EXE"

# Definiere den Speicherort, an dem die heruntergeladene Datei gespeichert werden soll
$DownloadLocation = "C:\Temp"

Set-ExecutionPolicy Unrestricted -Force

# Versuche, den Download und die Installation von Dell Command Update Client (DCUCli) durchzuführen
try {
    # Überprüfe, ob der Download-Speicherort existiert, falls nicht, erstelle ihn
    $TestDownloadLocation = Test-Path $DownloadLocation
    if (!$TestDownloadLocation) { 
        new-item $DownloadLocation -ItemType Directory -force 
    }

    # Überprüfe, ob die Datei bereits vorhanden ist. Wenn nicht, lade sie herunter und installiere sie stillschweigend.
    $TestDownloadLocationZip = Test-Path "$DownloadLocation\DellCommandUpdate.exe"
    if (!$TestDownloadLocationZip) {
        Invoke-WebRequest -UseBasicParsing -Uri $DownloadURL -OutFile "$($DownloadLocation)\DellCommandUpdate.exe"
        Start-Process -FilePath "$($DownloadLocation)\DellCommandUpdate.exe" -ArgumentList '/s' -Verbose -Wait
        # Setze den Starttyp des Dienstes 'DellClientManagementService' auf 'Manuell'
        set-service -name 'DellClientManagementService' -StartupType Manual
    }
}
# Erfasse Ausnahmen, falls beim Download oder der Installation ein Fehler auftritt
catch {
    write-host "Der Download und die Installation von DCUCli sind fehlgeschlagen. Fehler: $($\_.Exception.Message)"
    exit 1
}

# Starte den Dell Command Update Client (DCU-CLI), um nach verfügbaren Updates zu suchen und erstelle einen Bericht
start-process "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe" -ArgumentList "/scan -report=$DownloadLocation" -Wait

# Lese den XML-Bericht mit den anwendbaren Updates ein
[xml]$XMLReport = get-content "$DownloadLocation\DCUApplicableUpdates.xml"

# Lösche die XML-Datei, da sie nicht mehr benötigt wird und manchmal Schwierigkeiten beim Überschreiben verursacht
remove-item "$DownloadLocation\DCUApplicableUpdates.xml" -Force

# Zähle die verfügbaren Updates nach Typen
$AvailableUpdates = $XMLReport.updates.update
$BIOSUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "BIOS" }).name.Count
$ApplicationUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Application" }).name.Count
$DriverUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Driver" }).name.Count
$FirmwareUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Firmware" }).name.Count
$OtherUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Other" }).name.Count
$PatchUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Patch" }).name.Count
$UtilityUpdates = ($XMLReport.updates.update | Where-Object { $_.type -eq "Utility" }).name.Count
$UrgentUpdates = ($XMLReport.updates.update | Where-Object { $_.Urgency -eq "Urgent" }).name.Count
