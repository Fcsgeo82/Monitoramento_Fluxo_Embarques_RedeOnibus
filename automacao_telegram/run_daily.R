# =============================================================================
# run_daily.R — Orquestrador do pipeline diário (MVP)
#
# Saídas desta versão:
#   ✅ mensagem_kpis.txt  — resumo textual da rede
#   ✅ relatorio_rede_YYYY-MM-DD.pdf — tabela detalhada por linha/sentido/faixa
#
# Saídas previstas em versões futuras:
#   ⬜ grafico_demanda.png
#   ⬜ grafico_headway.png
#   ⬜ mapa_embarques.png
#
# Para executar manualmente: source("automacao_telegram/run_daily.R")
# Para agendar: ver PLANO_IMPLEMENTACAO.md — Etapa 6
# =============================================================================

BASE_DIR <- "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus"
setwd(BASE_DIR)

cat("====================================================\n")
cat(sprintf("🚀 Pipeline iniciado — %s\n", format(Sys.time(), "%d/%m/%Y %H:%M:%S")))
cat("====================================================\n\n")

# -----------------------------------------------------------------------------
# SETUP: carregar configurações e funções de envio
# -----------------------------------------------------------------------------
source("automacao_telegram/config.R")
source("automacao_telegram/telegram_sender.R")

data_ref     <- Sys.Date() - 1
data_ref_fmt <- format(data_ref, "%d/%m/%Y")

# Validação mínima das credenciais Telegram
if (nchar(TELEGRAM_TOKEN) < 10 || nchar(TELEGRAM_CHAT_ID) < 1) {
  stop(paste(
    "❌ Credenciais do Telegram não configuradas.",
    "Defina as variáveis de ambiente TELEGRAM_BOT_TOKEN e TELEGRAM_CHAT_ID.",
    "Consulte config.R para instruções."
  ))
}

# -----------------------------------------------------------------------------
# ETAPA 1: Extração de dados (Script 1 com data automática)
# -----------------------------------------------------------------------------
cat(sprintf("[1/3] Extraindo dados de %s...\n", data_ref_fmt))

script_linhas <- readLines(CAMINHO_SCRIPT_1, warn = FALSE)

# Substituir datas hardcoded pela data de referência
script_linhas <- gsub(
  pattern     = 'data_inicio\\s*<-\\s*as\\.Date\\(".*?"\\)',
  replacement = sprintf('data_inicio <- as.Date("%s")', data_ref),
  x           = script_linhas
)
script_linhas <- gsub(
  pattern     = 'data_fim\\s*<-\\s*as\\.Date\\(".*?"\\)',
  replacement = sprintf('data_fim    <- as.Date("%s")', data_ref),
  x           = script_linhas
)

# Remover rm(list=ls()) e gc() para não limpar o ambiente corrente
script_linhas <- gsub("^\\s*rm\\(list\\s*=\\s*ls\\(\\)\\)\\s*$", "", script_linhas)
script_linhas <- gsub("^\\s*gc\\(\\)\\s*$",                      "", script_linhas)

tryCatch({
  eval(parse(text = paste(script_linhas, collapse = "\n")))

  if (!exists("registros_final") || nrow(registros_final) == 0) {
    stop("Extração retornou zero registros.")
  }

  cat(sprintf("    ✅ %s embarques extraídos.\n\n", format(nrow(registros_final), big.mark = ".")))

}, error = function(e) {
  msg <- sprintf("❌ *Falha na extração* (%s):\n`%s`", data_ref_fmt, e$message)
  try(telegram_send_text(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, msg), silent = TRUE)
  stop(e$message)
})

# -----------------------------------------------------------------------------
# ETAPA 2: Geração do relatório (KPIs + PDF tabular)
# -----------------------------------------------------------------------------
cat("[2/3] Gerando KPIs e PDF tabular da rede...\n")

tryCatch({
  source("automacao_telegram/relatorio_pdf_rede.R", local = FALSE)
  cat("    ✅ Artefatos gerados.\n\n")

}, error = function(e) {
  msg <- sprintf("❌ *Falha na geração do relatório* (%s):\n`%s`", data_ref_fmt, e$message)
  try(telegram_send_text(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, msg), silent = TRUE)
  stop(e$message)
})

# -----------------------------------------------------------------------------
# ETAPA 3: Envio ao Telegram
# -----------------------------------------------------------------------------
cat("[3/3] Enviando ao Telegram...\n")

tryCatch({
  enviar_relatorio_mvp(TELEGRAM_TOKEN, TELEGRAM_CHAT_ID, data_ref)
  cat("    ✅ Envio concluído.\n\n")

}, error = function(e) {
  cat(sprintf("    ❌ Erro no envio: %s\n", e$message))
  stop(e$message)
})

cat("====================================================\n")
cat(sprintf("🏁 Pipeline finalizado — %s\n", format(Sys.time(), "%d/%m/%Y %H:%M:%S")))
cat("====================================================\n")
