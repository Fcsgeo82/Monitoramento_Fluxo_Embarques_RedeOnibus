# AGENTS.md — Memória de sessão (Monitoramento Fluxo Embarques RedeOnibus)

Arquivo auto-carregado em toda sessão. Mantenha atualizado e conciso.
Para histórico detalhado, ver `.opencode/memory.md` e `CHANGELOG.md`.

## Projeto
Pipeline automatizado de análise de embarques de ônibus da rede SMTR/RJ,
transformando dados brutos do BigQuery em relatórios diários (PDF e KPIs)
enviados via bot do Telegram, além de painel Shiny interativo por linha.
Stack: R (data.table, bigrquery, basedosdados, dplyr, sf, httr2, gt, webshot2) + Shiny/Leaflet.

## Estrutura
- `1. Dados_embarques_GPS.R`: script principal de extração da rede completa (BigQuery).
- `1.2 Dados_embarques_GPS_Linha.R`: extração filtrada por linha(s) específica(s) (`viagem_valida` + `view_gps_sppo_completo`).
- `2.1. Mapa_fluxo_embarques_v2.R`: dashboard Shiny interativo (upload `.rds`/`.csv` até 5 GB, filtro por dia específico ou média diária multi-dia, mapas OpenStreetMap/Esri sem API Key, animação temporal, headway e desvio de rota por variante de itinerário).
- `CHANGELOG.md`: histórico de versões e alterações validadas.
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
- Fontes de dados: `transacao` (JAE), `transacao_riocard`, `gps_validador`, `gps_onibus_sppo` / `view_gps_sppo_completo`, `viagem_inferida` / `viagem_valida`.

## Memória: como usar
- Sessão começa: ler `AGENTS.md` (já carregado) e, se pedido, `.opencode/memory.md`.
- Ao terminar tarefa relevante: atualizar `AGENTS.md` (estado atual), `.opencode/memory.md` (histórico) e `CHANGELOG.md` antes de encerrar.
- NUNCA registrar segredos/credenciais nestes arquivos.
