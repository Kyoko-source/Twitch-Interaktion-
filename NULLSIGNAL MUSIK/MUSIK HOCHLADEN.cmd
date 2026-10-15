@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\deploy\upload-nullsignal-music.ps1" -SourceFolder "%~dp0."
pause
