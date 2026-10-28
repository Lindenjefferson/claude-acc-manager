# Contas do Claude Code neste PC

Este PC tem uma conta principal do Claude Code e contas secundárias, todas com o mesmo ambiente. Só o login muda de uma para outra.

| Conta | Papel | E-mail | Pasta de config |
|---|---|---|---|
{{TABELA}}

- Abro cada conta com `cc <conta>`, no terminal ou na barra de endereço do Explorer (`{{ATALHO}}` / `{{ATALHO}} <conta>`). Scripts e `contas.json` ficam em `~/.claude-contas`.
- Para saber em qual conta esta sessão está, rode `claude auth status --json` (campo `email`). O nome da sessão, "pasta (conta)", também indica a conta.
- O Remote Control só liga ao abrir pelo `cc`: nas contas com `"rc": true` no `contas.json`, ou com `cc <conta> --rc`. O `settings.json` compartilhado tem `remoteControlAtStartup: false`; não mude isso para `true`, porque ligaria o RC também nas contas em que o usuário não quer.
- `cc -l` mostra o uso de cada conta (5h e semanal) e se o RC liga por padrão nela. A status line mostra a conta e o uso da sessão.

## O que é compartilhado
- Cada conta tem login (`.credentials.json`) e `.claude.json` próprios. Os conectores do claude.ai também são por conta.
- Todo o resto aponta para `~/.claude`: settings.json, history.jsonl, este CLAUDE.md (links) e projects/, skills/, plugins/, sessions/ (junctions).
- Por isso, sessões de contas diferentes se enxergam via ListAgents/SendMessage, e memória e histórico de projetos são os mesmos em todas.
- Claude in Chrome funciona a partir de qualquer conta (usa os logins do próprio Chrome). A extensão está logada na conta {{CHROME}}. Se o usuário disser que trocou, atualize `chrome` no `contas.json` e rode `setup-contas.ps1`.

## Proibições
- **Publicar artefatos** (Artifact, Claude Docs ou qualquer publicação no claude.ai) acontece na conta logada no Claude Code, não na do Chrome:
  - **Sem conta indicada, publique na conta principal, {{PUBLICAR}} ({{EMAIL_PUBLICAR}}).**
  - **Se o usuário indicar outra conta, peça confirmação antes** (AskUserQuestion), mostrando nome e e-mail dela, por exemplo: "Publicar na conta X (email), não na principal?". Só siga com um sim explícito. Nunca escolha outra conta por conta própria.
  - Confira a conta da sessão atual com `claude auth status --json`. Se já for a conta alvo, publique aqui.
  - Se não for, grave o conteúdo num arquivo e procure com ListAgents uma sessão cujo nome termine em "(<conta alvo>)". Se não houver, abra uma com `powershell -NoProfile -ExecutionPolicy Bypass -File ~/.claude-contas/abrir-conta.ps1 <conta alvo> <pasta>` (com `-Rc` ou `-NoRc` para ligar ou desligar o Remote Control nela).
  - Peça por SendMessage que ela confira a própria conta e publique. O usuário aprova na janela dela.
- **Não copiar nem mover `.credentials.json`** entre pastas de conta. Cada conta faz `/login` na própria pasta.
- **Não apagar as pastas `~/.claude-contas/<conta>` com `Remove-Item -Recurse`**: em junctions isso apaga o conteúdo real em `~/.claude`. Para desfazer, use `~/.claude-contas/desfazer-contas.ps1`.
- **Não definir `CLAUDE_CONFIG_DIR` apontando para `~/.claude`**: a conta da pasta mestre roda sem a variável, senão o Claude procura o `.claude.json` no lugar errado.
- Para adicionar, remover ou reinstalar contas, use a skill `gerenciador-contas`.
