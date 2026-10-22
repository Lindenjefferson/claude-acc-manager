# instalar.ps1 [-Verificar]
# Copia os scripts desta pasta para ~/.claude-contas, faz backup na primeira vez, cria as contas
# (setup-contas.ps1), registra o atalho do Explorer e atualiza o CLAUDE.md global.
# Pre-requisito: ~/.claude-contas/contas.json ja escrito (veja contas.exemplo.json).
# -Verificar: so checa o ambiente e lista conflitos, sem alterar nada.
param([switch]$Verificar)
$origem = $PSScriptRoot
. (Join-Path $origem 'comum.ps1')

# ---- checagens ----
$problemas = @(); $avisos = @()
if (-not (Test-Path $Claude)) { $problemas += "claude.exe nao encontrado (procurei no PATH e em $Claude)" }
$cfgArq = Join-Path $Base 'contas.json'
if (-not (Test-Path $cfgArq)) { $problemas += "falta $cfgArq (copie contas.exemplo.json e ajuste)" }

$tmp = Join-Path $env:TEMP ("mc-linktest-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
Set-Content "$tmp\a.txt" 'x'
cmd /c mklink "$tmp\b.txt" "$tmp\a.txt" 2>$null | Out-Null
$symlinkOk = Test-Link "$tmp\b.txt"
Remove-Item $tmp -Recurse -Force
if (-not $symlinkOk) { $avisos += 'symlink indisponivel (modo desenvolvedor desligado): arquivos compartilhados usarao hard link' }

if (Test-Path $cfgArq) {
    $cfg = Get-Contas
    $atalho = $cfg.Atalho
    # A barra do Explorer navega para uma pasta com o mesmo nome antes de executar o atalho.
    $lugares = @($env:USERPROFILE, [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'),
                 [Environment]::GetFolderPath('MyPictures'), [Environment]::GetFolderPath('MyMusic'),
                 [Environment]::GetFolderPath('MyVideos'), (Join-Path $env:USERPROFILE 'Downloads'))
    foreach ($l in $lugares) {
        if ($l -and (Test-Path -LiteralPath (Join-Path $l $atalho) -PathType Container)) {
            $problemas += "existe a pasta '$(Join-Path $l $atalho)': digitar '$atalho' no Explorer abriria essa pasta. Escolha outro atalhoExplorer."
        }
    }
    $outro = Get-Command 'cc' -ErrorAction SilentlyContinue | Where-Object { $_.Source -and $_.Source -notlike "$Base*" }
    if ($outro) { $avisos += "ja existe um comando 'cc' em $($outro.Source -join ', '); no terminal, o que vier antes no PATH vence" }
    $pol = Get-ExecutionPolicy -Scope CurrentUser
    if ($pol -in 'Undefined', 'Restricted', 'AllSigned') { $avisos += "ExecutionPolicy do usuario = ${pol}: por isso o cc e um .cmd (nao depende do `$PROFILE)" }
}

Write-Host "claude.exe: $Claude"
Write-Host "symlink: $(if ($symlinkOk) { 'ok' } else { 'nao' })"
$avisos | ForEach-Object { Write-Host "AVISO: $_" -ForegroundColor Yellow }
$problemas | ForEach-Object { Write-Host "PROBLEMA: $_" -ForegroundColor Red }
if ($Verificar) { return }
if ($problemas) { throw 'Resolva os problemas acima antes de instalar.' }

# ---- backup (so na primeira instalacao) ----
if (-not (Get-ChildItem (Join-Path $Base 'backups') -Directory -Filter 'instalacao_*' -ErrorAction SilentlyContinue)) {
    $b = Join-Path $Base ("backups\instalacao_" + (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
    New-Item -ItemType Directory -Force "$b\.claude\plugins" | Out-Null
    foreach ($f in @("$env:USERPROFILE\.claude.json")) { if (Test-Path $f) { Copy-Item $f $b } }
    foreach ($f in 'settings.json', 'history.jsonl', 'CLAUDE.md') { $p = Join-Path $Mestre $f; if (Test-Path $p) { Copy-Item $p "$b\.claude\" } }
    Copy-Item (Join-Path $Mestre 'plugins\*.json') "$b\.claude\plugins\" -ErrorAction SilentlyContinue
    Write-Host "backup: $b"
}

# ---- copia os scripts (nunca sobrescreve contas.json) ----
Get-ChildItem $origem -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($origem.Length).TrimStart('\')
    $dest = Join-Path $Base $rel
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    Copy-Item $_.FullName $dest -Force
}
$desativado = Join-Path $Base 'cc.ps1.desativado'
if (Test-Path $desativado) { Remove-Item $desativado }
Write-Host "scripts copiados para $Base"

# ---- contas, PATH e CLAUDE.md ----
& (Join-Path $Base 'setup-contas.ps1')

# ---- atalho do Explorer ----
$chave = Get-ChaveAppPaths $atalho
New-Item $chave -Force | Out-Null
Set-ItemProperty $chave -Name '(default)' -Value (Join-Path $Base 'explorer\claude-aqui.cmd')
Write-Host "Explorer: digite '$atalho' ou '$atalho <conta>' na barra de endereco"

& (Join-Path $Base 'cc.ps1') -l
