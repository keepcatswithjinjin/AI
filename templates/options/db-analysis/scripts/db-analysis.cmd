@echo off
powershell -ExecutionPolicy Bypass -File "%~dp0db-analysis.ps1" %*
