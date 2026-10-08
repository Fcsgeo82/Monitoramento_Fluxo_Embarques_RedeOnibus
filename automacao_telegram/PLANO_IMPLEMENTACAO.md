# Plano de Implementação — Relatório Diário de Embarques via Telegram Bot

**Projeto:** Monitoramento de Fluxo de Embarques — Rede de Ônibus (SMTR/RJ)  
**Objetivo:** Automatizar a geração e envio diário de um relatório estático de KPIs, visualizações e relatório tabular em PDF (rede completa) para um canal/grupo do Telegram, orquestrado por um bot.  
**Data de criação:** 14/07/2026  
**Última atualização:** 06/08/2026 — Tabelas BigQuery atualizadas, pipeline completo testado e funcionando

---

## Visão Geral da Arquitetura

```
[Task Scheduler / Monitor — 06:00 diário]
        │
        ▼
 run_daily.R  (orquestrador)
        │
        ├─► [Script 1 — Extração BigQuery]
        │       └─► base_embarques_final_YYYY-MM-DD.rds
        │
        ├─► [relatorio_pdf_rede.R — Relatório tabular PDF da rede + KPIs]
        │       ├─► output/mensagem_kpis_bloco1.txt (Resumo Executivo)
        │       ├─► output/mensagem_kpis_bloco2.txt (Detalhamento Operacional)
        │       └─► output/relatorio_rede_YYYY-MM-DD.pdf
        │
        └─► [telegram_sender.R — Envio]
                └─► Telegram Bot API → Grupo Operacional
```

**Princípio fundamental:** Os scripts originais (`1. Dados_embarques_GPS.R` e `2.1. Mapa_fluxo_embarques_v2.R`) **não serão modificados** (exceto para atualização de nomes de tabelas/colunas do BigQuery). Todo o pipeline de automação vive na pasta `automacao_telegram/`.

---

## Estrutura de Arquivos da Pasta `automacao_telegram/`

```
automacao_telegram/
│
├── PLANO_IMPLEMENTACAO.md       ← este documento
├── CONTEXTO.md                  ← documentação técnica e estado do projeto
├── README_MONITOR.md            ← guia do monitor de execução
├── SETUP_TELEGRAM.md            ← configuração do bot Telegram
├── SETUP_SCHEDULER_WIN.md       ← configuração do agendador Windows
├── requirements.txt             ← pacotes R necessários
│
├── run_daily.R                  ← ETAPA 5: orquestrador principal ✅ CONCLUÍDO
├── relatorio_pdf_rede.R         ← ETAPA 2B: relatório tabular PDF + KPIs ✅ CONCLUÍDO
├── telegram_sender.R            ← ETAPA 3/4: funções de envio via API ✅ CONCLUÍDO
├── config.R                     ← credenciais e parâmetros (não versionar!) ✅ CONCLUÍDO
├── monitor_clock.R              ← monitor de execução contínua ✅ CONCLUÍDO
├── iniciar_monitor.bat          ← atalho para iniciar monitor ✅ CONCLUÍDO
│
└── output/                      ← pasta de saída dos artefatos gerados
    ├── mensagem_kpis.txt
    ├── mensagem_kpis_bloco1.txt
    ├── mensagem_kpis_bloco2.txt
    └── relatorio_rede_YYYY-MM-DD.pdf
```

---

## Fontes de Dados (BigQuery) — **ATUALIZADO 06/08/2026**

| Finalidade | Tabela Original (Descontinuada) | Tabela Atual | Colunas Principais |
|------------|----------------------------------|--------------|---------------------|
| Bilhetagem JAE | — | `rj-smtr.br_rj_riodejaneiro_bilhetagem.transacao` | `datetime_transacao`, `id_veiculo`, `tipo_transacao` |
| Bilhetagem RioCard | — | `rj-smtr.bilhetagem.transacao_riocard` | `datetime_transacao`, `id_validador` |
| Validador ↔ Veículo | — | `rj-smtr.monitoramento.gps_validador` | `id_validador`, `id_veiculo` |
| **GPS Ônibus** | `rj-smtr.br_rj_riodejaneiro_veiculos.gps_sppo` | `rj-smtr.monitoramento.gps_onibus_sppo` | `id_veiculo`, `servico`, `latitude`, `longitude`, `datetime_gps` |
| **Viagens** | `rj-smtr.projeto_subsidio_sppo.viagem_completa` | `rj-smtr.monitoramento_interno.viagem_inferida` | `servico`, `sentido`, `datetime_partida`, `datetime_chegada`, `id_veiculo`, `id_viagem` |

---

## Etapas de Implementação

---

### ETAPA 1 — Adaptar a extração para data automática

**Arquivo:** nenhum novo arquivo — a adaptação é feita via `source()` com parâmetro  
**Status:** ✅ **CONCLUÍDO** (integrado ao `run_daily.R`)

#### Resultado esperado
- `.rds` salvo em `C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados/base_embarques_final_YYYY-MM-DD.rds`

---

### ETAPA 2 — Criar `relatorio_estatico.R` (extração de plots do Shiny)

