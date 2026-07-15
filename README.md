# 🚍 Monitoramento de Fluxo de Embarques — Rede de Ônibus (SMTR/RJ)

Este projeto automatiza o pipeline de análise de dados de embarques de ônibus da rede SMTR/RJ, transformando dados brutos do BigQuery em relatórios diários enviados via bot do Telegram.

## 📋 Visão Geral

O pipeline realiza a extração de dados georreferenciados (bilhetagem JAE, RioCard e GPS SPPO), calcula indicadores de desempenho (KPIs) e gera um relatório tabular detalhado por linha e rota, entregando tudo de forma automática para os tomadores de decisão.

### 🚀 Fluxo de Trabalho

1.  **Extração:** O script `1. Dados_embarques_GPS.R` consulta o BigQuery e consolida os dados em um arquivo `.rds`.
2.  **Orquestração:** O `run_daily.R` coordena a extração e a geração dos artefatos.
3.  **Geração de Relatórios:**
    *   **Texto:** Resumo de KPIs (Total de embarques, Headway médio, etc.) via Telegram.
    *   **PDF:** Relatório tabular completo com métricas por linha, sentido e faixas horárias.
4.  **Distribuição:** O `telegram_sender.R` utiliza a API do Telegram para enviar os artefatos para o grupo operacional.
5.  **Monitoramento:** O script `monitor_clock.R` garante a execução diária sem necessidade de privilégios de administrador.

## 📂 Estrutura do Projeto

### Pasta Raiz
*   `1. Dados_embarques_GPS.R`: Script principal de extração de dados (BigQuery).
*   `2.1. Mapa_fluxo_embarques_v2.R`: Dashboard interativo em Shiny para exploração profunda.

### Pasta `automacao_telegram/` (Pipeline de Automação)
*   `run_daily.R`: Orquestrador principal do pipeline.
*   `relatorio_pdf_rede.R`: Gerador do relatório tabular em PDF.
*   `telegram_sender.R`: Módulo de comunicação com o Bot do Telegram.
*   `config.R`: Configurações de parâmetros e caminhos (não versionar credenciais).
*   `monitor_clock.R`: Script de monitoramento contínuo do relógio.
*   `iniciar_monitor.bat`: Atalho para iniciar o monitoramento via prompt de comando.
*   `CONTEXTO.md`: Documentação técnica e estado do projeto.
*   `PLANO_IMPLEMENTACAO.md`: Roadmap de desenvolvimento.
*   `SETUP_TELEGRAM.md`: Guia de configuração do bot.
*   `SETUP_SCHEDULER_WIN.md`: Guia de configuração do agendador Windows.
*   `requirements.txt`: Lista de pacotes R necessários.
*   `output/`: Pasta contendo os relatórios gerados.

## 🛠️ Requisitos e Instalação

### Dependências de Software
*   R (versão 4.6.1 ou superior)
*   Google Cloud SDK (para autenticação via Service Account JSON)
*   Chromium/Chrome (necessário para renderização de PDFs via `webshot2`)

### Configuração de Autenticação (Google Cloud)
Para que a extração de dados funcione corretamente, utilize um arquivo de conta de serviço (Service Account JSON). O caminho deve estar configurado ou ser lido pelo script de extração.

### Pacotes R Principais
```r
install.packages(c("tidyverse", "data.table", "httr2", "gt", "glue", "webshot2", "bigrquery", "glue"))
# O pacote basedosdados deve ser instalado via GitHub
remotes::install_github("basedosdados/basedosdados-r")
```

## ⚙️ Configuração

1.  **Credenciais do Google:** Certifique-se de que o arquivo JSON da Service Account está acessível.
2.  **Credenciais do Telegram:** Configure as variáveis de ambiente `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID` no Windows (escopo de Usuário) ou via `.Renviron`.
3.  **Configurações Locais:** Ajuste os caminhos e parâmetros no arquivo `automacao_telegram/config.R`.

## 📅 Automação e Agendamento

Existem duas formas de garantir a execução diária:

1.  **Via Monitor (Sem Admin):** Execute o arquivo `automacao_telegram/iniciar_monitor.bat`. Ele abrirá uma janela que deve permanecer aberta (pode ser minimizada) monitorando o horário definido em `monitor_clock.R`.
2.  **Via Task Scheduler (Requer Admin):** Configure o Agendador de Tarefas do Windows para rodar o `Rscript.exe` apontando para o `run_daily.R`, conforme instruções em `automacao_telegram/SETUP_SCHEDULER_WIN.md`.

---
*Projeto desenvolvido para monitoramento operacional de transporte público.*
