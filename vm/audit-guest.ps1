$ErrorActionPreference = 'SilentlyContinue'
$log = 'C:\pnp-audit.txt'
Remove-Item $log -Force

'=== OS ===' | Out-File $log -Encoding UTF8
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber | Format-List | Out-File $log -Append -Encoding UTF8

'=== Computer ===' | Out-File $log -Append -Encoding UTF8
Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer,Model,TotalPhysicalMemory,NumberOfLogicalProcessors,HypervisorPresent | Format-List | Out-File $log -Append -Encoding UTF8

'=== BCD debug ===' | Out-File $log -Append -Encoding UTF8
bcdedit /enum '{current}' | Out-File $log -Append -Encoding UTF8
bcdedit /dbgsettings | Out-File $log -Append -Encoding UTF8

'=== PnP devices ===' | Out-File $log -Append -Encoding UTF8
Get-PnpDevice | Select-Object Status,Class,FriendlyName,InstanceId | Sort-Object Class,FriendlyName | Format-Table -AutoSize | Out-File $log -Append -Encoding UTF8

'=== Disconnected devices ===' | Out-File $log -Append -Encoding UTF8
pnputil /enum-devices /disconnected | Out-File $log -Append -Encoding UTF8

'=== OEM drivers ===' | Out-File $log -Append -Encoding UTF8
pnputil /enum-drivers | Out-File $log -Append -Encoding UTF8

'=== Network adapters (including hidden) ===' | Out-File $log -Append -Encoding UTF8
Get-NetAdapter -IncludeHidden | Select-Object Name,InterfaceDescription,Status,MacAddress,PnPDeviceID | Format-List | Out-File $log -Append -Encoding UTF8

'=== Audio endpoints ===' | Out-File $log -Append -Encoding UTF8
Get-PnpDevice -Class AudioEndpoint | Select-Object Status,FriendlyName,InstanceId | Format-Table -AutoSize | Out-File $log -Append -Encoding UTF8

'=== Video/USB/system devices ===' | Out-File $log -Append -Encoding UTF8
Get-PnpDevice -Class Display,USB,System | Select-Object Status,Class,FriendlyName,InstanceId | Sort-Object Class,FriendlyName | Format-Table -AutoSize | Out-File $log -Append -Encoding UTF8

'=== Done ===' | Out-File $log -Append -Encoding UTF8
Copy-Item $log '\\10.0.2.4\share\pnp-audit.txt' -Force
Write-Host 'Audit written to C:\pnp-audit.txt and \\10.0.2.4\share\pnp-audit.txt'
