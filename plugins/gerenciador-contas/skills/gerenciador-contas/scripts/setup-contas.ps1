# Atualiza o bloco de contas no ~/.claude/CLAUDE.md, cria/atualiza as pastas das contas
# listadas em contas.json e coloca bin\ no PATH do usuario.
# Idempotente: pode rodar de novo a qualquer momento (ex.: depois de adicionar uma conta).
. (Join-Path $PSScriptRoot 'comum.ps1')

$cfg = Get-Contas
if (-not $cfg.Principal) { throw 'Falta "principal" em contas.json' }
if (-not ($cfg.Contas.Nome -contains $cfg.Padrao)) { throw "Conta padrao '$($cfg.Padrao)' nao existe em contas.json" }
if (-not ($cfg.Contas.Nome -contains $cfg.Publicar)) { throw "Conta principal/de publicar '$($cfg.Publicar)' nao existe em contas.json" }
if ($cfg.Chrome -and -not ($cfg.Contas.Nome -contains $cfg.Chrome)) { throw "Conta do Chrome '$($cfg.Chrome)' nao existe em contas.json" }
if (@($cfg.Contas | Where-Object Mestre).Count -gt 1) { throw 'Mais de uma conta usa a pasta mestre ~/.claude' }

# Antes dos links: se o CLAUDE.md ainda nao existir, ele precisa existir para ser ligado.
Update-ClaudeMd
Write-Host "CLAUDE.md: bloco de contas atualizado em $(Join-Path $Mestre 'CLAUDE.md')"

foreach ($c in $cfg.Contas) {
    if ($c.Mestre) { Write-Host "[$($c.Nome)] usa a pasta mestre $($c.Pasta), nada a fazer"; continue }
    $msgs = Sync-LinksConta $c
    if ($msgs) { $msgs | ForEach-Object { Write-Host "[$($c.Nome)] $_" } } else { Write-Host "[$($c.Nome)] ok, ja estava configurada" }
}

# RC desligado para sessoes abertas sem o cc; status line com conta e uso.
foreach ($m in @((Set-RcDesligadoCompartilhado), (Register-StatusLine))) { if ($m) { Write-Host $m } }

$bin = Join-Path $Base 'bin'
$path = [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (($path -split ';') -contains $bin)) {
    [Environment]::SetEnvironmentVariable('Path', ($path.TrimEnd(';') + ';' + $bin), 'User')
    Write-Host "PATH: adicionado $bin (vale para terminais abertos a partir de agora)"
}
