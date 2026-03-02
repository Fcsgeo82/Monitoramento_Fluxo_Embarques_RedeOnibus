library(shiny)
library(leaflet)
library(leaflet.extras)
library(dplyr)
library(lubridate)
library(ggplot2)
library(tidytransit)
library(sf)
library(DT)

# COM CARREGAMENTO INTERATIVO DE RDS E GTFS / ABA: MAPA ANIMAÇÃO TEMPORAL

# =============================================================================
# 1. CONSTANTES
# =============================================================================

COLUNAS_OBRIGATORIAS_RDS <- c("linha", "sentido", "horario_embarque",
                              "latitude", "longitude", "id_viagem")

# Intervalo em milissegundos entre frames na animação automática (2 segundos)
ANIM_INTERVALO_MS <- 2000

# =============================================================================
# 2. FUNÇÕES AUXILIARES
# =============================================================================

# Calcula o bounding box de um objeto sf e aplica fitBounds no leafletProxy dado.
# Aceita tanto leafletProxy quanto um objeto leaflet diretamente.
zoom_para_rota <- function(mapa_proxy, geo_sf) {
  if (is.null(geo_sf) || nrow(geo_sf) == 0) return(mapa_proxy)
  bb <- st_bbox(geo_sf)
  mapa_proxy %>% fitBounds(
    lng1 = as.numeric(bb["xmin"]), lat1 = as.numeric(bb["ymin"]),
    lng2 = as.numeric(bb["xmax"]), lat2 = as.numeric(bb["ymax"])
  )
}

processar_gtfs <- function(gtfs) {
  gtfs_shapes <- shapes_as_sf(gtfs$shapes)
  
  gtfs$routes %>%
    select(route_id, route_short_name) %>%
    inner_join(gtfs$trips, by = "route_id") %>%
    select(route_short_name, shape_id, direction_id, trip_headsign) %>%
    distinct() %>%
    mutate(
      cod_sentido = case_when(
        grepl("CIRCULAR", trip_headsign, ignore.case = TRUE) ~ "C",
        direction_id == 0 ~ "I",
        direction_id == 1 ~ "V",
        TRUE ~ "I"
      ),
      label_sentido = case_when(
        cod_sentido == "C" ~ paste("🔄 CIRCULAR -", trip_headsign),
        cod_sentido == "I" ~ paste("➡️ IDA -",      trip_headsign),
        cod_sentido == "V" ~ paste("⬅️ VOLTA -",    trip_headsign)
      )
    ) %>%
    inner_join(gtfs_shapes, by = "shape_id") %>%
    st_as_sf() %>%
    st_transform(4326)
}

