# =============================================================================
# relatorio_pdf_rede.R
# Gera dois artefatos a partir dos dados de embarques do dia anterior:
#   1. mensagem_kpis.txt  — resumo textual da rede (enviado como mensagem Telegram)
#   2. relatorio_rede_YYYY-MM-DD.pdf — tabela detalhada por linha/sentido/faixa
#
# Requer: config.R já carregado no ambiente (feito pelo run_daily.R)
# Input:  .rds gerado pelo Script 1 (base_embarques_final_YYYY-MM-DD.rds)
# =============================================================================

library(dplyr)
library(lubridate)
library(tidyr)
library(gt)
library(glue)

# -----------------------------------------------------------------------------
# 0. Setup
# -----------------------------------------------------------------------------

# Usa data_ref do ambiente pai se já definida (útil para testes); caso contrário, ontem
if (!exists("data_ref")) data_ref <- Sys.Date() - 1
data_ref_fmt <- format(data_ref, "%d/%m/%Y")

# Garantir que o diretório de output existe
if (!dir.exists(CAMINHO_OUTPUT)) dir.create(CAMINHO_OUTPUT, recursive = TRUE)

caminho_rds <- file.path(
  CAMINHO_RDS_BASE,
  glue("base_embarques_final_{data_ref}.rds")
)

if (!file.exists(caminho_rds)) {
  stop(glue("❌ Arquivo RDS não encontrado: {caminho_rds}"))
}

message(glue("📂 Lendo dados: {caminho_rds}"))
dados_raw <- readRDS(caminho_rds)

# -----------------------------------------------------------------------------
# 1. Preparação base
# -----------------------------------------------------------------------------

dados <- dados_raw |>
  mutate(
    timestamp = as.POSIXct(horario_embarque),
    hora      = hour(timestamp),
    faixa     = case_when(
      hora < FAIXAS_HORARIAS$madrugada[2]  ~ "madrugada",
      hora < FAIXAS_HORARIAS$pico_manha[2] ~ "pico_manha",
      hora < FAIXAS_HORARIAS$entrepico[2]  ~ "entrepico",
      hora < FAIXAS_HORARIAS$pico_tarde[2] ~ "pico_tarde",
      TRUE                                  ~ "noturno"
    ),
    faixa = factor(faixa, levels = names(FAIXAS_HORARIAS))
  )

# Todas as faixas esperadas — garante colunas mesmo sem dados
faixas_todas <- names(FAIXAS_HORARIAS)

# -----------------------------------------------------------------------------
# 2. Métricas de rede (para mensagem_kpis.txt)
# -----------------------------------------------------------------------------

total_emb       <- nrow(dados)
total_linhas    <- n_distinct(dados$linha)
total_partidas  <- n_distinct(dados$id_viagem)

emb_por_faixa_rede <- dados |>
  count(faixa, name = "embarques") |>
  mutate(faixa = as.character(faixa)) |>
  complete(faixa = faixas_todas, fill = list(embarques = 0L))

emb_por_tipo <- dados |>
  count(tipo_usuario, name = "embarques") |>
  arrange(desc(embarques))

fmt_num <- function(x) format(x, big.mark = ".", decimal.mark = ",", scientific = FALSE)

linhas_faixa <- emb_por_faixa_rede |>
  mutate(label = LABELS_FAIXAS[faixa]) |>
  mutate(linha_txt = glue("  • {label}: {fmt_num(embarques)}")) |>
  pull(linha_txt) |>
  paste(collapse = "\n")

linhas_tipo <- emb_por_tipo |>
  mutate(pct = round(embarques / total_emb * 100, 1)) |>
  mutate(linha_txt = glue("  • {tipo_usuario}: {fmt_num(embarques)} ({pct}%)")) |>
  pull(linha_txt) |>
  paste(collapse = "\n")

