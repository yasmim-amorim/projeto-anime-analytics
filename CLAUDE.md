# CLAUDE.md

Contexto para sessões futuras do Claude Code neste repositório.

## O que é este projeto

Projeto de portfólio (vaga de Analista de Dados) que demonstra um pipeline de dados completo:

**Coleta (API AniList, GraphQL) → Armazenamento (PostgreSQL) → SQL analítico → Tratamento (Python/pandas) → Modelagem dimensional → Power BI → Documentação**

Pergunta de negócio: como nota, popularidade e engajamento do público se comportam entre gêneros e estúdios de anime, e como isso evoluiu ao longo do tempo.

O plano de ação completo, com checklist por etapa, vive em [`plano-de-acao-projeto-anime.md`](plano-de-acao-projeto-anime.md) na raiz — **sempre ler esse arquivo primeiro** para saber o que já foi feito e o que falta.

## Histórico importante — não reabrir

O projeto passou por duas fontes de dados antes da atual. Nenhuma dessas duas decisões deve ser reaberta sem necessidade — ambas foram investigadas a fundo:

1. Começou como análise de e-commerce com a API do Mercado Livre. Migrado porque o acesso a catálogo/busca de produtos do ML exige aprovação no Developer Partner Program (GMV mínimo de R$2.500.000/mês), inviável para projeto pessoal. Detalhes em [`docs/historico/notas_api_mercadolivre.md`](docs/historico/notas_api_mercadolivre.md).
2. Migrou para a API Jikan (MyAnimeList). Funcionou na exploração inicial, mas a coleta em escala (~1.500 animes) esbarrou em instabilidade sistemática do backend da Jikan ao raspar o MyAnimeList ao vivo — confirmado via `curl` direto, fora do script, que não era bug nosso. Detalhes em [`docs/historico/notas_api_jikan.md`](docs/historico/notas_api_jikan.md).

Fonte atual: **AniList**, GraphQL, serve os dados do próprio banco (sem scraping sob demanda) — não apresentou o mesmo problema.

## Estrutura do repositório

```
├── plano-de-acao-projeto-anime.md   # plano de ação com checklist — ler primeiro
├── data/
│   ├── raw/anilist/<data>/          # JSON bruto por coleta (paginado) — fonte ativa
│   ├── historico_raw/jikan_.../     # coleta parcial da Jikan, preservada por histórico
│   └── processed/                   # CSVs tratados (um por tabela do schema)
├── src/
│   ├── coletar_anilist.py           # Etapa 2: coleta via GraphQL com retry/backoff
│   ├── tratar_dados.py              # Etapa 4: normaliza JSON bruto -> CSVs
│   ├── carga_sql.py                 # Etapa 5: carrega CSVs no Postgres
│   └── historico/                   # scripts arquivados: Mercado Livre + coletar_jikan.py
├── sql/
│   ├── ddl.sql                      # schema: dim_anime, dim_genero, dim_estudio,
│   │                                 # pontes N:N, fato_anime_metricas
│   └── queries_analiticas.sql       # views + window functions (Etapa 6)
├── docs/
│   ├── guia_powerbi.md              # guia de referência p/ montar o dashboard
│   └── historico/                   # investigação do Mercado Livre e da Jikan (arquivado)
└── dashboard/                       # .pbix vai aqui quando construído
```

## Como rodar o pipeline localmente

```bash
venv\Scripts\activate
python src/coletar_anilist.py  # popula data/raw/anilist/<data>/
python src/tratar_dados.py     # gera data/processed/*.csv
python src/carga_sql.py        # carrega no Postgres (TRUNCATE + reload nas dimensões/pontes, append na fato)
```

Requer `.env` local com `DATABASE_URL` (ver `.env.example`) e banco `anime_analytics` já criado com `sql/ddl.sql` rodado. O schema mudou na migração pra AniList (coluna `tipo_classificacao` saiu de `dim_genero`) — se o banco ainda tiver o schema antigo da Jikan, rodar o DDL de novo (`DROP TABLE ... CASCADE` nas 6 tabelas antes, ou dropar o banco e recriar).

## Coisas a saber antes de mexer

- **Mapeamento de campos Jikan → AniList**: o schema e `tratar_dados.py` preservam os nomes de coluna originais (`score`, `scored_by`, `rank`, `popularity`, `members`, `favorites`) mesmo a AniList tendo campos com nomes/semânticas diferentes — isso evitou ter que tocar nas views SQL e no guia do Power BI. Detalhes do mapeamento completo (o que veio de onde, e as perdas de granularidade aceitas conscientemente, como `classificacao_etaria`) estão na seção "Mapeamento de campos" em `plano-de-acao-projeto-anime.md`. Ler antes de mudar qualquer coisa relacionada a esses campos.
- **AniList tem rate limit de 30 req/min** (header `X-RateLimit-Limit`) e é estável — não é preciso o retry pesado que a Jikan exigia. `coletar_anilist.py` já tem espaçamento (2.2s) + retry/backoff leve, suficiente.
- **Escopo da coleta**: top ~1.500 animes por popularidade (`LIMITE_PAGINAS = 30`, `PER_PAGE = 50` em `coletar_anilist.py`), não a base inteira da AniList/MAL (dezenas de milhares).
- **Sem `dim_tempo`**: atributos de anime são estáticos; análise temporal usa `ano`/`temporada` do próprio anime, não da data de coleta.
- **`fato_anime_metricas`** acumula por `data_coleta` — permite série histórica se a coleta rodar mais de uma vez ao longo do tempo. `carga_sql.py` faz TRUNCATE+reload nas dimensões/pontes (a coleta mais recente refaz a "foto" do catálogo) mas `append` na fato.
- **Relacionamentos N:N no Power BI** (`ponte_anime_genero`, `ponte_anime_estudio`) precisam de direção de filtro "Ambos" — sem isso, filtrar por gênero/estúdio não reflete nos KPIs. Detalhes em `docs/guia_powerbi.md`.
- **`data/raw/*.json` e `data/processed/*.csv` são versionados no git** (decisão deliberada, para reprodutibilidade do portfólio) — não adicionar ao `.gitignore`.
- **A pasta local ainda pode se chamar `projeto-ecommerce-mercadolivre`** mesmo o GitHub remote já sendo `yasmim-amorim/projeto-anime-analytics`. Não dá pra renomear essa pasta de dentro de uma sessão ativa nela (Windows bloqueia por estar em uso) — precisa ser feito por fora (fechar sessão/terminal, `Rename-Item`, reabrir na pasta nova).

## Perfil da usuária

Ainda está aprendendo Python/pandas, SQL, PostgreSQL e Power BI — priorizar explicações práticas e passo a passo em vez de assumir conhecimento prévio profundo.
