# Uso e Remote Control por conta (design)

Data: 2026-10-22. Plugin `multiplas-contas` (versão atual 1.2.1).

## Por que

O usuário tem uma conta pessoal (principal) e três contas da empresa (edevize1, 2 e 3), todas no mesmo PC, abertas com `cc <conta>`. Ele também usa as contas da empresa para coisas pessoais. Daí vêm duas preocupações:

1. **Privacidade do Remote Control (RC).** Uma sessão com RC ligado numa conta da empresa fica visível para outras pessoas da empresa. Ele quer saber, e controlar, em qual conta o RC liga sozinho.
2. **Não esgotar a cota de uma conta.** Ele quer ver quanto cada conta já usou (os mesmos números do `/usage`: janela de 5 horas e semanal), para alternar entre elas e escolher a que tem mais folga. Também quer ser avisado quando o uso estiver alto, principalmente ao abrir uma conta com `cc`, mas também durante a sessão.

## Metas

- `cc -l` mostra, para cada conta, se o RC liga por padrão e o uso atual (5h e semanal).
- RC por padrão definido por conta: **pessoal ligado, contas da empresa desligado**.
- `cc <conta> --rc` liga o RC só naquela sessão. `cc <conta> --no-rc` desliga só naquela sessão.
- Ao abrir com `cc`, se a conta escolhida estiver com 80% ou mais na janela de 5h ou na semanal, o `cc` avisa antes de abrir: mostra o uso, sugere a conta com mais folga e pergunta "Abrir mesmo assim? (s/N)".
- Durante a sessão, a status line mostra a conta e o uso (5h e semanal), e muda de cor quando passa do limite.

O usuário aprovou todos esses comportamentos, inclusive o limite de 80%.

## Fora do escopo

- Trocar de conta automaticamente.
- Avisos fora do terminal (notificação do Windows, e-mail etc.).
- Histórico ou gráfico de uso.
- Detalhar o limite semanal por modelo (Opus/Sonnet) ou por superfície.

## O que não pode acontecer (anti-metas)

- **Ligar o RC numa conta da empresa sem o usuário pedir.** Na dúvida, desligado: se `rc` não estiver no `contas.json`, se o arquivo estiver ilegível ou se algo falhar ao montar o argumento, o RC fica desligado. Isso vale para todas as contas, exceto quando `rc: true` estiver explícito ou o usuário passar `--rc`.
- **Mexer em credenciais.** Nunca copiar, mover ou regravar `.credentials.json`, nem renovar o token por conta própria. Nunca imprimir o token nem gravá-lo em log ou arquivo temporário. Ler o arquivo na própria pasta da conta, só em memória, é permitido. Essa regra já existe no plugin (SKILL.md, seção "Nunca").
- **Deixar o `cc` lento ou travado.** A consulta de uso não pode bloquear a abertura por muito tempo. Se a rede falhar, o `cc` abre normalmente, sem o aviso ou com o último valor salvo.
- **Sobrescrever uma status line que o usuário já tenha.**

## O que foi verificado (Claude Code 2.1.308)

- **RC por padrão** é a configuração `remoteControlAtStartup` ("Start Remote Control bridge automatically each session"), no `settings.json`. Esse arquivo é **compartilhado** entre todas as contas (link para `~/.claude/settings.json`), então hoje o valor é o mesmo para todas. No momento ela não está definida, ou seja, RC desligado em todas.
- O `claude` aceita `--settings <arquivo-ou-json>` ("additional settings") e `--remote-control [nome]` / `--rc [nome]`.
- **Uso:** o `/usage` chama `GET https://api.anthropic.com/api/oauth/usage` com `Authorization: Bearer <accessToken>` e `anthropic-beta: oauth-2025-04-20`. A resposta tem `five_hour.utilization`, `seven_day.utilization` (porcentagem) e `resets_at`. O Claude Code guarda a última resposta em `cachedUsageUtilization` (com `fetchedAtMs`) no `.claude.json` de cada conta. Para a conta da pasta mestre, o arquivo é `~/.claude.json`; para as outras, `<pasta da conta>/.claude.json`.
- O `.credentials.json` de cada conta tem `claudeAiOauth.accessToken` e `expiresAt` (ms). O token dura poucas horas e é renovado quando o Claude daquela conta roda.
- **Status line:** o JSON que o Claude Code manda para o comando da status line inclui `rate_limits.five_hour.used_percentage` e `rate_limits.seven_day.used_percentage`.

## Como fica

### `contas.json`

Cada conta ganha o campo opcional `rc` (booleano, padrão `false`). Na raiz, `avisoUso` (porcentagem, padrão 80) guarda o limite do aviso.

```json
{
  "principal": "pessoal",
  "avisoUso": 80,
  "contas": {
    "pessoal":  { "email": "lindenjefferson@outlook.com", "rc": true },
    "edevize1": { "email": "tehnicai@edevize.ro" },
    ...
  }
}
```

Atualizar `contas.exemplo.json`, o `contas.json` real do usuário (pessoal com `rc: true`) e o `Get-Contas` em `comum.ps1`.

### RC ao abrir (`cc.ps1`)

