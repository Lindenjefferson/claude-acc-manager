# Uso e Remote Control por conta: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Objetivo:** fazer o `cc` mostrar e controlar, por conta, o uso (janela de 5 horas e semanal) e o Remote Control por padrão, com aviso de uso alto ao abrir e na status line.

**Arquitetura:**
- As funções novas ficam em `comum.ps1`. São funções puras, ou funções que recebem caminhos e o horário atual, para dar para testar com Pester.
- `cc.ps1` usa essas funções no `cc -l` e ao abrir uma conta.
- `statusline.ps1`, um script novo, desenha a status line a partir do JSON que o Claude Code manda.
- `instalar.ps1`, `setup-contas.ps1` e `desfazer-contas.ps1` editam `~/.claude/settings.json` como texto, para preservar o restante do arquivo.

**Stack:** Windows PowerShell 5.1 e Pester 3.4.0 (já vem no Windows; use a sintaxe `Should Be` / `Should Throw`, sem `-Be`).

**Spec:** `docs/superpowers/specs/2026-10-22-uso-e-rc-por-conta-design.md`

## Restrições globais

- Os `.ps1` ficam em ASCII puro. Caracteres não ASCII entram via `[char]0x..`, como já é feito em `comum.ps1`. Textos em português, sem acento no código.
- Nunca copiar, mover ou regravar `.credentials.json`. Nunca renovar o token. Nunca imprimir o token nem gravá-lo em arquivo ou log. Ler o arquivo na pasta da própria conta, em memória, é permitido.
- O RC fica desligado salvo se `"rc": true` estiver explícito para a conta, ou se o usuário passar `--rc`. Em qualquer falha, desligado.
- `avisoUso` tem padrão 80. O amarelo começa em `avisoUso`, o vermelho em 95.
- Endpoint de uso: `GET https://api.anthropic.com/api/oauth/usage`, com os headers `Authorization: Bearer <accessToken>` e `anthropic-beta: oauth-2025-04-20`. Timeout de 3 s. Forçar TLS 1.2 no PS 5.1.
- O valor salvo de uso fica em `cachedUsageUtilization` (`fetchedAtMs`, `utilization.five_hour.utilization`/`resets_at`, `utilization.seven_day.*`) no `.claude.json` da conta. Para a conta da pasta mestre, o arquivo é `~/.claude.json`.
- A status line lê `rate_limits.five_hour.used_percentage` e `rate_limits.seven_day.used_percentage`.
- Ao editar `~/.claude/settings.json`: ler em UTF-8 e gravar com `Write-TextoSemBom`. Fazer a edição por texto (regex/inserção), nunca com `ConvertTo-Json` no arquivo inteiro.
- Testes ficam em `tests/` e rodam com `powershell -NoProfile -Command "Invoke-Pester tests -EnableExit"`. Cada arquivo de teste define `$env:USERPROFILE` como uma pasta em `$TestDrive` **antes** de fazer dot-source de `comum.ps1`. Isso isola `$Base` e `$Mestre` do PC real.
- A versão passa para 1.3.0.

## Pontos para revisar

1. **Conta sem pasta, sem login ou sem `.claude.json`:** o `cc -l` mostra `-` na coluna de uso, sem erro. Teste na Tarefa 2.
2. **Rede fora, ou API respondendo 401/429:** o `cc` cai para o valor salvo e abre normalmente. Teste na Tarefa 2.
3. **Valor salvo com `resets_at` no passado:** aquela janela já reiniciou, então conta como 0%. Teste na Tarefa 2.
4. **`settings.json` ausente, com `remoteControlAtStartup: true` ou com `statusLine` de outra pessoa:** não corromper o arquivo e não sobrescrever o que é de outra pessoa. Testes nas Tarefas 3 e 5.
5. **`--rc` com nome (`cc edevize1 --rc minha-sessao`), `--rc` com `-p`, ou `--settings` passado pelo usuário:** o nome chega ao `claude`, o `-p` não pergunta nada, e o `--settings` do usuário não é duplicado. Testes nas Tarefas 3 e 4.

---

### Tarefa 1: campos `rc` e `avisoUso` no `contas.json`

