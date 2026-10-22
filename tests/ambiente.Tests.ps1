. (Join-Path $PSScriptRoot '_contas-falsas.ps1')
$perfilReal = $env:USERPROFILE
$raiz = Join-Path ([IO.Path]::GetTempPath()) ("mc-amb-" + [guid]::NewGuid())
. New-AmbienteFalso $raiz @{ principal = 'a'; contas = @{ a = @{ email = 'a@x' } } }
$env:USERPROFILE = $perfilReal

Describe 'Clear-AmbienteSessaoPai' {
    It 'tira as variaveis CLAUDE* herdadas e mantem CLAUDE_CONFIG_DIR' {
        $guardado = @{}
        Get-ChildItem Env: | Where-Object Name -like 'CLAUDE*' | ForEach-Object { $guardado[$_.Name] = $_.Value }
        try {
            $env:CLAUDE_CODE_CHILD_SESSION = '1'
            $env:CLAUDECODE = '1'
            $env:CLAUDE_CONFIG_DIR = 'C:\x'
            $env:ANTHROPIC_TESTE_MC = 'fica'
            $tirados = Clear-AmbienteSessaoPai
            $env:CLAUDE_CODE_CHILD_SESSION | Should Be $null
            $env:CLAUDECODE | Should Be $null
            $env:CLAUDE_CONFIG_DIR | Should Be 'C:\x'
            $env:ANTHROPIC_TESTE_MC | Should Be 'fica'
            ($tirados -contains 'CLAUDE_CODE_CHILD_SESSION') | Should Be $true
        } finally {
            Remove-Item Env:ANTHROPIC_TESTE_MC, Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue
            foreach ($k in $guardado.Keys) { Set-Item "Env:$k" $guardado[$k] }
        }
    }
}

Remove-Item -LiteralPath $raiz -Recurse -Force -ErrorAction SilentlyContinue
