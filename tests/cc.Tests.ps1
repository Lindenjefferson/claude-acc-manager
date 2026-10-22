. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE
$raiz = Join-Path ([IO.Path]::GetTempPath()) ("mc-cc-" + [guid]::NewGuid())
. New-AmbienteFalso $raiz @{ principal = 'a'; contas = @{ a = @{ email = 'a@x' } } }

Describe 'Get-ArgsClaude' {
    It 'acrescenta o --settings do RC' {
        $a = Get-ArgsClaude ([pscustomobject]@{ Ligado = $true; Resto = @('-p', 'oi'); SettingsDoUsuario = $false })
        ($a -join ' ') | Should Be ('-p oi --settings ' + (Join-Path $raiz '.claude-contas\rc\ligado.json'))
    }

    It 'desligado aponta para desligado.json' {
        $a = Get-ArgsClaude ([pscustomobject]@{ Ligado = $false; Resto = @(); SettingsDoUsuario = $false })
        $a[-1] | Should Be (Join-Path $raiz '.claude-contas\rc\desligado.json')
    }

    It 'nao duplica o --settings do usuario' {
        $a = Get-ArgsClaude ([pscustomobject]@{ Ligado = $false; Resto = @('--settings', 'meu.json'); SettingsDoUsuario = $true })
        @($a | Where-Object { $_ -eq '--settings' }).Count | Should Be 1
        ($a -join ' ') | Should Be '--settings meu.json'
    }
}

$env:USERPROFILE = $perfilReal
Remove-Item -LiteralPath $raiz -Recurse -Force -ErrorAction SilentlyContinue
