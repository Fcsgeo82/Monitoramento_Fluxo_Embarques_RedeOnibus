# Plano de Implementação — Relatório Diário de Embarques via Telegram Bot

**Projeto:** Monitoramento de Fluxo de Embarques — Rede de Ônibus (SMTR/RJ)  
**Objetivo:** Automatizar a geração e envio diário de um relatório estático de KPIs, visualizações e relatório tabular em PDF (rede completa) para um canal/grupo do Telegram, orquestrado por um bot.  
**Data de criação:** 14/07/2026  
**Última atualização:** 14/07/2026 — adicionada Etapa 2B: relatório PDF tabular da rede  

---

## Visão Geral da Arquitetura

```
[Task Scheduler — 06:00 diário]
        │
        ▼
 run_daily.R  (orquestrador)
        │
        ├─► [Script 1 — Extração BigQuery]
        │       └─► base_embarques_final_YYYY-MM-DD.rds
        │
        ├─► [relatorio_estatico.R — Geração de outputs visuais]
        │       ├─► output/grafico_demanda.png
        │       ├─► output/grafico_headway.png
        │       ├─► output/mapa_embarques.png
        │       └─► output/mensagem_kpis.txt
        │
        ├─► [relatorio_pdf_rede.R — Relatório tabular PDF da rede]
        │       └─► output/relatorio_rede_YYYY-MM-DD.pdf
        │
        └─► [telegram_sender.R — Envio]
                └─► Telegram Bot API → Canal/Grupo/Chat
```

**Princípio fundamental:** Os scripts originais (`1. Dados_embarques_GPS.R` e `2.1. Mapa_fluxo_embarques_v2.R`) **não serão modificados**. Todo o pipeline de automação vive na pasta `automacao_telegram/`.

---

## Estrutura de Arquivos da Pasta `automacao_telegram/`

```
automacao_telegram/
│
├── PLANO_IMPLEMENTACAO.md       ← este documento
│
├── run_daily.R                  ← ETAPA 5: orquestrador principal
├── relatorio_estatico.R         ← ETAPA 2: geração de plots e KPIs estáticos
├── relatorio_pdf_rede.R         ← ETAPA 2B: relatório tabular PDF da rede completa
├── telegram_sender.R            ← ETAPA 3/4: funções de envio via API
├── config.R                     ← credenciais e parâmetros (não versionar!)
│
└── output/                      ← pasta de saída dos artefatos gerados
    ├── grafico_demanda.png
    ├── grafico_headway.png
    ├── mapa_embarques.png
    ├── mensagem_kpis.txt
    └── relatorio_rede_YYYY-MM-DD.pdf
```

---

## Etapas de Implementação

---

### ETAPA 1 — Adaptar a extração para data automática

**Arquivo:** nenhum novo arquivo — a adaptação é feita via `source()` com parâmetro  
**Status:** ⬜ Pendente

#### Objetivo
O Script 1 original usa datas hardcoded (`data_inicio <- as.Date("2026-02-24")`). Na automação, precisamos que ele sempre processe o dia anterior.

#### Estratégia (sem alterar o Script 1)
No `run_daily.R`, antes de fazer `source()` do Script 1, definimos as variáveis de data no ambiente global. O Script 1 usará esses valores pré-existentes caso exista lógica de verificação, **OU** criamos um wrapper que substitui apenas as linhas de data via `readLines()` + `eval(parse(...))`.

Abordagem recomendada — sobrescrever via ambiente antes do source:

```r
# No run_daily.R, antes do source:
data_inicio <- Sys.Date() - 1
data_fim    <- Sys.Date() - 1

# Alternativa mais robusta: copiar o script e substituir as datas
script_original <- readLines(
  "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus/1. Dados_embarques_GPS.R"
)

script_adaptado <- gsub(
  pattern     = 'data_inicio <- as\\.Date\\(".*?"\\)',
  replacement = sprintf('data_inicio <- as.Date("%s")', Sys.Date() - 1),
  x           = script_original
)
script_adaptado <- gsub(
  pattern     = 'data_fim    <- as\\.Date\\(".*?"\\)',
  replacement = sprintf('data_fim    <- as.Date("%s")', Sys.Date() - 1),
  x           = script_adaptado
)

eval(parse(text = script_adaptado))
```

