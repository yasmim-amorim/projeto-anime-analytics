# Plano de Ação — Projeto de Portfólio: Análise de Anime (API Jikan)

## Contexto do projeto

Projeto de portfólio para vaga de Analista de Dados, demonstrando o ciclo completo:
**Coleta (API) → Armazenamento → SQL → Tratamento → Modelagem → Power BI → Documentação/GitHub**

O projeto começou com a API do Mercado Livre, mas o acesso a catálogo/busca de produtos exige aprovação no Developer Partner Program (GMV mínimo de R$2.500.000/mês), inviável para um projeto pessoal. Essa investigação está preservada em [`docs/historico/`](docs/historico/README.md). O projeto foi migrado para a **API Jikan** (`https://api.jikan.moe/v4/`), API pública e gratuita do MyAnimeList, sem necessidade de autenticação.

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
- [ ] Renomear repositório no GitHub para `projeto-analise-anime-jikan` + atualizar remote local
- [ ] Atualizar `.env`/`.env.example` (remover variáveis `ML_*`, banco `anime_analytics`)
- [ ] Reescrever `README.md` da raiz para o domínio anime

## Etapa 1 — Exploração da API Jikan
- [x] Testar endpoints reais (`/anime`, `/top/anime`, `/genres/anime`) — sem autenticação, campos confirmados
- [x] Confirmar rate limit (~3 req/s, ~60/min) e observar instabilidade intermitente do upstream (504 em ~30% das chamadas)
- [ ] Definir escopo final da amostra: top ~1.000–1.500 animes por popularidade

## Etapa 2 — Script de coleta (`src/coletar_jikan.py`)
- [ ] Função central `chamar_api()` com espaçamento entre chamadas e retry/backoff exponencial (504/429/timeout)
- [ ] Paginação via `pagination.has_next_page`, salvando cada página bruta em `data/raw/jikan/<data>/`
- [ ] Log de páginas com falha (`falhas.json`) + segunda passada de reprocessamento
- [ ] Rodar coleta completa e validar contagem de itens

## Etapa 3 — Modelagem do banco de dados
- [ ] `sql/ddl.sql`: `fato_anime_metricas`, `dim_anime`, `dim_genero`, `dim_estudio`, `ponte_anime_genero`, `ponte_anime_estudio`
- [ ] Criar banco `anime_analytics` no Postgres local e rodar o DDL

## Etapa 4 — Tratamento e transformação (Python/pandas)
- [ ] Carregar JSONs brutos, normalizar campos aninhados (`genres`, `studios`, `themes`, `demographics`)
- [ ] Parsear `duration` (texto) para minutos numéricos
- [ ] Tratar nulos (`score` ausente, `aired.to` nulo quando em exibição)
- [ ] Deduplicar por `anime_id`, gerar DataFrames finais por tabela

## Etapa 5 — Carga no banco de dados
- [ ] `src/carga_sql.py`: dimensões → pontes → fato (mesmo padrão do projeto anterior)
- [ ] Validar contagem de linhas e integridade referencial

## Etapa 6 — Camada analítica em SQL
- [ ] Views: `vw_nota_media_genero`, `vw_ranking_estudios`, `vw_engajamento_genero`, `vw_score_vs_popularidade`
- [ ] Window functions sobre as pontes N:N (`RANK() OVER (PARTITION BY genero_id ORDER BY score DESC)`, `NTILE()`)

## Etapa 7 — Conexão e modelagem no Power BI
- [ ] Conectar ao Postgres, validar relacionamentos N:N via tabelas-ponte
- [ ] `DimData` via DAX `CALENDAR()` baseada em `ano` (não em data de coleta)
- [ ] Medidas DAX para os KPIs das 4 famílias de perguntas acima

## Etapa 8 — Construção das páginas do dashboard
- [ ] **Página 1 — Visão Geral**: KPIs (total de animes, nota média, membros totais, gêneros/estúdios cobertos)
- [ ] **Página 2 — Análise por Gênero**: nota, popularidade, engajamento
- [ ] **Página 3 — Análise por Estúdio**: ranking por volume/nota média/membros
- [ ] **Página 4 — Evolução por Ano/Temporada**: produção e nota média ao longo do tempo
- [ ] **Página 5 — Explorador de Dados**: tabela com filtros livres
- [ ] Filtros globais: tipo, fonte, status, classificação etária, ano/temporada, gênero, estúdio

## Etapa 9 — Insights e storytelling
- [ ] Levantar 3–5 insights reais encontrados nos dados
- [ ] Anotar decisões técnicas relevantes tomadas ao longo do projeto (e por quê)

## Etapa 10 — Documentação
- [ ] `README.md` completo: objetivo, arquitetura, como rodar, prints, insights, tecnologias
- [ ] Diagrama simples do fluxo (Jikan → Python → PostgreSQL → SQL → Power BI)
- [ ] Seção "Nota histórica" linkando `docs/historico/`

## Etapa 11 — Publicação no GitHub
- [ ] Confirmar `.gitignore` cobre `venv/`, `.env`
- [ ] Subir código, SQL, `.pbix` e documentação

## Etapa 12 — Divulgação (currículo, LinkedIn, portfólio)
- [ ] Bullet de currículo com resultado quantificado
- [ ] Post no LinkedIn com prints + insights + link do GitHub

---

## Estrutura do repositório

```
projeto-analise-anime-jikan/
├── README.md
├── plano-de-acao-projeto-anime.md
├── data/
│   ├── raw/jikan/
│   └── processed/
├── src/
│   ├── coletar_jikan.py
│   ├── tratar_dados.py
│   ├── carga_sql.py
│   └── historico/          (auth_ml.py, explorar_api.py — Mercado Livre)
├── sql/
│   ├── ddl.sql
│   └── queries_analiticas.sql
├── dashboard/
│   └── projeto.pbix
└── docs/
    ├── historico/           (investigação do Mercado Livre)
    └── prints/
```

## Observações para próximas sessões
- Domínio migrado de e-commerce (Mercado Livre) para anime (Jikan) — não reabrir essa decisão sem necessidade
- Jikan não exige autenticação, mas tem instabilidade intermitente (504) — sempre implementar retry/backoff
- Sem `dim_tempo`: atributos de anime são estáticos, análise temporal usa `ano`/`temporada` do próprio anime
- Escopo: top ~1.000–1.500 animes, não a base inteira do MAL (30k+)
- Usuária ainda está aprendendo essas tecnologias — priorizar explicações práticas e passo a passo
