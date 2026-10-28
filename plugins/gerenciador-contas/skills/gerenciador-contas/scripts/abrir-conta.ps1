# abrir-conta.ps1 <conta> [pasta] [-Rc | -NoRc]
# Abre uma aba nova do Windows Terminal (ou, sem ele, uma janela) com "cc <conta>" na pasta
# indicada (padrao: pasta atual). Usado por uma sessao de uma conta para abrir uma sessao de outra
# conta (ex.: a que pode publicar artefatos) e depois falar com ela por SendMessage. O usuario ve
# e aprova na janela. -Rc / -NoRc viram --rc / --no-rc do cc (com -File, um --rc cru seria lido
# como parametro deste script).
param([Parameter(Mandatory)][string]$Conta, [string]$Pasta = (Get-Location).Path,
      [switch]$Rc, [switch]$NoRc)
. (Join-Path $PSScriptRoot 'comum.ps1')

if (-not ((Get-Contas).Contas.Nome -contains $Conta)) { throw "Conta '$Conta' nao existe em contas.json" }
if (-not (Test-Path -LiteralPath $Pasta -PathType Container)) { throw "Pasta nao existe: $Pasta" }

$extra = @()
if ($Rc) { $extra += '--rc' }
if ($NoRc) { $extra += '--no-rc' }

# A sessao que chama passa CLAUDECODE, CLAUDE_CODE_CHILD_SESSION e o socket de mensagens dela;
# herdados, a sessao nova se comporta como filha (sem historico) e fala pelo canal errado.
$null = Clear-AmbienteSessaoPai

# Start-Process abre o cc.cmd num console classico (conhost), sem cores; o Windows Terminal nao.
$cc = Join-Path $Base 'bin\cc.cmd'
$wt = Get-Command wt.exe -ErrorAction SilentlyContinue
if ($wt) {
    & $wt.Source -w new -d $Pasta $cc $Conta @extra
} else {
    Start-Process -FilePath $cc -ArgumentList (@($Conta) + $extra) -WorkingDirectory $Pasta
}
Write-Host "Janela aberta: cc $Conta $($extra -join ' ') em $Pasta. Use ListAgents para achar a sessao '$(Split-Path -Leaf $Pasta) ($Conta)'."
