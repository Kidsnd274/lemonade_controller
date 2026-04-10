@echo off
setlocal enabledelayedexpansion

set "ROOT_DIR=%~dp0.."
set "OUTPUT_DIR=%ROOT_DIR%\build\output"

:: Extract version from pubspec.yaml (strips the +buildnumber suffix)
for /f "tokens=2 delims= " %%a in ('findstr /b "version:" "%~dp0..\pubspec.yaml"') do (
    for /f "tokens=1 delims=+" %%b in ("%%a") do set APP_VERSION=%%b
)

echo.
echo  ============================================
echo   Lemonade Controller - Windows Build
echo   Version: %APP_VERSION%
echo  ============================================
echo.

:: Build the Flutter Windows release
echo  [1/3] Building Flutter app...
echo  --------------------------------------------
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo  [x] Flutter build failed!
    exit /b 1
)
echo.
echo  [ok]  Flutter build complete.
echo.

:: Zip the release build
echo  [2/3] Creating portable zip...
echo  --------------------------------------------
set ZIP_NAME=lemonade-controller-%APP_VERSION%-windows-x64.zip
set RELEASE_DIR=%~dp0..\build\windows\x64\runner\Release
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
tar -a -c -f "%OUTPUT_DIR%\%ZIP_NAME%" -C "%RELEASE_DIR%" *
if errorlevel 1 (
    echo.
    echo  [x] Failed to create zip!
    exit /b 1
)
echo.
echo  [ok]  %ZIP_NAME%
echo.

:: Build the installer using Inno Setup
echo  [3/3] Building installer...
echo  --------------------------------------------
"C:\Program Files (x86)\Inno Setup 6\iscc.exe" "%~dp0..\windows\setup\setup_script.iss"
if errorlevel 1 (
    echo.
    echo  [x] Inno Setup build failed!
    exit /b 1
)
echo.

echo  ============================================
echo   Build complete!
echo.
echo   Output:
echo     %OUTPUT_DIR%\%ZIP_NAME%
echo     %OUTPUT_DIR%\lemonade-controller-setup.exe
echo  ============================================
echo.
