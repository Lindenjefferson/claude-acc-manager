# cc [conta] [--rc|--no-rc] [argumentos do claude...]   abre o Claude Code na conta (padrao: "padrao" do contas.json)
# cc -l                                                 lista as contas, o e-mail logado, o RC e o uso de cada uma
# --rc / --no-rc liga ou desliga o Remote Control so nesta sessao (padrao: "rc" da conta no contas.json).
. (Join-Path $PSScriptRoot 'comum.ps1')

$cfg = Get-Contas
$resto = @($args)

if ($resto.Count -and $resto[0] -in '-l', '--listar', '--contas') {
    $(foreach ($c in $cfg.Contas) {
        $s = if (Test-Path -LiteralPath $c.Pasta) { Get-StatusConta $c } else { $null }
        $logado = if (-not $s) { 'pasta nao criada (rode setup-contas.ps1)' }
                  elseif ($s.loggedIn) { $s.email + $(if ($s.email -ne $c.Email) { '  <-- DIFERENTE do configurado' }) }
                  else { 'nao logada' }
        $papel = @()
        if ($c.Nome -eq $cfg.Publicar) { $papel += 'principal' }
        if ($c.Nome -eq $cfg.Chrome) { $papel += 'Chrome' }
        $uso = Get-UsoConta $c
        $max = Get-MaxUso $uso
        [pscustomobject]@{
            Conta  = $c.Nome + $(if ($c.Nome -eq $cfg.Padrao) { ' *' })
            Papel    = ($papel -join ', ')
            Esperado = $c.Email
            Logado   = $logado
            RC     = $(if ($c.Rc) { 'ligado' } else { 'desligado' })
            Uso    = $(if ($null -ne $max -and $max -ge $cfg.AvisoUso) { '! ' }) + (Format-Uso $uso)
        }
    }) | Format-Table -AutoSize | Out-String -Width 300 | Write-Host
    Write-Host '* = conta padrao (cc sem argumento); Chrome = conta logada na extensao Claude in Chrome'
    Write-Host "RC = Remote Control ao abrir com cc (mude na hora com --rc / --no-rc); ! = uso >= $($cfg.AvisoUso)%"
    return
}

$conta = $cfg.Contas | Where-Object Nome -eq $cfg.Padrao
if ($resto.Count -and -not "$($resto[0])".StartsWith('-')) {
    $conta = $cfg.Contas | Where-Object Nome -eq $resto[0]
    if (-not $conta) {
        Write-Host "Conta '$($resto[0])' nao existe. Contas: $($cfg.Contas.Nome -join ', ')" -ForegroundColor Red
        return
    }
    $resto = @($resto | Select-Object -Skip 1)
}
$decisao = Split-ArgsRc $conta $resto
$resto = $decisao.Resto

foreach ($m in (Sync-LinksConta $conta)) { Write-Host "[$($conta.Nome)] $m" -ForegroundColor DarkGray }
try {
    $m = Set-RcDesligadoCompartilhado
    if ($m) { Write-Host "[$($conta.Nome)] $m" -ForegroundColor DarkGray }
} catch {
    Write-Host "Nao consegui conferir o RC no settings.json compartilhado: $($_.Exception.Message)" -ForegroundColor Yellow
}
if ($decisao.SettingsDoUsuario) { Write-Host 'Voce passou --settings: o RC segue o que estiver nele.' -ForegroundColor Yellow }

$s = Get-StatusConta $conta
if (-not $s.loggedIn) {
    Write-Host "Conta $($conta.Nome) ainda nao esta logada: use /login com $($conta.Email)" -ForegroundColor Yellow
} elseif ($s.email -ne $conta.Email) {
    Write-Host "ATENCAO: a pasta da conta $($conta.Nome) esta logada como $($s.email), mas o esperado e $($conta.Email)." -ForegroundColor Red
    if ((Read-Host 'Abrir mesmo assim? (s/N)') -notmatch '^[sS]') { return }
}

# Uso alto: avisa, sugere a conta com mais folga e pergunta (no modo -p so avisa em stderr).
$naoInterativo = [bool]($resto | Where-Object { $_ -in '-p', '--print' })
$uso = Get-UsoConta $conta
$max = Get-MaxUso $uso
if ($null -ne $max -and $max -ge $cfg.AvisoUso) {
    $linhas = @("Conta $($conta.Nome) com uso alto: $(Format-Uso $uso)")
    $usos = @{}
    foreach ($o in ($cfg.Contas | Where-Object Nome -ne $conta.Nome)) { $usos[$o.Nome] = Get-UsoConta $o }
    $sug = Select-ContaSugerida $usos $conta.Nome
    if ($sug -and (Get-MaxUso $usos[$sug]) -lt $max) { $linhas += "Sugestao: cc $sug ($(Format-Uso $usos[$sug]))" }
    if ($naoInterativo) {
        $linhas | ForEach-Object { [Console]::Error.WriteLine($_) }
    } else {
        $linhas | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
        if ((Read-Host 'Abrir mesmo assim? (s/N)') -notmatch '^[sS]') { return }
    }
}

# Nome da sessao = pasta (conta), a menos que o usuario esteja retomando ou ja tenha dado nome.
$extra = @()
if (-not ($resto | Where-Object { $_ -in '-n', '--name', '-r', '--resume', '-c', '--continue', '-p', '--print' })) {
    $extra = @('-n', ('{0} ({1})' -f (Split-Path -Leaf (Get-Location)), $conta.Nome))
}
$argsClaude = Get-ArgsClaude $decisao

try {
    Invoke-ComConta $conta { & $Claude @extra @argsClaude }
} finally {
    $null = Sync-LinksConta $conta
}