mensagem_kpis <- glue(
  "📊 *Relatório Operacional da Rede — {data_ref_fmt}*\n",
  "\n",
  "🚍 *Resumo Geral*\n",
  "  • Total de embarques: {fmt_num(total_emb)}\n",
  "  • Linhas em operação: {fmt_num(total_linhas)}\n",
  "  • Partidas observadas: {fmt_num(total_partidas)}\n",
  "\n",
  "👥 *Por tipo de usuário*\n",
  "{linhas_tipo}\n",
  "\n",
  "⏰ *Embarques por faixa horária*\n",
  "{linhas_faixa}"
)

caminho_kpis <- file.path(CAMINHO_OUTPUT, "mensagem_kpis.txt")
writeLines(mensagem_kpis, caminho_kpis)
message(glue("✅ KPIs salvos: {caminho_kpis}"))

# -----------------------------------------------------------------------------
# 3. Tabela por linha/sentido (para PDF)
# -----------------------------------------------------------------------------

# 3a. Embarques totais e por faixa
emb_total <- dados |>
  group_by(linha, sentido) |>
  summarise(total_embarques = n(), .groups = "drop")

emb_faixa <- dados |>
  group_by(linha, sentido, faixa) |>
  summarise(embarques = n(), .groups = "drop") |>
  mutate(faixa = paste0("emb_", faixa)) |>
  pivot_wider(names_from = faixa, values_from = embarques, values_fill = 0L)

# Garantir todas as colunas de embarque
for (col in paste0("emb_", faixas_todas)) {
  if (!col %in% names(emb_faixa)) emb_faixa[[col]] <- 0L
}

# 3b. Viagens e headway
viagens <- dados |>
  group_by(linha, sentido, id_viagem) |>
  summarise(
    inicio_viagem = min(timestamp),
    faixa_viagem  = as.character(first(faixa)),
    .groups       = "drop"
  ) |>
  arrange(linha, sentido, inicio_viagem) |>
  group_by(linha, sentido) |>
  mutate(headway_min = as.numeric(difftime(inicio_viagem, lag(inicio_viagem), units = "mins"))) |>
  ungroup()

partidas_total <- viagens |>
  group_by(linha, sentido) |>
  summarise(partidas_total = n_distinct(id_viagem), .groups = "drop")

partidas_faixa <- viagens |>
  group_by(linha, sentido, faixa_viagem) |>
  summarise(partidas = n(), .groups = "drop") |>
  mutate(faixa_viagem = paste0("partidas_", faixa_viagem)) |>
  pivot_wider(names_from = faixa_viagem, values_from = partidas, values_fill = 0L)

for (col in paste0("partidas_", faixas_todas)) {
  if (!col %in% names(partidas_faixa)) partidas_faixa[[col]] <- 0L
}

headway_faixa <- viagens |>
  filter(faixa_viagem %in% FAIXAS_HEADWAY) |>
  group_by(linha, sentido, faixa_viagem) |>
  summarise(headway_medio = round(mean(headway_min, na.rm = TRUE), 1), .groups = "drop") |>
  mutate(faixa_viagem = paste0("headway_", faixa_viagem)) |>
  pivot_wider(names_from = faixa_viagem, values_from = headway_medio)

for (col in paste0("headway_", FAIXAS_HEADWAY)) {
  if (!col %in% names(headway_faixa)) headway_faixa[[col]] <- NA_real_
}

# 3c. Consolidação na ordem de colunas desejada
tabela_rede <- emb_total |>
  left_join(emb_faixa,      by = c("linha", "sentido")) |>
  left_join(partidas_total, by = c("linha", "sentido")) |>
  left_join(partidas_faixa, by = c("linha", "sentido")) |>
  left_join(headway_faixa,  by = c("linha", "sentido")) |>
  arrange(linha, sentido) |>
  select(
    linha, sentido,
    total_embarques,
    emb_madrugada, emb_pico_manha, emb_entrepico, emb_pico_tarde, emb_noturno,
    partidas_total,
    partidas_madrugada, partidas_pico_manha, partidas_entrepico,
    partidas_pico_tarde, partidas_noturno,
    headway_pico_manha, headway_entrepico, headway_pico_tarde
  )