#### Resultado esperado
- `.rds` salvo em `C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados/base_embarques_final_YYYY-MM-DD.rds`

---

### ETAPA 2 — Criar `relatorio_estatico.R` (extração de plots do Shiny)

**Arquivo:** `automacao_telegram/relatorio_estatico.R`  
**Status:** ⬜ Pendente

#### Objetivo
Extrair a lógica de visualização do Script 2 (app Shiny) para um script R puro que gera arquivos estáticos (PNG, texto).

#### Inputs necessários
- `.rds` gerado na Etapa 1
- Arquivo GTFS `.zip` (caminho fixo ou configurável em `config.R`)

#### Outputs gerados
| Arquivo | Conteúdo | Origem no Script 2 |
|---|---|---|
| `grafico_demanda.png` | Volume de embarques por hora do dia | `output$grafico_demanda` |
| `grafico_headway.png` | Regularidade / intervalos entre partidas | `output$grafico_headway` |
| `mapa_embarques.png` | Mapa estático de calor de embarques | `output$mapa` (leaflet) |
| `mensagem_kpis.txt` | Total embarques, headway médio, % fora de rota | `output$kpi_ui` |

#### Dependências de pacotes
```r
library(ggplot2)
library(dplyr)
library(lubridate)
library(leaflet)
library(leaflet.extras)
library(webshot2)      # captura de mapa leaflet → PNG
library(htmlwidgets)
library(tidytransit)
library(sf)
library(glue)
```

#### Notas de implementação
- Os gráficos `grafico_demanda` e `grafico_headway` já são `ggplot` — `ggsave()` direto.
- O mapa leaflet requer `htmlwidgets::saveWidget()` + `webshot2::webshot()` para converter para PNG.
- Definir quais linhas serão analisadas: pode ser uma lista configurável em `config.R` (ex.: top 5 linhas por volume) ou a rede inteira agregada.
- O script deve ser parametrizável para linha e sentido, ou gerar um resumo agregado da rede.

#### Estrutura básica do script
```r
# relatorio_estatico.R
# Lê config, carrega dados, gera PNGs e texto de KPIs

source("automacao_telegram/config.R")

# 1. Carregar dados
dados <- readRDS(caminho_rds_ontem)
gtfs  <- tidytransit::read_gtfs(CAMINHO_GTFS)

# 2. Processar (lógica extraída do Shiny)
dados <- dados |>
  mutate(
    timestamp    = as.POSIXct(horario_embarque),
    hora_inteira = hour(timestamp),
    hora_decimal = hour(timestamp) + minute(timestamp) / 60
  )

# 3. Gráfico de demanda por hora
p_demanda <- dados |>
  group_by(hora_inteira) |>
  summarise(total = n(), .groups = "drop") |>
  ggplot(aes(x = hora_inteira, y = total)) +
  geom_col(fill = "#2980b9") +
  scale_x_continuous(breaks = 0:23) +
  labs(title = glue("Volume de Embarques por Hora — {Sys.Date() - 1}"),
       x = "Hora do Dia", y = "Embarques") +
  theme_minimal()

ggsave("automacao_telegram/output/grafico_demanda.png",
       p_demanda, width = 10, height = 4, dpi = 150)

# 4. Gráfico de headway (agregado rede ou linha configurada)
# ... (lógica de df_viagens extraída do Shiny)

# 5. Mapa estático
mapa <- leaflet(dados) |>
  addProviderTiles("CartoDB.Positron") |>
  setView(lng = -43.3, lat = -22.9, zoom = 11) |>
  addHeatmap(lng = ~longitude, lat = ~latitude, radius = 15)

htmlwidgets::saveWidget(mapa, "automacao_telegram/output/mapa_temp.html", selfcontained = TRUE)
webshot2::webshot("automacao_telegram/output/mapa_temp.html",
                  "automacao_telegram/output/mapa_embarques.png",
                  delay = 2, vwidth = 1200, vheight = 800)

# 6. Texto de KPIs
total_embarques <- nrow(dados)
# headway médio e % fora de rota: calculados aqui
writeLines(
  glue("📅 Data: {Sys.Date() - 1}
🚍 Total de embarques: {format(total_embarques, big.mark='.')}
⏱️ Headway médio: {headway_medio} min
⚠️ % fora de rota: {perc_fora_rota}%"),
  "automacao_telegram/output/mensagem_kpis.txt"
)
```

