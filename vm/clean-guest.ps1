# Clean up guest-only anti-detection leftovers.
# Run from an elevated PowerShell:
#   powershell -ExecutionPolicy Bypass -File \\10.0.2.4\qemu\clean-guest.ps1
$ErrorActionPreference = 'SilentlyContinue'
$log = 'C:\clean-guest.log'
Remove-Item $log -Force

function Log($text) {
    $text | Out-File $log -Append -Encoding UTF8
    Write-Host $text
}

function Remove-Pnp($instanceId, $reason) {
    if (-not $instanceId) { return }
    Log "REMOVE [$reason] $instanceId"
    pnputil /remove-device "$instanceId" 2>&1 | Out-File $log -Append -Encoding UTF8
}

Log '=== START ==='
bcdedit /debug off 2>&1 | Out-File $log -Append -Encoding UTF8
Log 'Kernel debugging disabled.'

# Microsoft Kernel Debug Network Adapter (ROOT\KDNIC) and any other debug NIC.
Get-PnpDevice -Class Net |
    Where-Object { $_.FriendlyName -match 'Kernel Debug|KDNIC' -or $_.InstanceId -match 'KDNIC' } |
    ForEach-Object { Remove-Pnp $_.InstanceId 'kernel-debug-nic' }

# Remove all non-present/ghost devices from earlier QXL/VirtIO/Hyper-V profiles.
$ghosts = Get-PnpDevice -Status Unknown
Log "Ghost devices found: $($ghosts.Count)"
foreach ($d in $ghosts) {
    Remove-Pnp $d.InstanceId "ghost-$($d.Class)"
}

# A GEEKOM A8 mini PC has no PS/2 ports; remove stale PS/2 devices.
Get-PnpDevice -Class Keyboard |
    Where-Object { $_.InstanceId -match 'PNP0303|PS2' } |
    ForEach-Object { Remove-Pnp $_.InstanceId 'ps2-keyboard' }
Get-PnpDevice -Class Mouse |
    Where-Object { $_.InstanceId -match 'PNP0F13|PS2' } |
    ForEach-Object { Remove-Pnp $_.InstanceId 'ps2-mouse' }

pnputil /scan-devices 2>&1 | Out-File $log -Append -Encoding UTF8
Start-Sleep -Seconds 2

Log '=== REMAINING NETWORK ==='
Get-PnpDevice -Class Net | Select-Object Status,FriendlyName,InstanceId |
    Format-Table -AutoSize | Out-File $log -Append -Encoding UTF8
Log '=== REMAINING KEYBOARD/MOUSE ==='
Get-PnpDevice -Class Keyboard,Mouse | Select-Object Status,Class,FriendlyName,InstanceId |
    Format-Table -AutoSize | Out-File $log -Append -Encoding UTF8
Log '=== DONE ==='

Copy-Item $log '\\10.0.2.4\qemu\clean-guest.log' -Force
Write-Host 'Cleanup complete. Reboot the VM to finish removing the ghost devices.'
