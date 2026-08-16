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

- ✅ Coleta (`src/coletar_anilist.py`) e tratamento (`src/tratar_dados.py`) completos: 5.000 animes processados em `data/processed/` (teto de paginação da API AniList).
- ✅ Schema (`sql/ddl.sql`) e camada analítica em SQL (views + window functions em `sql/queries_analiticas.sql`) implementados.
- 🚧 Carga da coleta completa no banco (`src/carga_sql.py`) e construção do dashboard no Power BI (guia de referência já escrito em [`docs/guia_powerbi.md`](docs/guia_powerbi.md)).

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

## Próximos passos

- Carregar a coleta completa no PostgreSQL e construir o dashboard no Power BI.
- Adicionar prints do dashboard e principais insights a esta documentação.
