# Análise de Anime — API Jikan

> 🚧 Projeto em andamento.

Projeto de portfólio (Analista de Dados) demonstrando o ciclo completo de um pipeline de dados:

**Coleta (API) → Armazenamento (PostgreSQL) → SQL → Tratamento (Python/pandas) → Modelagem → Power BI → Documentação**

## Pergunta de negócio

Como nota, popularidade e engajamento do público se comportam entre gêneros e estúdios de anime, e como isso evoluiu ao longo do tempo?

## Stack

- **Coleta:** Python (`requests`), API pública [Jikan](https://docs.api.jikan.moe/) (MyAnimeList)
- **Armazenamento:** PostgreSQL
- **Transformação:** Python (`pandas`), SQL
- **Carga:** SQLAlchemy
- **Visualização:** Power BI

## Status

Setup do projeto migrado da tentativa inicial com a API do Mercado Livre (ver [Nota histórica](docs/historico/README.md)) para a API Jikan. Coleta e modelagem em andamento.

Detalhes do plano completo em [`plano-de-acao-projeto-anime.md`](plano-de-acao-projeto-anime.md).

## Nota histórica

O projeto começou como uma análise de e-commerce com a API do Mercado Livre. Após investigação extensa (OAuth completo, conta verificada, múltiplos endpoints testados), confirmamos que o acesso a catálogo/busca de produtos exige aprovação no Developer Partner Program do Mercado Livre — com GMV mínimo de R$2.500.000/mês, inviável para um projeto pessoal. Essa investigação está documentada em [`docs/historico/`](docs/historico/README.md) e o projeto foi migrado para a API Jikan, que é pública e não exige autenticação.

## Como rodar

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Configure um arquivo `.env` na raiz com a variável `DATABASE_URL` apontando para o seu PostgreSQL local, banco `anime_analytics` (veja `.env.example`).

_Este README será expandido com arquitetura, prints do dashboard e insights ao final do projeto._
