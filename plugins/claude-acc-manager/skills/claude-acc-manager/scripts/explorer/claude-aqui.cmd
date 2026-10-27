@echo off
rem Chamado ao digitar o atalho (ex.: "cc" ou "cc conta") na barra de endereco do Explorer, via App Paths.
rem Abre o PowerShell na pasta do Explorer ja rodando o Claude; ao sair do Claude, fica no PowerShell.
powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "%~dp0claude-aqui.ps1" %*
