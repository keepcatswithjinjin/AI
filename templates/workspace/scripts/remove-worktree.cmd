@echo off
where pwsh.exe >nul 2>nul
if errorlevel 1 (
  echo PowerShell 7 ^(pwsh.exe^) is required. 1>&2
  exit /b 1
)
pwsh.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0remove-worktree.ps1" %*
exit /b %errorlevel%
