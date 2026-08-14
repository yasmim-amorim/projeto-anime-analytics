# Análise de E-commerce — API Mercado Livre

> 🚧 Projeto em andamento.

Projeto de portfólio (Analista de Dados) demonstrando o ciclo completo de um pipeline de dados:

**Coleta (API) → Armazenamento (PostgreSQL) → SQL → Tratamento (Python/pandas) → Modelagem → Power BI → Documentação**

## Pergunta de negócio

Como preços, avaliações e vendedores se comportam entre categorias de tecnologia (Celulares, Informática, Games) no Mercado Livre, e como isso varia ao longo do tempo?

## Stack

- **Coleta:** Python (`requests`)
- **Armazenamento:** PostgreSQL
- **Transformação:** Python (`pandas`), SQL
- **Carga:** SQLAlchemy
- **Visualização:** Power BI

## Status

Setup inicial do repositório e exploração da API do Mercado Livre.

Detalhes do plano completo em [`plano-de-acao-projeto-mercadolivre.md`](plano-de-acao-projeto-mercadolivre.md).

## Como rodar

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Configure um arquivo `.env` na raiz com a variável `DATABASE_URL` apontando para o seu PostgreSQL local (veja `.env.example`, quando disponível).

_Este README será expandido com arquitetura, prints do dashboard e insights ao final do projeto._
