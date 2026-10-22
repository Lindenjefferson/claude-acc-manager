# claude-multiplas-contas

Plugin privado do Claude Code com a skill `multiplas-contas`. No Windows, ela permite:

- ter uma conta principal e quantas secundárias quiser, e alternar entre elas com `cc <conta>` sem relogar. Cada conta tem só o login separado; settings, histórico, memória, skills e plugins são compartilhados. Artefatos são publicados na principal, ou em outra conta indicada com confirmação;
- abrir o Claude na pasta atual digitando `cc` (ou `cc <conta>`) na barra de endereço do Explorer;
- ver o uso de cada conta (janela de 5h e semanal) no `cc -l` e na status line, com aviso de uso alto ao abrir;
- escolher em quais contas o Remote Control liga por padrão (`"rc": true`), com `--rc` / `--no-rc` para mudar só naquela sessão.

## Instalar num PC novo

O `gh` precisa estar logado na conta que tem acesso a este repositório, porque ele é privado.

```
/plugin marketplace add Lindenjefferson/claude-multiplas-contas
/plugin install multiplas-contas@linden-privado
```

Depois, numa sessão do Claude Code: **"instala a skill multiplas-contas"**. Ela verifica o PC, pergunta as contas, instala e diz o que falta (um `/login` por conta).

## Conteúdo

- `plugins/multiplas-contas/skills/multiplas-contas/SKILL.md`: roteiro de instalação, manutenção e regras.
- `.../scripts/`: os scripts PowerShell, copiados para `~/.claude-contas` na instalação.
  - `instalar.ps1`, `setup-contas.ps1`, `desfazer-contas.ps1`: instalam, mantêm e desfazem.
  - `cc.ps1` e `bin/cc.cmd`: o comando `cc`.
  - `statusline.ps1`: a status line com conta e uso.
  - `abrir-conta.ps1`: abre uma janela de outra conta.
  - `explorer/`: o atalho da barra do Explorer.
  - `modelo-CLAUDE.md`: modelo do bloco de regras do `~/.claude/CLAUDE.md`.
  - `contas.exemplo.json`: exemplo de configuração.

O `contas.json` com as contas reais fica só em cada PC, em `~/.claude-contas`, e nunca vai para o repositório.
