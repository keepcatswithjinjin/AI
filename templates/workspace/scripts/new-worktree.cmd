@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0new-worktree.ps1" %*
