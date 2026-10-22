# Status line do Claude Code: "<conta> | 5h x% / sem y%", em amarelo a partir de avisoUso e vermelho a partir de 95%.
# O Claude Code manda o JSON da sessao pela entrada padrao. Em qualquer falha, escreve uma linha vazia.
try {
    . (Join-Path $PSScriptRoot 'comum.ps1')
    $entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $conta = try { Get-ContaAtual } catch { $null }
    $aviso = try { (Get-Contas).AvisoUso } catch { 80 }
    [Console]::Out.Write((Format-StatusLine $entrada $conta $aviso))
} catch {
    [Console]::Out.Write('')
}
