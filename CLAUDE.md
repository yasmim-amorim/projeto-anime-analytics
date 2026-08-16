# CLAUDE.md

Contexto para sessões futuras do Claude Code neste repositório.

## O que é este projeto

Projeto de portfólio (vaga de Analista de Dados) que demonstra um pipeline de dados completo:

**Coleta (API AniList, GraphQL) → Armazenamento (PostgreSQL) → SQL analítico → Tratamento (Python/pandas) → Modelagem dimensional → Power BI → Documentação**

Pergunta de negócio: como nota, popularidade e engajamento do público se comportam entre gêneros e estúdios de anime, e como isso evoluiu ao longo do tempo.

O plano de ação completo, com checklist por etapa, vive em `plano-de-acao-projeto-anime.md` na raiz (arquivo local, fora do controle de versão — ver `.gitignore`) — **sempre ler esse arquivo primeiro** para saber o que já foi feito e o que falta.

## Estrutura do repositório

```
├── data/
│   ├── raw/anilist/<data>/          # JSON bruto por coleta (paginado)
│   └── processed/                   # CSVs tratados (um por tabela do schema)
├── src/
│   ├── coletar_anilist.py           # coleta via GraphQL com retry/backoff
│   ├── tratar_dados.py              # normaliza JSON bruto -> CSVs
│   └── carga_sql.py                 # carrega CSVs no Postgres
├── sql/
│   ├── ddl.sql                      # schema: dim_anime, dim_genero, dim_estudio,
│   │                                 # pontes N:N, fato_anime_metricas
│   └── queries_analiticas.sql       # views + window functions
├── docs/
│   └── guia_powerbi.md              # guia de referência p/ montar o dashboard
└── dashboard/                       # .pbix vai aqui quando construído
```

## Como rodar o pipeline localmente

```bash
venv\Scripts\activate
python src/coletar_anilist.py  # popula data/raw/anilist/<data>/
python src/tratar_dados.py     # gera data/processed/*.csv
python src/carga_sql.py        # upsert no Postgres — seguro rodar de novo, não apaga histórico
```

Requer `.env` local com `DATABASE_URL` (ver `.env.example`) e banco `anime_analytics` já criado com `sql/ddl.sql` rodado. **`ddl.sql` é destrutivo** (`DROP TABLE ... CASCADE` no topo, pra ser idempotente) — rodar só na configuração inicial ou numa migração de schema, nunca como parte do fluxo normal de recoleta.

## Coisas a saber antes de mexer

- **Origem dos campos de métrica**: `score` vem de `averageScore` (0-100) da AniList dividido por 10, pra escala 0-10. `scored_by` é calculado somando os buckets de `stats.scoreDistribution` (a API não expõe contagem direta de avaliações). `rank`/`popularity` vêm de `rankings[]` filtrando `type: RATED`/`type: POPULAR` com `allTime: true` (nem todo anime tem os dois, fica `NULL`). `members` é o campo `popularity` da AniList (contagem de usuários com o anime na lista). `favorites` é `favourites`, direto. Detalhes completos em `plano-de-acao-projeto-anime.md`.
- **Conteúdo adulto é filtrado no tratamento**: `tratar_dados.py` remove animes com `isAdult = true` ou gênero Hentai/Ecchi antes de gerar os CSVs (`filtrar_conteudo_adulto()`), fora de escopo pro portfólio. O JSON bruto em `data/raw/` continua intacto (raw data não é editado) — o filtro só existe na camada de tratamento pra frente. A coluna `classificacao_etaria` (que só existia pra marcar `'Adult'`) foi removida do schema — ficaria sempre `NULL` de qualquer forma, já que esse conteúdo nunca chega no banco.
- **`dim_genero` usa `nome_genero` (texto) como chave, não um id numérico**: a AniList não fornece id de gênero, e um id sequencial gerado por ordem alfabética a cada `tratar_dados.py` seria instável (muda se o conjunto de gêneros mudar entre coletas) — corrompendo silenciosamente `ponte_anime_genero` numa recoleta futura. Nome como chave natural evita isso.
- **AniList tem rate limit de 30 req/min** (header `X-RateLimit-Limit`). `coletar_anilist.py` já tem espaçamento (2.2s) + retry/backoff leve, suficiente pra manter estabilidade.
- **Escopo da coleta**: top 5.000 animes por popularidade (`LIMITE_PAGINAS = 100`, `PER_PAGE = 50` em `coletar_anilist.py`) — esse é o teto de profundidade de paginação da própria API AniList (`page * perPage <= 5000`), não uma escolha nossa. A base completa da AniList tem dezenas de milhares de títulos; ir além do teto exigiria particionar a coleta por outro critério (ano, gênero etc.) e deduplicar.
- **Sem `dim_tempo`**: atributos de anime são estáticos; análise temporal usa `ano`/`temporada` do próprio anime, não da data de coleta.
- **`fato_anime_metricas`** acumula por `data_coleta` — permite série histórica se a coleta rodar mais de uma vez ao longo do tempo. `carga_sql.py` faz **upsert** (staging table + `INSERT ... ON CONFLICT`) em tudo, dimensões/pontes/fato — nunca `TRUNCATE`. Isso importa: um `TRUNCATE CASCADE` em `dim_anime` arrastaria `fato_anime_metricas` junto (tem FK pra `dim_anime`), apagando o histórico mesmo que a fato não estivesse no comando explicitamente. Testado: rodar `carga_sql.py` duas vezes seguidas não duplica nem apaga nada.
- **Relacionamentos N:N no Power BI** (`ponte_anime_genero`, `ponte_anime_estudio`) precisam de direção de filtro "Ambos" — sem isso, filtrar por gênero/estúdio não reflete nos KPIs. Detalhes em `docs/guia_powerbi.md`.
- **`data/raw/*.json` e `data/processed/*.csv` são versionados no git** (decisão deliberada, para reprodutibilidade do portfólio) — não adicionar ao `.gitignore`.
- **`plano-de-acao-projeto-anime.md` não é versionado** — é material de trabalho interno (checklist, notas de sessão), não parte do portfólio público. Continua existindo localmente e deve ser lido/atualizado normalmente entre sessões.

## Estado atual (ver plano de ação para detalhes)

- Coleta completa (5.000 animes, teto de paginação da API AniList) e tratamento com filtro de conteúdo adulto aplicado: **4.378 animes, 376 estúdios, 17 gêneros** em `data/processed/` e já carregados no Postgres.
- Power BI: guia de referência escrito, dashboard ainda não iniciado.

## Perfil da usuária

Ainda está aprendendo Python/pandas, SQL, PostgreSQL e Power BI — priorizar explicações práticas e passo a passo em vez de assumir conhecimento prévio profundo.
