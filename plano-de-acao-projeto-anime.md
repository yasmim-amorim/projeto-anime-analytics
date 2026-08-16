# Plano de Ação — Projeto de Portfólio: Análise de Anime (API AniList)

## Contexto do projeto

Projeto de portfólio para vaga de Analista de Dados, demonstrando o ciclo completo:
**Coleta (API) → Armazenamento → SQL → Tratamento → Modelagem → Power BI → Documentação/GitHub**

O projeto passou por duas fontes de dados antes da atual — Mercado Livre (bloqueado por exigência de Developer Partner Program com GMV mínimo de R$2.500.000/mês) e depois Jikan/MyAnimeList (bloqueado por instabilidade sistemática do backend ao raspar o MyAnimeList ao vivo). Ambas as investigações estão preservadas em [`docs/historico/`](docs/historico/README.md). O projeto está agora na **API AniList** (`https://graphql.anilist.co`, GraphQL), que serve os dados do próprio banco (não faz scraping sob demanda) e não apresentou o mesmo problema de instabilidade.

**Pergunta de negócio central:** Como nota, popularidade e engajamento do público se comportam entre gêneros e estúdios de anime, e como isso evoluiu ao longo do tempo?

### Perguntas de negócio que o dashboard vai responder

Cada grupo abaixo corresponde a uma página do Power BI — é isso que dá "propósito" ao dashboard, em vez de ser só gráfico bonito.

**Qualidade e avaliação**
- Quais gêneros têm a nota média (`score`) mais alta? E qual tem a nota mais consistente (menor variação)?
- Existem animes "cult" (nota alta, popularidade baixa) versus "hype" (popularidade alta, nota mediana)?
- A nota média varia por tipo de produção (`type`: TV, Filme, OVA, Special)?
- Animes adaptados de mangá têm nota média maior que roteiros originais (`source`)?
- Existe relação entre duração por episódio e nota?

**Estúdios e concorrência**
- Quais estúdios têm o maior volume de produções no período coberto?
- Quais estúdios têm a maior nota média (qualidade), não só volume?
- Existe um estúdio "especialista" que domina algum gênero específico?
- Estúdios com mais títulos acumulam proporcionalmente mais membros/favoritos, ou é só volume sem força de marca?

**Comportamento do público / engajamento**
- Quais animes têm mais membros/favoritos dentro de cada gênero (maior "prova social")?
- Animes mais assistidos (`members`) são também os mais bem avaliados, ou nota e popularidade não andam juntas?
- Existe viés de poucos votos (nota alta sustentada por poucas avaliações)? Necessário filtrar por `scored_by >= 1000` para comparações de "melhor avaliado".
- Qual gênero tem a maior proporção de favoritos por membro (fidelização do público, não só audiência)?

**Estratégia de gênero e evolução temporal**
- Qual gênero tem maior potencial de "descoberta" (nota alta, popularidade baixa, volume relevante de votos)?
- Como o volume de produção por gênero evoluiu ao longo dos anos (`year`)?
- Existe sazonalidade de qualidade por temporada de lançamento (`season`: inverno/primavera/verão/outono)?
- Se fosse recomendar hoje um anime pra maximizar chance de boa recepção, qual gênero/tipo tem a maior nota média com volume relevante de votos?

**Stack:** Python (requests, pandas) → PostgreSQL → SQL → Power BI → Git/GitHub

---

## Etapa 0 — Reorganização e setup (concluída/reaproveitada)
- [x] venv Python, `requirements.txt`, PostgreSQL local instalado (reaproveitados do projeto anterior)
- [x] Artefatos do Mercado Livre movidos para `docs/historico/` e `src/historico/`
- [x] Renomear repositório no GitHub para `projeto-anime-analytics` + atualizar remote local (remote já aponta para o repo novo; falta só renomear a pasta local — ver observações)
- [x] Atualizar `.env`/`.env.example` (sem variáveis `ML_*`, banco `anime_analytics` configurado)
- [x] Reescrever `README.md` da raiz para o domínio anime

