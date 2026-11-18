@echo off
setlocal
set "PYTHON=%~dp0runtime\python\python.exe"
set "APP_DIR=%~dp0runtime\python\app"
if not defined LOCALAPPDATA (
  echo LOCALAPPDATA is not defined. 1>&2
  exit /b 1
)
if not exist "%PYTHON%" (
  echo Embedded Python is missing. Run build_embedded.ps1 first. 1>&2
  exit /b 1
)
pushd "%APP_DIR%"
"%PYTHON%" "%APP_DIR%\backend.py" --data-dir "%LOCALAPPDATA%\PycnoLab" %*
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%
