---
name: multiplas-contas
description: Instala e mantém várias contas do Claude Code no Windows, alternadas com `cc <conta>` sem relogar (CLAUDE_CONFIG_DIR por conta, resto compartilhado com ~/.claude), mais o atalho "cc" na barra de endereço do Explorer. Use para instalar num PC novo, adicionar/remover conta, trocar a conta padrão ou a que publica artefatos, reinstalar depois de atualizar o plugin, desfazer, diagnosticar o `cc`, ou abrir uma sessão de outra conta (ex.: para publicar um artefato).
---

# Múltiplas contas do Claude Code (Windows)

Os scripts ficam na pasta `scripts/` ao lado deste SKILL.md e são instalados em `~/.claude-contas`. Rode-os sempre com `powershell -NoProfile -ExecutionPolicy Bypass -File <script>`: a política de execução padrão do Windows bloqueia .ps1.

## Como funciona (para explicar ao usuário)
- Cada conta tem uma pasta de config própria (`CLAUDE_CONFIG_DIR`) com seu login (`.credentials.json`) e seu `.claude.json`.
- Todo o resto aponta para `~/.claude` (a "pasta mestre"): `settings.json`, `history.jsonl`, `CLAUDE.md`, `keybindings.json` por link de arquivo; `projects/`, `skills/`, `plugins/`, `sessions/` etc. por junction. Assim, histórico, memória, skills, plugins e a lista de sessões são iguais em todas as contas.
- A conta já logada em `~/.claude` usa a própria pasta mestre (`"pasta": "~/.claude"`) e roda **sem** `CLAUDE_CONFIG_DIR`.
- `cc [conta] [args]` abre o Claude na conta (sem conta = padrão), confere o e-mail logado com `claude auth status --json` e nomeia a sessão "pasta (conta)". `cc -l` lista as contas.
- Na barra de endereço do Explorer, o atalho (padrão `cc`) abre o PowerShell na pasta atual com `cc`. O Explorer não repassa a pasta para comandos do App Paths, então `explorer/claude-aqui.ps1` descobre a pasta pela janela do Explorer que está na frente.
- Uma conta nova recebe só as chaves de configuração do `~/.claude.json` (MCPs, projetos confiáveis etc.), nunca os dados da conta. Conectores do claude.ai são por conta e se configuram no site.

## Instalar num PC novo
1. Rode `scripts/instalar.ps1 -Verificar`. Ele mostra o caminho do `claude.exe`, se há symlink (modo desenvolvedor) e conflitos. Se houver PROBLEMA, resolva com o usuário antes de seguir.
2. Rode `claude auth status --json` (sem `CLAUDE_CONFIG_DIR`) para saber qual e-mail já está logado em `~/.claude`.
3. Pergunte ao usuário, de uma vez:
   - nomes curtos e e-mails das contas;
   - qual é a padrão (`cc` sem argumento);
   - qual conta pode publicar artefatos (`publicar`);
   - o atalho do Explorer (padrão `cc`).
   A conta cujo e-mail apareceu no passo 2 recebe `"pasta": "~/.claude"`, porque já está logada lá; explique isso. Não copie `.credentials.json` de uma pasta para outra.
4. Escreva `~/.claude-contas/contas.json` em UTF-8 sem BOM, no formato de `scripts/contas.exemplo.json`.
5. Rode `scripts/instalar.ps1`. Ele faz backup na primeira vez, copia os scripts, cria as pastas e os links, põe `~/.claude-contas/bin` no PATH, registra o atalho do Explorer e escreve o bloco de contas no `~/.claude/CLAUDE.md` (entre marcas `<!-- multiplas-contas:... -->`, preservando o resto do arquivo).
6. Passe ao usuário os próximos passos:
   - abrir um terminal **novo** (o PATH mudou);
   - rodar `cc <conta>` e `/login` uma vez em cada conta não logada;
   - conferir com `cc -l`.

## Manutenção
- **Adicionar conta:** acrescente a conta em `~/.claude-contas/contas.json` e rode `~/.claude-contas/setup-contas.ps1`, que é idempotente e também atualiza o CLAUDE.md. Depois o usuário roda `cc <nova>` e faz `/login`.
- **Trocar padrão, conta de publicar ou atalho:** edite `contas.json` e rode `setup-contas.ps1`. Se mudou o atalho, rode `instalar.ps1`, que registra o novo; apague à mão a chave antiga em `HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\<antigo>.exe`.
- **Remover uma conta:** primeiro tire os links da pasta dela com `. ~/.claude-contas/comum.ps1; Remove-LinksConta ((Get-Contas).Contas | ? Nome -eq '<conta>')`. Confira que não sobrou link na pasta (`Get-ChildItem -Force | ? LinkType`). Só então apague a pasta, tire a conta do `contas.json` e rode `setup-contas.ps1`.
- **Depois de atualizar o plugin:** rode `scripts/instalar.ps1` de novo para copiar os scripts novos. Ele não refaz o backup nem toca no `contas.json`.
- **Desfazer:** `~/.claude-contas/desfazer-contas.ps1` remove links, PATH, atalho e o bloco do CLAUDE.md. Com `-ApagarPastas`, apaga também as pastas das contas extras.

## Publicar artefato a partir de uma conta que não publica
1. Grave o conteúdo num arquivo.
2. Procure com ListAgents uma sessão cujo nome termine em "(<conta de publicar>)".
3. Se não houver, rode `~/.claude-contas/abrir-conta.ps1 <conta de publicar> <pasta>`, que abre uma janela nova, e procure a sessão de novo.
4. Peça por SendMessage que ela confira a conta com `claude auth status --json` e publique o arquivo.
5. O modo automático dela pede a aprovação do usuário na janela dela. Isso é esperado; avise o usuário.
Claude in Chrome não precisa disso: funciona em qualquer conta.

## Nunca
- `Remove-Item -Recurse` (ou apagar pelo Explorer) numa pasta de conta que ainda tem junctions. Isso apaga o conteúdo real de `~/.claude`. Use `Remove-LinksConta` ou `desfazer-contas.ps1`.
- Copiar ou mover `.credentials.json` entre pastas: o token é renovado e a cópia deixa de valer.
- Definir `CLAUDE_CONFIG_DIR` apontando para `~/.claude`: o Claude passaria a procurar `.claude.json` dentro da pasta.
- Usar `$PROFILE` para o `cc`: em PCs com a política de execução padrão, ele não carrega. O `cc` é um `.cmd` no PATH de propósito.

## Diagnóstico
- **Digitar o atalho no Explorer abre uma pasta em vez do Claude:** existe uma pasta com esse nome (o Explorer navega antes de executar). Troque `atalhoExplorer`. `instalar.ps1 -Verificar` procura esses conflitos.
- **"cc não é reconhecido":** o terminal foi aberto antes da instalação. Abra outro.
- **Aviso "logada como X, esperado Y":** o `/login` foi feito com o e-mail errado naquela pasta. Rode `/logout` e `/login` dentro de `cc <conta>`.
- **Mensagem "alteração levada para a mestre":** um programa salvou por cima de um link e o `cc` refez o link. O conteúdo anterior fica em `~/.claude-contas/backups`.
