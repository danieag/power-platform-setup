@echo off
setlocal
rem Process-only exception for this reviewed launcher; no persistent policy change.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup.ps1" %*
set "setup_exit=%errorlevel%"
echo.
echo Setup exit code: %setup_exit%
if "%~1"=="" pause
exit /b %setup_exit%
