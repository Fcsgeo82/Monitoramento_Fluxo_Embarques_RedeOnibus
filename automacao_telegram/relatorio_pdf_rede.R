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
library(readr)

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
# 0b. Carregar mapeamento linha → consórcio
# -----------------------------------------------------------------------------
# O script roda a partir da pasta automacao_telegram/ (via run_daily.R)
caminho_consorcio <- "config_consorcio.csv"
if (file.exists(caminho_consorcio)) {
  mapa_consorcio <- readr::read_csv(caminho_consorcio, show_col_types = FALSE, lazy = FALSE)
  names(mapa_consorcio) <- c("linha", "consorcio")
  message(glue("📋 Mapeamento de consórcio carregado: {nrow(mapa_consorcio)} linhas"))
} else {
  warning(glue("⚠️ Arquivo de mapeamento consórcio não encontrado: {caminho_consorcio}"))
  mapa_consorcio <- tibble(linha = character(), consorcio = character())
}

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
  ) |>
  # Adicionar coluna de consórcio via join
  left_join(mapa_consorcio, by = "linha") |>
  mutate(consorcio = if_else(is.na(consorcio), "SEM_MAPEAMENTO", consorcio))

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

# -----------------------------------------------------------------------------
# 2b. Métricas por Consórcio
# -----------------------------------------------------------------------------

consorcios_ativos <- sort(unique(dados$consorcio))
consorcios_com_dados <- consorcios_ativos[consorcios_ativos != "SEM_MAPEAMENTO"]

linhas_consorcio <- NULL
if (length(consorcios_com_dados) > 0) {
  emb_por_consorcio <- dados |>
    filter(consorcio != "SEM_MAPEAMENTO") |>
    group_by(consorcio) |>
    summarise(
      embarques   = n(),
      linhas      = n_distinct(linha),
      partidas    = n_distinct(id_viagem),
      .groups = "drop"
    ) |>
    arrange(desc(embarques)) |>
    mutate(
      pct_emb = round(embarques / total_emb * 100, 1),
      pct_lin = round(linhas / total_linhas * 100, 1),
      pct_par = round(partidas / total_partidas * 100, 1)
    )

  linhas_consorcio <- emb_por_consorcio |>
    mutate(linha_txt = glue("  • {consorcio}: {fmt_num(embarques)} embarques ({pct_emb}%) | {fmt_num(linhas)} linhas ({pct_lin}%) | {fmt_num(partidas)} partidas ({pct_par}%)")) |>
    pull(linha_txt) |>
    paste(collapse = "\n")
} else {
  linhas_consorcio <- "  • ⚠️ Nenhum mapeamento de consórcio encontrado"
}

# -----------------------------------------------------------------------------
# 2c. Top 5 linhas por volume (opcional, boa métrica operacional)
# -----------------------------------------------------------------------------

top5_linhas <- dados |>
  group_by(linha, sentido) |>
  summarise(embarques = n(), .groups = "drop") |>
  arrange(desc(embarques)) |>
  slice_head(n = 5) |>
  mutate(linha_txt = glue("  • {linha} ({sentido}): {fmt_num(embarques)}")) |>
  pull(linha_txt) |>
  paste(collapse = "\n")

# -----------------------------------------------------------------------------
# 2d. Headway médio por faixa (rede)
# -----------------------------------------------------------------------------

# Reutiliza a lógica de viagens já calculada para o PDF
viagens_rede <- dados |>
  group_by(id_viagem) |>
  summarise(
    inicio_viagem = min(timestamp),
    faixa_viagem  = as.character(first(faixa)),
    .groups = "drop"
  ) |>
  arrange(inicio_viagem) |>
  mutate(headway_min = as.numeric(difftime(inicio_viagem, lag(inicio_viagem), units = "mins")))

headway_por_faixa_rede <- viagens_rede |>
  filter(faixa_viagem %in% names(FAIXAS_HORARIAS)) |>
  group_by(faixa_viagem) |>
  summarise(headway_medio = round(mean(headway_min, na.rm = TRUE), 1), .groups = "drop") |>
  mutate(label = LABELS_FAIXAS[faixa_viagem])

linhas_headway_rede <- headway_por_faixa_rede |>
  mutate(linha_txt = glue("  • {label}: {headway_medio} min")) |>
  pull(linha_txt) |>
  paste(collapse = "\n")

# -----------------------------------------------------------------------------
# 2e. Headway médio por Consórcio (apenas faixas de headway)
# -----------------------------------------------------------------------------

