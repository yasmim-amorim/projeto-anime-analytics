# Análise de Anime — API AniList

Projeto de portfólio (Analista de Dados) demonstrando o ciclo completo de um pipeline de dados:

**Coleta (API) → Armazenamento (PostgreSQL) → SQL → Tratamento (Python/pandas) → Modelagem → Power BI → Documentação**

## Pergunta de negócio

Como nota, popularidade e engajamento do público se comportam entre gêneros e estúdios de anime, e como isso evoluiu ao longo do tempo?

## Stack

- **Coleta:** Python (`requests`), API pública [AniList](https://docs.anilist.co/) (GraphQL)
- **Armazenamento:** PostgreSQL
- **Transformação:** Python (`pandas`), SQL
- **Carga:** SQLAlchemy
- **Visualização:** Power BI

## Status

- ✅ Coleta (`src/coletar_anilist.py`, 5.000 animes — teto de paginação da API AniList) e tratamento (`src/tratar_dados.py`, com filtro de conteúdo adulto) completos: 4.378 animes, 376 estúdios, 17 gêneros em `data/processed/`.
- ✅ Schema (`sql/ddl.sql`), camada analítica em SQL (views + window functions em `sql/queries_analiticas.sql`) e carga no PostgreSQL (`src/carga_sql.py`) completos.
- ✅ Dashboard no Power BI completo (4 páginas: Visão Geral, Ranking, Gênero e Estúdios, Temporadas), guia de referência em [`docs/guia_powerbi.md`](docs/guia_powerbi.md).

## Como rodar

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Configure um arquivo `.env` na raiz com a variável `DATABASE_URL` apontando para o seu PostgreSQL local, banco `anime_analytics` (veja `.env.example`). Rode `sql/ddl.sql` nesse banco antes da primeira carga.

```bash
python src/coletar_anilist.py   # popula data/raw/anilist/<data>/
python src/tratar_dados.py      # gera data/processed/*.csv
python src/carga_sql.py         # carrega no Postgres
```

## Dashboard

O dashboard completo (Power BI, 4 páginas — Visão Geral, Ranking, Gênero e Estúdios, Temporadas) está em `dashboard/anime_dashboard.pbix`. Para interagir com os filtros, basta abrir no [Power BI Desktop](https://www.microsoft.com/pt-br/power-platform/products/power-bi/desktop) (gratuito) — os dados já vêm embutidos no arquivo, não é preciso conexão com banco.

Também disponível:
- **PDF estático** (sem interatividade): [`dashboard/anime_dashboard.pdf`](dashboard/anime_dashboard.pdf)
- **Vídeo demonstrativo**: [assista aqui](LINK_DO_YOUTUBE)

## Próximos passos

- Adicionar prints do dashboard e principais insights a esta documentação.
