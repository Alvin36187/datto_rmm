# Programm: XY
# Author: Alvin Huwiler
# Datum : XX.XX.XXXX
# Version : 1.0

# Dies ist ein einfaches PowerShell-Programmtemplate

# Überprüfen, ob es optionale Updates gibt

# PowerShell-Modul für Windows-Updates importieren
Import-Module PSWindowsUpdate

# Liste der verfügbaren Updates abrufen
$optionalUpdates = Get-WindowsUpdate -Category "Optional"

# Überprüfen, ob optionale Updates vorhanden sind
if ($optionalUpdates) {
    Write-Host "Es gibt optionale Updates für deinen PC:"
    # Liste der optionalen Updates anzeigen
    $optionalUpdates | Format-Table Title, KB, Description, Size -AutoSize
} else {
    Write-Host "Es sind keine optionalen Updates für deinen PC verfügbar."
}