. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE

Describe 'Get-Contas: rc e avisoUso' {
    AfterAll { $env:USERPROFILE = $perfilReal }

    It 'rc true so quando explicito' {
        . New-AmbienteFalso (Join-Path $TestDrive 'p1') @{
            principal = 'a'
            contas = @{ a = @{ email = 'a@x'; rc = $true }; b = @{ email = 'b@x' }; c = @{ email = 'c@x'; rc = 'true' } }
        }
        $cs = (Get-Contas).Contas
        ($cs | Where-Object Nome -eq 'a').Rc | Should Be $true
        ($cs | Where-Object Nome -eq 'b').Rc | Should Be $false
        ($cs | Where-Object Nome -eq 'c').Rc | Should Be $false
    }

    It 'avisoUso padrao 80' {
        . New-AmbienteFalso (Join-Path $TestDrive 'p2') @{ principal = 'a'; contas = @{ a = @{ email = 'a@x' } } }
        (Get-Contas).AvisoUso | Should Be 80
        . New-AmbienteFalso (Join-Path $TestDrive 'p3') @{ principal = 'a'; avisoUso = 70; contas = @{ a = @{ email = 'a@x' } } }
        (Get-Contas).AvisoUso | Should Be 70
        . New-AmbienteFalso (Join-Path $TestDrive 'p4') @{ principal = 'a'; avisoUso = 'x'; contas = @{ a = @{ email = 'a@x' } } }
        (Get-Contas).AvisoUso | Should Be 80
    }
}
