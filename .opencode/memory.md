# Memória de longo prazo — Monitoramento Fluxo Embarques RedeOnibus

Registro de decisões, histórico e contexto detalhado. Complementa o `AGENTS.md`.
Preferência: adicionar entradas no topo, datadas.

---

## 2026-08-27 — Criação do banco de memória

- Criados `AGENTS.md` e `.opencode/memory.md`.
- Pipeline diário de embarques de ônibus da rede SMTR/RJ em R, com envio de relatórios via Telegram.
- Extração via `1. Dados_embarques_GPS.R` (BigQuery) -> `.rds`; `run_daily.R` orquestra; `relatorio_pdf_rede.R` gera PDF (webshot2/Chromium); `telegram_sender.R` envia.
- KPIs: total de embarques, headway médio, etc. por linha e faixa horária.
- Duas formas de agendamento: monitor (`iniciar_monitor.bat` + `monitor_clock.R`, sem admin) ou Task Scheduler do Windows.
- Tabelas BigQuery: transacao (JAE), transacao_riocard, gps_validador, gps_onibus_sppo, viagem_inferida.
- `config_consorcio.csv` e `capacidade_tecnologia.csv` como dados de apoio.
- Autenticação por ADC (navegador); token do Telegram via variáveis de ambiente (secret — não versionar).