# -----------------------------------------------------------------------------
# 4. Gerar PDF com gt
# -----------------------------------------------------------------------------

caminho_pdf <- file.path(CAMINHO_OUTPUT, glue("relatorio_rede_{data_ref}.pdf"))

tabela_gt <- tabela_rede |>
  gt(groupname_col = "sentido") |>

  # Cabeçalho
  tab_header(
    title    = md("**Relatório Operacional da Rede de Ônibus**"),
    subtitle = md(glue("Data de referência: **{data_ref_fmt}** &nbsp;|&nbsp; ",
                       "Total: **{fmt_num(total_emb)}** embarques &nbsp;|&nbsp; ",
                       "**{fmt_num(total_linhas)}** linhas &nbsp;|&nbsp; ",
                       "**{fmt_num(total_partidas)}** partidas"))
  ) |>

  # Spanners de grupo de colunas
  tab_spanner(
    label   = md("**Embarques por Faixa Horária**"),
    columns = starts_with("emb_")
  ) |>
  tab_spanner(
    label   = md("**Partidas Observadas por Faixa**"),
    columns = starts_with("partidas_")
  ) |>
  tab_spanner(
    label   = md("**Headway Médio (min)**"),
    columns = starts_with("headway_")
  ) |>

  # Labels das colunas
  cols_label(
    linha                = "Linha",
    total_embarques      = "Total",
    emb_madrugada        = "Madrugada\n00–05h",
    emb_pico_manha       = "Pico Manhã\n06–08h",
    emb_entrepico        = "Entrepico\n09–16h",
    emb_pico_tarde       = "Pico Tarde\n17–19h",
    emb_noturno          = "Noturno\n20–23h",
    partidas_total       = "Total",
    partidas_madrugada   = "Madrugada",
    partidas_pico_manha  = "Pico Manhã",
    partidas_entrepico   = "Entrepico",
    partidas_pico_tarde  = "Pico Tarde",
    partidas_noturno     = "Noturno",
    headway_pico_manha   = "Pico Manhã",
    headway_entrepico    = "Entrepico",
    headway_pico_tarde   = "Pico Tarde"
  ) |>

  # Formatação numérica
  fmt_integer(columns = c(total_embarques, starts_with("emb_"),
                          partidas_total, starts_with("partidas_")),
              use_seps = TRUE) |>
  fmt_number(columns  = starts_with("headway_"), decimals = 1) |>
  sub_missing(columns = starts_with("headway_"), missing_text = "—") |>

  # Destaque de alerta: headway elevado
  tab_style(
    style     = list(cell_fill(color = "#fdecea"), cell_text(weight = "bold")),
    locations = cells_body(
      columns = headway_pico_manha,
      rows    = !is.na(headway_pico_manha) & headway_pico_manha > HEADWAY_ALERTA_MIN
    )
  ) |>
  tab_style(
    style     = list(cell_fill(color = "#fdecea"), cell_text(weight = "bold")),
    locations = cells_body(
      columns = headway_pico_tarde,
      rows    = !is.na(headway_pico_tarde) & headway_pico_tarde > HEADWAY_ALERTA_MIN
    )
  ) |>

  # Estilo geral
  opt_row_striping() |>
  opt_table_font(font = "Arial") |>
  tab_options(
    table.font.size        = px(10),
    heading.title.font.size = px(14),
    column_labels.font.weight = "bold",
    row_group.font.weight  = "bold",
    row_group.background.color = "#e8f4fd"
  ) |>

  # Rodapé
  tab_source_note(
    source_note = md(glue(
      "Fonte: SMTR/RJ — Bilhetagem eletrônica (JAE + RioCard) + GPS SPPO. ",
      "Gerado automaticamente em {format(Sys.time(), '%d/%m/%Y %H:%M')}."
    ))
  )

gtsave(tabela_gt, caminho_pdf)
message(glue("✅ PDF gerado: {caminho_pdf}"))
