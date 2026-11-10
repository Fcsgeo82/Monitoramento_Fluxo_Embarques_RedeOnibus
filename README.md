# 🚍 Monitoramento de Fluxo de Embarques — Rede de Ônibus (SMTR/RJ)

Este projeto automatiza o pipeline de análise de dados de embarques de ônibus da rede SMTR/RJ, transformando dados brutos do BigQuery em relatórios diários enviados via bot do Telegram e disponibilizando um painel Shiny interativo para análise espacial e temporal por linha.

## 📋 Visão Geral

O pipeline realiza a extração de dados georreferenciados (bilhetagem JAE, RioCard, GPS Ônibus e viagens inferidas/válidas), calcula indicadores de desempenho (KPIs) e gera um relatório tabular detalhado por linha e rota, entregando tudo de forma automática para os tomadores de decisão, além de permitir inspeção detalhada no dashboard Shiny.

### 🚀 Fluxo de Trabalho

1.  **Extração:**
    *   **Rede completa:** O script `1. Dados_embarques_GPS.R` consulta o BigQuery para toda a rede e consolida os dados em um arquivo `.rds`.
    *   **Por linha(s) específica(s):** O script `1.2 Dados_embarques_GPS_Linha.R` permite extrair períodos específicos filtrando apenas uma ou mais linhas (`LINHAS_SELECIONADAS`, nos modos `"exato"` ou `"contem"`).
2.  **Orquestração:** O `run_daily.R` coordena a extração diária e a geração dos artefatos.
3.  **Geração de Relatórios:**
    *   **Texto:** Resumo de KPIs (Total de embarques, Headway médio, etc.) via Telegram.
    *   **PDF:** Relatório tabular completo com métricas por linha, sentido e faixas horárias.
4.  **Distribuição:** O `telegram_sender.R` utiliza a API do Telegram para enviar os artefatos para o grupo operacional.
5.  **Monitoramento:** O script `monitor_clock.R` garante a execução diária sem necessidade de privilégios de administrador.
6.  **Exploração Visual (Shiny):** O script `2.1. Mapa_fluxo_embarques_v2.R` carrega arquivos `.rds` e `.zip` (GTFS) de até 5 GB para análise espacial de embarques, desvios de rota (incluindo variantes de itinerário e excepcionalidades), animação temporal hora a hora e regularidade (headway).

## 📂 Estrutura do Projeto

### Pasta Raiz
*   `1. Dados_embarques_GPS.R`: Script principal de extração de dados da rede completa (BigQuery).
*   `1.2 Dados_embarques_GPS_Linha.R`: Script de extração filtrada por linha(s) selecionada(s), otimizado para consultar GPS e bilhetagem apenas dos veículos que operaram as linhas no período.
*   `2.1. Mapa_fluxo_embarques_v2.R`: Dashboard interativo em Shiny para exploração espacial, animação temporal e análise de regularidade/desvio de rota.
*   `AGENTS.md`: Memória de sessão concisa para agentes de IA.
*   `CHANGELOG.md`: Histórico estruturado de alterações do projeto.

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

## 🗄️ Fontes de Dados (BigQuery)

| Tabela | Descrição | Uso |
|--------|-----------|-----|
| `rj-smtr.br_rj_riodejaneiro_bilhetagem.transacao` | Bilhetagem JAE | Scripts `1` e `1.2` |
| `rj-smtr.bilhetagem.transacao_riocard` | Bilhetagem RioCard | Scripts `1` e `1.2` |
| `rj-smtr.monitoramento.gps_validador` | Mapeamento validador ↔ veículo | Scripts `1` e `1.2` |
| `rj-smtr.monitoramento.gps_onibus_sppo` | GPS dos ônibus SPPO | Script `1` (rede completa) |
| `rj-smtr.monitoramento.view_gps_sppo_completo` | View consolidada de GPS SPPO | Script `1.2` (por linha) |
| `rj-smtr.monitoramento_interno.viagem_inferida` | Viagens inferidas da rede | Script `1` (rede completa) |
| `rj-smtr.monitoramento_interno.viagem_valida` | Viagens válidas monitoradas | Script `1.2` (por linha) |

## 🛠️ Requisitos e Instalação

### Dependências de Software
*   R (versão 4.6.1 ou superior)
*   Google Cloud SDK (para autenticação ADC ou Service Account JSON)
*   Chromium/Chrome (necessário para renderização de PDFs via `webshot2`)

### Configuração de Autenticação (Google Cloud)
Execute o comando abaixo para gerar suas credenciais locais (ADC):

```powershell
gcloud auth application-default login
```
Isso abrirá seu navegador para realizar o login e salvará o arquivo de credenciais automaticamente no seu sistema.

### Pacotes R Principais
```r
install.packages(c(
  "tidyverse", "data.table", "httr2", "gt", "glue", "webshot2",
  "bigrquery", "googlesheets4", "sf", "h3jsr", "shiny",
  "leaflet", "leaflet.extras", "tidytransit", "DT"
))
# O pacote basedosdados deve ser instalado via GitHub
remotes::install_github("basedosdados/basedosdados-r")
```

## ⚙️ Configuração

1.  **Credenciais do Google:** Autentique via `gcloud auth application-default login` ou configure o caminho do JSON da Service Account quando aplicável.
2.  **Credenciais do Telegram:** Configure as variáveis de ambiente `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID` no Windows (escopo de Usuário) ou via `.Renviron`.
3.  **Configurações Locais:** Ajuste os caminhos e parâmetros no arquivo `automacao_telegram/config.R`.

## 📅 Automação e Agendamento

Existem duas formas de garantir a execução diária:

1.  **Via Monitor (Sem Admin):** Execute o arquivo `automacao_telegram/iniciar_monitor.bat`. Ele abrirá uma janela que deve permanecer aberta (pode ser minimizada) monitorando o horário definido em `monitor_clock.R`.
2.  **Via Task Scheduler (Requer Admin):** Configure o Agendador de Tarefas do Windows para rodar o `Rscript.exe` apontando para o `run_daily.R`, conforme instruções em `automacao_telegram/SETUP_SCHEDULER_WIN.md`.

---
*Projeto desenvolvido para monitoramento operacional de transporte público.*
