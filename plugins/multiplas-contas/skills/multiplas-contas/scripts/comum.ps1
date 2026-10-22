# Funcoes compartilhadas pelos scripts de ~/.claude-contas.
# Cada conta tem sua pasta de config (CLAUDE_CONFIG_DIR) com login proprio;
# o resto aponta para a pasta mestre ~/.claude via symlink (arquivos) ou junction (pastas).
# Arquivos .ps1 ficam em ASCII: o Windows PowerShell 5.1 le .ps1 sem BOM como ANSI.

$Script:Base   = Join-Path $env:USERPROFILE '.claude-contas'
$Script:Mestre = Join-Path $env:USERPROFILE '.claude'

$Script:Claude = Get-Command claude.exe -CommandType Application -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -notlike "$Base*" } | Select-Object -First 1 -ExpandProperty Source
if (-not $Claude) { $Script:Claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe' }

# O que e compartilhado com a pasta mestre. Login (.credentials.json), .claude.json,
# cache, state, shell-snapshots, backups etc. ficam separados por conta.
$Script:ArquivosCompartilhados = @('settings.json', 'history.jsonl', 'CLAUDE.md', 'keybindings.json')
$Script:PastasCompartilhadas   = @('projects', 'file-history', 'session-env', 'sessions', 'skills',
                                   'plugins', 'dev-mods', 'agents', 'commands', 'output-styles', 'hooks', 'rules')

# Chaves do ~/.claude.json copiadas para uma conta nova (config, nao dados da conta).
$Script:ChavesSemente = @('mcpServers', 'projects', 'githubRepoPaths', 'hasCompletedOnboarding',
                          'lastOnboardingVersion', 'installMethod', 'autoUpdates', 'autoUpdatesProtectedForNative',
                          'claudeInChromeDefaultEnabled', 'hasCompletedClaudeInChromeOnboarding',
                          'cachedChromeExtensionInstalled')

$Script:MarcaInicio = '<!-- multiplas-contas:inicio -->'
$Script:MarcaFim    = '<!-- multiplas-contas:fim -->'

function Get-Contas {
    $cfg = Get-Content (Join-Path $Base 'contas.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $lista = foreach ($p in $cfg.contas.PSObject.Properties) {
        $pasta = if ($p.Value.pasta) { $p.Value.pasta -replace '^~', $env:USERPROFILE } else { Join-Path $Base $p.Name }
        $pasta = [IO.Path]::GetFullPath($pasta)
        [pscustomobject]@{
            Nome   = $p.Name
            Email  = $p.Value.email
            Pasta  = $pasta
            Mestre = ($pasta.TrimEnd('\') -eq $Mestre.TrimEnd('\'))
        }
    }
    # "principal" e a conta padrao do cc e a unica que publica; "padrao"/"publicar" separam os dois papeis.
    $principal = if ($cfg.principal) { $cfg.principal } else { $cfg.padrao }
    [pscustomobject]@{
        Principal = $principal
        Padrao   = $(if ($cfg.padrao) { $cfg.padrao } else { $principal })
        Publicar = $(if ($cfg.publicar) { $cfg.publicar } else { $principal })
        Atalho   = $(if ($cfg.atalhoExplorer) { $cfg.atalhoExplorer } else { 'cc' })
        Contas   = @($lista)
    }
}

function Test-Link([string]$caminho) {
    $i = Get-Item -LiteralPath $caminho -Force -ErrorAction SilentlyContinue
    return ($i -and $i.LinkType)
}

function Write-TextoSemBom([string]$caminho, [string]$texto) {
    [IO.File]::WriteAllText($caminho, $texto, (New-Object Text.UTF8Encoding $false))
}

# Symlink de arquivo exige modo desenvolvedor (ou admin). Sem ele, cai para hard link,
# que tambem funciona; se um programa salvar por cima e quebrar o link, Sync-LinksConta refaz.
function New-LinkArquivo([string]$link, [string]$alvo) {
    cmd /c mklink "$link" "$alvo" 2>$null | Out-Null
    if (-not (Test-Link $link)) { cmd /c mklink /H "$link" "$alvo" 2>$null | Out-Null }
    if (-not (Test-Path -LiteralPath $link)) { throw "Nao consegui criar link de $link para $alvo" }
}

function Test-LinkArquivoOk([string]$link, [string]$alvo) {
    $i = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if (-not $i) { return $false }
    if ($i.LinkType -eq 'SymbolicLink') { return $true }
    if ($i.LinkType -eq 'HardLink') {
        # Hard link so vale se ainda aponta para o mesmo arquivo da mestre.
        $a = cmd /c fsutil hardlink list "$alvo" 2>$null
        $nome = $link.Substring(2)  # fsutil lista sem a letra da unidade
        return [bool]($a | Where-Object { $_ -ieq $nome })
    }
    return $false
}

# Garante os links de uma conta. Se um link de arquivo virou arquivo comum (alguns programas
# salvam gravando um temporario e renomeando por cima), a versao mais nova vai para a mestre
# antes de refazer o link, para nao perder a alteracao. Retorna mensagens do que fez.
function Sync-LinksConta($conta) {
    $msgs = @()
    if ($conta.Mestre) { return $msgs }
    New-Item -ItemType Directory -Force $conta.Pasta | Out-Null
    $carimbo = Get-Date -Format 'yyyyMMdd_HHmmss'

    foreach ($nome in $ArquivosCompartilhados) {
        $alvo = Join-Path $Mestre $nome
        $link = Join-Path $conta.Pasta $nome
        if (-not (Test-Path -LiteralPath $alvo)) { continue }
        if (Test-LinkArquivoOk $link $alvo) { continue }
        if (Test-Path -LiteralPath $link) {
            $local = Get-Item -LiteralPath $link -Force
            $bak = Join-Path $Base ("backups\relink_{0}_{1}_{2}" -f $conta.Nome, $carimbo, $nome)
            New-Item -ItemType Directory -Force (Split-Path $bak) | Out-Null
            if ($local.LastWriteTime -gt (Get-Item -LiteralPath $alvo).LastWriteTime) {
                Copy-Item -LiteralPath $alvo $bak
                Copy-Item -LiteralPath $link $alvo -Force
                $msgs += "${nome}: alteracao feita na conta $($conta.Nome) levada para a mestre (anterior em $bak)"
            } else {
                Copy-Item -LiteralPath $link $bak
            }
            Remove-Item -LiteralPath $link -Force
        }
        New-LinkArquivo $link $alvo
        $msgs += "link: $link"
    }

    foreach ($nome in $PastasCompartilhadas) {
        $alvo = Join-Path $Mestre $nome
        $link = Join-Path $conta.Pasta $nome
        if (-not (Test-Path -LiteralPath $alvo)) { continue }
        if (Test-Link $link) { continue }
        if (Test-Path -LiteralPath $link) {
            # Pasta real criada pelo Claude antes do link: preserva em backups e liga.
            $bak = Join-Path $Base ("backups\relink_{0}_{1}_{2}" -f $conta.Nome, $carimbo, $nome)
            New-Item -ItemType Directory -Force (Split-Path $bak) | Out-Null
            Move-Item -LiteralPath $link $bak
            $msgs += "${nome}: pasta local da conta $($conta.Nome) movida para $bak"
        }
        New-Item -ItemType Junction -Path $link -Target $alvo | Out-Null
        $msgs += "junction: $link"
    }

    # .claude.json inicial: so as chaves de configuracao da mestre, sem dados da conta.
    $estado = Join-Path $conta.Pasta '.claude.json'
    $origem = Join-Path $env:USERPROFILE '.claude.json'
    if (-not (Test-Path -LiteralPath $estado) -and (Test-Path -LiteralPath $origem)) {
        $orig = Get-Content $origem -Raw -Encoding UTF8 | ConvertFrom-Json
        $novo = [ordered]@{}
        foreach ($k in $ChavesSemente) { if ($null -ne $orig.$k) { $novo[$k] = $orig.$k } }
        Write-TextoSemBom $estado (([pscustomobject]$novo) | ConvertTo-Json -Depth 100)
        $msgs += "estado inicial: $estado"
    }
    return $msgs
}

# Remove so os links (nunca o conteudo da mestre).
function Remove-LinksConta($conta) {
    if ($conta.Mestre -or -not (Test-Path -LiteralPath $conta.Pasta)) { return }
    Get-ChildItem -LiteralPath $conta.Pasta -Force | Where-Object { $_.LinkType } | ForEach-Object {
        if ($_.PSIsContainer) { [IO.Directory]::Delete($_.FullName, $false) } else { [IO.File]::Delete($_.FullName) }
    }
    foreach ($nome in $ArquivosCompartilhados) {
        # Hard links nao aparecem como LinkType em todas as versoes; so remove se ainda for
        # o mesmo arquivo da mestre (copia que divergiu fica, para nao perder alteracao).
        $f = Join-Path $conta.Pasta $nome
        if ((Test-Path -LiteralPath $f) -and (Test-LinkArquivoOk $f (Join-Path $Mestre $nome))) { [IO.File]::Delete($f) }
    }
}

function Invoke-ComConta($conta, [scriptblock]$bloco) {
    $antes = $env:CLAUDE_CONFIG_DIR
    try {
        # A conta da pasta mestre roda sem a variavel, senao o Claude procura .claude.json dentro de ~/.claude.
        if ($conta.Mestre) { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue } else { $env:CLAUDE_CONFIG_DIR = $conta.Pasta }
        & $bloco
    } finally {
        if ($null -ne $antes) { $env:CLAUDE_CONFIG_DIR = $antes } else { Remove-Item Env:CLAUDE_CONFIG_DIR -ErrorAction SilentlyContinue }
    }
}

function Get-StatusConta($conta) {
    Invoke-ComConta $conta { & $Claude auth status --json 2>$null | ConvertFrom-Json }
}

# Atualiza o bloco entre as marcas no ~/.claude/CLAUDE.md a partir de modelo-CLAUDE.md.
function Update-ClaudeMd {
    $cfg = Get-Contas
    $modelo = Get-Content (Join-Path $Base 'modelo-CLAUDE.md') -Raw -Encoding UTF8
    $linhas = foreach ($c in $cfg.Contas) {
        $papel = if ($c.Nome -eq $cfg.Publicar) { 'principal' } else { 'secundaria' }
        if ($c.Nome -eq $cfg.Padrao -and $cfg.Padrao -ne $cfg.Publicar) { $papel += ', padrao do cc' }
        $p = if ($c.Mestre) { '`~/.claude` (pasta mestre)' } else { '`~/.claude-contas/' + $c.Nome + '`' }
        '| {0} | {1} | {2} | {3} |' -f $c.Nome, $papel, $c.Email, $p
    }
    $pub = $cfg.Contas | Where-Object Nome -eq $cfg.Publicar
    $bloco = $modelo.Replace('{{TABELA}}', ($linhas -join "`n")).
        Replace('{{PUBLICAR}}', $cfg.Publicar).Replace('{{EMAIL_PUBLICAR}}', $pub.Email).Replace('{{ATALHO}}', $cfg.Atalho)
    $bloco = "$MarcaInicio`n$($bloco.Trim())`n$MarcaFim"

    $md = Join-Path $Mestre 'CLAUDE.md'
    $atual = if (Test-Path $md) { Get-Content $md -Raw -Encoding UTF8 } else { '' }
    $i = $atual.IndexOf($MarcaInicio); $f = $atual.IndexOf($MarcaFim)
    if ($i -ge 0 -and $f -gt $i) {
        $novo = $atual.Substring(0, $i) + $bloco + $atual.Substring($f + $MarcaFim.Length)
    } elseif ($atual.Trim()) {
        $novo = $atual.TrimEnd() + "`n`n" + $bloco + "`n"
    } else {
        $novo = $bloco + "`n"
    }
    Write-TextoSemBom $md $novo
}

function Remove-BlocoClaudeMd {
    $md = Join-Path $Mestre 'CLAUDE.md'
    if (-not (Test-Path $md)) { return }
    $atual = Get-Content $md -Raw -Encoding UTF8
    $i = $atual.IndexOf($MarcaInicio); $f = $atual.IndexOf($MarcaFim)
    if ($i -lt 0 -or $f -lt $i) { return }
    $novo = ($atual.Substring(0, $i) + $atual.Substring($f + $MarcaFim.Length)).Trim()
    if ($novo) { Write-TextoSemBom $md ($novo + "`n") } else { Remove-Item $md }
}

function Get-ChaveAppPaths([string]$atalho) { "HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\$atalho.exe" }
