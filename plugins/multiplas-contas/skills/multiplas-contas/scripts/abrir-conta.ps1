# abrir-conta.ps1 <conta> [pasta]
# Abre uma JANELA nova com "cc <conta>" na pasta indicada (padrao: pasta atual).
# Usado por uma sessao de uma conta para abrir uma sessao de outra conta (ex.: a que pode
# publicar artefatos) e depois falar com ela por SendMessage. O usuario ve e aprova na janela.
param([Parameter(Mandatory)][string]$Conta, [string]$Pasta = (Get-Location).Path)
. (Join-Path $PSScriptRoot 'comum.ps1')

if (-not ((Get-Contas).Contas.Nome -contains $Conta)) { throw "Conta '$Conta' nao existe em contas.json" }
if (-not (Test-Path -LiteralPath $Pasta -PathType Container)) { throw "Pasta nao existe: $Pasta" }

Start-Process -FilePath (Join-Path $Base 'bin\cc.cmd') -ArgumentList $Conta -WorkingDirectory $Pasta
Write-Host "Janela aberta: cc $Conta em $Pasta. Use ListAgents para achar a sessao '$(Split-Path -Leaf $Pasta) ($Conta)'."
