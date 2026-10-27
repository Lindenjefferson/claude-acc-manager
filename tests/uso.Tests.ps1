. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE
$raiz = Join-Path ([IO.Path]::GetTempPath()) ("mc-uso-" + [guid]::NewGuid())
. New-AmbienteFalso $raiz @{
    principal = 'mestre'
    contas = @{
        mestre   = @{ email = 'm@x'; pasta = '~/.claude' }
        valida   = @{ email = 'v@x' }
        vencida  = @{ email = 'e@x' }
        semnada  = @{ email = 's@x' }
        reiniciou = @{ email = 'r@x' }
    }
}

$agora = Get-Date
function ConvertTo-Ms([datetime]$d) { [DateTimeOffset]::new($d).ToUnixTimeMilliseconds() }
function New-Util([int]$cinco, [int]$semana, [datetime]$resetCinco) {
    @{ five_hour = @{ utilization = $cinco; resets_at = ([DateTimeOffset]::new($resetCinco)).ToString('o') }
       seven_day = @{ utilization = $semana; resets_at = ([DateTimeOffset]::new($agora.AddDays(3))).ToString('o') } }
}
function Set-Conta([string]$nome, $expira, $util) {
    $p = Join-Path $raiz ".claude-contas\$nome"
    New-Item -ItemType Directory -Force $p | Out-Null
    if ($expira) {
        $cred = @{ claudeAiOauth = @{ accessToken = 'tok-falso'; expiresAt = (ConvertTo-Ms $expira) } }
        [IO.File]::WriteAllText((Join-Path $p '.credentials.json'), ($cred | ConvertTo-Json -Depth 5))
    }
    if ($util) {
        $est = @{ cachedUsageUtilization = @{ fetchedAtMs = (ConvertTo-Ms $agora.AddMinutes(-30)); utilization = $util } }
        [IO.File]::WriteAllText((Join-Path $p '.claude.json'), ($est | ConvertTo-Json -Depth 10))
    }
}
Set-Conta 'valida' $agora.AddHours(1) (New-Util 2 27 $agora.AddHours(2))
Set-Conta 'vencida' $agora.AddHours(-1) (New-Util 2 27 $agora.AddHours(2))
Set-Conta 'reiniciou' $null (New-Util 90 30 $agora.AddMinutes(-10))
$contas = (Get-Contas).Contas
function C([string]$n) { $contas | Where-Object Nome -eq $n }

Describe 'Get-UsoConta' {
    It 'usa API quando token valido' {
        Mock Invoke-UsoApi { [pscustomobject]@{ five_hour = @{ utilization = 12; resets_at = $null }; seven_day = @{ utilization = 40; resets_at = $null } } }
        $u = Get-UsoConta (C 'valida') -agora $agora
        $u.Fonte | Should Be 'agora'
        $u.Cinco | Should Be 12
        $u.Semana | Should Be 40
    }

    It 'cai para o salvo quando token vencido' {
        Mock Invoke-UsoApi { throw 'nao devia chamar' }
        $u = Get-UsoConta (C 'vencida') -agora $agora
        $u.Fonte | Should Be 'salvo'
        $u.Cinco | Should Be 2
        $u.Semana | Should Be 27
        Assert-MockCalled Invoke-UsoApi -Times 0 -Scope It
    }

    It 'cai para o salvo quando API falha' {
        Mock Invoke-UsoApi { throw '401' }
        (Get-UsoConta (C 'valida') -agora $agora).Fonte | Should Be 'salvo'
    }

    It 'conta sem pasta nem login' {
        $u = Get-UsoConta (C 'semnada') -agora $agora
        $u.Fonte | Should Be $null
        Format-Uso $u | Should Be '-'
    }

    It 'janela reiniciada vira zero' {
        $u = Get-UsoConta (C 'reiniciou') -agora $agora
        $u.Cinco | Should Be 0
        $u.ResetCinco | Should Be $null
        $u.Semana | Should Be 30
    }

    It 'conta mestre le ~/.claude.json' {
        Get-ArquivoEstado (C 'mestre') | Should Be (Join-Path $raiz '.claude.json')
        Get-ArquivoEstado (C 'valida') | Should Be (Join-Path $raiz '.claude-contas\valida\.claude.json')
    }

    It 'token nunca aparece' {
        Mock Invoke-UsoApi { throw '401' }
        $u = Get-UsoConta (C 'valida') -agora $agora
        (Format-Uso $u) | Should Not Match 'tok-falso'
        ($u | ConvertTo-Json -Depth 5) | Should Not Match 'tok-falso'
    }
}