**Arquivos:**
- Modificar: `plugins/multiplas-contas/skills/multiplas-contas/scripts/comum.ps1` (`Get-Contas`)
- Modificar: `plugins/multiplas-contas/skills/multiplas-contas/scripts/contas.exemplo.json` (`"avisoUso": 80` e `"rc": true` na principal)
- Criar: `tests/_contas-falsas.ps1` (helper) e `tests/contas.Tests.ps1`

**Interfaces:**
- Produz: cada item de `(Get-Contas).Contas` ganha `Rc` ([bool], `$true` só se `rc` for exatamente `true` no JSON). `Get-Contas` ganha `AvisoUso` ([int]; 80 se o campo faltar ou não for um número entre 1 e 100).
- Produz: `tests/_contas-falsas.ps1` define `New-AmbienteFalso([string]$raiz, [hashtable]$contasJson)`. A função cria `$raiz\.claude`, `$raiz\.claude-contas\contas.json` (o hashtable convertido para JSON) e `$raiz\.claude.json` (`{}`), aponta `$env:USERPROFILE` para `$raiz` e faz dot-source de `comum.ps1` no escopo de quem chamou. Uso: `. New-AmbienteFalso ...`.

- [ ] **Passo 1: escrever os testes que falham**, em `tests/contas.Tests.ps1`:
  - `rc true so quando explicito`: contas `a` (`rc: true`), `b` (sem `rc`) e `c` (`rc: "true"`). Esperado: `a.Rc` é `$true`, e `b.Rc` e `c.Rc` são `$false`.
  - `avisoUso padrao 80`: sem o campo, `AvisoUso | Should Be 80`. Com `"avisoUso": 70`, deve dar 70. Com `"avisoUso": "x"`, deve dar 80.
- [ ] **Passo 2:** rode `powershell -NoProfile -Command "Invoke-Pester tests -EnableExit"`. Esperado: FALHA (`Rc` e `AvisoUso` não existem).
- [ ] **Passo 3:** implemente os campos em `Get-Contas` e atualize `contas.exemplo.json`.
- [ ] **Passo 4:** rode de novo. Esperado: PASSA.
- [ ] **Passo 5:** commit, com a mensagem `contas.json: campos rc e avisoUso`.

### Tarefa 2: uso de cada conta

**Arquivos:**
- Modificar: `.../scripts/comum.ps1`
- Criar: `tests/uso.Tests.ps1`

**Interfaces:**
- Consome: `Get-Contas` e `Pasta`/`Mestre` de cada conta (Tarefa 1).
- Produz:
  - `Get-ArquivoEstado($conta) -> [string]`: devolve `~/.claude.json` se `Mestre`; senão, `<Pasta>\.claude.json`.
  - `Get-TokenConta($conta, [datetime]$agora) -> [string] | $null`: devolve `claudeAiOauth.accessToken` de `<Pasta>\.credentials.json`, ou `$null` se o arquivo não existir, não abrir ou se `expiresAt` for menor ou igual a `$agora` + 60 s.
  - `Invoke-UsoApi([string]$token, [int]$timeoutSeg = 3) -> objeto`: o JSON da API (com `five_hour` e `seven_day`). Usa `Invoke-RestMethod`.
  - `ConvertTo-Uso($util, [string]$fonte, $quando, [datetime]$agora) -> [pscustomobject]`, com:
    - `Cinco` e `Semana` ([int] ou `$null`);
    - `ResetCinco` e `ResetSemana` ([datetime] local ou `$null`);
    - `Fonte` (`'agora'`, `'salvo'` ou `$null`);
    - `Quando` ([datetime] ou `$null`).
    Uma janela cujo `resets_at` for menor ou igual a `$agora` passa a valer `0`, e o reset dela fica `$null`.
  - `Get-UsoConta($conta, [int]$timeoutSeg = 3, [datetime]$agora = (Get-Date))`: com token, consulta a API (`Fonte 'agora'`). Sem token, ou se a API lançar erro, usa `cachedUsageUtilization` (`Fonte 'salvo'`, `Quando` a partir de `fetchedAtMs`). Sem nenhum dos dois, devolve um objeto com tudo `$null`. Nunca lança erro.
  - `Get-MaxUso($uso) -> [int] | $null`.
  - `Format-Uso($uso) -> [string]`: devolve `5h 2% / sem 27%`. Com `Fonte 'salvo'`, acrescenta ` (salvo HH:mm)`. Sem dados, devolve `-`.
  - `Select-ContaSugerida([hashtable]$usos, [string]$excluir) -> [string] | $null`: devolve o nome com menor `Get-MaxUso`, ignorando `$excluir` e as contas sem dados.

