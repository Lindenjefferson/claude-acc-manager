. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE

# Grava o CLAUDE.md da pasta mestre e o modelo no ambiente falso montado por New-AmbienteFalso.
function Set-ClaudeMdFalso([string]$raiz, [string]$texto) {
    Copy-Item (Join-Path $ScriptsDir 'modelo-CLAUDE.md') (Join-Path $raiz '.claude-contas')
    [IO.File]::WriteAllText((Join-Path $raiz '.claude\CLAUDE.md'), $texto)
    Join-Path $raiz '.claude\CLAUDE.md'
}

Describe 'Bloco do CLAUDE.md' {
    AfterAll { $env:USERPROFILE = $perfilReal }
    $antigo = "# Meu`n`n<!-- multiplas-contas:inicio -->`nvelho`n<!-- multiplas-contas:fim -->`n"

    It 'troca o bloco com as marcas antigas (multiplas-contas) pelo novo, sem duplicar' {
        $raiz = Join-Path $TestDrive 'm1'
        . New-AmbienteFalso $raiz @{ principal = 'a'; contas = @{ a = @{ email = 'a@x' } } }
        $md = Set-ClaudeMdFalso $raiz ($antigo + "`nfim do usuario`n")
        Update-ClaudeMd
        $t = Get-Content $md -Raw
        $t | Should Not Match 'multiplas-contas:'
        $t | Should Not Match 'velho'
        ([regex]::Matches($t, '<!-- claude-acc-manager:inicio -->')).Count | Should Be 1
        $t | Should Match '# Meu'
        $t | Should Match 'fim do usuario'
    }

    It 'remove o bloco com as marcas antigas' {
        $raiz = Join-Path $TestDrive 'm2'
        . New-AmbienteFalso $raiz @{ principal = 'a'; contas = @{ a = @{ email = 'a@x' } } }
        $md = Set-ClaudeMdFalso $raiz $antigo
        Remove-BlocoClaudeMd
        (Get-Content $md -Raw).Trim() | Should Be '# Meu'
    }
}
