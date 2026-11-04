@echo off
rem Map the QEMU user-mode SMB share exposed by start-win10-stealth.sh.
net use Z: /delete /y >nul 2>&1
net use Z: \\10.0.2.4\qemu /persistent:no
if errorlevel 1 (
  echo Could not map Z: to \\10.0.2.4\qemu
  pause
) else (
  echo Z: -^> \\10.0.2.4\qemu
)