- [ ] **Passo 1: escrever os testes que falham.** O token falso é `'tok-falso'`, e `Invoke-UsoApi`/`Invoke-RestMethod` são substituídos por `Mock`.
  - `usa API quando token valido`: `.credentials.json` com `expiresAt` daqui a 1 h e `Invoke-UsoApi` devolvendo `five_hour.utilization 12` e `seven_day.utilization 40`. Esperado: `Fonte 'agora'`, `Cinco 12`, `Semana 40`.
  - `cai para o salvo quando token vencido`: `expiresAt` há 1 h e `cachedUsageUtilization` com 2 e 27. Esperado: `Fonte 'salvo'`, `Cinco 2`, `Semana 27`, e `Invoke-UsoApi` chamado 0 vezes (`Assert-MockCalled -Times 0`).
  - `cai para o salvo quando API falha`: o mock lança `throw '401'`. Esperado: `Fonte 'salvo'`.
  - `conta sem pasta nem login`: esperado `Fonte $null`, `Format-Uso` igual a `-`, e nenhum erro.
  - `janela reiniciada vira zero`: `resets_at` da janela de 5h há 10 minutos, com utilização 90. Esperado: `Cinco 0`.
  - `conta mestre le ~/.claude.json`: `Get-ArquivoEstado` da conta com `Mestre` devolve `$env:USERPROFILE\.claude.json`.
  - `format e max`: com 2 e 27 e fonte `agora`, `Format-Uso` devolve `5h 2% / sem 27%` e `Get-MaxUso` devolve 27.
  - `sugere a de menor maximo`: com `a` = 90/10, `b` = 30/50, `c` = sem dados e excluindo `a`, o resultado é `b`.
  - `token nunca aparece`: `Format-Uso` e as propriedades do objeto devolvido não contêm `tok-falso`.
- [ ] **Passo 2:** rode os testes. Esperado: FALHA.
- [ ] **Passo 3:** implemente as funções. Em `Invoke-UsoApi`, defina `[Net.ServicePointManager]::SecurityProtocol` com TLS 1.2 antes da chamada.
- [ ] **Passo 4:** rode os testes. Esperado: PASSA.
- [ ] **Passo 5:** faça uma checagem real, sem imprimir o token: `powershell -NoProfile -Command ". ./plugins/multiplas-contas/skills/multiplas-contas/scripts/comum.ps1; (Get-Contas).Contas | % { '{0}: {1}' -f $_.Nome, (Format-Uso (Get-UsoConta $_)) }"`. Esperado: uma linha por conta, sem erro. As contas não logadas mostram `-`.
- [ ] **Passo 6:** commit, com a mensagem `Uso por conta (API ou valor salvo)`.

### Tarefa 3: decisão do RC e `settings.json` compartilhado

**Arquivos:**
- Modificar: `.../scripts/comum.ps1`
- Criar: `tests/rc.Tests.ps1`

**Interfaces:**
- Consome: `Rc` da conta (Tarefa 1).
- Produz:
  - `Split-ArgsRc($conta, [object[]]$argumentos) -> [pscustomobject]`, com:
    - `Ligado` ([bool]): o último entre `--rc`/`--no-rc` vence; sem nenhum dos dois, vale `$conta.Rc`;
    - `Resto` ([object[]]): os argumentos sem `--no-rc`. O `--rc` e um nome logo depois dele **ficam**, para o `claude` receber `--rc [nome]`;
    - `SettingsDoUsuario` ([bool]): `$true` se `Resto` tiver `--settings`.
  - `Get-ArquivoRc([bool]$ligado) -> [string]`: devolve `$Base\rc\ligado.json` ou `$Base\rc\desligado.json`. Cria o arquivo se faltar, com `{"remoteControlAtStartup": true}` ou `false`.
  - `Set-RcDesligadoCompartilhado -> [string] | $null`: em `$Mestre\settings.json`, troca `"remoteControlAtStartup": true` por `false`, ou insere `"remoteControlAtStartup": false,` logo depois do primeiro `{`, se a chave não existir. Se o arquivo não existir, cria `{ "remoteControlAtStartup": false }`. Devolve uma mensagem se mudou algo; `$null` se já estava `false`.

