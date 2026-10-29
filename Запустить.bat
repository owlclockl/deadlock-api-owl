@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0local\windows\launcher.ps1"
set "RESULT=%ERRORLEVEL%"
pause
exit /b %RESULT%
