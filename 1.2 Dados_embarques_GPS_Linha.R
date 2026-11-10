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
bq_auth()
gs4_auth(email = "felipe.siqueira@prefeitura.rio")
basedosdados::set_billing_id("rj-smtr")

# =========================================================
# 📌 SELEÇÃO DE LINHAS
# =========================================================
# Informe aqui as linhas (campo servico) que deseja processar.
# Exemplos: c("328"), c("328", "SN328"), c("010", "011", "012").
LINHAS_SELECIONADAS <- c("133")

# Modo de comparação:
#   "exato"  -> mantém apenas valores idênticos aos informados em LINHAS_SELECIONADAS
#   "contem" -> mantém valores que contenham o texto informado
#               (ex.: "328" também seleciona "SN328")
MODO_SELECAO <- "exato"

# 📌 Definição do Período de Extração
data_inicio <- as.Date("2026-10-01")
data_fim <- as.Date("2026-10-02")
datas <- seq(data_inicio, data_fim, by = "day")

# 📌 Helper: aplica a seleção de linhas a um data.frame
selecionar_por_linha <- function(df, coluna = "linha",
                                 linhas = get0("LINHAS_SELECIONADAS"),
                                 modo = get0("MODO_SELECAO", ifnotfound = "exato")) {
    if (is.null(df) || nrow(df) == 0 || length(linhas) == 0) {
        return(df)
    }

    valores <- as.character(df[[coluna]])

    manter <- switch(modo,
        exato  = valores %in% linhas,
        contem = Reduce(`|`, lapply(linhas, function(p) grepl(p, valores, fixed = TRUE))),
        stop("MODO_SELECAO deve ser 'exato' ou 'contem'.")
    )

    df[manter, ]
}

# 📌 Planilha de tecnologias (Cadastro Auxiliar)
tecnologia <- tryCatch(
    {
        read_sheet("1n79LCQfCVY392b5wwvXZZfmcIUYFwzKb7R89G__PgYE")
    },
    error = function(e) {
        message("❌ Erro ao carregar planilha de tecnologias")
        stop("Planilha essencial")
    }
)