## Etapa 1 — Exploração da API AniList
- [x] Testar endpoints reais via GraphQL (`Page.media`) — sem autenticação, campos confirmados (título, format, source, score, popularidade, favoritos, gêneros, estúdios, rankings, distribuição de notas)
- [x] Confirmar rate limit (30 req/min, header `X-RateLimit-Limit`) e validar estabilidade (200 OK consistente em páginas que falhavam sistematicamente na Jikan)
- [x] Definir escopo final da amostra: top ~1.500 animes por popularidade (`LIMITE_PAGINAS = 30`, `PER_PAGE = 50` em `coletar_anilist.py`)

## Etapa 2 — Script de coleta (`src/coletar_anilist.py`)
- [x] Função central `chamar_api()` com espaçamento entre chamadas e retry/backoff exponencial (429/timeout)
- [x] Paginação via `pageInfo.hasNextPage`, salvando cada página bruta em `data/raw/anilist/<data>/`
- [x] Log de páginas com falha (`falhas.json`) + segunda passada de reprocessamento
- [ ] Rodar coleta completa e validar contagem de itens

## Etapa 3 — Modelagem do banco de dados
- [x] `sql/ddl.sql` atualizado para o schema da AniList: `fato_anime_metricas`, `dim_anime`, `dim_genero` (sem `tipo_classificacao` — a AniList só tem gêneros simples, sem temas/demografias separados), `dim_estudio`, `ponte_anime_genero`, `ponte_anime_estudio`
- [ ] Rodar o DDL atualizado no banco `anime_analytics` (schema mudou — precisa recriar as tabelas)

## Etapa 4 — Tratamento e transformação (Python/pandas)
- [x] Carregar JSONs brutos, normalizar campos aninhados (`genres`, `studios` filtrados por `isAnimationStudio`, `rankings`, `stats.scoreDistribution`)
- [x] Montar datas a partir de `{year, month, day}` parciais (duração já vem em minutos, sem parsing de texto)
- [x] Tratar nulos (`score`/`ano`/`temporada` ausentes) e mapear `scored_by` somando `scoreDistribution`
- [x] Deduplicar por `anime_id`, gerar DataFrames finais por tabela

## Etapa 5 — Carga no banco de dados
- [x] `src/carga_sql.py`: dimensões → pontes → fato (sem mudanças — nomes de tabela/coluna preservados)
- [ ] Validar contagem de linhas e integridade referencial com a base completa (pendente da Etapa 2/3)

## Etapa 6 — Camada analítica em SQL
- [x] Views: `vw_nota_media_genero`, `vw_ranking_estudios`, `vw_engajamento_genero`, `vw_score_vs_popularidade` (atualizadas — sem filtro por `tipo_classificacao`)
- [x] Window functions sobre as pontes N:N (`RANK() OVER (PARTITION BY genero_id ORDER BY score DESC)`, `NTILE()`) — em `sql/queries_analiticas.sql`
- [ ] Reaplicar no banco depois que o DDL for recriado (Etapa 3)

## Etapa 7 — Conexão e modelagem no Power BI
- [x] Guia de referência escrito (`docs/guia_powerbi.md`) com passo a passo de conexão, relacionamentos e medidas DAX
- [ ] Conectar ao Postgres de fato no Power BI Desktop e validar relacionamentos N:N via tabelas-ponte
- [ ] `DimData` via DAX `CALENDAR()` baseada em `ano` (não em data de coleta)
- [ ] Medidas DAX para os KPIs das 4 famílias de perguntas acima

## Etapa 8 — Construção das páginas do dashboard
- [ ] **Página 1 — Visão Geral**: KPIs (total de animes, nota média, membros totais, gêneros/estúdios cobertos)
- [ ] **Página 2 — Análise por Gênero**: nota, popularidade, engajamento
- [ ] **Página 3 — Análise por Estúdio**: ranking por volume/nota média/membros
- [ ] **Página 4 — Evolução por Ano/Temporada**: produção e nota média ao longo do tempo
- [ ] **Página 5 — Explorador de Dados**: tabela com filtros livres
- [ ] Filtros globais: tipo, fonte, status, classificação etária, ano/temporada, gênero, estúdio

> Etapas 7-8 fazem mais sentido depois que a Etapa 2 (coleta completa) entregar volume real de dados — construir o dashboard hoje significaria remontar tudo depois.

## Etapa 9 — Insights e storytelling
- [ ] Levantar 3–5 insights reais encontrados nos dados
- [ ] Anotar decisões técnicas relevantes tomadas ao longo do projeto (e por quê)

