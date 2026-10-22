. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE
$raiz = Join-Path ([IO.Path]::GetTempPath()) ("mc-rc-" + [guid]::NewGuid())
. New-AmbienteFalso $raiz @{ principal = 'pessoal'; contas = @{ pessoal = @{ email = 'p@x'; rc = $true }; edevize1 = @{ email = 'e@x' } } }
$contas = (Get-Contas).Contas
$pessoal = $contas | Where-Object Nome -eq 'pessoal'
$empresa = $contas | Where-Object Nome -eq 'edevize1'
$settings = Join-Path $raiz '.claude\settings.json'
function Set-Settings([string]$texto) { [IO.File]::WriteAllText($settings, $texto) }
function Get-Settings { Get-Content -LiteralPath $settings -Raw | ConvertFrom-Json }

Describe 'Split-ArgsRc' {
    It 'padrao da conta' {
        (Split-ArgsRc $pessoal @()).Ligado | Should Be $true
        (Split-ArgsRc $empresa @()).Ligado | Should Be $false
    }

    It '--rc liga e fica nos args' {
        $d = Split-ArgsRc $empresa @('--rc', 'minha-sessao')
        $d.Ligado | Should Be $true
        ($d.Resto -join ' ') | Should Be '--rc minha-sessao'
    }

    It '--no-rc desliga e sai dos args' {
        $d = Split-ArgsRc $pessoal @('--no-rc', '-p', 'oi')
        $d.Ligado | Should Be $false
        ($d.Resto -join ' ') | Should Be '-p oi'
    }

    It 'o ultimo vence' {
        (Split-ArgsRc $empresa @('--rc', '--no-rc')).Ligado | Should Be $false
        (Split-ArgsRc $pessoal @('--no-rc', '--remote-control')).Ligado | Should Be $true
    }

    It 'settings do usuario detectado' {
        (Split-ArgsRc $empresa @('--settings', 'x.json')).SettingsDoUsuario | Should Be $true
        (Split-ArgsRc $empresa @('-p', 'oi')).SettingsDoUsuario | Should Be $false
    }
}

Describe 'Get-ArquivoRc' {
    It 'arquivos rc' {
        (Get-Content (Get-ArquivoRc $false) -Raw | ConvertFrom-Json).remoteControlAtStartup | Should Be $false
        (Get-Content (Get-ArquivoRc $true) -Raw | ConvertFrom-Json).remoteControlAtStartup | Should Be $true
        Get-ArquivoRc $true | Should Be (Join-Path $raiz '.claude-contas\rc\ligado.json')
    }
}

Describe 'Set-RcDesligadoCompartilhado' {
    It 'compartilhado: true vira false' {
        Set-Settings "{`n  `"theme`": `"dark`",`n  `"remoteControlAtStartup`": true`n}"
        Set-RcDesligadoCompartilhado | Should Not BeNullOrEmpty
        $s = Get-Settings
        $s.remoteControlAtStartup | Should Be $false
        $s.theme | Should Be 'dark'
    }

    It 'compartilhado: insere quando falta' {
        Set-Settings '{"theme":"dark"}'
        Set-RcDesligadoCompartilhado | Should Not BeNullOrEmpty
        $s = Get-Settings
        $s.remoteControlAtStartup | Should Be $false
        $s.theme | Should Be 'dark'
    }

    It 'compartilhado: objeto vazio' {
        Set-Settings '{}'
        $null = Set-RcDesligadoCompartilhado
        (Get-Settings).remoteControlAtStartup | Should Be $false
    }

    It 'compartilhado: ja false nao mexe' {
        Set-Settings '{"remoteControlAtStartup": false, "theme":"dark"}'
        $antes = (Get-Item $settings).LastWriteTimeUtc
        Start-Sleep -Milliseconds 50
        Set-RcDesligadoCompartilhado | Should Be $null
        (Get-Item $settings).LastWriteTimeUtc | Should Be $antes
    }

    It 'compartilhado: arquivo ausente' {
        Remove-Item $settings -ErrorAction SilentlyContinue
        $null = Set-RcDesligadoCompartilhado
        (Get-Settings).remoteControlAtStartup | Should Be $false
    }
}

$env:USERPROFILE = $perfilReal
Remove-Item -LiteralPath $raiz -Recurse -Force -ErrorAction SilentlyContinue