---

### ETAPA 2B — Criar `relatorio_pdf_rede.R` (relatório tabular PDF da rede completa)

**Arquivo:** `automacao_telegram/relatorio_pdf_rede.R`  
**Status:** ⬜ Pendente

#### Objetivo
Gerar um PDF tabular com uma linha por serviço da rede, consolidando métricas de demanda e regularidade por **faixas horárias**, para permitir comparação rápida entre linhas e identificação de pontos de atenção operacional.

#### Faixas horárias adotadas

| Código | Faixa | Período |
|--------|-------|---------|
| `madrugada` | Madrugada | 00h – 05h59 |
| `pico_manha` | Pico Manhã | 06h – 08h59 |
| `entrepico` | Entrepico | 09h – 16h59 |
| `pico_tarde` | Pico Tarde | 17h – 19h59 |
| `noturno` | Noturno | 20h – 23h59 |

#### Estrutura da tabela final (uma linha por serviço/sentido)

| Campo | Descrição |
|-------|-----------|
| `linha` | Código do serviço |
| `sentido` | I / V / C |
| `total_embarques` | Total de embarques no dia |
| `emb_madrugada` | Embarques na madrugada |
| `emb_pico_manha` | Embarques no pico manhã |
| `emb_entrepico` | Embarques no entrepico |
| `emb_pico_tarde` | Embarques no pico tarde |
| `emb_noturno` | Embarques no noturno |
| `partidas_total` | Total de viagens observadas no dia |
| `partidas_madrugada` | Viagens observadas na madrugada |
| `partidas_pico_manha` | Viagens observadas no pico manhã |
| `partidas_entrepico` | Viagens observadas no entrepico |
| `partidas_pico_tarde` | Viagens observadas no pico tarde |
| `partidas_noturno` | Viagens observadas no noturno |
| `headway_pico_manha` | Headway médio no pico manhã (min) |
| `headway_entrepico` | Headway médio no entrepico (min) |
| `headway_pico_tarde` | Headway médio no pico tarde (min) |

> **Nota:** Headway não é calculado para madrugada e noturno pela baixa frequência, que tornaria o indicador pouco informativo; pode ser adicionado conforme necessidade.

#### Dependências de pacotes

```r
library(dplyr)
library(lubridate)
library(gt)          # geração da tabela formatada e exportação para PDF
library(glue)
library(scales)      # formatação de números
```

> `gt::gtsave()` exporta para PDF usando o Chromium (via `webshot2`). Alternativa: `knitr` + `tinytex` para PDF LaTeX mais robusto.

#### Lógica de cálculo