# =============================================================================
# 3. INTERFACE (UI)
# =============================================================================
ui <- fluidPage(
  tags$head(tags$style(HTML("
    body { background-color: #f4f7f9; }

    .sidebar {
      background: white; padding: 15px; border-radius: 12px;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1);
    }

    .upload-bloco {
      background: #f8f9fa; border: 1px solid #e0e0e0;
      border-radius: 8px; padding: 10px 12px; margin-bottom: 8px;
    }
    .upload-bloco .titulo-bloco { font-weight: bold; font-size: 0.9em; margin-bottom: 4px; }
    .status-msg { margin-top: 4px; font-size: 0.82em; min-height: 18px; }

    .kpi-box { padding: 5px 10px; border-radius: 6px; margin-bottom: 5px;
               color: white; text-align: center; }
    .kpi-box h4 { margin: 2px 0; font-size: 1.1em; font-weight: bold; }
    .kpi-box h5 { margin: 2px 0; font-size: 0.8em; opacity: 0.9; text-transform: uppercase; }
    .kpi-vol    { background: #2980b9; }
    .kpi-reg    { background: #8e44ad; }
    .kpi-alerta { background: #e67e22; }

    .upload-box {
      background: white; border-radius: 12px; padding: 40px; text-align: center;
      box-shadow: 0 4px 10px rgba(0,0,0,0.1); margin-top: 60px;
    }
    .upload-box h3 { color: #2c3e50; }
    .upload-box p  { color: #7f8c8d; }
    .upload-box .checklist { text-align: left; display: inline-block;
                             margin-top: 12px; font-size: 0.95em; }

    /* ── Controles da animação ── */
    .anim-painel {
      background: white; border-radius: 10px; padding: 14px 18px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.08); margin-bottom: 10px;
    }
    .anim-badge {
      display: inline-block; background: #2c3e50; color: white;
      border-radius: 6px; padding: 4px 14px; font-size: 1.4em;
      font-weight: bold; letter-spacing: 2px; margin-bottom: 6px;
    }
    .btn-play {
      background: #27ae60; color: white; border: none;
      border-radius: 6px; padding: 6px 20px; font-size: 1em;
      cursor: pointer; margin-right: 6px;
    }
    .btn-play:hover { background: #219150; }
    .btn-pause {
      background: #e67e22; color: white; border: none;
      border-radius: 6px; padding: 6px 20px; font-size: 1em;
      cursor: pointer;
    }
    .btn-pause:hover { background: #ca6f1e; }
    .kpi-anim {
      display: inline-block; background: #eaf4fb; border-radius: 6px;
      padding: 4px 12px; font-size: 0.9em; color: #2980b9;
      font-weight: bold; margin-top: 4px;
    }
  "))),
  
  titlePanel("🚍 Monitor Operacional SMTR - Gestão de Fluxo"),
  
  sidebarLayout(
    
    # ── SIDEBAR ────────────────────────────────────────────────────────────────
    sidebarPanel(class = "sidebar", width = 3,
                 
                 div(class = "upload-bloco",
                     div(class = "titulo-bloco", "📂 Base de Embarques (.rds)"),
                     fileInput("arquivo_rds", label = NULL,
                               accept = ".rds", buttonLabel = "Selecionar",
                               placeholder = "Nenhum arquivo"),
                     uiOutput("status_rds")
                 ),
                 
                 div(class = "upload-bloco",
                     div(class = "titulo-bloco", "🗺️ GTFS (.zip)"),
                     fileInput("arquivo_gtfs", label = NULL,
                               accept = ".zip", buttonLabel = "Selecionar",
                               placeholder = "Nenhum arquivo"),
                     uiOutput("status_gtfs")
                 ),
                 
                 hr(),
                 
                 conditionalPanel(
                   condition = "output.tudo_carregado == true",
                   
                   selectizeInput("linha_sel", "🚍 Linha:", choices = NULL),
                   uiOutput("filtro_sentido_ui"),
                   sliderInput("hora", "⏰ Intervalo Horário:",
                               min = 0, max = 24, value = c(6, 22), step = 1),
                   hr(),
                   uiOutput("kpi_ui"),
                   hr(),
                   checkboxGroupInput("opcoes_mapa", "Exibir no Mapa:",
                                      choices  = c("Itinerário" = "gtfs", "Clusters" = "clust"),
                                      selected = c("gtfs", "clust")),
                   checkboxInput("heatmap_mode", "🔥 Heatmap de Demanda", value = FALSE),
                   hr(),
                   sliderInput("tol_desvio", "📏 Tolerância Desvio (m):",
                               min = 50, max = 500, value = 150)
                 )
    ),
    
    # ── PAINEL PRINCIPAL ───────────────────────────────────────────────────────
    mainPanel(
      
      conditionalPanel(
        condition = "output.tudo_carregado == false",
        div(class = "upload-box",
            h3("👋 Bem-vindo ao Monitor SMTR"),
            p("Carregue os dois arquivos no painel lateral para iniciar a análise."),
            div(class = "checklist", uiOutput("checklist_arquivos"))
        )
      ),
      
      conditionalPanel(
        condition = "output.tudo_carregado == true",
        tabsetPanel(
          
          # ── Aba 1: Mapa e Demanda ────────────────────────────────────────────
          tabPanel("Mapa e Demanda",
                   leafletOutput("mapa", height = "650px"),
                   br(),
                   plotOutput("grafico_demanda", height = "200px")),
          
          # ── Aba 2: Mapa Animado ──────────────────────────────────────────────
          tabPanel("🎬 Mapa Animado",
                   br(),
                   
                   # Controles próprios da aba (sentido + intervalo + modo visual)
                   fluidRow(
                     column(4,
                            div(class = "upload-bloco",
                                div(class = "titulo-bloco", "🧭 Sentido"),
                                uiOutput("anim_sentido_ui")
                            )
                     ),
                     column(4,
                            div(class = "upload-bloco",
                                div(class = "titulo-bloco", "⏰ Intervalo Horário"),
                                sliderInput("anim_hora", label = NULL,
                                            min = 0, max = 24, value = c(6, 22), step = 1)
                            )
                     ),
                     column(4,
                            div(class = "upload-bloco",
                                div(class = "titulo-bloco", "👁️ Visualização"),
                                radioButtons("anim_modo", label = NULL,
                                             choices  = c("🔥 Heatmap"  = "heat",
                                                          "📍 Pontos"   = "pontos",
                                                          "🔵 Clusters" = "clusters"),
                                             selected = "heat",
                                             inline   = FALSE)
                            )
                     )
                   ),
                   
                   # Painel central da animação: badge de hora + mapa
                   div(class = "anim-painel",
                       fluidRow(
                         column(12, align = "center",
                                # Badge com a hora atual do frame
                                div(class = "anim-badge", textOutput("anim_hora_label", inline = TRUE)),
                                br(),
                                # KPI de embarques no frame atual
                                div(class = "kpi-anim", textOutput("anim_kpi_frame", inline = TRUE))
                         )
                       ),
                       br(),
                       leafletOutput("mapa_anim", height = "520px"),
                       br(),
                       
                       # Controles de navegação
                       fluidRow(
                         column(12, align = "center",
                                
                                # Botões Play / Pause
                                actionButton("anim_play",  "▶ Play",  class = "btn-play"),
                                actionButton("anim_pause", "⏸ Pause", class = "btn-pause"),
                                
                                br(), br(),
                                
                                # Slider manual de frame (hora)
                                uiOutput("anim_slider_ui")
                         )
                       )
                   )
          ),
          
          # ── Aba 3: Regularidade ──────────────────────────────────────────────
          tabPanel("Regularidade (Headway)",
                   br(),
                   plotOutput("grafico_headway", height = "450px")),
          
          # ── Aba 4: Dados das Viagens ─────────────────────────────────────────
          tabPanel("Dados das Viagens",
                   br(),
                   DTOutput("tabela_resumo"))
        )
      )
    )
  )
)

# =============================================================================
# 4. SERVIDOR (SERVER)
# =============================================================================
server <- function(input, output, session) {
  
  # ---------------------------------------------------------------------------
  # 4.1  ESTADOS REATIVOS
  # ---------------------------------------------------------------------------
  
  dados_globais <- reactiveVal(NULL)
  geo_gtfs      <- reactiveVal(NULL)
  
  # Estado interno da animação
  anim_rodando  <- reactiveVal(FALSE)   # TRUE = play em curso
  anim_frame    <- reactiveVal(1L)      # índice do frame atual
  anim_timer    <- reactiveVal(NULL)    # handle do observeEvent de tempo
  
  output$tudo_carregado <- reactive({
    !is.null(dados_globais()) && !is.null(geo_gtfs())
  })
  outputOptions(output, "tudo_carregado", suspendWhenHidden = FALSE)
  
  # ---------------------------------------------------------------------------
  # 4.2  UPLOAD RDS
  # ---------------------------------------------------------------------------
  
  observeEvent(input$arquivo_rds, {
    req(input$arquivo_rds)
    df_raw <- tryCatch(readRDS(input$arquivo_rds$datapath), error = function(e) NULL)
    
    if (is.null(df_raw) || !is.data.frame(df_raw)) {
      output$status_rds <- renderUI(
        p(class="status-msg", style="color:#e74c3c;",
          "❌ Arquivo inválido: não é um data.frame."))
      dados_globais(NULL); return()
    }
    
    faltando <- setdiff(COLUNAS_OBRIGATORIAS_RDS, names(df_raw))
    if (length(faltando) > 0) {
      output$status_rds <- renderUI(
        p(class="status-msg", style="color:#e74c3c;",
          paste0("❌ Colunas ausentes: ", paste(faltando, collapse=", "))))
      dados_globais(NULL); return()
    }
    
    df_proc <- df_raw %>%
      mutate(timestamp    = as.POSIXct(horario_embarque),
             hora_inteira = hour(timestamp),
             hora_decimal = hour(timestamp) + minute(timestamp) / 60)
    
    dados_globais(df_proc)
    output$status_rds <- renderUI(
      p(class="status-msg", style="color:#27ae60;",
        paste0("✅ ", format(nrow(df_proc), big.mark="."), " registros carregados.")))
    
    atualizar_linhas(df_proc, geo_gtfs())
  })
  
  # ---------------------------------------------------------------------------
  # 4.3  UPLOAD GTFS
  # ---------------------------------------------------------------------------
  
  observeEvent(input$arquivo_gtfs, {
    req(input$arquivo_gtfs)
    gtfs_raw <- tryCatch(read_gtfs(input$arquivo_gtfs$datapath), error = function(e) NULL)
    
    if (is.null(gtfs_raw)) {
      output$status_gtfs <- renderUI(
        p(class="status-msg", style="color:#e74c3c;",
          "❌ Não foi possível ler o arquivo GTFS."))
      geo_gtfs(NULL); return()
    }
    
    faltando <- setdiff(c("routes","trips","shapes"), names(gtfs_raw))
    if (length(faltando) > 0) {
      output$status_gtfs <- renderUI(
        p(class="status-msg", style="color:#e74c3c;",
          paste0("❌ Tabelas ausentes no GTFS: ", paste(faltando, collapse=", "))))
      geo_gtfs(NULL); return()
    }
    
    geo_proc <- tryCatch(processar_gtfs(gtfs_raw), error = function(e) NULL)
    if (is.null(geo_proc) || nrow(geo_proc) == 0) {
      output$status_gtfs <- renderUI(
        p(class="status-msg", style="color:#e74c3c;",
          "❌ Erro ao processar geometrias do GTFS."))
      geo_gtfs(NULL); return()
    }
    
    geo_gtfs(geo_proc)
    n_rotas <- length(unique(geo_proc$route_short_name))
    output$status_gtfs <- renderUI(
      p(class="status-msg", style="color:#27ae60;",
        paste0("✅ ", format(n_rotas, big.mark="."), " rotas carregadas.")))
    
    atualizar_linhas(dados_globais(), geo_proc)
  })
  
  # ---------------------------------------------------------------------------
  # 4.4  HELPER: atualiza seletor de linhas
  # ---------------------------------------------------------------------------
  
  atualizar_linhas <- function(df, geo) {
    if (is.null(df) || is.null(geo)) return()
    linhas_comuns <- sort(intersect(unique(df$linha), unique(geo$route_short_name)))
    opcoes <- if (length(linhas_comuns) > 0) linhas_comuns else sort(unique(df$linha))
    updateSelectizeInput(session, "linha_sel", choices=opcoes, selected=opcoes[1])
  }
  
  # ---------------------------------------------------------------------------
  # 4.5  CHECKLIST
  # ---------------------------------------------------------------------------
  
  output$checklist_arquivos <- renderUI({
    tagList(
      p(if (!is.null(dados_globais())) "✅ Base de embarques (.rds) carregada"
        else "⬜ Base de embarques (.rds) — pendente"),
      p(if (!is.null(geo_gtfs()))      "✅ GTFS (.zip) carregado"
        else "⬜ GTFS (.zip) — pendente")
    )
  })
  
  # ---------------------------------------------------------------------------
  # 4.6  FILTROS COMPARTILHADOS (painel principal)
  # ---------------------------------------------------------------------------
  
  output$filtro_sentido_ui <- renderUI({
    req(input$linha_sel, geo_gtfs())
    opcoes_df <- geo_gtfs() %>%
      filter(route_short_name == input$linha_sel) %>%
      st_drop_geometry() %>% select(label_sentido, cod_sentido) %>% distinct()
    radioButtons("sentido_sel", "🧭 Sentido:",
                 choices = setNames(opcoes_df$cod_sentido, opcoes_df$label_sentido))
  })
  
  df_analisado <- reactive({
    req(input$linha_sel, input$sentido_sel, dados_globais(), geo_gtfs())
    df <- dados_globais() %>%
      filter(linha == input$linha_sel, sentido == input$sentido_sel,
             between(hora_decimal, input$hora[1], input$hora[2]))
    if (nrow(df) == 0) return(df)
    geo <- geo_gtfs() %>%
      filter(route_short_name == input$linha_sel, cod_sentido == input$sentido_sel)
    if (nrow(geo) > 0) {
      df_sf <- st_as_sf(df, coords = c("longitude","latitude"), crs = 4326)
      df$fora_rota <- as.numeric(st_distance(df_sf, geo)) > input$tol_desvio
    } else { df$fora_rota <- FALSE }
    df
  })
  
  df_viagens <- reactive({
    df <- df_analisado()
    if (nrow(df) == 0) return(NULL)
    df %>%
      group_by(id_viagem) %>%
      summarise(horario_inicio=min(timestamp), horario_fim=max(timestamp),
                embarques=n(), fora_rota_count=sum(fora_rota), .groups="drop") %>%
      arrange(horario_inicio) %>%
      mutate(headway = as.numeric(difftime(horario_inicio, lag(horario_inicio), units="mins")))
  })
  
  output$kpi_ui <- renderUI({
    df <- df_analisado(); viagens <- df_viagens()
    if (nrow(df) == 0) return(p("Sem dados para os filtros selecionados."))
    m_headway <- if (!is.null(viagens)) round(mean(viagens$headway, na.rm=TRUE),1) else 0
    m_desvio  <- round((sum(df$fora_rota)/nrow(df))*100, 1)
    tagList(
      div(class="kpi-box kpi-vol",    h5("Total Embarques"), h4(format(nrow(df), big.mark="."))),
      div(class="kpi-box kpi-reg",    h5("Headway Médio"),   h4(paste0(m_headway," min"))),
      div(class="kpi-box kpi-alerta", h5("% Fora de Rota"),  h4(paste0(m_desvio,"%")))
    )
  })
  
  # ---------------------------------------------------------------------------
  # 4.7  MAPA PRINCIPAL
  # ---------------------------------------------------------------------------
  
  output$mapa <- renderLeaflet({
    leaflet() %>% addProviderTiles("CartoDB.Positron") %>%
      setView(lng=-43.3, lat=-22.9, zoom=11)
  })
  
  observe({
    req(dados_globais(), geo_gtfs())
    df  <- df_analisado()
    geo <- geo_gtfs() %>%
      filter(route_short_name==input$linha_sel, cod_sentido==input$sentido_sel)
    
    proxy <- leafletProxy("mapa") %>%
      clearGroup("itinerario") %>% clearGroup("embarques") %>% clearHeatmap()
    
    if ("gtfs" %in% input$opcoes_mapa && nrow(geo) > 0)
      proxy %>% addPolylines(data=geo, color="#ff4757", weight=4, opacity=0.8, group="itinerario")
    
    # Zoom automático ao traçado da linha sempre que ela mudar
    zoom_para_rota(proxy, geo)
    
    if (nrow(df) > 0) {
      if (input$heatmap_mode) {
        proxy %>% addHeatmap(data=df, lng=~longitude, lat=~latitude, radius=15)
      } else {
        proxy %>% addCircleMarkers(data=df, lng=~longitude, lat=~latitude, radius=5,
                                   color=~ifelse(fora_rota,"#e67e22","#1e3c72"), fillOpacity=0.7, group="embarques",
                                   clusterOptions=if("clust" %in% input$opcoes_mapa) markerClusterOptions() else NULL)
      }
    }
  })
  
  output$grafico_demanda <- renderPlot({
    df_plot <- df_analisado() %>%
      group_by(hora_inteira) %>% summarise(total=n(), .groups="drop")
    ggplot(df_plot, aes(x=hora_inteira, y=total)) +
      geom_col(fill="#2980b9") + scale_x_continuous(breaks=0:23) +
      labs(title="Volume por Hora", x="Hora do Dia", y="Embarques") + theme_minimal()
  })
  
  output$grafico_headway <- renderPlot({
    hd <- df_viagens(); req(hd)
    min_time <- lubridate::floor_date(min(hd$horario_inicio),   "hour")
    max_time <- lubridate::ceiling_date(max(hd$horario_inicio), "hour")
    ggplot(hd, aes(x=horario_inicio, y=headway)) +
      geom_line(color="#8e44ad", linewidth=1.2) +
      geom_point(color="#8e44ad", size=4) +
      scale_x_datetime(breaks=seq.POSIXt(min_time,max_time,by="1 hour"), date_labels="%H:00") +
      labs(title="Análise de Regularidade entre Partidas",
           x="Horário de Início da Viagem", y="Intervalo (Minutos)") +
      theme_minimal() +
      theme(axis.title=element_text(size=14,face="bold"),
            axis.text=element_text(size=12,color="black"),
            panel.grid.minor=element_blank())
  })
  
  output$tabela_resumo <- renderDT({
    req(df_viagens())
    df_viagens() %>%
      mutate(Início=format(horario_inicio,"%H:%M:%S"), Fim=format(horario_fim,"%H:%M:%S"),
             `Headway (m)`=ifelse(is.na(headway),"-",round(headway,1))) %>%
      select(id_viagem, Início, Fim, `Headway (m)`,
             Embarques=embarques, `Fora Rota`=fora_rota_count) %>%
      datatable(rownames=FALSE, options=list(pageLength=10, scrollX=TRUE))
  })
  
  # ===========================================================================
  # 4.8  ABA DE MAPA ANIMADO
  # ===========================================================================
  
  # ── Filtro de sentido próprio da aba animada ─────────────────────────────────
  output$anim_sentido_ui <- renderUI({
    req(input$linha_sel, geo_gtfs())
    opcoes_df <- geo_gtfs() %>%
      filter(route_short_name == input$linha_sel) %>%
      st_drop_geometry() %>% select(label_sentido, cod_sentido) %>% distinct()
    radioButtons("anim_sentido_sel", label = NULL,
                 choices = setNames(opcoes_df$cod_sentido, opcoes_df$label_sentido))
  })
  
  # ── Reactive: dados da aba animada (linha + sentido + intervalo próprios) ────
  df_anim_base <- reactive({
    req(input$linha_sel, input$anim_sentido_sel, dados_globais())
    dados_globais() %>%
      filter(linha   == input$linha_sel,
             sentido == input$anim_sentido_sel,
             between(hora_decimal, input$anim_hora[1], input$anim_hora[2]))
  })
  
  # ── Reactive: vetor de horas (frames) disponíveis no intervalo selecionado ──
  frames_horas <- reactive({
    df <- df_anim_base()
    if (nrow(df) == 0) return(integer(0))
    seq(input$anim_hora[1], input$anim_hora[2] - 1L, by = 1L)
  })
  
  # Reseta o frame para 1 sempre que os filtros da aba mudarem
  observeEvent(list(input$linha_sel, input$anim_sentido_sel, input$anim_hora), {
    anim_frame(1L)
    anim_rodando(FALSE)
  })
  
  # ── Slider dinâmico de frame — usa horas reais como valores e labels ─────────
  output$anim_slider_ui <- renderUI({
    horas <- frames_horas()
    if (length(horas) == 0) return(NULL)
    
    # O slider usa diretamente as horas reais (ex: 6..21) como valores,
    # eliminando a conversão índice → hora e tornando os ticks legíveis.
    tagList(
      sliderInput("anim_frame_slider",
                  label  = "⏱️ Navegar por hora:",
                  min    = horas[1],
                  max    = horas[length(horas)],
                  value  = horas[anim_frame()],
                  step   = 1L,
                  width  = "90%",
                  ticks  = TRUE),
      
      # JS: dispara input a cada movimento do mouse (não só ao soltar),
      # habilitando atualização em tempo real do mapa enquanto arrasta.
      tags$script(HTML("
        $(document).ready(function() {
          // Aguarda o slider ser renderizado antes de vincular o evento
          setTimeout(function() {
            var slider = document.getElementById('anim_frame_slider');
            if (slider) {
              slider.addEventListener('input', function() {
                // Força Shiny a receber o valor atual enquanto arrasta
                Shiny.setInputValue('anim_frame_slider', parseInt(this.value),
                                    {priority: 'event'});
              });
            }
          }, 500);
        });
      "))
    )
  })
  
  # Sincroniza slider (hora real) → índice interno do frame
  observeEvent(input$anim_frame_slider, {
    horas <- frames_horas()
    if (length(horas) == 0) return()
    # Converte hora real de volta para índice (posição no vetor de frames)
    idx <- which(horas == input$anim_frame_slider)
    if (length(idx) > 0) anim_frame(idx[1])
  }, ignoreInit = TRUE)
  
  # ── Botões Play / Pause ──────────────────────────────────────────────────────
  observeEvent(input$anim_play, {
    horas <- frames_horas()
    if (length(horas) == 0) return()
    # Se já estava no último frame, reinicia do começo
    if (anim_frame() >= length(horas)) anim_frame(1L)
    anim_rodando(TRUE)
  })
  
  observeEvent(input$anim_pause, {
    anim_rodando(FALSE)
  })
  
  # ── Timer reativo: avança frame automaticamente enquanto play ativo ──────────
  observe({
    req(anim_rodando())
    invalidateLater(ANIM_INTERVALO_MS, session)
    
    isolate({
      horas <- frames_horas()
      if (length(horas) == 0) { anim_rodando(FALSE); return() }
      
      prox <- anim_frame() + 1L
      if (prox > length(horas)) {
        # Chegou ao último frame: para automaticamente
        anim_rodando(FALSE)
      } else {
        anim_frame(prox)
        # Mantém slider sincronizado com hora real correspondente ao novo frame
        updateSliderInput(session, "anim_frame_slider", value = horas[prox])
      }
    })
  })
  
  # ── Label da hora atual ──────────────────────────────────────────────────────
  output$anim_hora_label <- renderText({
    horas <- frames_horas()
    if (length(horas) == 0) return("—")
    h <- horas[anim_frame()]
    sprintf("%02d:00 – %02d:59", h, h)
  })
  
  # ── KPI do frame atual ───────────────────────────────────────────────────────
  output$anim_kpi_frame <- renderText({
    horas <- frames_horas()
    if (length(horas) == 0) return("")
    h  <- horas[anim_frame()]
    df <- df_anim_base() %>% filter(hora_inteira == h)
    paste0(format(nrow(df), big.mark="."), " embarques neste frame")
  })
  
  # ── Mapa animado base (renderizado uma vez) ──────────────────────────────────
  output$mapa_anim <- renderLeaflet({
    leaflet() %>% addProviderTiles("CartoDB.Positron") %>%
      setView(lng=-43.3, lat=-22.9, zoom=11)
  })
  
  # ── Observer 1: zoom — só dispara quando linha ou sentido mudam ─────────────
  # Separado do observer de frames para não resetar o zoom ao animar.
  observeEvent(list(input$linha_sel, input$anim_sentido_sel), {
    req(geo_gtfs(), input$anim_sentido_sel)
    geo <- geo_gtfs() %>%
      filter(route_short_name == input$linha_sel,
             cod_sentido      == input$anim_sentido_sel)
    zoom_para_rota(leafletProxy("mapa_anim"), geo)
  })
  
  # ── Observer 2: conteúdo — atualiza camadas a cada frame, SEM mexer no zoom ─
  observe({
    req(dados_globais(), geo_gtfs(), input$anim_sentido_sel, input$anim_modo)
    horas <- frames_horas()
    if (length(horas) == 0) return()
    
    h  <- horas[isolate(anim_frame())]   # hora do frame atual
    df <- df_anim_base() %>% filter(hora_inteira == h)
    
    geo <- geo_gtfs() %>%
      filter(route_short_name == input$linha_sel,
             cod_sentido      == input$anim_sentido_sel)
    
    # Limpa apenas as camadas de dados — não toca na viewport do mapa
    proxy <- leafletProxy("mapa_anim") %>%
      clearGroup("anim_itinerario") %>%
      clearGroup("anim_pontos") %>%
      clearHeatmap()
    
    # Itinerário como referência espacial fixa em todos os frames
    if (nrow(geo) > 0)
      proxy %>% addPolylines(data=geo, color="#ff4757", weight=4,
                             opacity=0.7, group="anim_itinerario")
    
    if (nrow(df) > 0) {
      if (input$anim_modo == "heat") {
        proxy %>% addHeatmap(data=df, lng=~longitude, lat=~latitude,
                             radius=18, blur=25, max=0.8)
      } else if (input$anim_modo == "clusters") {
        proxy %>% addCircleMarkers(data=df, lng=~longitude, lat=~latitude,
                                   radius=5, color="#1e3c72", fillColor="#2980b9",
                                   fillOpacity=0.75, weight=1, group="anim_pontos",
                                   clusterOptions=markerClusterOptions())
      } else {
        proxy %>% addCircleMarkers(data=df, lng=~longitude, lat=~latitude,
                                   radius=5, color="#1e3c72", fillColor="#2980b9",
                                   fillOpacity=0.75, weight=1, group="anim_pontos")
      }
    }
  }) |> bindEvent(anim_frame(), input$anim_modo, input$anim_sentido_sel,
                  input$anim_hora, input$linha_sel)
  
}

# =============================================================================
# Inicializa a aplicação
# =============================================================================
shinyApp(ui, server)