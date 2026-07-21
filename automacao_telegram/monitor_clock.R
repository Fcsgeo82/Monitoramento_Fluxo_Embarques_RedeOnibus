# ⏰ Monitor de Execução Diária (Vigia do Pipeline)
# Este script atua como um "vigia" para o pipeline de automação. 
# Ele roda continuamente em sua sessão de usuário, monitorando o relógio e disparando o processo `run_daily.R` no horário configurado.

library(glue)

# ==============================================================================
# CONFIGURAÇÃO
# ==============================================================================
# Horário de execução (formato 24h: "HH:MM")
HORARIO_EXECUCAO <- "11:00"

# Caminho absoluto para o script principal (evita erros de diretório)
CAMINHO_RUN_DAILY <- "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus/automacao_telegram/run_daily.R"

# Arquivo para controlar se o script já rodou hoje (evita duplicidade)
# Salvo na pasta automacao_telegram
ARQUIVO_CONTROLE <- "C:/github_repositories/Monitoramento_Fluxo_Embarques_RedeOnibus/automacao_telegram/ultima_execucao.txt"

# ==============================================================================
# FUNÇÕES DE SUPORTE
# ==============================================================================

registrar_execucao <- function() {
  writeLines(as.character(Sys.Date()), ARQUIVO_CONTROLE)
}

ja_rodou_hoje <- function() {
  if (!file.exists(ARQUIVO_CONTROLE)) return(FALSE)
  ultima_data <- readLines(ARQUIVO_CONTROLE, warn = FALSE)
  return(ultima_data == as.character(Sys.Date()))
}

# ==============================================================================
# LOOP PRINCIPAL
# ==============================================================================

cat(glue("\n🚀 Monitor iniciado. Aguardando horário: {HORARIO_EXECUCAO}\n"))
cat(glue("📂 Script alvo: {CAMINHO_RUN_DAILY}\n"))
cat("------------------------------------------------------------\n")

while (TRUE) {
  agora <- format(Sys.time(), "%H:%M")
  
  # Verifica se atingiu o horário e se ainda não rodou hoje
  if (agora == HORARIO_EXECUCAO && !ja_rodou_hoje()) {
    
    cat(glue("\n[{Sys.time()}] 🏃 Disparando pipeline...\n"))
    
    # Tenta executar o script principal
    tryCatch({
      # Seta o diretório de trabalho para o local do script principal para evitar erros de path
      setwd(dirname(CAMINHO_RUN_DAILY))
      
      # Executa o script
      source(basename(CAMINHO_RUN_DAILY))
      
      # Se chegou aqui sem erro, registra o sucesso
      registrar_execucao()
      cat(glue("[{Sys.time()}] ✅ Sucesso! Pipeline concluído e registrado.\n"))
      
    }, error = function(e) {
      cat(glue("[{Sys.time()}] ❌ ERRO no pipeline: {e$message}\n"))
    })
    
    # Pequena pausa para não entrar em loop imediato no mesmo minuto
    Sys.sleep(3605)
    
  } else if (agora == HORARIO_EXECUCAO && ja_rodou_hoje()) {
    # Se já rodou, apenas silencia para não poluir o console
    Sys.sleep(3605)
  } else {
    # Loop de espera (checa a cada 60 segundos)
    Sys.sleep(60)
  }
}