```r
# relatorio_pdf_rede.R

source("automacao_telegram/config.R")
library(dplyr); library(lubridate); library(gt); library(glue); library(scales)

data_ref <- Sys.Date() - 1

# ── 1. Carregar dados ─────────────────────────────────────────────────────────
caminho_rds <- glue(
  "C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados/base_embarques_final_{data_ref}.rds"
)
dados <- readRDS(caminho_rds) |>
  mutate(
    hora        = hour(as.POSIXct(horario_embarque)),
    faixa       = case_when(
      hora < 6              ~ "madrugada",
      hora < 9              ~ "pico_manha",
      hora < 17             ~ "entrepico",
      hora < 20             ~ "pico_tarde",
      TRUE                  ~ "noturno"
    )
  )

# ── 2. Embarques por linha/sentido/faixa ──────────────────────────────────────
emb_faixa <- dados |>
  group_by(linha, sentido, faixa) |>
  summarise(embarques = n(), .groups = "drop") |>
  tidyr::pivot_wider(names_from = faixa, values_from = embarques,
                     names_prefix = "emb_", values_fill = 0)

emb_total <- dados |>
  group_by(linha, sentido) |>
  summarise(total_embarques = n(), .groups = "drop")

# ── 3. Viagens e headway por linha/sentido/faixa ──────────────────────────────
viagens <- dados |>
  group_by(linha, sentido, id_viagem) |>
  summarise(
    inicio_viagem = min(as.POSIXct(horario_embarque)),
    faixa_viagem  = first(faixa),
    .groups = "drop"
  ) |>
  arrange(linha, sentido, inicio_viagem) |>
  group_by(linha, sentido) |>
  mutate(headway = as.numeric(difftime(inicio_viagem, lag(inicio_viagem), units = "mins"))) |>
  ungroup()

partidas_faixa <- viagens |>
  group_by(linha, sentido, faixa_viagem) |>
  summarise(partidas = n(), .groups = "drop") |>
  tidyr::pivot_wider(names_from = faixa_viagem, values_from = partidas,
                     names_prefix = "partidas_", values_fill = 0)

partidas_total <- viagens |>
  group_by(linha, sentido) |>
  summarise(partidas_total = n_distinct(id_viagem), .groups = "drop")

headway_faixa <- viagens |>
  filter(faixa_viagem %in% c("pico_manha", "entrepico", "pico_tarde")) |>
  group_by(linha, sentido, faixa_viagem) |>
  summarise(headway_medio = round(mean(headway, na.rm = TRUE), 1), .groups = "drop") |>
  tidyr::pivot_wider(names_from = faixa_viagem, values_from = headway_medio,
                     names_prefix = "headway_")

# ── 4. Consolidar tudo ────────────────────────────────────────────────────────
tabela_rede <- emb_total |>
  left_join(emb_faixa,      by = c("linha", "sentido")) |>
  left_join(partidas_total, by = c("linha", "sentido")) |>
  left_join(partidas_faixa, by = c("linha", "sentido")) |>
  left_join(headway_faixa,  by = c("linha", "sentido")) |>
  arrange(linha, sentido) |>
  # Garantir colunas mesmo que a faixa não exista nos dados
  mutate(across(starts_with("emb_"),      \(x) replace_na(x, 0)),
         across(starts_with("partidas_"), \(x) replace_na(x, 0)))

# ── 5. Formatar e exportar como PDF via gt ────────────────────────────────────
caminho_pdf <- glue("automacao_telegram/output/relatorio_rede_{data_ref}.pdf")

tabela_rede |>
  gt(groupname_col = "sentido") |>
  tab_header(
    title    = md(glue("**Relatório Operacional da Rede de Ônibus**")),
    subtitle = md(glue("Data de referência: **{data_ref}**"))
  ) |>
  tab_spanner(label = "Embarques por Faixa", columns = starts_with("emb_")) |>
  tab_spanner(label = "Partidas por Faixa",  columns = starts_with("partidas_")) |>
  tab_spanner(label = "Headway Médio (min)", columns = starts_with("headway_")) |>
  cols_label(
    linha              = "Linha",
    total_embarques    = "Total",
    emb_madrugada      = "Madrugada\n(00–05h)",
    emb_pico_manha     = "Pico Manhã\n(06–08h)",
    emb_entrepico      = "Entrepico\n(09–16h)",
    emb_pico_tarde     = "Pico Tarde\n(17–19h)",
    emb_noturno        = "Noturno\n(20–23h)",
    partidas_total     = "Total",
    partidas_madrugada = "Madrugada",
    partidas_pico_manha= "Pico Manhã",
    partidas_entrepico = "Entrepico",
    partidas_pico_tarde= "Pico Tarde",
    partidas_noturno   = "Noturno",
    headway_pico_manha = "Pico Manhã",
    headway_entrepico  = "Entrepico",
    headway_pico_tarde = "Pico Tarde"
  ) |>
  fmt_number(columns = starts_with("emb_"),      decimals = 0, use_seps = TRUE) |>
  fmt_number(columns = "total_embarques",         decimals = 0, use_seps = TRUE) |>
  fmt_number(columns = starts_with("headway_"),   decimals = 1) |>
  # Destacar células com headway > 30 min (possível irregularidade)
  tab_style(
    style = cell_fill(color = "#fdecea"),
    locations = cells_body(
      columns = starts_with("headway_"),
      rows    = headway_pico_manha > 30 | headway_pico_tarde > 30
    )
  ) |>
  tab_source_note(
    source_note = md(glue("Fonte: SMTR/RJ — Bilhetagem eletrônica + GPS SPPO. Gerado automaticamente em {Sys.time()}"))
  ) |>
  opt_table_font(font = google_font("IBM Plex Sans")) |>
  opt_row_striping() |>
  gtsave(caminho_pdf)

message(glue("✅ PDF gerado: {caminho_pdf}"))
```

