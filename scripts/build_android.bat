@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT_DIR=%~dp0.."
set "OUTPUT_DIR=%ROOT_DIR%\build\app\outputs\flutter-apk"
set "APP_NAME=lemonade-controller"

if "%~1"=="" (
    set "BUILD_ARGS=--split-per-abi"
) else (
    set "BUILD_ARGS=%*"
)

pushd "%ROOT_DIR%" || (
    echo Failed to open project root: "%ROOT_DIR%"
    exit /b 1
)

echo Building APKs with args: !BUILD_ARGS!
call flutter build apk !BUILD_ARGS!
if errorlevel 1 (
    echo Flutter build failed. Skipping rename step.
    popd
    exit /b 1
)

set "VERSION_LINE="
for /f "usebackq tokens=1,* delims=:" %%A in (`findstr /b /c:"version:" "pubspec.yaml"`) do (
    set "VERSION_LINE=%%B"
)

if not defined VERSION_LINE (
    echo Could not read "version:" from pubspec.yaml
    popd
    exit /b 1
)

set "VERSION_LINE=!VERSION_LINE: =!"
for /f "tokens=1,2 delims=+" %%A in ("!VERSION_LINE!") do (
    set "APP_VERSION=%%A"
    set "BUILD_NUMBER=%%B"
)

if not defined BUILD_NUMBER set "BUILD_NUMBER=0"
set "VERSION_TAG=!APP_VERSION!-!BUILD_NUMBER!"

if not exist "%OUTPUT_DIR%\*.apk" (
    echo No APK files found in "%OUTPUT_DIR%"
    popd
    exit /b 1
)

echo Renaming APK outputs in "%OUTPUT_DIR%"...
for %%F in ("%OUTPUT_DIR%\*.apk") do (
    set "FILE_BASE=%%~nF"
    set "ABI=universal"
    set "BUILD_TYPE=release"

    echo "!FILE_BASE!" | findstr /i /c:"arm64-v8a" >nul && set "ABI=arm64-v8a"
    echo "!FILE_BASE!" | findstr /i /c:"armeabi-v7a" >nul && set "ABI=armeabi-v7a"
    echo "!FILE_BASE!" | findstr /i /c:"x86_64" >nul && set "ABI=x86_64"
    echo "!FILE_BASE!" | findstr /i /c:"x86" >nul && if /i "!ABI!"=="universal" set "ABI=x86"

    echo "!FILE_BASE!" | findstr /i /c:"-debug" >nul && set "BUILD_TYPE=debug"
    echo "!FILE_BASE!" | findstr /i /c:"-profile" >nul && set "BUILD_TYPE=profile"

    set "NEW_NAME=%APP_NAME%-!VERSION_TAG!-!BUILD_TYPE!-!ABI!.apk"

    if /i not "%%~nxF"=="!NEW_NAME!" (
        if exist "%OUTPUT_DIR%\!NEW_NAME!" del /f /q "%OUTPUT_DIR%\!NEW_NAME!"
        ren "%%~fF" "!NEW_NAME!"
        if errorlevel 1 (
            echo Failed to rename "%%~nxF"
        ) else (
            echo   %%~nxF ^> !NEW_NAME!
        )
    ) else (
        echo   %%~nxF (already named)
    )
)

echo Done.
popd
exit /b 0