# 📅 Guia de Configuração: Agendador de Tarefas do Windows (Task Scheduler)

Este documento detalha o procedimento para automatizar a execução do pipeline `run_daily.R` utilizando o Agendador de Tarefas do Windows.

## 🚀 Objetivo
Garantir que o relatório diário de embarques seja gerado e enviado ao Telegram automaticamente todos os dias, sem intervenção manual.

---

## 🛠️ Pré-requisitos

Antes de iniciar, certifique-se de que:
1.  **Rscript está no PATH do sistema:** Abra o PowerShell e digite `Rscript --version`. Se retornar a versão, está correto.
    *   *Caso contrário, você precisará usar o caminho completo (ex: `C:\Program Files\R\R-4.6.1\bin\Rscript.exe`).*
2.  **Credenciais de ambiente:** As variáveis de ambiente `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID` (e a do Google Cloud, se aplicável) foram configuradas no escopo de **Usuário** no Windows.
3.  **Caminhos fixos:** O script `run_daily.R` utiliza caminhos absolutos ou baseados no `BASE_DIR` definido no próprio script.

---

## 📝 Passo a Passo para Configuração

### Opção 1: Via PowerShell (Recomendado - Mais rápido e preciso)

Abra o **PowerShell como Administrador** e execute o bloco de comandos abaixo. 

> [!IMPORTANT]
> **Ajuste os caminhos abaixo** antes de colar no terminal para corresponderem à sua instalação do R e à pasta do projeto.

```powershell
# 1. Defina os caminhos (AJUSTE ESTES VALORES)
$RscriptPath = "C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
$ScriptPath  = "C:\github_repositories\Monitoramento_Fluxo_Embarques_RedeOnibus\automacao_telegram\run_daily.R"

# 2. Defina o nome da tarefa
$TaskName = "SMTR_RelatorioEmbarques_Diario"

# 3. Criar a ação (O que o Windows vai fazer)
$action  = New-ScheduledTaskAction -Execute $RscriptPath -Argument $ScriptPath

# 4. Criar o gatilho (Quando vai fazer - Diariamente às 06:00 AM)
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00AM"

# 5. Configurar as definições (Rodar apenas se houver rede, iniciar se falhar)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

# 6. Registrar a tarefa no sistema
Register-ScheduledTask `
  -TaskName $TaskName `
  -Action   $action `
  -Trigger  $trigger `
  -Settings $settings `
  -RunLevel Highest
```

### Opção 2: Via Interface Gráfica (Manual)

1.  Abra o menu Iniciar e digite **"Agendador de Tarefas"** (Task Scheduler).
2.  No painel direito, clique em **"Criar Tarefa..."** (não use "Tarefa Básica").
3.  **Aba Geral:**
    *   **Nome:** `SMTR_RelatorioEmbarques_Diario`
    *   Marque **"Executar com privilégios mais altos"** (Run with highest privileges).
4.  **Aba Gatilhos (Triggers):**
    *   Clique em **"Novo..."**.
    *   Em "Iniciar a tarefa", selecione **"Em um agendamento"**.
    *   Selecione **"Diariamente"** e defina o horário (ex: `06:00:00`).
    *   Clique em OK.
5.  **Aba Ações (Actions):**
    *   Clique em **"Nova..."**.
    *   **Ação:** `Iniciar um programa`.
    *   **Programa/script:** `C:\Program Files\R\R-4.6.1\bin\Rscript.exe` *(verifique seu caminho real)*.
    *   **Adicione argumentos (opcional):** `C:\github_repositories\Monitoramento_Fluxo_Embarques_RedeOnibus\automacao_telegram\run_daily.R` *(verifique seu caminho real)*.
    *   Clique em OK.
6.  **Aba Condições (Conditions):**
    *   Marque **"Só iniciar a tarefa se a seguinte conexão de rede estiver disponível"** e selecione **"Qualquer conexão"**.
7.  **Aba Configurações (Settings):**
    *   Marque **"Executar a tarefa o mais rápido possível após uma inicialização agendada perdida"** (isso ajuda se o computador estiver desligado no horário do gatilho).
8.  Clique em **OK** para salvar.

---

## 🔍 Como Testar

Não espere até amanhã para saber se funcionou!

1.  No Agendador de Tarefas, localize sua tarefa na "Biblioteca do Agendador".
2.  Clique com o botão direito sobre ela e selecione **"Executar"** (Run).
3.  **Verifique o Telegram:** Se o bot enviar o relatório, a configuração está perfeita.
4.  **Verifique os Logs:** Caso não receba nada, verifique a pasta `automacao_telegram/output/` para ver se os arquivos foram gerados ou se há logs de erro no console do R.

## ⚠️ Solução de Problemas Comuns

| Problema | Causa Provável | Solução |
| :--- | :--- | :--- |
| A tarefa roda mas não envia nada | Variáveis de ambiente não carregadas | Certifique-se de que o Token/Chat_ID estão no `.Renviron` ou no sistema para o usuário correto. |
| Erro de "Arquivo não encontrado" | Caminhos relativos no script | Verifique se o `BASE_DIR` no `run_daily.R` aponta para o local correto. |
| O script falha ao acessar o BigQuery | Falha de autenticação (OAuth) | Use uma **Service Account (JSON)** em vez de credenciais de usuário interativas. |
| A tarefa não inicia | O `Rscript.exe` não está no PATH | Use o caminho absoluto completo no campo "Programa/script". |