#### Considerações de implementação

- **Colunas ausentes:** Se uma faixa não tiver registros para uma linha específica, `replace_na(..., 0)` garante que a coluna exista com zero, evitando erros na tabela gt.
- **Headway na madrugada/noturno:** Omitidos da tabela por padrão. Podem ser adicionados em `config.R` como parâmetro `FAIXAS_HEADWAY`.
- **Volume do PDF:** Redes grandes (centenas de linhas) podem gerar PDFs de múltiplas páginas — `gt` pagina automaticamente. Caso o tamanho do arquivo ultrapasse o limite do Telegram (50 MB), comprimir ou filtrar apenas as linhas com movimento.
- **Fonte da coluna `partidas`:** Deriva das viagens observadas nos dados de bilhetagem + GPS, não do planejado. Isso reflete apenas viagens com pelo menos um embarque registrado.
- **Alternativa sem Chromium:** Substituir `gtsave()` por renderização via `rmarkdown::render()` com `knitr::kable()` + `kableExtra`, usando `tinytex` para PDF LaTeX — mais pesado mas sem dependência de browser.

---

### ETAPA 3 — Criar o Bot no Telegram e obter credenciais

**Arquivo:** `automacao_telegram/config.R`  
**Status:** ⬜ Pendente

#### Passo a passo no Telegram
1. Abrir o Telegram e buscar `@BotFather`
2. Enviar `/newbot`
3. Escolher nome de exibição (ex.: `SMTR Monitor Bot`)
4. Escolher username (ex.: `smtr_monitor_bot`) — deve terminar em `bot`
5. Receber o **TOKEN** (formato: `123456789:AAFxxxxxxxxxxxxxxxx`)

#### Obter o chat_id
1. Adicionar o bot ao grupo/canal ou iniciar conversa direta
2. Enviar qualquer mensagem para o bot
3. Acessar no navegador:
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
4. Localizar o campo `"chat": {"id": XXXXXXXXX}` — esse é o `CHAT_ID`

#### Arquivo `config.R`
```r
# config.R — NÃO versionar este arquivo (adicionar ao .gitignore)

TELEGRAM_TOKEN  <- "SEU_TOKEN_AQUI"
TELEGRAM_CHAT_ID <- "SEU_CHAT_ID_AQUI"

CAMINHO_GTFS    <- "C:/R_SMTR/gtfs/gtfs_atual.zip"   # ajustar conforme necessário

# Linhas prioritárias para o relatório (NULL = rede inteira agregada)
LINHAS_RELATORIO <- NULL  # ou ex.: c("478", "232", "550")
```

> ⚠️ **Segurança:** Adicionar `config.R` ao `.gitignore` para não expor o token.

---

### ETAPA 4 — Criar `telegram_sender.R` (funções de envio)

**Arquivo:** `automacao_telegram/telegram_sender.R`  
**Status:** ⬜ Pendente

#### Dependências
```r
library(httr2)
library(glue)
```

#### Funções a implementar

