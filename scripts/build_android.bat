@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT_DIR=%~dp0.."
set "APK_DIR=%ROOT_DIR%\build\app\outputs\flutter-apk"
set "OUTPUT_DIR=%ROOT_DIR%\build\output"
set "APP_NAME=lemonade-controller"

if "%~1"=="" (
    set "BUILD_ARGS=--split-per-abi"
) else (
    set "BUILD_ARGS=%*"
)

pushd "%ROOT_DIR%" || (
    echo  [x] Failed to open project root: "%ROOT_DIR%"
    exit /b 1
)

:: Extract version from pubspec.yaml
set "VERSION_LINE="
for /f "usebackq tokens=1,* delims=:" %%A in (`findstr /b /c:"version:" "pubspec.yaml"`) do (
    set "VERSION_LINE=%%B"
)

if not defined VERSION_LINE (
    echo  [x] Could not read "version:" from pubspec.yaml
    popd
    exit /b 1
)

set "VERSION_LINE=!VERSION_LINE: =!"
for /f "tokens=1,2 delims=+" %%A in ("!VERSION_LINE!") do (
    set "APP_VERSION=%%A"
    set "BUILD_NUMBER=%%B"
)

if not defined BUILD_NUMBER set "BUILD_NUMBER=0"
set "VERSION_TAG=!APP_VERSION!"

echo.
echo  ============================================
echo   Lemonade Controller - Android Build
echo   Version: !APP_VERSION! ^(+!BUILD_NUMBER!^)
echo  ============================================
echo.

:: Build the Flutter APKs
echo  [1/2] Building APKs  [args: !BUILD_ARGS!]
echo  --------------------------------------------
call flutter build apk !BUILD_ARGS!
if errorlevel 1 (
    echo.
    echo  [x] Flutter build failed!
    popd
    exit /b 1
)
echo.
echo  [ok]  Flutter build complete.
echo.

:: Copy and rename APKs
if not exist "%APK_DIR%\*.apk" (
    echo  [x] No APK files found in "%APK_DIR%"
    popd
    exit /b 1
)

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo  [2/2] Copying APKs to output...
echo  --------------------------------------------
set "APK_COUNT=0"
for %%F in ("%APK_DIR%\*.apk") do (
    set "FILE_BASE=%%~nF"
    set "ABI=universal"
    set "BUILD_TYPE=android"

    echo "!FILE_BASE!" | findstr /i /c:"arm64-v8a" >nul && set "ABI=arm64-v8a"
    echo "!FILE_BASE!" | findstr /i /c:"armeabi-v7a" >nul && set "ABI=armeabi-v7a"
    echo "!FILE_BASE!" | findstr /i /c:"x86_64" >nul && set "ABI=x86_64"
    echo "!FILE_BASE!" | findstr /i /c:"x86" >nul && if /i "!ABI!"=="universal" set "ABI=x86"

    set "NEW_NAME=%APP_NAME%-!VERSION_TAG!-!BUILD_TYPE!-!ABI!.apk"

    if exist "%OUTPUT_DIR%\!NEW_NAME!" del /f /q "%OUTPUT_DIR%\!NEW_NAME!"
    copy /y "%%~fF" "%OUTPUT_DIR%\!NEW_NAME!" >nul
    if errorlevel 1 (
        echo    [x] %%~nxF
    ) else (
        echo    [ok]  !NEW_NAME!
        set /a APK_COUNT+=1
    )
)

echo.
echo  ============================================
echo   Build complete! !APK_COUNT! APK^(s^) output.
echo.
echo   Output:
for %%F in ("%OUTPUT_DIR%\%APP_NAME%*.apk") do (
    echo     %%~nxF
)
echo  ============================================
echo.

popd
exit /b 0
