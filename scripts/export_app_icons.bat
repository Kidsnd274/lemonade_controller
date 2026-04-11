@echo off
setlocal

set ICON_DIR=%~dp0..\assets\icon

echo === Android adaptive icon layers (432x432 xxxhdpi) ===
"L:\Program Files\Inkscape\bin\inkscape.exe" --export-type=png --export-background-opacity=0 -w 432 "%ICON_DIR%\android\ic_launcher_foreground.svg"
"L:\Program Files\Inkscape\bin\inkscape.exe" --export-type=png --export-background-opacity=0 -w 432 "%ICON_DIR%\android\ic_launcher_background.svg"
"L:\Program Files\Inkscape\bin\inkscape.exe" --export-type=png --export-background-opacity=0 -w 432 "%ICON_DIR%\android\ic_launcher_monochrome.svg"

echo === Windows icon (256x256) ===
"L:\Program Files\Inkscape\bin\inkscape.exe" --export-type=png --export-background-opacity=0 -w 256 "%ICON_DIR%\windows\app_icon.svg"

echo === macOS icon (1024x1024) ===
"L:\Program Files\Inkscape\bin\inkscape.exe" --export-type=png --export-background-opacity=0 -w 1024 "%ICON_DIR%\macos\app_icon.svg"

echo === Linux icon (128x128) ===
"L:\Program Files\Inkscape\bin\inkscape.exe" --export-type=png --export-background-opacity=0 -w 1024 "%ICON_DIR%\linux\assets\app_icon.svg"

echo Done.
