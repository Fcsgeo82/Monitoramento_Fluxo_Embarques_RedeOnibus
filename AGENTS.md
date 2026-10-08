# AGENTS.md — Memória de sessão (Monitoramento Fluxo Embarques RedeOnibus)

Arquivo auto-carregado em toda sessão. Mantenha atualizado e conciso.
Para histórico detalhado, ver `.opencode/memory.md`.

## Projeto
Pipeline automatizado de análise de embarques de ônibus da rede SMTR/RJ,
transformando dados brutos do BigQuery em relatórios diários (PDF e KPIs)
enviados via bot do Telegram. Stack: R (data.table, bigrquery, basedosdados,
httr2, gt, webshot2) + Shiny.

## Estrutura
- `1. Dados_embarques_GPS.R`: script principal de extração (BigQuery).
- `2.1. Mapa_fluxo_embarques_v2.R`: dashboard Shiny interativo.
- `automacao_telegram/`: pipeline de automação:
  - `run_daily.R`: orquestrador principal.
  - `relatorio_pdf_rede.R`: gera relatório tabular em PDF.
  - `telegram_sender.R`: comunicação com bot do Telegram.
  - `config.R`: parâmetros e caminhos (não versionar credenciais).
  - `monitor_clock.R`: monitoramento de execução diária (sem admin).
  - `iniciar_monitor.bat`: atalho para iniciar monitoramento.
  - `output/`: relatórios gerados (PDFs, mensagens de KPI).

## Convenções
- Código, docs e comentários em português. Linguagem: R.
- Autenticação BigQuery via ADC (`gcloud auth application-default login`).
- Telegram: variáveis de ambiente `TELEGRAM_BOT_TOKEN` e `TELEGRAM_CHAT_ID` (nunca versionar).
- Fontes de dados: transacao (JAE), transacao_riocard, gps_validador, gps_onibus_sppo, viagem_inferida.

## Memória: como usar
- Sessão começa: ler `AGENTS.md` (já carregado) e, se pedido, `.opencode/memory.md`.
- Ao terminar tarefa relevante: atualizar `AGENTS.md` (estado atual) e `.opencode/memory.md` (histórico) antes de encerrar.
- NUNCA registrar segredos/credenciais nestes arquivos.
