@echo off
rem Map the QEMU user-mode SMB share exposed by start-win10.sh.
rem Run once manually, or copy this file to the Windows Startup folder.
timeout /t 3 /nobreak >nul
net use Z: /delete /y >nul 2>&1
net use Z: \\10.0.2.4\qemu /persistent:yes
if errorlevel 1 (
  echo Could not map Z: to \\10.0.2.4\qemu
) else (
  echo Z: -^> \\10.0.2.4\qemu
)
