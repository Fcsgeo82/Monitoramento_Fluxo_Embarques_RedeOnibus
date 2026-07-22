# =============================================================================
# config.R — Parâmetros e credenciais do pipeline de automação
# ⚠️  NÃO versionar este arquivo — adicionar ao .gitignore
# =============================================================================

# -----------------------------------------------------------------------------
# CREDENCIAIS TELEGRAM
# Opção recomendada: definir como variáveis de ambiente no SO e deixar as
# linhas abaixo como estão. Para configurar no Windows, execute no PowerShell:
#   [System.Environment]::SetEnvironmentVariable("TELEGRAM_BOT_TOKEN","<token>","User")
#   [System.Environment]::SetEnvironmentVariable("TELEGRAM_CHAT_ID","<id>","User")
#
# Alternativa direta (menos seguro, não commitar):
#   TELEGRAM_TOKEN   <- "123456789:AAFxxxxxxxxxxxxxxxx"
#   TELEGRAM_CHAT_ID <- "-1001234567890"
# -----------------------------------------------------------------------------
TELEGRAM_TOKEN   <- Sys.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID <- Sys.getenv("TELEGRAM_CHAT_ID")

# -----------------------------------------------------------------------------
# CAMINHOS DO PROJETO
# -----------------------------------------------------------------------------

# Diretório de saída dos artefatos gerados
CAMINHO_OUTPUT <- "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus/automacao_telegram/output"

# Diretório onde o Script 1 salva os .rds
CAMINHO_RDS_BASE <- "C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados"

# Script 1 original (não modificado)
CAMINHO_SCRIPT_1 <- "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus/1. Dados_embarques_GPS.R"

# -----------------------------------------------------------------------------
# FAIXAS HORÁRIAS
# Lista nomeada: cada elemento é um vetor c(hora_inicio, hora_fim) — fim exclusivo.
# -----------------------------------------------------------------------------
FAIXAS_HORARIAS <- list(
  madrugada  = c( 0,  5),
  pico_manha = c( 5,  9),
  entrepico  = c( 9, 15),
  pico_tarde = c(15, 19),
  noturno    = c(19, 24)
)

# Labels legíveis para cada faixa (usados no PDF e na mensagem)
LABELS_FAIXAS <- c(
  madrugada  = "Madrugada (00–05h)",
  pico_manha = "Pico Manhã (05–09h)",
  entrepico  = "Entrepico (09–15h)",
  pico_tarde = "Pico Tarde (15–19h)",
  noturno    = "Noturno (19–24h)"
)

# Faixas para as quais calcular headway médio na tabela PDF
FAIXAS_HEADWAY <- c("pico_manha", "entrepico", "pico_tarde")

# -----------------------------------------------------------------------------
# PARÂMETROS DO RELATÓRIO PDF
# -----------------------------------------------------------------------------

# Threshold de headway (min) acima do qual a célula é destacada em vermelho
HEADWAY_ALERTA_MIN <- 30

# -----------------------------------------------------------------------------
# UTILITÁRIOS
# -----------------------------------------------------------------------------

# Formatação numérica BR (milhar='.', decimal=',') sem aviso de locale
fmt_num <- function(x) {
  # Tratar vetores
  if (length(x) > 1) return(vapply(x, fmt_num, character(1)))

  # Converte para string sem notação científica, preservando decimais
  x_chr <- format(x, scientific = FALSE, trim = TRUE, digits = 15)

  # Extrair sinal se negativo
  sinal <- if (startsWith(x_chr, "-")) "-" else ""
  x_chr <- sub("^-", "", x_chr)

  # Divide parte inteira e decimal pelo ponto decimal (fixed=TRUE = literal '.')
  parts <- strsplit(x_chr, ".", fixed = TRUE)[[1]]
  int_part <- parts[1]
  dec_part <- if (length(parts) > 1) parts[2] else ""

  # Adicionar separador de milhar '.' na parte inteira (manual, sem formatC/prettyNum)
  # Regex: insere '.' antes de cada grupo de 3 dígitos a partir do final
  int_formatted <- gsub("(\\d)(?=(\\d{3})+$)", "\\1.", int_part, perl = TRUE)

  # Recombinar com sinal e vírgula decimal se houver parte decimal
  if (nchar(dec_part) > 0 && dec_part != "0") {
    paste0(sinal, int_formatted, ",", dec_part)
  } else {
    paste0(sinal, int_formatted)
  }
}
