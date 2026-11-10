# Changelog

Todas as alterações relevantes deste projeto são documentadas neste arquivo.

---

## [2026-11-04 / 2026-11-05] — Extração por Linha (`1.2`) e Melhorias no Dashboard Shiny (`2.1`)

### Adicionado
- **`1.2 Dados_embarques_GPS_Linha.R`**: Script para extração georreferenciada de embarques filtrada por uma ou mais linhas específicas (`LINHAS_SELECIONADAS`), com suporte aos modos `"exato"` e `"contem"`, consultando `rj-smtr.monitoramento_interno.viagem_valida` e `rj-smtr.monitoramento.view_gps_sppo_completo`.
- **`2.1. Mapa_fluxo_embarques_v2.R`**:
  - Suporte a upload de arquivos `.rds` e `.csv` (via `data.table::fread`) no mesmo campo de entrada.
  - Novo controle de **Período de Análise** na barra lateral quando a base possui mais de 1 dia: alternância entre **Média Diária (Todos os Dias)** e **Por Dia Específico** (com seletor da data `DD/MM/YYYY`), aplicado a todas as abas (incluindo Mapa Animado).
  - Novo card de KPI **Média Diária (N dias)** exibido junto ao **Total Embarques** no modo de média diária.
  - Cálculo de headway agrupado por `data_dia` (evitando distorção na virada entre dias), gráfico de demanda por média diária horária, gráfico de headway médio por faixa horária no modo multi-dia e coluna `Data` na tabela de viagens.
  - Aumento do limite máximo de upload (`shiny.maxRequestSize`) para **5 GB** (`5000 * 1024^2`), permitindo carregar pacotes GTFS (`.zip`) e bases `.rds`/`.csv` de múltiplos dias.
  - Seletor de camadas de mapa base gratuitas (`OpenStreetMap` e `Esri.WorldGrayCanvas`), sem necessidade de chave de API.
- **`.gitignore`** e **`CHANGELOG.md`**: Padronização de controle de versão e histórico de mudanças.

### Corrigido
- **`1.2 Dados_embarques_GPS_Linha.R`**:
  - Consulta antecipada de `viagem_valida` com verificação de retorno vazio (`nrow == 0`) antes de consultar tabelas de bilhetagem e GPS no BigQuery, evitando falhas e retentativas desnecessárias em dias sem viagens registradas.
  - Conversão explícita de `datetime_partida`, `datetime_chegada` e `data_hora` com `as.POSIXct()` e substituição de `if_else()` por `case_when()` no cálculo de `datetime_partida_adj`.
  - Adição de `relationship = "many-to-many"` no `left_join` de viagens e uso de `conditionMessage(e)` no `tryCatch`.
  - Resolução de avisos estáticos de diagnóstico R (aba *Problems*): eliminação de `<<-`, qualificação explícita com `.data$` nos verbos `dplyr`, uso de `setorderv()` no `data.table` e passagem nomeada de argumentos no `glue()`.
- **`2.1. Mapa_fluxo_embarques_v2.R`**:
  - Substituição do provedor `CartoDB.Positron` (que passou a bloquear tiles exigindo API Key comercial) por `OpenStreetMap` (`addTiles()`) e `Esri.WorldGrayCanvas`.
  - Correção de erro fatal no `data.table` (`Fornecidos 2*N itens a serem atribuídos a N itens da coluna 'fora_rota'`) quando uma linha possui múltiplos `shape_id` para o mesmo sentido (ex.: itinerário regular e `[excepcionalidade]`), utilizando `st_union(geo)` no cálculo de `st_distance()` e vinculando o seletor de sentido ao `label_sentido` específico.
  - Inclusão de `decimal.mark = ","` junto a `big.mark = "."` nas chamadas de `format()` para eliminar avisos do `prettyNum`.

---

## [2026-08-27] — Estruturação de Memória do Projeto

### Adicionado
- Criação de `AGENTS.md` e `.opencode/memory.md` para registro arquitetural e memória de longo prazo.

---

## [2026-08-06] — MVP da Automação Diária via Telegram

### Adicionado
- Pipeline completo em `automacao_telegram/` (`run_daily.R`, `relatorio_pdf_rede.R`, `telegram_sender.R`, `config.R`, `monitor_clock.R`, `iniciar_monitor.bat`).
- Atualização das tabelas BigQuery em `1. Dados_embarques_GPS.R` para `rj-smtr.monitoramento.gps_onibus_sppo` e `rj-smtr.monitoramento_interno.viagem_inferida`.