- [ ] **Passo 1: escrever os testes que falham.**
  - `padrao da conta`: com `Rc $true` e sem flags, `Ligado` é `$true`; com `Rc $false`, é `$false`.
  - `--rc liga e fica nos args`: `edevize1` (`Rc $false`) com `@('--rc','minha-sessao')` dá `Ligado $true`, e `Resto` é igual a `@('--rc','minha-sessao')`.
  - `--no-rc desliga e sai dos args`: pessoal com `@('--no-rc','-p','oi')` dá `Ligado $false` e `Resto` `@('-p','oi')`.
  - `settings do usuario detectado`: `@('--settings','x.json')` dá `SettingsDoUsuario $true`.
  - `arquivos rc`: `Get-Content (Get-ArquivoRc $false) -Raw | ConvertFrom-Json` resulta em `remoteControlAtStartup` igual a `$false`.
  - `compartilhado: true vira false`: um `settings.json` com `"theme": "dark"` e `"remoteControlAtStartup": true` fica com `false`, mantém `"theme": "dark"` e continua sendo um JSON válido (`ConvertFrom-Json` sem erro).
  - `compartilhado: insere quando falta`: `{"theme":"dark"}` passa a ter `remoteControlAtStartup` igual a `$false` e mantém o tema.
  - `compartilhado: ja false nao mexe`: devolve `$null`, e o `LastWriteTime` do arquivo não muda.
  - `compartilhado: arquivo ausente`: o arquivo é criado e é um JSON válido.
- [ ] **Passo 2:** rode os testes. Esperado: FALHA.
- [ ] **Passo 3:** implemente.
- [ ] **Passo 4:** rode os testes. Esperado: PASSA.
- [ ] **Passo 5:** commit, com a mensagem `Decisao do RC por conta e RC desligado no settings compartilhado`.

### Tarefa 4: `cc.ps1` (lista, RC ao abrir e aviso de uso)

**Arquivos:**
- Modificar: `.../scripts/cc.ps1`
- Criar: `tests/cc.Tests.ps1`

**Interfaces:**
- Consome: `Split-ArgsRc`, `Get-ArquivoRc`, `Get-UsoConta`, `Format-Uso`, `Get-MaxUso`, `Select-ContaSugerida` e `AvisoUso`.
- Produz: `Get-ArgsClaude($decisaoRc) -> [object[]]`, em `comum.ps1`. Devolve `$decisaoRc.Resto` mais `--settings <Get-ArquivoRc $decisaoRc.Ligado>`, a menos que `SettingsDoUsuario` seja verdadeiro. Nesse caso devolve só `Resto`, e o `cc` avisa: `Voce passou --settings: o RC segue o que estiver nele.`

**Comportamento do `cc.ps1`:**
1. Rodar `Split-ArgsRc` antes de identificar a conta, para que `cc --rc` funcione com a conta padrão. A identificação da conta usa o primeiro item de `Resto`.
2. **`cc -l`:** acrescentar as colunas `RC` (`ligado` ou `desligado`, conforme `$c.Rc`) e `Uso` (`Format-Uso`, com o prefixo `! ` quando `Get-MaxUso` for maior ou igual a `AvisoUso`). Na legenda, acrescentar: `RC = Remote Control ao abrir com cc (mude na hora com --rc / --no-rc); ! = uso >= <AvisoUso>%`.
3. **Ao abrir**, depois da checagem de login:
   - Se `Set-RcDesligadoCompartilhado` devolver uma mensagem, mostrá-la em DarkGray.
   - Calcular o uso da conta. Se `Get-MaxUso` for maior ou igual a `AvisoUso`:
     - mostrar em amarelo `Conta <nome> com uso alto: <Format-Uso>`;
     - calcular o uso das demais contas e mostrar `Sugestao: cc <nome> (<Format-Uso>)`, se houver uma sugestão;
     - fora do modo `-p`/`--print`, perguntar `Abrir mesmo assim? (s/N)` e sair se a resposta não for `s`;
     - em `-p`, escrever o aviso em stderr e seguir.
   - Chamar `& $Claude @extra @(Get-ArgsClaude $decisao)`.