**Arquivo:** `automacao_telegram/relatorio_estatico.R`  
**Status:** ⬜ Pendente (opcional - gráficos/mapa)

---

### ETAPA 2B — Criar `relatorio_pdf_rede.R` (relatório tabular PDF da rede completa)

**Arquivo:** `automacao_telegram/relatorio_pdf_rede.R`  
**Status:** ✅ **CONCLUÍDO E TESTADO**

#### Melhorias implementadas além do plano original:
- **2 blocos de KPIs:** Bloco 1 (Resumo Executivo) + Bloco 2 (Detalhamento Operacional)
- **Métricas adicionais:** Headway por consórcio, top 5 linhas, taxa de ocupação, linha sem partida, sparkline de headway, ranking piores linhas
- **Comparativos:** Dia anterior e mesma D.S. anterior
- **Correção `max()/min()` warnings:** Tratamento de casos sem dados válidos
- **Timeout PDF resolvido:** Parâmetro `expand = 10` no `gtsave()`

---

### ETAPA 3 — Criar o Bot no Telegram e obter credenciais

**Arquivo:** `automacao_telegram/config.R`  
**Status:** ✅ **CONCLUÍDO**

---

### ETAPA 4 — Criar `telegram_sender.R` (funções de envio)

**Arquivo:** `automacao_telegram/telegram_sender.R`  
**Status:** ✅ **CONCLUÍDO E TESTADO**

#### Funcionalidades implementadas:
- `telegram_send_text()` — envio de mensagens com Markdown
- `telegram_send_document()` — envio de PDF
- `enviar_relatorio_mvp()` — wrapper que envia: KPIs Bloco 1 + KPIs Bloco 2 + PDF

---

### ETAPA 5 — Criar `run_daily.R` (orquestrador)

**Arquivo:** `automacao_telegram/run_daily.R`  
**Status:** ✅ **CONCLUÍDO E TESTADO (06/08/2026)**

#### Funcionalidades:
- Adaptação dinâmica de datas no Script 1 via regex (`readLines` + `gsub` + `eval(parse())`)
- Remoção de `rm(list=ls())` e `gc()` do Script 1 antes de avaliar
- Tratamento de erros com notificação via Telegram em cada etapa
- Execução completa testada: **2.203.154 embarques processados em ~2min30s**

---

### ETAPA 6 — Agendar no Windows Task Scheduler

**Status:** ⏳ **PRÓXIMO PASSO** (pendente)

---

## Checklist de Implementação

| # | Etapa | Arquivo(s) | Status |
|---|-------|-----------|--------|
| 1 | Data automática no Script 1 | `run_daily.R` | ✅ |
| 2 | Plots estáticos do Shiny | `relatorio_estatico.R` | ⬜ (opcional) |
| 2B | Relatório tabular PDF da rede | `relatorio_pdf_rede.R` | ✅ |
| 3 | Criar bot e obter credenciais | `config.R` | ✅ |
| 4 | Funções de envio Telegram | `telegram_sender.R` | ✅ |
| 5 | Orquestrador principal | `run_daily.R` | ✅ |
| 6 | Agendamento Task Scheduler | — | ⏳ **PRÓXIMO** |

---

## Correções Técnicas Relevantes (06/08/2026)

| Problema | Solução | Arquivo |
|----------|---------|---------|
| `if_else` erro de tipos POSIXct | Substituído por `case_when` + `as.POSIXct()` explícito | `1. Dados_embarques_GPS.R` |
| Timeout `gtsave()` em PDF grande | Adicionado `expand = 10` | `relatorio_pdf_rede.R` |
| Warnings `max()/min()` retorna `-Inf`/`Inf` | Verificação `length(vals) > 0` antes de `max()` | `relatorio_pdf_rede.R` |
| Nomes de colunas BigQuery antigos | Mapeamento: `timestamp_gps`→`datetime_gps`, `servico_informado`→`servico` | `1. Dados_embarques_GPS.R` |

---

## Dependências de Pacotes R

```r
# Instalar se necessário:
install.packages(c("httr2", "webshot2", "htmlwidgets", "glue", "curl",
                   "gt", "scales", "tidyr", "data.table", "lubridate"))

# webshot2 e gt::gtsave() requerem o Chromium/Chrome instalado:
webshot2::install_chromote()  # ou garantir que Chrome está no PATH

# basedosdados via GitHub:
remotes::install_github("basedosdados/basedosdados-r")
```

---

## Segurança e Boas Práticas

- **Nunca versionar `config.R`** — adicionar ao `.gitignore`
- O token do Telegram fica apenas local; configurado via variáveis de ambiente do SO:
  ```r
  TELEGRAM_TOKEN   <- Sys.getenv("TELEGRAM_BOT_TOKEN")
  TELEGRAM_CHAT_ID <- Sys.getenv("TELEGRAM_CHAT_ID")
  ```
- Manter logs de execução para diagnóstico de falhas
- Testar cada etapa manualmente antes de ativar o agendamento

---

*Documento gerado em 14/07/2026 — atualizado em 06/08/2026 com tabelas BigQuery, pipeline testado e correções técnicas.*