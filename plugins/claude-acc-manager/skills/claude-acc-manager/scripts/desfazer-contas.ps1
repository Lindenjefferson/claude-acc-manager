# Desfaz a instalacao sem tocar no conteudo da pasta mestre ~/.claude: remove so os links das
# contas extras, tira bin\ do PATH, remove o atalho do Explorer, o bloco de contas do CLAUDE.md
# e a statusLine de conta e uso do settings.json.
# Com -ApagarPastas, apaga tambem as pastas das contas extras (logins delas; exige /login de novo).
param([switch]$ApagarPastas)
. (Join-Path $PSScriptRoot 'comum.ps1')

$cfg = Get-Contas
foreach ($c in $cfg.Contas) {
    if ($c.Mestre) { continue }
    Remove-LinksConta $c
    Write-Host "[$($c.Nome)] links removidos"
    if ($ApagarPastas -and (Test-Path -LiteralPath $c.Pasta)) {
        if (Get-ChildItem -LiteralPath $c.Pasta -Recurse -Force | Where-Object { $_.LinkType }) { throw "Ainda ha links em $($c.Pasta); nada apagado" }
        Remove-Item -LiteralPath $c.Pasta -Recurse -Force
        Write-Host "[$($c.Nome)] pasta apagada"
    }
}

$bin = Join-Path $Base 'bin'
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
[Environment]::SetEnvironmentVariable('Path', ((($path -split ';') | Where-Object { $_ -and $_ -ne $bin }) -join ';'), 'User')
Write-Host "PATH: removido $bin"

$chave = Get-ChaveAppPaths $cfg.Atalho
if (Test-Path $chave) { Remove-Item $chave -Force; Write-Host "Explorer: atalho '$($cfg.Atalho)' removido" }

Remove-BlocoClaudeMd
Write-Host 'CLAUDE.md: bloco de contas removido'

# A statusLine sai so se for a nossa; remoteControlAtStartup false fica (seguro sem o cc).
$m = Unregister-StatusLine
if ($m) { Write-Host $m }

$cc = Join-Path $Base 'cc.ps1'
if (Test-Path $cc) { Rename-Item $cc 'cc.ps1.desativado' -Force; Write-Host 'cc desativado (cc.ps1.desativado); instalar.ps1 reativa' }
