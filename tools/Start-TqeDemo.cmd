@echo off
setlocal
rem One click start for the TQE live CoT sender panel. Process scope only:
rem no execution policy is written to the registry and nothing is installed.
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" set "PS=powershell.exe"
start "TQE Live CoT Sender" "%PS%" -STA -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Show-TqeDemo.ps1" -ConfigPath "%~dp0..\demo-config.json"
endlocal
