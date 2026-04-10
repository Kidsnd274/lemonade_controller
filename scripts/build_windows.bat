@echo off

flutter build windows --release

"C:\Program Files (x86)\Inno Setup 6\iscc.exe" "%~dp0..\windows\setup\setup_script.iss"
