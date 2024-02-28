# drive-list change monitor :: build 3/seagull, february 2024 :: reduxes code by scripting simon

this script, like all datto RMM Component scripts unless otherwise explicitly stated, is the copyrighted property of Datto, Inc.;
it may not be shared, sold, or distributed beyond the Datto RMM product, whole or in part, even with modifications applied, for 
any reason. this includes on reddit, on discord, or as part of other RMM tools. PCSM and VSAX stand as exceptions to this rule.
  
the moment you edit this script it becomes your own risk and support will not provide assistance with it.#>

function writeAlert ($message, $tier) {
 Write-Host "<-Start Result->"
 Write-host "STATUS=OK: $message"
 Write-Host "<-End Result->"
 exit $tier
}

#--------------------------------------------------- CODE --------------------------------------------------

#get a list of fixed drives
$varLatest=-join (Get-WmiObject win32_logicalDisk | Where-Object {$_.DriveType -eq 3} | Select-Object -expand DeviceID)

#load the old list into a variable and replace it with the new list
$varStored=(get-itemproperty -path "HKLM:\Software\CentraStage" -name SGLDriveList -ea 0).SGLDriveList
new-itemproperty -path "HKLM:\Software\CentraStage" -name "SGLDriveList" -value $varLatest -Force

#if this is the first time the script is run, place a marker and exit
if ($varStored -eq $null) {
 writeAlert "NOTICE: Script being run for first time. A marker has been placed." 0
} 

#compare comparison marker to latest data and report on result
if ($varLatest -eq $varStored) {
 writeAlert "OK: No change since last scan [$varLatest]" 0
} else {
writeAlert "ALERT: List changed. WAS [$varStored] :: IS [$varLatest]" 1
}