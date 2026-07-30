@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0publish-to-branch.ps1" %*
