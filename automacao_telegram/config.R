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
