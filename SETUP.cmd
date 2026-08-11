@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0SETUP.ps1" %*
set "code=%ERRORLEVEL%"
echo.
if not "%code%"=="0" (
  echo [FAILED] Local Coding Agent setup exited with code %code%.
) else (
  echo [PASS] Local Coding Agent setup completed.
)
exit /b %code%
