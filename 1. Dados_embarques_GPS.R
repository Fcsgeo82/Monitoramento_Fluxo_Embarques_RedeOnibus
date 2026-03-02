# 📌 Liberar memória
rm(list = ls())
gc()

# 📌 Pacotes
library(data.table)
library(sf)
library(dplyr)
library(lubridate)
library(h3jsr)
library(googlesheets4)
library(bigrquery)
library(basedosdados)
library(glue)
library(purrr)

# 📌 Configurações e Autenticação
options(bigrquery.quiet = TRUE)
bq_auth(path = "C:/R_SMTR/rj-smtr-felipe-coriolano-siqueira.json", cache = FALSE)
basedosdados::set_billing_id("rj-smtr")

# 📌 Definição do Período de Extração
data_inicio <- as.Date("2026-02-24")
data_fim    <- as.Date("2026-02-24")
datas <- seq(data_inicio, data_fim, by = "day")

# 📌 Planilha de tecnologias (Cadastro Auxiliar)
tecnologia <- tryCatch({
  read_sheet("1n79LCQfCVY392b5wwvXZZfmcIUYFwzKb7R89G__PgYE")
}, error = function(e) {
  message("❌ Erro ao carregar planilha de tecnologias")
  stop("Planilha essencial")
})

# 📌 Função de Processamento por Dia
processar_dia <- function(data, max_tentativas = 3, delay_segundos = 5) {
  tentativa <- 1
  registros_dia_final <- NULL
  
  while (tentativa <= max_tentativas && is.null(registros_dia_final)) {
    tryCatch({
      message(glue("🔄 Processando {data} (Tentativa {tentativa}/{max_tentativas})..."))
      
      # 1. Queries SQL
      # JAE: Extrai o tipo real da transação
      q_jae   <- glue("SELECT datetime_transacao, id_veiculo, tipo_transacao FROM `rj-smtr.br_rj_riodejaneiro_bilhetagem.transacao` WHERE data = '{data}' AND modo = 'Ônibus'")
      
      # RioCard: Extrai apenas o necessário (assumiremos Pagante no R)
      q_rio   <- glue("SELECT datetime_transacao, id_validador FROM `rj-smtr.bilhetagem.transacao_riocard` WHERE data = '{data}'")
      
      q_track <- glue("SELECT DISTINCT(id_validador), id_veiculo FROM `rj-smtr.monitoramento.gps_validador` WHERE modo = 'Ônibus' AND data = '{data}'")
      q_gps   <- glue("SELECT id_veiculo, latitude, longitude, timestamp_gps FROM `rj-smtr.br_rj_riodejaneiro_veiculos.gps_sppo` WHERE data = '{data}'")
      q_trip  <- glue("SELECT servico_informado, sentido, datetime_partida, datetime_chegada, id_veiculo, id_viagem FROM `rj-smtr.projeto_subsidio_sppo.viagem_completa` WHERE data = '{data}'")
      
      # 2. Leitura de Dados
      registros_jae <- basedosdados::read_sql(q_jae)
      registros_rio <- basedosdados::read_sql(q_rio)
      
      veiculos_ref  <- basedosdados::read_sql(q_track) %>%
        filter(nchar(id_veiculo) == 5, substr(id_veiculo, 1, 2) != "99") %>%
        group_by(id_validador) %>% filter(n() == 1) %>% ungroup()
      
      gps <- basedosdados::read_sql(q_gps) %>%
        rename(data_hora = timestamp_gps) %>%
        mutate(id_veiculo = substr(id_veiculo, 2, 6)) %>%
        as.data.table()
      
      trip <- basedosdados::read_sql(q_trip) %>%
        mutate(id_veiculo = substr(id_veiculo, 2, 6)) %>%
        group_by(id_veiculo) %>% arrange(datetime_partida) %>%
        mutate(datetime_partida_adj = if_else(!is.na(lag(datetime_chegada)), lag(datetime_chegada), datetime_partida - 1800)) %>%
        ungroup()
      
      # 3. Consolidação da Bilhetagem
      # RioCard: Forçamos o tipo para "Pagante"
      bilhetagem_rio <- registros_rio %>%
        left_join(veiculos_ref, by = "id_validador") %>%
        filter(!is.na(id_veiculo)) %>%
        select(id_veiculo, data_hora = datetime_transacao) %>%
        mutate(tipo_usuario = "Pagante")
      
      # JAE: Mantemos o tipo original vindo da transação
      bilhetagem_jae <- registros_jae %>%
        select(id_veiculo, data_hora = datetime_transacao, tipo_usuario = tipo_transacao)
      
      bilhetagem_total <- bind_rows(bilhetagem_rio, bilhetagem_jae) %>% as.data.table()
      
      # 4. Join Bilhetagem + GPS
      setorder(gps, id_veiculo, data_hora)
      setorder(bilhetagem_total, id_veiculo, data_hora)
      
      embarques_coords <- gps[bilhetagem_total,
                              on = .(id_veiculo, data_hora),
                              roll = "nearest",
                              .(id_veiculo, 
                                horario_embarque = i.data_hora, 
                                tipo_usuario = i.tipo_usuario,
                                latitude, 
                                longitude)]
      
      # 5. Join Final com Viagens (Linha e Sentido)
      registros_dia_final <- embarques_coords %>%
        left_join(trip, by = "id_veiculo") %>%
        filter(horario_embarque > datetime_partida_adj & horario_embarque <= datetime_chegada) %>%
        select(
          id_veiculo,
          linha = servico_informado,
          sentido,
          tipo_usuario,
          horario_embarque,
          latitude,
          longitude,
          id_viagem
        )
      
      return(registros_dia_final)
      
    }, error = function(e) {
      message(glue("❌ Erro na tentativa {tentativa} para {data}: {e$message}"))
      tentativa <<- tentativa + 1
      Sys.sleep(delay_segundos)
      return(NULL)
    })
  }
  return(registros_dia_final)
}

# 📌 Execução
pb <- progress::progress_bar$new(total = length(datas))
todos_dias_lista <- map(datas, ~{ pb$tick(); processar_dia(.x) })
registros_final <- bind_rows(todos_dias_lista) %>% compact()

# 📌 Salvamento
if (nrow(registros_final) > 0) {
  caminho_diretorio <- "C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados"
  if (!dir.exists(caminho_diretorio)) dir.create(caminho_diretorio, recursive = TRUE)
  
  caminho_saida <- file.path(caminho_diretorio, glue("base_embarques_final_{data_inicio}.rds"))
  saveRDS(registros_final, caminho_saida)
  
  message("---")
  message(glue("✅ Processamento finalizado! Total: {nrow(registros_final)} embarques."))
  message(glue("💾 Arquivo salvo em: {caminho_saida}"))
} else {
  message("⚠️ Nenhum dado encontrado para salvar.")
}

