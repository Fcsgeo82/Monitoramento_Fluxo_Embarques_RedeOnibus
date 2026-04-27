# 🚍 Monitoramento de Fluxo de Embarques - Rede de Ônibus

[![R](https://img.shields.io/badge/R-4.0%2B-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Shiny-Framework-blueviolet.svg)](https://shiny.posit.co/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Sistema avançado para extração, processamento e visualização de dados de embarques de ônibus. Este projeto integra dados de bilhetagem (JAE e RioCard), telemetria GPS e especificações GTFS para fornecer uma visão analítica completa da operação de transporte.

---

## ✨ Funcionalidades Principais

*   **📊 Consolidação de Dados**: Integração automática entre registros de bilhetagem e coordenadas de GPS.
*   **🗺️ Mapas Interativos**: Visualização espacial de embarques com suporte a clusters e heatmaps.
*   **🎬 Animação Temporal**: Modo de reprodução que permite observar a dinâmica dos embarques ao longo das horas do dia.
*   **📈 Análise de Regularidade**: Cálculo automático de *headway* (intervalo entre partidas) para gestão da frequência.
*   **📍 Auditoria Espacial**: Identificação de embarques realizados fora do itinerário planejado (GTFS).

---

## 🛠️ Tecnologias Utilizadas

O projeto é construído sobre o ecossistema R, utilizando as seguintes bibliotecas principais:

| Categoria | Bibliotecas |
| :--- | :--- |
| **Backend & Dados** | `data.table`, `dplyr`, `sf`, `lubridate`, `glue` |
| **Integração Cloud** | `bigrquery`, `basedosdados`, `googlesheets4` |
| **Visualização** | `shiny`, `leaflet`, `ggplot2`, `DT`, `leaflet.extras` |
| **Trânsito & GTFS** | `tidytransit`, `h3jsr` |

---

## 🚀 Como Executar

### 1. Pré-requisitos

Certifique-se de ter o **R (>= 4.0)** instalado. Recomendamos o uso do **RStudio**.

### 2. Instalação de Dependências

Instale todos os pacotes necessários executando o seguinte comando no console do R:

```r
install.packages(c("data.table", "sf", "dplyr", "lubridate", "h3jsr", 
                   "googlesheets4", "bigrquery", "basedosdados", "glue", 
                   "purrr", "progress", "shiny", "leaflet", "leaflet.extras", 
                   "ggplot2", "tidytransit", "DT"))
```

*Ou utilize o arquivo `requirements.txt` como referência.*

### 3. Configuração de Autenticação

Para extrair dados do BigQuery, você precisará de uma chave de serviço do Google Cloud (JSON).
Edite o arquivo `1. Dados_embarques_GPS.R` e aponte para o caminho correto do seu arquivo de credenciais:

```r
bq_auth(path = "C:/R_SMTR/rj-smtr-felipe-coriolano-siqueira.json", cache = FALSE)
```

### 4. Fluxo de Trabalho

1.  **Extração**: Execute `1. Dados_embarques_GPS.R` para processar os dados brutos e gerar o arquivo `.rds`.
2.  **Visualização**: Execute `2.1. Mapa_fluxo_embarques_v2.R` para abrir o dashboard Shiny.
3.  **Upload**: No dashboard, carregue o arquivo `.rds` gerado e o arquivo `.zip` do GTFS correspondente.

---

## 📂 Estrutura do Projeto

*   `1. Dados_embarques_GPS.R`: Script de extração e processamento pesado via BigQuery.
*   `2.1. Mapa_fluxo_embarques_v2.R`: Interface do Dashboard Shiny.
*   `DESCRIPTION`: Metadados do projeto e lista de dependências.
*   `requirements.txt`: Lista simplificada de bibliotecas.

---

## 📄 Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

---
*Desenvolvido para a Secretaria Municipal de Transportes do Rio de Janeiro.*
