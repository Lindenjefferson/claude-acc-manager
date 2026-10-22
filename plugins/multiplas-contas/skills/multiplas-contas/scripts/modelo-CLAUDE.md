# Contas do Claude Code neste PC

Este PC tem uma conta principal do Claude Code e contas secundárias, todas com o mesmo ambiente. Só o login muda de uma para outra.

| Conta | Papel | E-mail | Pasta de config |
|---|---|---|---|
{{TABELA}}

- Abro cada conta com `cc <conta>`, no terminal ou na barra de endereço do Explorer (`{{ATALHO}}` / `{{ATALHO}} <conta>`). Scripts e `contas.json` ficam em `~/.claude-contas`.
- Para saber em qual conta esta sessão está, rode `claude auth status --json` (campo `email`). O nome da sessão, "pasta (conta)", também indica a conta.

## O que é compartilhado
- Cada conta tem login (`.credentials.json`) e `.claude.json` próprios. Os conectores do claude.ai também são por conta.
- Todo o resto aponta para `~/.claude`: settings.json, history.jsonl, este CLAUDE.md (links) e projects/, skills/, plugins/, sessions/ (junctions).
- Por isso, sessões de contas diferentes se enxergam via ListAgents/SendMessage, e memória e histórico de projetos são os mesmos em todas.
- Claude in Chrome funciona em qualquer conta (usa os logins do próprio Chrome).

## Proibições
- **Só publicar artefatos** (Artifact, Claude Docs ou qualquer publicação no claude.ai) **na conta principal, {{PUBLICAR}} ({{EMAIL_PUBLICAR}}).** Nunca nas secundárias.
  - Antes de publicar, confira a conta. Se não for a {{PUBLICAR}}, grave o conteúdo num arquivo e procure com ListAgents uma sessão cujo nome termine em "({{PUBLICAR}})". Se não houver, abra uma com `powershell -NoProfile -ExecutionPolicy Bypass -File ~/.claude-contas/abrir-conta.ps1 {{PUBLICAR}} <pasta>`. Depois peça por SendMessage que ela publique; o usuário aprova na janela dela.
  - A publicação usa a conta logada no Claude Code, não o login do Chrome.
- **Não copiar nem mover `.credentials.json`** entre pastas de conta. Cada conta faz `/login` na própria pasta.
- **Não apagar as pastas `~/.claude-contas/<conta>` com `Remove-Item -Recurse`**: em junctions isso apaga o conteúdo real em `~/.claude`. Para desfazer, use `~/.claude-contas/desfazer-contas.ps1`.
- **Não definir `CLAUDE_CONFIG_DIR` apontando para `~/.claude`**: a conta da pasta mestre roda sem a variável, senão o Claude procura o `.claude.json` no lugar errado.
- Para adicionar, remover ou reinstalar contas, use a skill `multiplas-contas`.