```r
# telegram_sender.R

library(httr2)
library(glue)

BASE_URL <- function(token) glue("https://api.telegram.org/bot{token}")

# Envia mensagem de texto (suporta Markdown)
telegram_send_text <- function(token, chat_id, texto, parse_mode = "Markdown") {
  request(BASE_URL(token)) |>
    req_url_path_append("sendMessage") |>
    req_body_json(list(
      chat_id    = chat_id,
      text       = texto,
      parse_mode = parse_mode
    )) |>
    req_perform()
}

# Envia imagem PNG com legenda opcional
telegram_send_photo <- function(token, chat_id, caminho_imagem, legenda = "") {
  request(BASE_URL(token)) |>
    req_url_path_append("sendPhoto") |>
    req_body_multipart(
      chat_id = as.character(chat_id),
      caption = legenda,
      photo   = curl::form_file(caminho_imagem)
    ) |>
    req_perform()
}

# Envia documento (PDF, RDS, etc.)
telegram_send_document <- function(token, chat_id, caminho_arquivo, legenda = "") {
  request(BASE_URL(token)) |>
    req_url_path_append("sendDocument") |>
    req_body_multipart(
      chat_id  = as.character(chat_id),
      caption  = legenda,
      document = curl::form_file(caminho_arquivo)
    ) |>
    req_perform()
}

# Wrapper: envia o pacote completo de relatório
enviar_relatorio <- function(token, chat_id, data_ref = Sys.Date() - 1) {
  
  kpis <- readLines("automacao_telegram/output/mensagem_kpis.txt") |> paste(collapse = "\n")
  
  # 1. Mensagem de abertura com KPIs
  telegram_send_text(token, chat_id, kpis)
  
  # 2. Mapa de calor
  telegram_send_photo(token, chat_id,
    "automacao_telegram/output/mapa_embarques.png",
    legenda = glue("🗺️ Mapa de Calor de Embarques — {data_ref}"))
  
  # 3. Volume por hora
  telegram_send_photo(token, chat_id,
    "automacao_telegram/output/grafico_demanda.png",
    legenda = glue("📊 Volume por Hora — {data_ref}"))
  
  # 4. Regularidade
  telegram_send_photo(token, chat_id,
    "automacao_telegram/output/grafico_headway.png",
    legenda = glue("⏱️ Regularidade (Headway) — {data_ref}"))
  
  # 5. Relatório tabular PDF da rede completa
  caminho_pdf <- glue("automacao_telegram/output/relatorio_rede_{data_ref}.pdf")
  if (file.exists(caminho_pdf)) {
    telegram_send_document(token, chat_id,
      caminho_pdf,
      legenda = glue("📋 Relatório Tabular da Rede — {data_ref}"))
  } else {
    warning(glue("PDF não encontrado: {caminho_pdf}"))
  }
  
  message(glue("✅ Relatório de {data_ref} enviado com sucesso ao Telegram."))
}
```

---

### ETAPA 5 — Criar `run_daily.R` (orquestrador)

**Arquivo:** `automacao_telegram/run_daily.R`  
**Status:** ⬜ Pendente

#### Objetivo
Script único que encadeia todas as etapas em sequência, com log e tratamento de erros.

```r
# run_daily.R — Orquestrador do relatório diário de embarques
# Executado automaticamente pelo Windows Task Scheduler

cat("====================================================\n")
cat(sprintf("🚀 Iniciando pipeline — %s\n", Sys.time()))
cat("====================================================\n")

source("automacao_telegram/config.R")
source("automacao_telegram/telegram_sender.R")

data_ref <- Sys.Date() - 1

# ── ETAPA 1: Extração de dados (Script 1 com data dinâmica) ──────────────────
cat("\n📥 [1/3] Extraindo dados do BigQuery...\n")
tryCatch({
  script_original <- readLines(
    "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus/1. Dados_embarques_GPS.R"
  )
  script_adaptado <- gsub(
    'data_inicio <- as\\.Date\\(".*?"\\)',
    sprintf('data_inicio <- as.Date("%s")', data_ref),
    script_original
  )
  script_adaptado <- gsub(
    'data_fim    <- as\\.Date\\(".*?"\\)',
    sprintf('data_fim    <- as.Date("%s")', data_ref),
    script_adaptado
  )
  eval(parse(text = script_adaptado))
  cat(sprintf("✅ Extração concluída: %s registros.\n", nrow(registros_final)))
}, error = function(e) {
  telegram_send_text(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID,
    sprintf("❌ *Falha na extração de dados* (%s):\n`%s`", data_ref, e$message))
  stop(e)
})

# ── ETAPA 2: Geração de relatório estático ───────────────────────────────────
cat("\n📊 [2/3] Gerando visualizações estáticas...\n")
tryCatch({
  source("automacao_telegram/relatorio_estatico.R")
  cat("✅ Visualizações geradas.\n")
}, error = function(e) {
  telegram_send_text(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID,
    sprintf("❌ *Falha na geração do relatório visual* (%s):\n`%s`", data_ref, e$message))
  stop(e)
})

# ── ETAPA 2B: Geração do relatório PDF tabular da rede ───────────────────────
cat("\n📋 [2B/3] Gerando relatório PDF tabular da rede...\n")
tryCatch({
  source("automacao_telegram/relatorio_pdf_rede.R")
  cat("✅ PDF gerado.\n")
}, error = function(e) {
  telegram_send_text(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID,
    sprintf("❌ *Falha na geração do PDF tabular* (%s):\n`%s`", data_ref, e$message))
  stop(e)
})

# ── ETAPA 3: Envio ao Telegram ───────────────────────────────────────────────
cat("\n📨 [3/3] Enviando ao Telegram...\n"))
tryCatch({
  enviar_relatorio(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, data_ref)
  cat("✅ Envio concluído.\n")
}, error = function(e) {
  cat(sprintf("❌ Erro no envio: %s\n", e$message))
  stop(e)
})

cat("\n====================================================\n")
cat(sprintf("🏁 Pipeline finalizado — %s\n", Sys.time()))
cat("====================================================\n")
```

