# ⏰ Monitor de Execução Diária (Vigia do Pipeline)

Este script atua como um "vigia" para o pipeline de automação. Ele roda continuamente em sua sessão de usuário, monitorando o relógio e disparando o processo `run_daily.R` no horário configurado.

## 🚀 Como usar

1.  **Configuração:** Abra o arquivo `monitor_clock.R` e ajuste o `HORARIO_EXECUCAO` e o `CAMINHO_RUN_DAILY`.
2.  **Execução:** No RStudio ou Console, execute: `source("automacao_telegram/monitor_clock.R")`.
3.  **Manutenção:** Mantenha uma janela do R (ou o RStudio) aberta. Você pode minimizá-la, mas não deve fechá-la.

## 🛠️ Funcionalidades

*   **Verificação de Horário:** Checa a cada 60 segundos se o horário atual coincide com o alvo.
*   **Controle de Duplicidade:** Garante que o relatório só seja disparado **uma vez por dia**, registrando a data da última execução bem-sucedida.
*   **Notificação de Erros:** Se o processo de monitoramento falhar, ele tentará avisar via Telegram.
*   **Logs de Console:** Exibe no terminal o status atual (esperando, executando ou erro).

## 📂 Arquivos Relacionados

*   `automacao_telegram/run_daily.R`: O script que será disparado pelo monitor.
*   `automacao_telegram/config.R`: Onde as credenciais do Telegram residem.

