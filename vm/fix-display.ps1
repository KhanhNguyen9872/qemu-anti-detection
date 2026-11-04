# Remove a failed OEM display driver binding from the spoofed 1002:1900 VGA
# and keep the inbox Microsoft Basic Display Adapter instead.
# Run from an elevated PowerShell.
$ErrorActionPreference = 'SilentlyContinue'
$log = 'C:\fix-display.log'
Remove-Item $log -Force

function Log($text) {
    $text | Out-File $log -Append -Encoding UTF8
    Write-Host $text
}

function Run($exe, $arguments) {
    Log "> $exe $arguments"
    & $exe $arguments 2>&1 | Out-File $log -Append -Encoding UTF8
}

function Get-DriverInf($instanceId) {
    try {
        (Get-PnpDeviceProperty -InstanceId $instanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data
    } catch {
        ''
    }
}

Log '=== disable Windows Update driver search ==='
reg add 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' /v SearchOrderConfig /t REG_DWORD /d 0 /f 2>&1 | Out-File $log -Append -Encoding UTF8
reg add 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f 2>&1 | Out-File $log -Append -Encoding UTF8

$display = Get-PnpDevice -Class Display
$bad = $display | Where-Object { $_.Status -eq 'Error' -or $_.FriendlyName -match 'AMD Radeon' }
$phantom = $display | Where-Object {
    $_.Status -eq 'Unknown' -and $_.FriendlyName -match 'Microsoft Basic Display'
}
$software = Get-PnpDevice -Class SoftwareComponent |
    Where-Object { $_.FriendlyName -match 'AMD' }

$remove = @($bad) + @($phantom) + @($software)
$oemInfs = @()

Log "=== remove display/OEM devices: $($remove.Count) ==="
foreach ($d in $remove) {
    if (-not $d.InstanceId) { continue }
    $inf = Get-DriverInf $d.InstanceId
    if ($inf -match '^oem\d+\.inf$') { $oemInfs += $inf }
    Log "REMOVE $($d.FriendlyName) [$($d.Status)] $($d.InstanceId) inf=$inf"
    Run 'pnputil' @('/remove-device', $d.InstanceId)
}

Log '=== delete failed AMD OEM packages (keep smbusamd) ==='
foreach ($inf in ($oemInfs | Sort-Object -Unique)) {
    if ($inf -match 'smbus') { continue }
    Run 'pnputil' @('/delete-driver', $inf, '/uninstall', '/force')
}

Log '=== rescan display ==='
Run 'pnputil' @('/scan-devices')
Start-Sleep -Seconds 4

Log '=== display state ==='
Get-PnpDevice -Class Display | Select-Object Status,FriendlyName,InstanceId,Problem |
    Format-List | Out-File $log -Append -Encoding UTF8

Copy-Item $log '\\10.0.2.4\qemu\fix-display.log' -Force
Write-Host 'Display fix complete. Reboot the VM.'