---

### ETAPA 6 — Agendar no Windows Task Scheduler

**Status:** ⬜ Pendente

#### Opção A: via PowerShell (recomendado)

```powershell
$RscriptPath = "C:\Program Files\R\R-4.6.1\bin\Rscript.exe"
$ScriptPath  = "C:\github_repositories\Monitoramento_Fluxo_Embarques_RedeOnibus\automacao_telegram\run_daily.R"

$action  = New-ScheduledTaskAction -Execute $RscriptPath -Argument $ScriptPath
$trigger = New-ScheduledTaskTrigger -Daily -At "06:00AM"
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
  -TaskName "SMTR_RelatorioEmbarques_Diario" `
  -Action   $action `
  -Trigger  $trigger `
  -Settings $settings `
  -RunLevel Highest
```

#### Opção B: via interface gráfica
1. Abrir "Agendador de Tarefas" no Windows
2. Criar Tarefa Básica
3. Gatilho: Diário às 06:00
4. Ação: Iniciar Programa
   - Programa: `"C:\Program Files\R\R-4.6.1\bin\Rscript.exe"`
   - Argumentos: `"C:\github_repositories\...\automacao_telegram\run_daily.R"`

#### Considerações
- O horário de 06:00 garante que os dados do dia anterior já estejam disponíveis no BigQuery.
- Verificar se o usuário do agendador tem acesso à rede e às credenciais de autenticação (`.json` do BigQuery).
- Redirecionar saída para log: adicionar `>> log_YYYY-MM.txt 2>&1` nos argumentos.

---

## Checklist de Implementação

| # | Etapa | Arquivo(s) | Status |
|---|-------|-----------|--------|
| 1 | Data automática no Script 1 | `run_daily.R` | ⬜ |
| 2 | Plots estáticos do Shiny | `relatorio_estatico.R` | ⬜ |
| 2B | Relatório tabular PDF da rede | `relatorio_pdf_rede.R` | ⬜ |
| 3 | Criar bot e obter credenciais | `config.R` | ⬜ |
| 4 | Funções de envio Telegram | `telegram_sender.R` | ⬜ |
| 5 | Orquestrador principal | `run_daily.R` | ⬜ |
| 6 | Agendamento Task Scheduler | — | ⬜ |

---

## Dependências de Pacotes R

```r
# Instalar se necessário:
install.packages(c("httr2", "webshot2", "htmlwidgets", "glue", "curl",
                   "gt", "scales", "tidyr"))

# webshot2 e gt::gtsave() requerem o Chromium/Chrome instalado:
webshot2::install_chromote()  # ou garantir que Chrome está no PATH
```

---

## Segurança e Boas Práticas

- **Nunca versionar `config.R`** — adicionar ao `.gitignore`
- O token do Telegram deve ficar apenas local; considerar variáveis de ambiente do SO como alternativa mais segura:
  ```r
  TELEGRAM_TOKEN   <- Sys.getenv("TELEGRAM_BOT_TOKEN")
  TELEGRAM_CHAT_ID <- Sys.getenv("TELEGRAM_CHAT_ID")
  ```
- Manter logs de execução para diagnóstico de falhas
- Testar cada etapa manualmente antes de ativar o agendamento

---

*Documento gerado em 14/07/2026 — atualizar conforme implementação avançar.*
