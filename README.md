# Análise de Anime — API AniList

Projeto de portfólio (Analista de Dados) que percorre o ciclo completo de um pipeline de dados: da coleta via API pública até um dashboard interativo, passando por modelagem de banco relacional, camada analítica em SQL e tratamento em Python.

**Coleta (API) → Armazenamento (PostgreSQL) → SQL → Tratamento (Python/pandas) → Modelagem dimensional → Power BI**

## Pergunta de negócio

Como nota, popularidade e engajamento do público se comportam entre gêneros e estúdios de anime — e como isso evoluiu ao longo do tempo?

## Stack

- **Coleta:** Python (`requests`), API pública [AniList](https://docs.anilist.co/) (GraphQL)
- **Armazenamento:** PostgreSQL
- **Transformação:** Python (`pandas`), SQL
- **Carga:** SQLAlchemy
- **Visualização:** Power BI

## Status

- ✅ Coleta (`src/coletar_anilist.py`) e tratamento (`src/tratar_dados.py`) completos — 4.378 animes, 376 estúdios e 17 gêneros em `data/processed/`, a partir dos 5.000 animes mais populares da AniList (teto de paginação da própria API).
- ✅ Modelagem dimensional (`sql/ddl.sql`), camada analítica em SQL — views e window functions em `sql/queries_analiticas.sql` — e carga no PostgreSQL (`src/carga_sql.py`) completas.
- ✅ Dashboard no Power BI completo, com 4 páginas (Visão Geral, Ranking, Gênero e Estúdios, Temporadas). Guia de referência em [`docs/guia_powerbi.md`](docs/guia_powerbi.md).

## Como rodar

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Crie um arquivo `.env` na raiz com a variável `DATABASE_URL` apontando para o seu PostgreSQL local, banco `anime_analytics` (veja `.env.example` como referência). Rode `sql/ddl.sql` nesse banco antes da primeira carga.

```bash
python src/coletar_anilist.py   # popula data/raw/anilist/<data>/
python src/tratar_dados.py      # gera data/processed/*.csv
python src/carga_sql.py         # carrega no Postgres
```

## Dashboard

O dashboard completo (Power BI, 4 páginas) está em [`dashboard/anime_dashboard.pbix`](dashboard/anime_dashboard.pbix). Para interagir com os filtros, basta abrir no [Power BI Desktop](https://www.microsoft.com/pt-br/power-platform/products/power-bi/desktop) — gratuito, e não é preciso conexão com banco, já que os dados vêm embutidos no próprio arquivo.

Também disponível:
- **PDF estático** (sem interatividade): [`dashboard/anime_dashboard.pdf`](dashboard/anime_dashboard.pdf)
- **Vídeo demonstrativo**: [assista aqui](https://youtu.be/1ACAOAdmqOw)

## Próximos passos

- Adicionar prints do dashboard e principais insights a esta documentação.