headway_consorcio <- NULL
if (length(consorcios_com_dados) > 0) {
  # Viagens por consórcio
  viagens_consorcio <- dados |>
    filter(consorcio != "SEM_MAPEAMENTO") |>
    group_by(id_viagem, consorcio) |>
    summarise(
      inicio_viagem = min(timestamp),
      faixa_viagem  = as.character(first(faixa)),
      .groups = "drop"
    ) |>
    arrange(consorcio, inicio_viagem) |>
    group_by(consorcio) |>
    mutate(headway_min = as.numeric(difftime(inicio_viagem, lag(inicio_viagem), units = "mins"))) |>
    ungroup()

  headway_consorcio_calc <- viagens_consorcio |>
    filter(faixa_viagem %in% FAIXAS_HEADWAY) |>
    group_by(consorcio) |>
    summarise(headway_medio = round(mean(headway_min, na.rm = TRUE), 1), .groups = "drop") |>
    arrange(headway_medio)

  if (nrow(headway_consorcio_calc) > 0) {
    linhas_headway_consorcio <- headway_consorcio_calc |>
      mutate(linha_txt = glue("  • {consorcio}: {headway_medio} min")) |>
      pull(linha_txt) |>
      paste(collapse = "\n")
  } else {
    linhas_headway_consorcio <- "  • —"
  }
} else {
  linhas_headway_consorcio <- "  • —"
}

# -----------------------------------------------------------------------------
# 2f. Taxa de Integração e Cobertura GPS
# -----------------------------------------------------------------------------

# Taxa de integração: % de embarques que são do tipo Integração
integracao_tipos <- c("Integração", "Integração gratuidade", "Integração EMV")
taxa_integracao <- sum(dados$tipo_usuario %in% integracao_tipos) / total_emb * 100
taxa_integracao_fmt <- round(taxa_integracao, 1)

# Cobertura GPS: % de embarques com coordenadas válidas
com_coords <- dados |>
  filter(!is.na(latitude) & !is.na(longitude) & latitude != 0 & longitude != 0) |>
  nrow()
taxa_cobertura_gps <- com_coords / total_emb * 100
taxa_cobertura_gps_fmt <- round(taxa_cobertura_gps, 1)

# Faixa de maior movimento
faixa_pico <- emb_por_faixa_rede |>
  filter(embarques == max(embarques)) |>
  pull(label) |>
  paste(collapse = ", ")

# -----------------------------------------------------------------------------
# 2g. Métricas adicionais (itens 4a-4f do roadmap)
# -----------------------------------------------------------------------------

# 4a. Comparativo com dia anterior e mesmo dia da semana anterior
data_anterior <- data_ref - 1
data_semana_anterior <- data_ref - 7

caminho_rds_anterior <- file.path(CAMINHO_RDS_BASE, glue("base_embarques_final_{data_anterior}.rds"))
caminho_rds_semana_ant <- file.path(CAMINHO_RDS_BASE, glue("base_embarques_final_{data_semana_anterior}.rds"))

comparativo_anterior <- "  • Dia anterior: —"
comparativo_semana_anterior <- "  • Mesma D.S. anterior: —"

if (file.exists(caminho_rds_anterior)) {
  dados_ant <- readRDS(caminho_rds_anterior)
  total_ant <- nrow(dados_ant)
  var_ant <- round((total_emb - total_ant) / total_ant * 100, 1)
  sinal_ant <- ifelse(var_ant >= 0, "+", "")
  comparativo_anterior <- glue("  • Dia anterior ({format(data_anterior, '%d/%m')}): {fmt_num(total_ant)} ({sinal_ant}{var_ant}%)")
} else {
  comparativo_anterior <- "  • Dia anterior: arquivo não encontrado"
}

if (file.exists(caminho_rds_semana_ant)) {
  dados_sem_ant <- readRDS(caminho_rds_semana_ant)
  total_sem_ant <- nrow(dados_sem_ant)
  var_sem_ant <- round((total_emb - total_sem_ant) / total_sem_ant * 100, 1)
  sinal_sem_ant <- ifelse(var_sem_ant >= 0, "+", "")
  comparativo_semana_anterior <- glue("  • Mesma D.S. anterior ({format(data_semana_anterior, '%d/%m')}): {fmt_num(total_sem_ant)} ({sinal_sem_ant}{var_sem_ant}%)")
} else {
  comparativo_semana_anterior <- "  • Mesma D.S. anterior: arquivo não encontrado"
}

