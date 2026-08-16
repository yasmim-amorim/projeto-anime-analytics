# Análise de Anime — API AniList

> 🚧 Projeto em andamento.

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

- ✅ Coleta (`src/coletar_anilist.py`, GraphQL com retry/backoff), banco (`sql/ddl.sql`), tratamento (`src/tratar_dados.py`) e camada analítica em SQL (views + window functions em `sql/queries_analiticas.sql`) implementados.
- 🚧 Rodando a coleta completa (~1.500 animes) e recarregando o banco com o volume real de dados.
- 🚧 Power BI: guia de referência escrito ([`docs/guia_powerbi.md`](docs/guia_powerbi.md)), dashboard ainda não construído — depende da coleta completa.

Detalhes do plano completo, com checklist por etapa, em [`plano-de-acao-projeto-anime.md`](plano-de-acao-projeto-anime.md).

## Nota histórica

O projeto passou por duas fontes de dados antes da atual:

1. Começou como análise de e-commerce com a API do Mercado Livre — abandonada porque acesso a catálogo/busca de produtos exige aprovação no Developer Partner Program (GMV mínimo de R$2.500.000/mês, inviável para projeto pessoal).
2. Migrou para a API Jikan (MyAnimeList) — funcionou na exploração inicial, mas a coleta em escala esbarrou em instabilidade sistemática do backend da Jikan ao raspar o MyAnimeList ao vivo.

Detalhes completos de ambas as investigações em [`docs/historico/`](docs/historico/README.md).

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

_Este README será expandido com arquitetura, prints do dashboard e insights ao final do projeto._