# 📌 Função de Processamento por Dia
processar_dia <- function(data, max_tentativas = 3, delay_segundos = 5) {
    tentativa <- 1
    registros_dia_final <- NULL

    while (tentativa <= max_tentativas && is.null(registros_dia_final)) {
        resultado_tentativa <- tryCatch(
            {
                message(glue(
                    "🔄 Processando {data} (Tentativa {tentativa}/{max_tentativas})...",
                    data = data,
                    tentativa = tentativa,
                    max_tentativas = max_tentativas
                ))

                # 1. Query de Viagens
                # A query de viagens é feita SEM filtro de linha: a janela ajustada de cada
                # viagem (datetime_partida_adj) depende da sequência completa de viagens do
                # veículo no dia. O filtro de linha é aplicado logo após esse cálculo.
                q_trip <- glue(
                    "SELECT servico, sentido, datetime_partida, datetime_chegada, id_veiculo, id_viagem FROM `rj-smtr.monitoramento_interno.viagem_valida` WHERE data = '{data}'",
                    data = data
                )

                trip_raw <- basedosdados::read_sql(q_trip)

                if (is.null(trip_raw) || nrow(trip_raw) == 0) {
                    message(glue(
                        "⚠️ Nenhuma viagem encontrada em viagem_valida para {data}. Dia ignorado.",
                        data = data
                    ))
                    return(NULL)
                }

                trip <- trip_raw %>%
                    mutate(
                        id_veiculo = substr(.data$id_veiculo, 2, 6),
                        datetime_partida = as.POSIXct(.data$datetime_partida),
                        datetime_chegada = as.POSIXct(.data$datetime_chegada)
                    ) %>%
                    group_by(.data$id_veiculo) %>%
                    arrange(.data$datetime_partida) %>%
                    mutate(
                        datetime_partida_adj = case_when(
                            !is.na(lag(.data$datetime_chegada)) ~ lag(.data$datetime_chegada),
                            TRUE ~ .data$datetime_partida - 1800
                        )
                    ) %>%
                    ungroup()

                # 1.1 Filtra as viagens das linhas escolhidas (após calcular a janela ajustada)
                trip <- selecionar_por_linha(trip, coluna = "servico")

                if (is.null(trip) || nrow(trip) == 0) {
                    message(glue(
                        "⚠️ Nenhuma viagem das linhas selecionadas em {data}. Dia ignorado.",
                        data = data
                    ))
                    return(NULL)
                }

                veiculos_linhas <- unique(trip$id_veiculo)

                # 2. Leitura de Bilhetagem e GPS (apenas quando há viagens válidas no dia)
                q_jae <- glue(
                    "SELECT datetime_transacao, id_veiculo FROM `rj-smtr.br_rj_riodejaneiro_bilhetagem.transacao` WHERE data = '{data}' AND modo = 'Ônibus'",
                    data = data
                )

                q_rio <- glue(
                    "SELECT datetime_transacao, id_validador FROM `rj-smtr.bilhetagem.transacao_riocard` WHERE data = '{data}'",
                    data = data
                )

                q_track <- glue(
                    "SELECT DISTINCT(id_validador), id_veiculo FROM `rj-smtr.monitoramento.gps_validador` WHERE modo = 'Ônibus' AND data = '{data}'",
                    data = data
                )

                registros_jae <- basedosdados::read_sql(q_jae)
                registros_rio <- basedosdados::read_sql(q_rio)

                veiculos_ref <- basedosdados::read_sql(q_track) %>%
                    filter(nchar(.data$id_veiculo) == 5, substr(.data$id_veiculo, 1, 2) != "99") %>%
                    group_by(.data$id_validador) %>%
                    filter(n() == 1) %>%
                    ungroup()

                # 2.2 GPS apenas dos veículos das linhas selecionadas
                veiculos_sql <- paste0("'", veiculos_linhas, "'", collapse = ",")
                q_gps <- glue(
                    "SELECT id_veiculo, latitude, longitude, timestamp_gps FROM `rj-smtr.monitoramento.view_gps_sppo_completo` WHERE data = '{data}' AND RIGHT(id_veiculo, 5) IN ({veiculos_sql})",
                    data = data,
                    veiculos_sql = veiculos_sql
                )

                gps <- basedosdados::read_sql(q_gps) %>%
                    rename(data_hora = "timestamp_gps") %>%
                    mutate(
                        id_veiculo = substr(.data$id_veiculo, 2, 6),
                        data_hora = as.POSIXct(.data$data_hora)
                    ) %>%
                    as.data.table()

                # 3. Consolidação da Bilhetagem (JAE + RioCard, uma linha por embarque)
                bilhetagem_rio <- registros_rio %>%
                    left_join(veiculos_ref, by = "id_validador") %>%
                    filter(!is.na(.data$id_veiculo)) %>%
                    select("id_veiculo", data_hora = "datetime_transacao") %>%
                    mutate(data_hora = as.POSIXct(.data$data_hora))

                bilhetagem_jae <- registros_jae %>%
                    select("id_veiculo", data_hora = "datetime_transacao") %>%
                    mutate(data_hora = as.POSIXct(.data$data_hora))

                bilhetagem_total <- bind_rows(bilhetagem_rio, bilhetagem_jae) %>% as.data.table()

                # 3.1 Mantém apenas a bilhetagem dos veículos que operaram as linhas escolhidas
                bilhetagem_total <- bilhetagem_total[bilhetagem_total$id_veiculo %in% veiculos_linhas]

                if (nrow(bilhetagem_total) == 0) {
                    message(glue(
                        "⚠️ Nenhuma bilhetagem para os veículos das linhas selecionadas em {data}.",
                        data = data
                    ))
                    return(NULL)
                }

                # 4. Join Bilhetagem + GPS
                setorderv(gps, c("id_veiculo", "data_hora"))
                setorderv(bilhetagem_total, c("id_veiculo", "data_hora"))

                embarques_coords <- gps[
                    bilhetagem_total,
                    on = c("id_veiculo", "data_hora"),
                    roll = "nearest"
                ][, c("id_veiculo", "data_hora", "latitude", "longitude"), with = FALSE]
                setnames(embarques_coords, "data_hora", "horario_embarque")

                # 5. Join Final com Viagens (Linha e Sentido)
                registros_dia_final <- embarques_coords %>%
                    left_join(trip, by = "id_veiculo", relationship = "many-to-many") %>%
                    filter(
                        .data$horario_embarque > .data$datetime_partida_adj &
                            .data$horario_embarque <= .data$datetime_chegada
                    ) %>%
                    select(
                        "id_veiculo",
                        linha = "servico",
                        "sentido",
                        "horario_embarque",
                        "latitude",
                        "longitude",
                        "id_viagem"
                    ) %>%
                    as.data.table()

                # 5.1 Garantia final: somente as linhas escolhidas
                registros_dia_final <- selecionar_por_linha(registros_dia_final, coluna = "linha")

                registros_dia_final
            },
            error = function(e) {
                message(glue(
                    "❌ Erro na tentativa {tentativa} para {data}: {erro}",
                    tentativa = tentativa,
                    data = data,
                    erro = conditionMessage(e)
                ))
                Sys.sleep(delay_segundos)
                NULL
            }
        )

        if (!is.null(resultado_tentativa)) {
            registros_dia_final <- resultado_tentativa
        } else {
            tentativa <- tentativa + 1
        }
    }
    registros_dia_final
}

# 📌 Execução
pb <- progress::progress_bar$new(total = length(datas))
todos_dias_lista <- map(datas, ~ {
    pb$tick()
    processar_dia(.x)
})
registros_final <- bind_rows(Filter(Negate(is.null), todos_dias_lista))

# 📌 Salvamento
if (nrow(registros_final) > 0) {
    caminho_diretorio <- "C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados"
    if (!dir.exists(caminho_diretorio)) dir.create(caminho_diretorio, recursive = TRUE)

    tag_linhas <- paste(gsub("[^A-Za-z0-9]+", "", LINHAS_SELECIONADAS), collapse = "-")
    caminho_saida <- file.path(
        caminho_diretorio,
        glue("base_embarques_linhas_{tag_linhas}_{data_inicio}_{data_fim}.rds")
    )
    saveRDS(registros_final, caminho_saida)

    resumo_linhas <- registros_final %>%
        count(.data$linha, sort = TRUE)

    message("---")
    message(glue("✅ Processamento finalizado! Total: {nrow(registros_final)} embarques."))
    message(glue("🚌 Linhas processadas: {paste(resumo_linhas$linha, collapse = ', ')}"))
    print(resumo_linhas)
    message(glue("💾 Arquivo salvo em: {caminho_saida}"))
} else {
    message("⚠️ Nenhum dado encontrado para salvar.")
}
