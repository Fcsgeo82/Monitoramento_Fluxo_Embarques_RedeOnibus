# Setup do Bot do Telegram

Guia de referência para criação do bot, obtenção de credenciais e configuração das variáveis de ambiente no Windows.

---

## 1. Criar o bot via BotFather

1. Abra o Telegram e busque por **@BotFather**
2. Inicie a conversa e envie `/newbot`
3. Siga as instruções:
   - **Nome de exibição** — ex.: `SMTR Monitor Operacional`
   - **Username** — deve terminar em `bot`, ex.: `smtr_monitor_bot`
4. Ao finalizar, o BotFather retorna o **token** no formato:
   ```
   123456789:AAFxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ```
   Guarde este token — ele não é recuperável sem o BotFather.

---

## 2. Obter o `chat_id` do destinatário

O `chat_id` identifica para onde o bot deve enviar as mensagens. O procedimento varia conforme o destino.

### Conversa direta (usuário individual)

1. Encontre seu bot no Telegram pelo username e envie qualquer mensagem (ex.: `/start`)
2. Acesse no navegador, substituindo `<TOKEN>` pelo token do bot:
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
3. Localize o campo `"chat": { "id": XXXXXXXXX }` — este é o `chat_id`

### Grupo ou canal

1. Adicione o bot ao grupo/canal com permissão de envio de mensagens
2. Envie qualquer mensagem no grupo
3. Acesse a URL de `getUpdates` acima
4. O `chat_id` de grupos é negativo (ex.: `-1001234567890`)

> **Dica:** Se `getUpdates` retornar lista vazia, aguarde 1 minuto e tente novamente após enviar uma nova mensagem no chat.

---

## 3. Configurar variáveis de ambiente no Windows

As credenciais são armazenadas como variáveis de ambiente do usuário para não ficarem expostas nos scripts. O escopo `"User"` persiste entre sessões sem necessitar de privilégios de administrador.

### Executar no PowerShell

```powershell
[System.Environment]::SetEnvironmentVariable("TELEGRAM_BOT_TOKEN", "<TOKEN>", "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_CHAT_ID",   "<CHAT_ID>", "User")
```

Substituir `<TOKEN>` e `<CHAT_ID>` pelos valores reais obtidos nas etapas anteriores.

### Verificar se foram gravadas

```powershell
[System.Environment]::GetEnvironmentVariable("TELEGRAM_BOT_TOKEN", "User")
[System.Environment]::GetEnvironmentVariable("TELEGRAM_CHAT_ID",   "User")
```

Ambas devem retornar os valores configurados.

> ⚠️ **Importante:** Variáveis de ambiente definidas via PowerShell **não ficam disponíveis imediatamente** na sessão R que já estava aberta. É necessário **reiniciar o RStudio** (ou a sessão R) para que `Sys.getenv()` as enxergue.

---

## 4. Verificar configuração no R

Após reiniciar a sessão R, execute:

```r
source("automacao_telegram/config.R")

cat("Token:", substr(TELEGRAM_TOKEN, 1, 10), "...\n")   # exibe apenas os primeiros caracteres
cat("Chat ID:", TELEGRAM_CHAT_ID, "\n")
```

Os valores devem ser lidos corretamente sem estar hardcoded no script.

---

## 5. Testar o envio

Teste de fumaça — enviar uma mensagem simples antes de executar o pipeline completo:

```r
source("automacao_telegram/config.R")
source("automacao_telegram/telegram_sender.R")

telegram_send_text(
  token   = TELEGRAM_TOKEN,
  chat_id = TELEGRAM_CHAT_ID,
  texto   = "✅ Conexão estabelecida. Bot do SMTR Monitor operacional."
)
```

Se a mensagem chegar ao chat/grupo, a configuração está correta e o pipeline pode ser executado.

---

## 6. Alterar ou revogar credenciais

### Atualizar um valor

Executar novamente o mesmo comando da Etapa 3 com o novo valor — a variável é sobrescrita.

### Remover uma variável

```powershell
[System.Environment]::SetEnvironmentVariable("TELEGRAM_BOT_TOKEN", $null, "User")
[System.Environment]::SetEnvironmentVariable("TELEGRAM_CHAT_ID",   $null, "User")
```

### Revogar o token do bot

Falar com o **@BotFather** → `/mybots` → selecionar o bot → **API Token** → **Revoke current token**.  
Após revogar, atualizar a variável de ambiente com o novo token (Etapas 3 e 4).

---

## Referências rápidas

| Item | Onde encontrar |
|------|---------------|
| Token do bot | Retornado pelo @BotFather ao criar o bot |
| chat_id (usuário) | `getUpdates` após mensagem direta ao bot |
| chat_id (grupo) | `getUpdates` após mensagem no grupo com o bot adicionado |
| Variável de ambiente (Windows) | Painel de Controle → Sistema → Variáveis de Ambiente |

---

*Documento criado em 14/07/2026.*