- O `cc` consome `--rc` e `--no-rc` (não repassa ao `claude`). A decisão final é: flag da linha de comando, senão `rc` da conta, senão desligado.
- O `cc` sempre passa a decisão de forma explícita, ligado **ou** desligado, para que um `remoteControlAtStartup: true` no `settings.json` compartilhado não ligue o RC numa conta da empresa. O meio sugerido é `--settings` com `{"remoteControlAtStartup": true|false}`.
- No Claude Code, configurações passadas na linha de comando têm precedência sobre o `settings.json` do usuário (só as configurações gerenciadas pela organização ficam acima). Mesmo assim, teste de verdade nos dois sentidos: abrir uma conta e conferir se o RC ligou ou não.
- **Se o teste mostrar que `--settings` não consegue desligar o RC** (minha decisão): o `cc` não abre a conta da empresa enquanto o `settings.json` compartilhado tiver `remoteControlAtStartup: true`. Ele avisa e para. Não criar `settings.json` por conta.
- **Sessões abertas sem o `cc`** (`claude` direto, IDE, app desktop) também não podem ligar o RC sozinhas (decisão do usuário). Hoje elas rodam como edevize2, a conta da pasta mestre, que é da empresa. Por isso, `instalar.ps1` e `setup-contas.ps1` gravam `remoteControlAtStartup: false` no `~/.claude/settings.json` compartilhado, preservando o resto do arquivo. O `cc` sobrepõe esse valor só quando a decisão for ligar. Se encontrarem `true` ali, trocam para `false` e avisam.
- No Windows PowerShell 5.1, passar JSON inline para um executável nativo perde as aspas. Prefira apontar `--settings` para um arquivo pequeno gerado pelo `cc` (por exemplo em `~/.claude-contas/rc/ligado.json` e `desligado.json`).
- Se o usuário já passar `--settings` por conta própria, a decisão de como combinar fica com o builder. Avisar é suficiente.

### Uso de cada conta (função nova em `comum.ps1`)

Uma função `Get-UsoConta $conta` devolve `{ Cinco, Semana, ResetCinco, ResetSemana, Fonte, Quando }`.

1. Se o token no `.credentials.json` da conta ainda não venceu (`expiresAt`), consultar o endpoint com timeout curto (cerca de 3 s). `Fonte = 'agora'`.
2. Se o token venceu, a chamada falhou ou não há login, usar `cachedUsageUtilization` do `.claude.json` da conta. `Fonte = 'salvo'`, `Quando = fetchedAtMs`.
3. Sem nenhum dos dois: valores vazios.

- Consultas em paralelo no `cc -l` são escolha do builder.
- **Limitação aceita:** uma conta que não é aberta há horas terá o token vencido e mostrará o último valor salvo, que pode estar desatualizado. O `cc` mostra quando esse valor foi salvo. Renovar o token pelo próprio código está proibido (anti-metas). Se existir um comando do próprio `claude` que atualize o uso daquela conta sem gastar cota e sem abrir sessão, o builder pode usá-lo, desde que seja rápido.

### `cc -l`

Colunas novas: **RC** (`ligado` ou `desligado`, o padrão da conta) e **Uso**, por exemplo `5h 2% · sem 27%`. Quando o dado for o valor salvo, acrescentar o horário, como `(salvo 14:03)`. Contas com 80% ou mais recebem um marcador visível (por exemplo `!`). A coluna `Logado` continua. Para caber, o builder pode juntar ou encurtar colunas. A legenda no fim explica RC e o marcador.

### Aviso ao abrir

Depois de conferir o login e antes de chamar o `claude`:
- Se o uso da conta escolhida (5h ou semanal) for maior ou igual a `avisoUso`, mostrar o uso em amarelo.
- Sugerir a conta logada com menor `max(5h, semanal)`, por exemplo `Sugestao: cc edevize3 (5h 4% · sem 12%)`. Para isso, consultar o uso das outras contas só nesse caso.
- Perguntar `Abrir mesmo assim? (s/N)`. Com N, sair sem abrir.
- Não perguntar nada com `-p`/`--print` (modo não interativo). Nesse caso, avisar só em stderr.

### Status line (script novo `statusline.ps1`)

- Lê o JSON da entrada padrão e mostra `<conta> · 5h 12% · sem 27%`.
- Cores: normal abaixo de `avisoUso`, amarelo a partir de `avisoUso`, vermelho a partir de 95% (minha escolha).
- A conta sai de `CLAUDE_CONFIG_DIR`, comparada com as pastas do `contas.json`. Sem a variável, é a conta da pasta mestre.
- Sem `rate_limits` no JSON (por exemplo, antes da primeira resposta), mostrar só a conta.
- A status line roda com frequência. O `powershell.exe` demora alguns décimos de segundo para iniciar. O builder deve medir e manter o script mínimo, sem chamar `claude` nem a rede.
- Se o tempo medido passar de 1 s (minha decisão), o builder pode usar outro runtime que já esteja instalado no PC. Nesse caso, o instalador e o desfazer precisam reconhecer a entrada pelo nome do script.
- Registro: `instalar.ps1` grava `statusLine` no `~/.claude/settings.json` só se ainda não houver uma, ou se a existente for a nossa. Se houver outra, não mexer e avisar. `desfazer-contas.ps1` remove a entrada só se for a nossa.

### Restante

- `instalar.ps1` copia o script novo. Os `.ps1` continuam em ASCII (regra do `comum.ps1`).
- Documentar em SKILL.md, README.md e `modelo-CLAUDE.md`: RC por conta, `--rc`/`--no-rc`, colunas novas do `cc -l` e a status line. Depois, rodar `setup-contas.ps1` para atualizar o CLAUDE.md.
- Subir a versão para 1.3.0 em `plugin.json` e `marketplace.json`.

## Decisões deixadas ao builder

- Formato exato das colunas e textos, desde que em português e no estilo dos scripts atuais.
- Paralelismo das consultas e valor exato do timeout.
- Onde ficam os arquivos de `--settings` gerados.
- Como tratar um `--settings` passado pelo usuário.