- [ ] **Passo 1: escrever os testes que falham** para `Get-ArgsClaude`:
  - `Ligado $true` e `Resto @('-p','oi')` dão `-p oi --settings <...\rc\ligado.json>`.
  - Com `SettingsDoUsuario $true`, não sai um segundo `--settings`.
- [ ] **Passo 2:** rode os testes. Esperado: FALHA.
- [ ] **Passo 3:** implemente `Get-ArgsClaude` e as mudanças no `cc.ps1`.
- [ ] **Passo 4:** rode os testes. Esperado: PASSA.
- [ ] **Passo 5:** verifique a lista. Rode `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/multiplas-contas/skills/multiplas-contas/scripts/cc.ps1 -l` (ela lê o `~/.claude-contas/contas.json` real). Esperado: as colunas RC e Uso aparecem. edevize2 mostra o uso; edevize1 e edevize3 mostram `-`.
- [ ] **Passo 6:** commit, com a mensagem `cc: colunas RC e Uso, --rc/--no-rc e aviso de uso alto`.

### Tarefa 5: status line

**Arquivos:**
- Criar: `.../scripts/statusline.ps1`
- Modificar: `.../scripts/comum.ps1`, `instalar.ps1`, `setup-contas.ps1` e `desfazer-contas.ps1`
- Criar: `tests/statusline.Tests.ps1`

**Interfaces:**
- Consome: `Get-Contas` e `AvisoUso`.
- Produz:
  - `Get-ContaAtual -> conta | $null`: compara o caminho completo de `$env:CLAUDE_CONFIG_DIR` com `Pasta`. Sem a variável, devolve a conta com `Mestre`.
  - `Format-StatusLine($entrada, $conta, [int]$aviso) -> [string]`, a parte testável do script. Devolve `<conta> | 5h 12% / sem 27%`. Cada porcentagem fica em amarelo (`[char]27 + '[33m'`) a partir de `$aviso` e em vermelho (`[char]27 + '[31m'`) a partir de 95, com reset `[char]27 + '[0m'`. Sem `rate_limits`, devolve só o nome da conta. Sem conta, devolve só o uso.
  - `statusline.ps1`: lê `[Console]::In.ReadToEnd()`, faz `ConvertFrom-Json`, chama `Format-StatusLine` e escreve o resultado. Se algo falhar, escreve uma linha vazia, sem stack trace.
  - `Register-StatusLine -> [string] | $null`: se `$Mestre\settings.json` não tiver `"statusLine"`, insere logo depois do primeiro `{` o trecho `"statusLine": {"type": "command", "command": "powershell -NoProfile -ExecutionPolicy Bypass -File <Base com /, por ex. C:/Users/linde/.claude-contas>/statusline.ps1"},`. Se já houver uma status line que contém `statusline.ps1`, não faz nada. Se houver outra status line, não mexe e devolve um aviso.
  - `Unregister-StatusLine`: remove o objeto `statusLine` só se ele contiver `statusline.ps1`, mantendo o JSON válido.
- `setup-contas.ps1` chama `Set-RcDesligadoCompartilhado` e `Register-StatusLine` e imprime as mensagens. `instalar.ps1` já chama o setup. `desfazer-contas.ps1` chama `Unregister-StatusLine` e deixa `remoteControlAtStartup: false` onde está.

- [ ] **Passo 1: escrever os testes que falham.**
  - `cores`: com `aviso` 80, os usos 50, 85 e 96 resultam em sem cor, `[33m` e `[31m`, respectivamente.
  - `texto`: a conta `edevize1` com 12 e 27 resulta em uma saída que, sem os códigos ANSI, é `edevize1 | 5h 12% / sem 27%`.
  - `sem rate_limits`: o resultado é `edevize1`.
  - `conta atual`: com `CLAUDE_CONFIG_DIR` igual à pasta de `b`, o resultado é `b`. Sem a variável, é a conta `Mestre`.
  - `script ponta a ponta`: com `$env:USERPROFILE` falso e `CLAUDE_CONFIG_DIR` definidos, o comando `'{"rate_limits":{"five_hour":{"used_percentage":85},"seven_day":{"used_percentage":10}}}' | powershell -NoProfile -ExecutionPolicy Bypass -File <scripts>\statusline.ps1` mostra uma saída contendo `5h` e `85%`.
  - `register: insere, idempotente, respeita outra`:
    - num `settings.json` sem statusLine, a status line é inserida e o JSON continua válido;
    - uma segunda chamada não muda o arquivo;
    - com `"statusLine": {"type":"command","command":"outra.sh"}`, o arquivo fica intacto e a função devolve um aviso.
  - `unregister`: remove só a nossa status line, mantém o JSON válido e não mexe na outra.
