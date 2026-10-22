# Helper dos testes: monta um USERPROFILE falso com .claude, .claude-contas\contas.json e .claude.json,
# e faz dot-source de comum.ps1 apontando para ele. Use com dot-source: . New-AmbienteFalso $raiz @{...}
$Script:ScriptsDir = Join-Path $PSScriptRoot '..\plugins\multiplas-contas\skills\multiplas-contas\scripts'

function New-AmbienteFalso([string]$raiz, [hashtable]$contasJson) {
    New-Item -ItemType Directory -Force (Join-Path $raiz '.claude'), (Join-Path $raiz '.claude-contas') | Out-Null
    [IO.File]::WriteAllText((Join-Path $raiz '.claude-contas\contas.json'), ($contasJson | ConvertTo-Json -Depth 10))
    [IO.File]::WriteAllText((Join-Path $raiz '.claude.json'), '{}')
    $env:USERPROFILE = $raiz
    . (Join-Path $ScriptsDir 'comum.ps1')
}