## Etapa 10 — Documentação
- [ ] `README.md` completo: objetivo, arquitetura, como rodar, prints, insights, tecnologias
- [ ] Diagrama simples do fluxo (AniList → Python → PostgreSQL → SQL → Power BI)
- [x] Seção "Nota histórica" linkando `docs/historico/`

## Etapa 11 — Publicação no GitHub
- [ ] Confirmar `.gitignore` cobre `venv/`, `.env`
- [ ] Subir código, SQL, `.pbix` e documentação

## Etapa 12 — Divulgação (currículo, LinkedIn, portfólio)
- [ ] Bullet de currículo com resultado quantificado
- [ ] Post no LinkedIn com prints + insights + link do GitHub

---

## Estrutura do repositório

```
projeto-anime-analytics/
├── README.md
├── CLAUDE.md
├── plano-de-acao-projeto-anime.md
├── data/
│   ├── raw/anilist/         (coleta ativa)
│   ├── historico_raw/jikan_.../  (coleta antiga, parcial, preservada)
│   └── processed/
├── src/
│   ├── coletar_anilist.py
│   ├── tratar_dados.py
│   ├── carga_sql.py
│   └── historico/          (auth_ml.py, explorar_api.py — Mercado Livre; coletar_jikan.py — Jikan)
├── sql/
│   ├── ddl.sql
│   └── queries_analiticas.sql
├── dashboard/
│   └── projeto.pbix
└── docs/
    ├── historico/           (investigação do Mercado Livre e da Jikan)
    └── prints/
```

## Observações para próximas sessões
- Domínio migrado de e-commerce (Mercado Livre) para anime; fonte de dados migrada de Jikan para AniList — não reabrir nenhuma das duas decisões sem necessidade. Diagnósticos completos em `docs/historico/`.
- Sem `dim_tempo`: atributos de anime são estáticos, análise temporal usa `ano`/`temporada` do próprio anime
- Escopo: top ~1.500 animes, não a base inteira da AniList/MAL (dezenas de milhares)
- Usuária ainda está aprendendo essas tecnologias — priorizar explicações práticas e passo a passo
- Repositório no GitHub já é `yasmim-amorim/projeto-anime-analytics`. A pasta local ainda pode se chamar `projeto-ecommerce-mercadolivre` — não dá pra renomear de dentro de uma sessão ativa nela (Windows bloqueia, diretório em uso). Precisa ser feito por fora: fechar a sessão/terminal, `Rename-Item`, reabrir apontando pra pasta nova.

### Mapeamento de campos Jikan → AniList (decisões tomadas na migração)
A AniList tem campos com nomes e semânticas um pouco diferentes da Jikan; o schema (`sql/ddl.sql`) e `tratar_dados.py` preservam os nomes de coluna originais sempre que davam pra mapear 1:1, pra não precisar tocar nas views/guia do Power BI:
- `score`: `averageScore` (escala 0-100) dividido por 10, pra manter a escala 0-10 da Jikan/MAL.
- `scored_by`: a AniList não expõe contagem direta de avaliações — somamos os buckets de `stats.scoreDistribution`.
- `rank` / `popularity` (colunas de ranking, não de contagem): extraídos de `rankings[]` filtrando `type: RATED`/`type: POPULAR` com `allTime: true`. Nem todo anime tem os dois (fica `NULL`).
- `members`: campo `popularity` da AniList (contagem de usuários com o anime na lista — nome confuso, mas é o equivalente direto de `members` da Jikan).
- `favorites`: `favourites` da AniList, direto.
- `dim_genero`: a AniList só retorna uma lista simples de nomes de gênero, sem id nem separação tema/demografia — removemos a coluna `tipo_classificacao` e geramos `genero_id` como surrogate (sequencial, ordem alfabética) no tratamento.
- `dim_estudio`: filtramos só `studios.nodes` com `isAnimationStudio = true` (a AniList lista produtoras/editoras junto com estúdios de animação).
- `classificacao_etaria`: a AniList não tem um campo tipo "PG-13"/"R" como o MAL — vira `'Adult'` quando `isAdult = true`, senão `NULL` (perda de granularidade aceita conscientemente).

Diagnóstico completo de por que saímos da Jikan: [`docs/historico/notas_api_jikan.md`](docs/historico/notas_api_jikan.md).
