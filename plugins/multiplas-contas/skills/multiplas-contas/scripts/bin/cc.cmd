@echo off
rem cc [conta] [args]: abre o Claude Code na conta escolhida (ver %USERPROFILE%\.claude-contas\contas.json).
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\cc.ps1" %*