Describe 'Format-Uso, Get-MaxUso, Select-ContaSugerida' {
    $esperado = 'Sess' + [char]0xE3 + 'o: 2% (reinicia em 1h00) ' + [char]0xB7 + ' Semana: 27% (reinicia em 3d 0h)'
    It 'format e max' {
        $u = ConvertTo-Uso (New-Util 2 27 $agora.AddHours(1)) 'agora' $null $agora
        Format-Uso $u $agora | Should Be $esperado
        Get-MaxUso $u | Should Be 27
    }

    It 'format do salvo traz o horario' {
        $q = $agora.AddMinutes(-30)
        $u = ConvertTo-Uso (New-Util 2 27 $agora.AddHours(1)) 'salvo' $q $agora
        Format-Uso $u $agora | Should Be ($esperado + (' (salvo {0})' -f $q.ToString('HH:mm')))
    }

    It 'salvo em outro dia traz a data' {
        $q = $agora.AddDays(-3)
        $u = ConvertTo-Uso (New-Util 2 27 $agora.AddHours(1)) 'salvo' $q $agora
        Format-Uso $u $agora | Should Be ($esperado + (' (salvo {0})' -f $q.ToString('dd/MM HH:mm')))
    }

    It 'salvo sem fetchedAtMs nao inventa 1970' {
        $p = Join-Path $raiz '.claude-contas\semdata'
        New-Item -ItemType Directory -Force $p | Out-Null
        $est = @{ cachedUsageUtilization = @{ utilization = (New-Util 2 27 $agora.AddHours(2)) } }
        [IO.File]::WriteAllText((Join-Path $p '.claude.json'), ($est | ConvertTo-Json -Depth 10))
        $c = [pscustomobject]@{ Nome = 'semdata'; Pasta = $p; Mestre = $false }
        $u = ConvertTo-Uso (New-Util 2 27 $agora.AddHours(1)) 'salvo' $null $agora
        Format-Uso $u $agora | Should Be ($esperado + ' (salvo, sem data)')
        $u = Get-UsoConta $c -agora $agora
        $u.Fonte | Should Be 'salvo'
        $u.Quando | Should Be $null
    }

    It 'tempo ate reiniciar' {
        Format-Reinicio $agora.AddMinutes(45) $agora | Should Be ' (reinicia em 45min)'
        Format-Reinicio $agora.AddMinutes(125) $agora | Should Be ' (reinicia em 2h05)'
        Format-Reinicio $agora.AddHours(76) $agora | Should Be ' (reinicia em 3d 4h)'
        Format-Reinicio $agora.AddMinutes(-1) $agora | Should Be ''
        Format-Reinicio $null $agora | Should Be ''
        $u = ConvertTo-Uso @{ five_hour = @{ utilization = 5; resets_at = $null } } 'agora' $null $agora
        Format-Uso $u $agora | Should Be ('Sess' + [char]0xE3 + 'o: 5% ' + [char]0xB7 + ' Semana: ?')
    }

    It 'sugere a de menor maximo' {
        $usos = @{
            a = ConvertTo-Uso (New-Util 90 10 $agora.AddHours(1)) 'agora' $null $agora
            b = ConvertTo-Uso (New-Util 30 50 $agora.AddHours(1)) 'agora' $null $agora
            c = ConvertTo-Uso $null $null $null $agora
        }
        Select-ContaSugerida $usos 'a' | Should Be 'b'
        Select-ContaSugerida @{ c = $usos.c } 'a' | Should Be $null
    }
}

$env:USERPROFILE = $perfilReal
Remove-Item -LiteralPath $raiz -Recurse -Force -ErrorAction SilentlyContinue
