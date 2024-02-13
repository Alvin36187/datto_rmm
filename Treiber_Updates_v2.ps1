# Programm: XY
# Author: Alvin Huwiler
# Datum : XX.XX.XXXX
# Version : 1.0

# Treiber-Updates installieren

# Liste der verfügbaren Treiber-Updates abrufen
$driverUpdates = Get-WindowsDriver -Online

# Überprüfen, ob Treiber-Updates vorhanden sind
if ($driverUpdates) {
    Write-Host "Es gibt Treiber-Updates für deinen PC. Die Installation beginnt..."

    # Treiber-Updates installieren
    Add-WindowsDriver -Online

    Write-Host "Die Treiber-Updates wurden erfolgreich installiert."
} else {
    Write-Host "Es sind keine Treiber-Updates für deinen PC verfügbar."
}
