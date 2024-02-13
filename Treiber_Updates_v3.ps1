# Programm: XY
# Author: Alvin Huwiler
# Datum : XX.XX.XXXX
# Version : 1.0

# Treiber-Updates installieren

# Treiberupdates über Windows Update installieren
$windowsUpdateSession = New-Object -ComObject Microsoft.Update.Session
$windowsUpdateSearcher = $windowsUpdateSession.CreateUpdateSearcher()
$windowsUpdates = $windowsUpdateSearcher.Search("IsInstalled=0 and Type='Driver'")

# Überprüfen, ob Treiberupdates verfügbar sind
if ($windowsUpdates.Updates.Count -gt 0) {
    Write-Host "Es gibt Treiberupdates für deinen PC. Die Installation beginnt..."

    # Treiberupdates installieren
    $windowsUpdates | ForEach-Object {
        $_.AcceptEula()
        $downloader = $windowsUpdateSession.CreateUpdateDownloader()
        $downloader.Updates = New-Object -ComObject Microsoft.Update.UpdateColl
        $downloader.Updates.Add($_)
        $downloader.Download()
        $installer = New-Object -ComObject Microsoft.Update.UpdateInstaller
        $installer.Updates = $windowsUpdates
        $installationResult = $installer.Install()
        if ($installationResult.ResultCode -eq 2) {
            Write-Host "Treiberupdate erfolgreich installiert: $($_.Title)"
        } else {
            Write-Host "Fehler beim Installieren des Treiberupdates: $($_.Title)"
        }
    }
} else {
    Write-Host "Es sind keine Treiberupdates für deinen PC verfügbar."
}
