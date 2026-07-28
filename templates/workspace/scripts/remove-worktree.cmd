@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0remove-worktree.ps1" %*
