# Contexto do Projeto — Automação de Relatório Diário via Telegram

*Última atualização: 15/07/2026*

---

## O que é este projeto

Pipeline de automação que transforma dois scripts R de análise de embarques de ônibus (SMTR/RJ) em um **relatório diário enviado automaticamente via bot do Telegram**.

---

## Scripts originais (não modificar)

| Arquivo | O que faz |
|---------|-----------|
| `1. Dados_embarques_GPS.R` | Consulta BigQuery (bilhetagem JAE + RioCard + GPS SPPO), cruza as fontes e salva `.rds` com todos os embarques georeferenciados do dia |
| `2.1. Mapa_fluxo_embarques_v2.R` | App Shiny interativo que consome o `.rds` + GTFS e exibe mapas, animações, headway e tabela de viagens |

O `.rds` gerado pelo Script 1 tem as colunas: `id_veiculo`, `linha`, `sentido`, `tipo_usuario`, `horario_embarque`, `latitude`, `longitude`, `id_viagem`.

---

## O que foi construído

Todos os arquivos novos vivem em `automacao_telegram/` — os scripts originais foram preservados integralmente.

| Arquivo | Finalidade |
|---------|-----------|
| `config.R` | Centraliza credenciais (token e chat_id via variáveis de ambiente) e parâmetros configuráveis (faixas horárias, threshold de headway, caminhos) |
| `relatorio_pdf_rede.R` | Lê o `.rds`, calcula KPIs da rede e métricas por linha/sentido/faixa horária, gera `mensagem_kpis.txt` e `relatorio_rede_YYYY-MM-DD.pdf` via pacote `gt` |
| `telegram_sender.R` | Funções `telegram_send_text()`, `telegram_send_document()` e wrapper `enviar_relatorio_mvp()` usando `httr2` |
| `run_daily.R` | Orquestrador: adapta datas do Script 1 em tempo de execução (sem editar o arquivo), gera os artefatos e envia ao Telegram |
| `PLANO_IMPLEMENTACAO.md` | Plano completo por etapas com código de referência para todas as entregas, incluindo as futuras |
| `SETUP_TELEGRAM.md` | Passo a passo: criação do bot (BotFather), obtenção do `chat_id`, configuração de variáveis de ambiente no Windows |
| `requirements.txt` | Lista de pacotes R necessários, organizados por componente |
| `output/` | Pasta de destino dos artefatos gerados em cada execução |

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

**Testado e funcionando:**
- ✅ `telegram_send_text()` — bot envia mensagens ao grupo corretamente
- ✅ `telegram_send_document()` — bot envia PDF ao grupo corretamente
- ✅ `relatorio_pdf_rede.R` — testado com `base_embarques_final_2026-03-16.rds`; gera `mensagem_kpis.txt` e PDF sem erros
- ✅ `enviar_relatorio_mvp()` — KPIs + PDF entregues ao grupo do Telegram
- ✅ **Autenticação via Service Account (JSON)** — configurada e testada no Script 1

**Pendente:**
- ⏳ `run_daily.R` completo (extração BigQuery + geração + envio) — ver seção de próximos passos
- ⬜ `grafico_demanda.png` — volume de embarques por hora (ggplot já existe no Shiny)
- ⬜ `grafico_headway.png` — regularidade entre partidas (ggplot já existe no Shiny)
- ⬜ `mapa_embarques.png` — mapa de calor estático (leaflet + webshot2)
- ⬜ Agendamento via Windows Task Scheduler (Etapa 6 do plano)

---

## Credenciais do Telegram

- Gravadas como variáveis de ambiente do usuário Windows via PowerShell (`SetEnvironmentVariable(..., "User")`)
- Lidas em `config.R` via `Sys.getenv()` — **não estão hardcoded em nenhum arquivo**
- Arquivo `.Renviron` criado em `C:\Users\02626810\.Renviron` com as duas variáveis — carregado automaticamente a cada início de sessão R
- O `chat_id` configurado é de um **grupo** (valor negativo)

---

## Próximos passos

1. **Concluir o teste completo do `run_daily.R`** — garantir que a extração BigQuery via Service Account funcione perfeitamente no loop.
2. **Agendar no Task Scheduler** — Etapa 6 do `PLANO_IMPLEMENTACAO.md`.
3. **Implementar gráficos e mapa** — quando oportuno, criar `relatorio_estatico.R` aproveitando a lógica de ggplot já presente no Script 2.

---

## Decisões técnicas relevantes

- O Script 1 tem `rm(list=ls())` no início — o `run_daily.R` remove essa linha via regex antes de avaliar o script, evitando que o ambiente corrente seja apagado.
- O `relatorio_pdf_rede.R` aceita `data_ref` pré-definida no ambiente (útil para testes com datas históricas); caso contrário, usa `Sys.Date() - 1`.
- O PDF usa `gt::gtsave()`, que depende do Chrome/Chromium via `webshot2`.
- `fmt_missing()` do `gt` está depreciado desde v0.6.0 — corrigido para `sub_missing()` no script.
- **Autenticação Google:** O uso de Service Account via arquivo JSON nomeado resolveu inconsistências de permissão e problemas de autenticação interativa (OAuth).

---

## Arquivos .rds disponíveis para teste

Localizados em `C:/R_SMTR/projetos/Mapa_dinâmico_embarques/Resultados/`:

```
base_embarques_final_2026-03-16.rds   ← mais recente, usado nos testes
base_embarques_final_2026-03-10.rds
base_embarques_final_2026-02-24.rds
base_embarques_final_2026-02-23.rds
base_embarques_final_2026-02-09.rds
base_embarques_final_2026-02-04.rds
(+ outros com nome diferente)
```
