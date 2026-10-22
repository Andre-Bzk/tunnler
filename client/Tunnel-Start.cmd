@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\tunnel.ps1" start
pause
