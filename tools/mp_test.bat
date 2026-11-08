@echo off
rem Convenience launcher for mp_test.ps1
rem   tools\mp_test.bat              human mode
rem   tools\mp_test.bat auto         automated smoke test
rem   tools\mp_test.bat -Stop        kill instances started by the script
where pwsh >nul 2>nul
if errorlevel 1 goto winps
pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0mp_test.ps1" %*
exit /b %errorlevel%
:winps
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0mp_test.ps1" %*
exit /b %errorlevel%
