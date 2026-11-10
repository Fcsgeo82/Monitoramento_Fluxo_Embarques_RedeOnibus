# Memória de longo prazo — Monitoramento Fluxo Embarques RedeOnibus

Registro de decisões, histórico e contexto detalhado. Complementa o `AGENTS.md`.
Preferência: adicionar entradas no topo, datadas.

---

## 2026-11-05 — Suporte a `.csv` e análise multi-dia (Por Dia e Média Diária) em `2.1. Mapa_fluxo_embarques_v2.R`

- `2.1. Mapa_fluxo_embarques_v2.R` atualizado para aceitar arquivos `.rds` e `.csv` (via `data.table::fread`) no upload de embarques.
- Quando a base contém mais de 1 dia, exibe seletor na barra lateral entre **"📊 Média Diária (Todos os Dias)"** e **"📆 Por Dia Específico"** (com `selectInput` para escolher a data `DD/MM/YYYY`), refletindo o filtro em todas as abas (incluindo Mapa Animado).
- Adicionado card de KPI **"Média Diária (N dias)"** ao lado de "Total Embarques" quando o modo Média Diária está ativo.
- Cálculo de `headway` em `df_viagens` agrupado por `data_dia` para impedir que o intervalo entre a última viagem de um dia e a primeira do dia seguinte contamine o headway médio.
- Gráficos de demanda e headway adaptados para exibir médias diárias por faixa horária no modo multi-dia, e adicionada coluna `Data` na tabela de viagens (`DT`).

## 2026-11-04 — Correção de tipos de data-hora e validação de viagens em `1.2 Dados_embarques_GPS_Linha.R`

- Em `1.2 Dados_embarques_GPS_Linha.R`, quando `viagem_valida` retornava 0 registros para uma data (ou colunas `datetime_partida`/`datetime_chegada` sem classe `POSIXct`), `mutate(datetime_partida_adj = if_else(...))` falhava e disparava 3 retentativas desnecessárias.
- Ajustado para:
  1. Consultar `viagem_valida` primeiro e encerrar o dia sem erro caso não haja viagens na data ou para as linhas selecionadas (evitando consultas desnecessárias de bilhetagem/GPS no BigQuery).
  2. Converter explicitamente `datetime_partida`, `datetime_chegada` e `data_hora` com `as.POSIXct()` e usar `case_when()` no cálculo de `datetime_partida_adj`.
  3. Adicionar `relationship = "many-to-many"` no `left_join` de viagens e `conditionMessage(e)` no log de erro do `tryCatch`.
  4. Corrigir avisos estáticos de diagnóstico R (aba Problems) em `1.2 Dados_embarques_GPS_Linha.R`: substituição de `<<-` por controle de retorno no loop `while`, uso explícito de `.data$`/strings nos verbos `dplyr`, substituição de `.()`/`setorder` por `setorderv`/indexação padrão do `data.table` e passagem explícita de variáveis para `glue()`.
- Em `2.1. Mapa_fluxo_embarques_v2.R`, adicionado `options(shiny.maxRequestSize = 5000 * 1024^2)` (5 GB) para permitir upload de arquivos GTFS (`.zip`) e bases `.rds` maiores que o limite padrão de 5 MB do Shiny, substituído o provedor de mapa base `CartoDB.Positron` (que passou a exigir API Key) por `OpenStreetMap` (`addTiles()`) e `Esri.WorldGrayCanvas` com seletor de camadas, e corrigido o cálculo de `fora_rota` com `st_union(geo)` e seleção por `label_sentido` para evitar erro no `data.table` quando uma linha possui múltiplos `shape_id` no mesmo sentido (ex.: itinerário regular + excepcionalidade).

## 2026-08-27 — Criação do banco de memória

- Criados `AGENTS.md` e `.opencode/memory.md`.
- Pipeline diário de embarques de ônibus da rede SMTR/RJ em R, com envio de relatórios via Telegram.
- Extração via `1. Dados_embarques_GPS.R` (BigQuery) -> `.rds`; `run_daily.R` orquestra; `relatorio_pdf_rede.R` gera PDF (webshot2/Chromium); `telegram_sender.R` envia.
- KPIs: total de embarques, headway médio, etc. por linha e faixa horária.
- Duas formas de agendamento: monitor (`iniciar_monitor.bat` + `monitor_clock.R`, sem admin) ou Task Scheduler do Windows.
- Tabelas BigQuery: transacao (JAE), transacao_riocard, gps_validador, gps_onibus_sppo, viagem_inferida.
- `config_consorcio.csv` e `capacidade_tecnologia.csv` como dados de apoio.
- Autenticação por ADC (navegador); token do Telegram via variáveis de ambiente (secret — não versionar).
