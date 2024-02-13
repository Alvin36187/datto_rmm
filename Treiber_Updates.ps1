# Programm: XY
# Author: Alvin Huwiler
# Datum : XX.XX.XXXX
# Version : 1.0

# Dies ist ein einfaches PowerShell-Programmtemplate

# Treiber-Updates überprüfen

# Liste der verfügbaren Treiber-Updates abrufen
$driverUpdates = Get-WindowsDriver -Online

# Überprüfen, ob Treiber-Updates vorhanden sind
if ($driverUpdates) {
    Write-Host "Es gibt Treiber-Updates für deinen PC:"
    # Liste der Treiber-Updates anzeigen
    $driverUpdates | Format-Table Driver, Version, Provider, Date -AutoSize
} else {
    Write-Host "Es sind keine Treiber-Updates für deinen PC verfügbar."
}
