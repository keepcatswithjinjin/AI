@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0register-workspace.ps1" %*
