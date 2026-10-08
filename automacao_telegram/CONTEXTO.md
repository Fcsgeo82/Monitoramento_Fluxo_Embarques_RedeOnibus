# Contexto do Projeto — Automação de Relatório Diário via Telegram

*Última atualização: 06/08/2026*

---

## O que é este projeto

Pipeline de automação que transforma dois scripts R de análise de embarques de ônibus (SMTR/RJ) em um **relatório diário enviado automaticamente via bot do Telegram**.

---

## Scripts originais (não modificar)

| Arquivo | O que faz |
|---------|-----------|
| `1. Dados_embarques_GPS.R` | Consulta BigQuery (bilhetagem JAE + RioCard + **GPS Ônibus SPPO** + **viagens inferidas**), cruza as fontes e salva `.rds` com todos os embarques georeferenciados do dia |
| `2.1. Mapa_fluxo_embarques_v2.R` | App Shiny interativo que consome o `.rds` + GTFS e exibe mapas, animações, headway e tabela de viagens |

O `.rds` gerado pelo Script 1 tem as colunas: `id_veiculo`, `linha`, `sentido`, `tipo_usuario`, `horario_embarque`, `latitude`, `longitude`, `id_viagem`.

---

## O que foi construído

Todos os arquivos novos vivem em `automacao_telegram/` — os scripts originais foram preservados integralmente.

| Arquivo | Finalidade |
|---------|-----------|
| `config.R` | Centraliza credenciais (token e chat_id via variáveis de ambiente) e parâmetros configuráveis (faixas horárias, threshold de headway, caminhos) |
| `relatorio_pdf_rede.R` | Lê o `.rds`, calcula KPIs da rede e métricas por linha/sentido/faixa horária, gera `mensagem_kpis.txt` (2 blocos) e `relatorio_rede_YYYY-MM-DD.pdf` via pacote `gt` |
| `telegram_sender.R` | Funções `telegram_send_text()`, `telegram_send_document()` e wrapper `enviar_relatorio_mvp()` usando `httr2` |
| `run_daily.R` | Orquestrador: adapta datas do Script 1 em tempo de execução (sem editar o arquivo), gera os artefatos e envia ao Telegram |
| `PLANO_IMPLEMENTACAO.md` | Plano completo por etapas com código de referência para todas as entregas, incluindo as futuras |
| `SETUP_TELEGRAM.md` | Passo a passo: criação do bot (BotFather), obtenção do `chat_id`, configuração de variáveis de ambiente no Windows |
| `requirements.txt` | Lista de pacotes R necessários, organizados por componente |
| `output/` | Pasta de destino dos artefatos gerados em cada execução |

---

## Fontes de Dados Atualizadas (BigQuery)

| Tabela Original | Tabela Atual | Observação |
|-----------------|--------------|------------|
| `rj-smtr.br_rj_riodejaneiro_veiculos.gps_sppo` | `rj-smtr.monitoramento.gps_onibus_sppo` | Coluna `timestamp_gps` → `datetime_gps`; adicionado campo `servico` |
| `rj-smtr.projeto_subsidio_sppo.viagem_completa` | `rj-smtr.monitoramento_interno.viagem_inferida` | Coluna `servico_informado` → `servico` |

---

## Faixas horárias adotadas

| Código | Período |
|--------|---------|
| `madrugada` | 00h – 05h |
| `pico_manha` | 05h – 09h |
| `entrepico` | 09h – 15h |
| `pico_tarde` | 15h – 19h |
| `noturno` | 19h – 24h |

Headway médio é calculado apenas para `pico_manha`, `entrepico` e `pico_tarde`.

---

## Estado atual do MVP

**Testado e funcionando (06/08/2026):**
- ✅ `telegram_send_text()` — bot envia mensagens ao grupo corretamente
- ✅ `telegram_send_document()` — bot envia PDF ao grupo corretamente
- ✅ `relatorio_pdf_rede.R` — testado com `base_embarques_final_2026-08-05.rds`; gera `mensagem_kpis.txt` (2 blocos) e PDF sem erros
- ✅ `enviar_relatorio_mvp()` — KPIs (bloco 1 + bloco 2) + PDF entregues ao grupo do Telegram
- ✅ `run_daily.R` — **pipeline completo funcionando**: extração BigQuery → geração KPIs/PDF → envio Telegram
- ✅ **Autenticação via Service Account (JSON)** — configurada e testada no Script 1
- ✅ **Correção `if_else` → `case_when`** — compatibilidade de tipos POSIXct no processamento de viagens
- ✅ **Timeout PDF resolvido** — parâmetro `expand = 10` no `gtsave()` para tabelas grandes

**Pendente:**
- ⬜ `grafico_demanda.png` — volume de embarques por hora (ggplot já existe no Shiny)
- ⬜ `grafico_headway.png` — regularidade entre partidas (ggplot já existe no Shiny)
- ⬜ `mapa_embarques.png` — mapa de calor estático (leaflet + webshot2)
- ⬜ Agendamento via Windows Task Scheduler (Etapa 6 do `PLANO_IMPLEMENTACAO.md`)

---

## Credenciais do Telegram

- Gravadas como variáveis de ambiente do usuário Windows via PowerShell (`SetEnvironmentVariable(..., "User")`)
- Lidas em `config.R` via `Sys.getenv()` — **não estão hardcoded em nenhum arquivo**
- Arquivo `.Renviron` criado em `C:\Users\02626810\.Renviron` com as duas variáveis — carregado automaticamente a cada início de sessão R
- O `chat_id` configurado é de um **grupo** (valor negativo)

---

## Próximos passos

1. **Agendar no Task Scheduler** — Etapa 6 do `PLANO_IMPLEMENTACAO.md`.
2. **Implementar gráficos e mapa** — quando oportuno, criar `relatorio_estatico.R` aproveitando a lógica de ggplot já presente no Script 2.

---

## Decisões técnicas relevantes

- O Script 1 tem `rm(list=ls())` no início — o `run_daily.R` remove essa linha via regex antes de avaliar o script, evitando que o ambiente corrente seja apagado.
- O `relatorio_pdf_rede.R` aceita `data_ref` pré-definida no ambiente (útil para testes com datas históricas); caso contrário, usa `Sys.Date() - 1`.
- O PDF usa `gt::gtsave()`, que depende do Chrome/Chromium via `webshot2`. Adicionado `expand = 10` para evitar timeout em tabelas grandes.
- `fmt_missing()` do `gt` está depreciado desde v0.6.0 — corrigido para `sub_missing()` no script.
- **Autenticação Google:** O uso de Service Account via arquivo JSON nomeado resolveu inconsistências de permissão e problemas de autenticação interativa (OAuth).
- **Correção de tipos:** `if_else` do dplyr é estrito com tipos; substituição por `case_when` + conversão explícita `as.POSIXct()` resolveu erro de "In argument" para `datetime_partida_adj`.

---

## Arquivos .rds disponíveis para teste

Localizados em `C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados/`:

```
base_embarques_final_2026-08-05.rds   ← mais recente (pipeline testado)
base_embarques_final_2026-07-23.rds
base_embarques_final_2026-07-22.rds
base_embarques_final_2026-07-21.rds
base_embarques_final_2026-07-20.rds
base_embarques_final_2026-07-15.rds
base_embarques_final_2026-07-14.rds
base_embarques_final_2026-07-13.rds
(+ outros anteriores)
```
