# Status line do Claude Code: "<conta> . Sessao (5h): x% (reinicia em 2h05) . Semana: y% (reinicia em 3d 4h)",
# com a porcentagem em amarelo a partir de avisoUso e vermelho a partir de 95%. O Claude Code manda o JSON da sessao pela entrada padrao e le a saida
# em UTF-8 (por isso a troca de encoding: o padrao do PowerShell 5.1 e o codepage OEM).
# Em qualquer falha, escreve uma linha vazia.
try {
    [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
    . (Join-Path $PSScriptRoot 'comum.ps1')
    $entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $conta = try { Get-ContaAtual } catch { $null }
    $aviso = try { (Get-Contas).AvisoUso } catch { 80 }
    [Console]::Out.Write((Format-StatusLine $entrada $conta $aviso))
} catch {
    [Console]::Out.Write('')
}