# 4b. Taxa de ocupação média (embarques / capacidade instalada)
# Carregar capacidade média por tecnologia do CSV (script roda a partir de automacao_telegram/)
capacidade_path <- "capacidade_tecnologia.csv"
if (file.exists(capacidade_path)) {
  cap_tecnologia <- readr::read_csv(capacidade_path, show_col_types = FALSE, lazy = FALSE)
  # Capacidade média ponderada (usando capacidade_media como padrão)
  cap_media_padrao <- round(mean(cap_tecnologia$capacidade_media, na.rm = TRUE), 0)

  # Capacidade instalada = partidas × capacidade média
  capacidade_instalada <- total_partidas * cap_media_padrao
  taxa_ocupacao <- ifelse(capacidade_instalada > 0, round(total_emb / capacidade_instalada * 100, 1), NA_real_)
  taxa_ocupacao_fmt <- ifelse(is.na(taxa_ocupacao), "—", glue("{taxa_ocupacao}%"))
} else {
  taxa_ocupacao_fmt <- "— (CSV capacidade não encontrado)"
}

# 4c. Linhas sem partida observada (do planejado assumido)
# Obter total de linhas únicas no GTFS/cadastro se disponível, senão usar total_linhas
linhas_sem_partida <- total_linhas - n_distinct(dados$linha)
linhas_sem_partida_fmt <- ifelse(linhas_sem_partida > 0, glue("{linhas_sem_partida} linhas"), "Nenhuma")

# 4d. % de linhas com headway > 30 min nas faixas de pico
# Reutilizar headway_faixa do PDF (mas calcular aqui para rede)
headway_alerta_linhas <- viagens |>
  filter(faixa_viagem %in% FAIXAS_HEADWAY) |>
  group_by(linha, sentido) |>
  summarise(
    headway_max = max(headway_min, na.rm = TRUE),
    .groups = "drop"
  ) |>
  filter(!is.na(headway_max) & headway_max > 30) |>
  nrow()

total_linhas_sentido <- viagens |>
  group_by(linha, sentido) |>
  summarise(n = n(), .groups = "drop") |>
  nrow()

pct_linhas_headway_alto <- ifelse(total_linhas_sentido > 0,
  round(headway_alerta_linhas / total_linhas_sentido * 100, 1), 0)

# 4e. Sparkline de headway por hora (texto simples)
# Calcular headway médio por hora do dia
headway_por_hora <- viagens |>
  mutate(hora = hour(inicio_viagem)) |>
  filter(hora >= 5, hora <= 22) |>  # horário operacional
  group_by(hora) |>
  summarise(hw = round(mean(headway_min, na.rm = TRUE), 1), .groups = "drop") |>
  arrange(hora)

# Criar sparkline simples com blocos Unicode
spark_chars <- c("▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")
if (nrow(headway_por_hora) > 0) {
  hw_min <- min(headway_por_hora$hw, na.rm = TRUE)
  hw_max <- max(headway_por_hora$hw, na.rm = TRUE)
  if (hw_max > hw_min) {
    headway_por_hora <- headway_por_hora |>
      mutate(
        idx = pmax(1, pmin(8, ceiling((hw - hw_min) / (hw_max - hw_min) * 8))),
        char = spark_chars[idx]
      )
  } else {
    headway_por_hora$char <- spark_chars[1]
  }
  sparkline_texto <- paste0(headway_por_hora$char, collapse = "")
  sparkline_legenda <- glue("  {min(headway_por_hora$hora)}h {spark_chars[1]} = {hw_min:.1f}min  →  {max(headway_por_hora$hora)}h {spark_chars[8]} = {hw_max:.1f}min")
} else {
  sparkline_texto <- "—"
  sparkline_legenda <- ""
}

# 4f. Ranking de piores consórcios/linhas (headway alto + baixa ocupação)
piores_linhas <- viagens |>
  filter(faixa_viagem %in% FAIXAS_HEADWAY) |>
  group_by(linha, sentido) |>
  summarise(
    headway_medio = round(mean(headway_min, na.rm = TRUE), 1),
    partidas = n(),
    .groups = "drop"
  ) |>
  filter(!is.na(headway_medio) & headway_medio > 20 & partidas >= 3) |>
  arrange(desc(headway_medio)) |>
  slice_head(n = 5)

if (nrow(piores_linhas) > 0) {
  ranking_piores <- piores_linhas |>
    mutate(linha_txt = glue("  • {linha} ({sentido}): HW médio {headway_medio}min | {partidas} partidas")) |>
    pull(linha_txt) |>
    paste(collapse = "\n")
} else {
  ranking_piores <- "  • Nenhuma linha com headway crítico (>20min) e partidas suficientes"
}

# -----------------------------------------------------------------------------
# 2h. Montar mensagem KPI — BLOCO 1: Resumo Executivo
# -----------------------------------------------------------------------------

