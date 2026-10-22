. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE
$configReal = $env:CLAUDE_CONFIG_DIR
$raiz = Join-Path ([IO.Path]::GetTempPath()) ("mc-sl-" + [guid]::NewGuid())
. New-AmbienteFalso $raiz @{ principal = 'a'; contas = @{ a = @{ email = 'a@x'; pasta = '~/.claude' }; b = @{ email = 'b@x' } } }
$contas = (Get-Contas).Contas
$b = $contas | Where-Object Nome -eq 'b'
$settings = Join-Path $raiz '.claude\settings.json'
$esc = [char]27
$ponto = [char]0xB7
function Texto([string]$conta, $c, $s) { $u = 'Sess' + [char]0xE3 + ('o (5h): {0}% {1} Semana: {2}%' -f $c, $ponto, $s); if ($conta) { "$conta $ponto $u" } else { $u } }
function Remove-Ansi([string]$t) { $t -replace "$esc\[[0-9;]*m", '' }
function New-Entrada($cinco, $semana) {
    [pscustomobject]@{ rate_limits = [pscustomobject]@{
        five_hour = [pscustomobject]@{ used_percentage = $cinco }; seven_day = [pscustomobject]@{ used_percentage = $semana } } }
}

Describe 'Format-StatusLine' {
    It 'cores' {
        $t = Format-StatusLine (New-Entrada 50 85) $b 80
        $t | Should Match ([regex]::Escape("$esc[33m85%"))
        $t | Should Not Match ([regex]::Escape("$esc[") + '3[13]m50')
        (Format-StatusLine (New-Entrada 96 10) $b 80) | Should Match ([regex]::Escape("$esc[31m96%"))
        (Format-StatusLine (New-Entrada 50 10) $b 80) | Should Not Match ([regex]::Escape("$esc["))
    }

    It 'texto' {
        Remove-Ansi (Format-StatusLine (New-Entrada 12 27) $b 80) | Should Be (Texto 'b' 12 27)
        Remove-Ansi (Format-StatusLine (New-Entrada 12.6 27) $b 80) | Should Be (Texto 'b' 13 27)
    }

    It 'sem rate_limits' {
        Format-StatusLine ([pscustomobject]@{ model = 'x' }) $b 80 | Should Be 'b'
    }

    It 'sem conta' {
        Remove-Ansi (Format-StatusLine (New-Entrada 12 27) $null 80) | Should Be (Texto $null 12 27)
    }
}

Describe 'Get-ContaAtual' {
    It 'conta atual' {
        $env:CLAUDE_CONFIG_DIR = $b.Pasta
        (Get-ContaAtual).Nome | Should Be 'b'
        Remove-Item Env:CLAUDE_CONFIG_DIR
        (Get-ContaAtual).Nome | Should Be 'a'
    }
}

Describe 'statusline.ps1' {
    It 'script ponta a ponta' {
        $script = Join-Path $ScriptsDir 'statusline.ps1'
        $env:USERPROFILE = $raiz
        $env:CLAUDE_CONFIG_DIR = $b.Pasta
        $antes = [Console]::OutputEncoding
        [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
        $out = '{"rate_limits":{"five_hour":{"used_percentage":85},"seven_day":{"used_percentage":10}}}' |
            powershell -NoProfile -ExecutionPolicy Bypass -File $script
        [Console]::OutputEncoding = $antes
        Remove-Item Env:CLAUDE_CONFIG_DIR
        Remove-Ansi ($out -join '') | Should Be (Texto 'b' 85 10)
    }

    It 'entrada invalida nao quebra' {
        $script = Join-Path $ScriptsDir 'statusline.ps1'
        $out = 'nao e json' | powershell -NoProfile -ExecutionPolicy Bypass -File $script 2>&1
        ($out -join '').Trim() | Should Be ''
    }
}

Describe 'Register-StatusLine / Unregister-StatusLine' {
    It 'register: insere e e idempotente' {
        [IO.File]::WriteAllText($settings, '{"theme":"dark"}')
        $null = Register-StatusLine
        $s = Get-Content $settings -Raw | ConvertFrom-Json
        $s.statusLine.command | Should Match 'statusline\.ps1'
        $s.theme | Should Be 'dark'
        $antes = Get-Content $settings -Raw
        Register-StatusLine | Should Be $null
        Get-Content $settings -Raw | Should Be $antes
    }

    It 'register: respeita outra status line' {
        $outra = '{"theme":"dark","statusLine":{"type":"command","command":"outra.sh"}}'
        [IO.File]::WriteAllText($settings, $outra)
        Register-StatusLine | Should Match 'outra'
        Get-Content $settings -Raw | Should Be $outra
    }

    It 'unregister: remove so a nossa' {
        [IO.File]::WriteAllText($settings, '{"theme":"dark"}')
        $null = Register-StatusLine
        Unregister-StatusLine
        $s = Get-Content $settings -Raw | ConvertFrom-Json
        $s.statusLine | Should Be $null
        $s.theme | Should Be 'dark'
        # nossa como ultima chave (virgula antes, nao depois)
        [IO.File]::WriteAllText($settings, '{"theme":"dark","statusLine":{"type":"command","command":"powershell -File C:/x/statusline.ps1"}}')
        Unregister-StatusLine
        (Get-Content $settings -Raw | ConvertFrom-Json).theme | Should Be 'dark'
        $outra = '{"statusLine":{"type":"command","command":"outra.sh"}}'
        [IO.File]::WriteAllText($settings, $outra)
        Unregister-StatusLine
        Get-Content $settings -Raw | Should Be $outra
    }
}

$env:USERPROFILE = $perfilReal
if ($null -ne $configReal) { $env:CLAUDE_CONFIG_DIR = $configReal }
Remove-Item -LiteralPath $raiz -Recurse -Force -ErrorAction SilentlyContinue
