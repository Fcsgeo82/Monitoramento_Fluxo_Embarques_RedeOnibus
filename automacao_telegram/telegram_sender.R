# =============================================================================
# telegram_sender.R
# Funções para envio de mensagens e arquivos via API do Telegram Bot.
# Requer: httr2, curl, glue
# =============================================================================

library(httr2)
library(glue)

# URL base da API
.tg_url <- function(token, metodo) {
  glue("https://api.telegram.org/bot{token}/{metodo}")
}

# -----------------------------------------------------------------------------
# telegram_send_text()
# Envia mensagem de texto. Suporta formatação Markdown do Telegram.
# parse_mode: "Markdown", "MarkdownV2" ou "HTML"
# -----------------------------------------------------------------------------
telegram_send_text <- function(token, chat_id, texto, parse_mode = "Markdown") {
  resp <- request(.tg_url(token, "sendMessage")) |>
    req_body_json(list(
      chat_id    = as.character(chat_id),
      text       = texto,
      parse_mode = parse_mode
    )) |>
    req_error(is_error = \(r) FALSE) |>   # capturar erro manualmente
    req_perform()

  if (resp_status(resp) != 200) {
    body <- resp_body_json(resp)
    stop(glue("Telegram sendMessage falhou [{resp_status(resp)}]: {body$description}"))
  }

  invisible(resp)
}

# -----------------------------------------------------------------------------
# telegram_send_document()
# Envia arquivo (PDF, RDS, etc.) com legenda opcional.
# Limite da API: 50 MB por arquivo.
# -----------------------------------------------------------------------------
telegram_send_document <- function(token, chat_id, caminho_arquivo, legenda = "") {
  if (!file.exists(caminho_arquivo)) {
    stop(glue("Arquivo não encontrado: {caminho_arquivo}"))
  }

  resp <- request(.tg_url(token, "sendDocument")) |>
    req_body_multipart(
      chat_id  = as.character(chat_id),
      caption  = legenda,
      document = curl::form_file(caminho_arquivo)
    ) |>
    req_error(is_error = \(r) FALSE) |>
    req_perform()

  if (resp_status(resp) != 200) {
    body <- resp_body_json(resp)
    stop(glue("Telegram sendDocument falhou [{resp_status(resp)}]: {body$description}"))
  }

  invisible(resp)
}

# -----------------------------------------------------------------------------
# enviar_relatorio_mvp()
# Wrapper para o MVP: envia mensagem de KPIs + PDF tabular da rede.
# -----------------------------------------------------------------------------
enviar_relatorio_mvp <- function(token, chat_id, data_ref = Sys.Date() - 1) {

  data_ref_fmt <- format(data_ref, "%d/%m/%Y")

  # 1. Mensagem de KPIs
  caminho_kpis <- file.path(CAMINHO_OUTPUT, "mensagem_kpis.txt")
  if (!file.exists(caminho_kpis)) stop("mensagem_kpis.txt não encontrado.")

  kpis <- readLines(caminho_kpis, warn = FALSE) |> paste(collapse = "\n")
  message("📨 Enviando mensagem de KPIs...")
  telegram_send_text(token, chat_id, kpis)

  # 2. PDF tabular da rede
  caminho_pdf <- file.path(CAMINHO_OUTPUT, glue("relatorio_rede_{data_ref}.pdf"))
  if (!file.exists(caminho_pdf)) stop(glue("PDF não encontrado: {caminho_pdf}"))

  message("📨 Enviando PDF tabular...")
  telegram_send_document(
    token, chat_id,
    caminho_pdf,
    legenda = glue("📋 Relatório Tabular da Rede — {data_ref_fmt}")
  )

  message(glue("✅ Envio concluído para {data_ref_fmt}."))
  invisible(TRUE)
}