- [ ] **Passo 2:** rode os testes. Esperado: FALHA.
- [ ] **Passo 3:** implemente. `statusline.ps1` faz dot-source de `comum.ps1`.
- [ ] **Passo 4:** rode os testes. Esperado: PASSA.
- [ ] **Passo 5:** meça o tempo. Rode `Measure-Command { '{}' | powershell -NoProfile -ExecutionPolicy Bypass -File <scripts>\statusline.ps1 }` 5 vezes e tire a média.
  - Se a média ficar abaixo de 1 s, siga.
  - Se ficar acima, tente primeiro tirar o dot-source de `comum.ps1`: copie para o script só o necessário para ler `contas.json`. Se ainda passar de 1 s, troque para um `statusline.js` (o node está no PC), mantendo o nome-base `statusline` para o `Register` e o `Unregister`, e anote isso no commit.
- [ ] **Passo 6:** commit, com a mensagem `Status line com conta e uso; registro no settings compartilhado`.

### Tarefa 6: documentação, versão, instalação neste PC e verificação real

**Arquivos:**
- Modificar: `SKILL.md`, `README.md`, `modelo-CLAUDE.md`, `plugins/multiplas-contas/.claude-plugin/plugin.json` (1.3.0) e `.claude-plugin/marketplace.json`, se ele tiver versão
- Fora do repositório: `~/.claude-contas/contas.json` (acrescentar `"rc": true` na `pessoal`, editando o texto e preservando o resto)

- [ ] **Passo 1: documentação.**
  - **SKILL.md, "Como funciona":** RC por conta (`rc` e `--rc`/`--no-rc`), RC desligado no `settings.json` compartilhado, colunas novas do `cc -l`, aviso de uso alto, `avisoUso` e a status line.
  - **SKILL.md, passo 3 da instalação:** perguntar em quais contas o RC deve ligar por padrão.
  - **SKILL.md, Diagnóstico:**
    - "Uso aparece como salvo HH:mm": o token da conta venceu; abrir a conta atualiza.
    - "Outra status line já existe": o instalador não mexe nela.
  - **README:** listar `statusline.ps1`.
  - **`modelo-CLAUDE.md`:** uma linha dizendo que o RC liga por padrão só nas contas com `rc: true`.
- [ ] **Passo 2:** rode todos os testes. Esperado: PASSA.
- [ ] **Passo 3:** instale neste PC. Edite o `contas.json` real e rode `powershell -NoProfile -ExecutionPolicy Bypass -File plugins/multiplas-contas/skills/multiplas-contas/scripts/instalar.ps1`. Esperado:
  - mensagens de RC desligado e de status line registrada;
  - `cc -l` com pessoal `ligado` e as outras contas `desligado`.
- [ ] **Passo 4: verificação real do RC, junto com o usuário.** Abra janelas com `~/.claude-contas/abrir-conta.ps1` e peça ao usuário para conferir se aparece o indicador de Remote Control ativo:
  - (a) `pessoal`: ligado;
  - (b) `edevize2`: desligado;
  - (c) `edevize2 --rc`: ligado. Use `Start-Process cc.cmd -ArgumentList 'edevize2','--rc'`;
  - (d) com `remoteControlAtStartup: true` posto temporariamente à mão no `settings.json` compartilhado, `edevize2` precisa abrir **desligado**. Depois, devolva o valor para `false`.

  Se (d) falhar, implemente o plano B do spec: o `cc` se recusa a abrir uma conta com RC desligado enquanto o `settings.json` compartilhado tiver `true`. Teste e repita (d).
- [ ] **Passo 5:** confira a status line com o usuário: ele deve ver `<conta> | 5h x% / sem y%` numa sessão aberta.
- [ ] **Passo 6:** commit, com a mensagem `multiplas-contas 1.3.0: uso e RC por conta (docs)`.
