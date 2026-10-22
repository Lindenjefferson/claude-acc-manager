# claude-multiplas-contas

Plugin privado do Claude Code com a skill `multiplas-contas`. No Windows, ela permite:

- alternar entre várias contas com `cc <conta>` sem relogar. Cada conta tem só o login separado; settings, histórico, memória, skills e plugins são compartilhados;
- abrir o Claude na pasta atual digitando `cc` (ou `cc <conta>`) na barra de endereço do Explorer.

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
  - `abrir-conta.ps1`: abre uma janela de outra conta.
  - `explorer/`: o atalho da barra do Explorer.
  - `modelo-CLAUDE.md`: modelo do bloco de regras do `~/.claude/CLAUDE.md`.
  - `contas.exemplo.json`: exemplo de configuração.

O `contas.json` com as contas reais fica só em cada PC, em `~/.claude-contas`, e nunca vai para o repositório.