mensagem_kpis_bloco1 <- glue(
  "📊 *Relatório Operacional da Rede — {data_ref_fmt}*\n",
  "\n",
  "🚍 *Resumo Geral*\n",
  "  • Total de embarques: {fmt_num(total_emb)}\n",
  "  • Linhas em operação: {fmt_num(total_linhas)}\n",
  "  • Partidas observadas: {fmt_num(total_partidas)}\n",
  "\n",
  "📊 *Comparativo Histórico*\n",
  "{comparativo_anterior}\n",
  "{comparativo_semana_anterior}\n",
  "\n",
  "🏢 *Por Consórcio*\n",
  "{linhas_consorcio}\n",
  "\n",
  "⏱️ *Headway médio por Consórcio (picos + entrepico)*\n",
  "{linhas_headway_consorcio}\n",
  "\n",
  "👥 *Por tipo de usuário*\n",
  "{linhas_tipo}\n",
  "\n",
  "⏰ *Embarques por faixa horária*\n",
  "{linhas_faixa}\n",
  "\n",
  "📈 *Faixa de maior movimento*: {faixa_pico}\n",
  "🔗 *Taxa de integração*: {taxa_integracao_fmt}%\n",
  "📍 *Cobertura GPS*: {taxa_cobertura_gps_fmt}%\n",
  "🚌 *Taxa de ocupação média*: {taxa_ocupacao_fmt}"
)

# -----------------------------------------------------------------------------
# 2i. Montar mensagem KPI — BLOCO 2: Detalhamento Operacional
# -----------------------------------------------------------------------------

mensagem_kpis_bloco2 <- glue(
  "📊 *Detalhamento Operacional — {data_ref_fmt}*\n",
  "\n",
  "⏱️ *Headway médio por faixa (rede)*\n",
  "{linhas_headway_rede}\n",
  "\n",
  "📊 *Evolução horária do Headway (5h–22h)*\n",
  "  {sparkline_texto}\n",
  "{sparkline_legenda}\n",
  "\n",
  "🏆 *Top 5 Linhas × Sentido (volume)*\n",
  "{top5_linhas}\n",
  "\n",
  "⚠️ *Linhas com Headway > 30 min (picos)*\n",
  "{headway_alerta_txt}\n",
  "\n",
  "🚫 *Linhas sem partida observada*\n",
  "{linhas_sem_partida_txt}\n",
  "\n",
  "🔻 *Top 5 Linhas com Headway Crítico (>20min)*\n",
  "{ranking_piores}"
)

# Salvar ambos os blocos
caminho_kpis <- file.path(CAMINHO_OUTPUT, "mensagem_kpis.txt")
writeLines(c(mensagem_kpis_bloco1, "\n---\n", mensagem_kpis_bloco2), caminho_kpis)

# Também salvar blocos separados para flexibilidade no envio
writeLines(mensagem_kpis_bloco1, file.path(CAMINHO_OUTPUT, "mensagem_kpis_bloco1.txt"))
writeLines(mensagem_kpis_bloco2, file.path(CAMINHO_OUTPUT, "mensagem_kpis_bloco2.txt"))

message(glue("✅ KPIs salvos: {caminho_kpis} (2 blocos)"))

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
  gt() |>

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
    emb_pico_manha       = "Pico Manhã\n05–09h",
    emb_entrepico        = "Entrepico\n09–15h",
    emb_pico_tarde       = "Pico Tarde\n15–19h",
    emb_noturno          = "Noturno\n19–24h",
    partidas_total       = "Total",
    partidas_madrugada   = "Madrug.",
    partidas_pico_manha  = "P. Manhã",
    partidas_entrepico   = "Entrepico",
    partidas_pico_tarde  = "P. Tarde",
    partidas_noturno     = "Noturno",
    headway_pico_manha   = "P. Manhã",
    headway_entrepico    = "Entrepico",
    headway_pico_tarde   = "P. Tarde"
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

  # Estilo geral e profissional
  opt_row_striping() |>
  opt_table_font(font = "Arial") |>
  tab_options(
    table.font.size           = px(7.5),
    heading.title.font.size   = px(12),
    heading.subtitle.font.size= px(8.5),
    column_labels.font.weight = "bold",
    column_labels.font.size   = px(8),
    row_group.font.weight     = "bold",
    row_group.background.color= "#f2f7fc",
    data_row.padding          = px(2),
    column_labels.padding     = px(3),
    table.margin.left         = px(5),
    table.margin.right        = px(5),
    table.width               = pct(100)
  ) |>

  # Rodapé
  tab_source_note(
    source_note = md(glue(
      "Fonte: SMTR/RJ — Bilhetagem eletrônica (JAE + RioCard) + GPS SPPO. ",
      "Gerado automaticamente em {format(Sys.time(), '%d/%m/%Y %H:%M')}."
    ))
  )

# Renderização do PDF em formato Paisagem amplo (vwidth=1700) para eliminar qualquer corte
gtsave(tabela_gt, caminho_pdf, zoom = 0.8, vwidth = 1700, vheight = 1100)
message(glue("✅ PDF gerado: {caminho_pdf}"))
