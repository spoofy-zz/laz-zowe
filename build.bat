@echo off
setlocal

echo === Building Zowe MVS Editor ===

for /f "delims=" %%v in ('lazbuild --version 2^>^&1') do (
    echo Lazarus: %%v
    goto :fpc_ver
)
:fpc_ver
for /f "delims=" %%v in ('fpc -iV 2^>^&1') do (
    echo FPC:     %%v
    goto :build
)
:build
echo.

set "MODE=%~1"
if "%MODE%"=="" set "MODE=Debug"
echo Build mode: %MODE%

lazbuild --build-mode="%MODE%" editor.lpi
if errorlevel 1 (
    echo Build FAILED.
    exit /b 1
)

echo.
echo === Build complete: editor.exe ===
endlocal
