@echo off
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: PowerShell 7 is required. Install PowerShell 7 and add pwsh.exe to PATH. 1>&2
  exit /b 1
)
pwsh.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0publish-to-branch.ps1" %*
exit /b %errorlevel%
