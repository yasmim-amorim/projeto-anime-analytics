# Análise de Anime (API AniList)

Projeto de portfólio (Analista de Dados) que percorre o ciclo completo de um pipeline de dados: da coleta via API pública até um dashboard interativo, passando por modelagem de banco relacional, camada analítica em SQL e tratamento em Python.

**Coleta (API) → Armazenamento (PostgreSQL) → SQL → Tratamento (Python/pandas) → Modelagem dimensional → Power BI**

## Pergunta de negócio

O catálogo de anime cresceu de forma acelerada na última década, com estúdios cada vez mais especializados e gêneros competindo por atenção do público. Este projeto investiga como três dimensões desse mercado se relacionam, e onde elas divergem:

> **Nota, popularidade e engajamento do público se comportam de forma parecida entre gêneros e estúdios de anime, ou existem descolamentos relevantes entre "o que é bem avaliado" e "o que é popular"? Como esse comportamento evoluiu ao longo do tempo e da sazonalidade de lançamentos?**

Isso se desdobra em perguntas mais concretas: quais estúdios entregam consistência de qualidade em vez de volume? Existem gêneros "cult" (nota alta, audiência baixa) escondidos na base? A sazonalidade de lançamento (outono, inverno, primavera, verão) tem relação com a qualidade média do que é lançado?

## Stack

- **Coleta:** Python (`requests`), API pública [AniList](https://docs.anilist.co/) (GraphQL)
- **Armazenamento:** PostgreSQL
- **Transformação:** Python (`pandas`)
- **Camada analítica:** SQL (views e window functions: ranking, quartis, quadrantes)
- **Carga:** SQLAlchemy (upsert via staging table, idempotente)
- **Configuração:** `python-dotenv`
- **Visualização:** Power BI (modelagem dimensional, medidas DAX dinâmicas)

## Status

- ✅ Coleta (`src/coletar_anilist.py`) e tratamento (`src/tratar_dados.py`) completos: 4.378 animes, 376 estúdios e 17 gêneros em `data/processed/`, a partir dos 5.000 animes mais populares da AniList (teto de paginação da própria API).
- ✅ Modelagem dimensional (`sql/ddl.sql`), camada analítica em SQL (views e window functions em `sql/queries_analiticas.sql`) e carga no PostgreSQL (`src/carga_sql.py`) completas.
- ✅ Dashboard no Power BI completo, com 4 páginas (Visão Geral, Ranking, Gênero e Estúdios, Temporadas). Guia de referência em [`docs/guia_powerbi.md`](docs/guia_powerbi.md).

## Como rodar

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

Requer [PostgreSQL](https://www.postgresql.org/download/) instalado localmente (ou acessível via rede). Crie um arquivo `.env` na raiz com a variável `DATABASE_URL` apontando para o seu banco, `anime_analytics` (veja `.env.example` como referência). Rode `sql/ddl.sql` nesse banco antes da primeira carga.

```bash
python src/coletar_anilist.py   # popula data/raw/anilist/<data>/
python src/tratar_dados.py      # gera data/processed/*.csv
python src/validar_dados.py     # confere integridade dos CSVs antes de carregar
python src/carga_sql.py         # carrega no Postgres
```

## Estrutura do repositório

```
├── data/
│   ├── raw/anilist/<data>/          # JSON bruto por coleta (paginado)
│   └── processed/                   # CSVs tratados (um por tabela do schema)
├── src/
│   ├── coletar_anilist.py           # coleta via GraphQL com retry/backoff
│   ├── tratar_dados.py              # normaliza JSON bruto -> CSVs
│   ├── validar_dados.py             # checa integridade dos CSVs
│   └── carga_sql.py                 # carrega CSVs no Postgres
├── sql/
│   ├── ddl.sql                      # schema: dim_anime, dim_genero, dim_estudio,
│   │                                 # pontes N:N, fato_anime_metricas
│   └── queries_analiticas.sql       # views + window functions
├── docs/
│   └── guia_powerbi.md              # guia de referência do dashboard
└── dashboard/
    ├── anime_dashboard.pbix
    └── anime_dashboard.pdf
```

## Dashboard

O dashboard completo (Power BI, 4 páginas) está em [`dashboard/anime_dashboard.pbix`](dashboard/anime_dashboard.pbix). Para interagir com os filtros, basta abrir no [Power BI Desktop](https://www.microsoft.com/pt-br/power-platform/products/power-bi/desktop) (gratuito); não é preciso conexão com banco, já que os dados vêm embutidos no próprio arquivo.

Também disponível:
- **PDF estático** (sem interatividade): [`dashboard/anime_dashboard.pdf`](dashboard/anime_dashboard.pdf)
- **Vídeo demonstrativo**: [assista aqui](https://youtu.be/1ACAOAdmqOw)

### Prints

| Visão Geral | Ranking |
|---|---|
| ![Visão Geral](docs/prints/visao_geral.png) | ![Ranking](docs/prints/ranking.png) |

| Gênero e Estúdios | Temporadas |
|---|---|
| ![Gênero e Estúdios](docs/prints/genero_e_estudios.png) | ![Temporadas](docs/prints/temporadas.png) |

## Principais insights

- **Especialização não é acidente, é estratégia de estúdio.** Entre os estúdios de maior catálogo, a Toei Animation concentra 75,7% dos seus 189 títulos em Action, e a bones, 74,8% dos seus 123, enquanto estúdios como Production I.G (211 títulos) e A-1 Pictures (162) mantêm catálogos mais diversificados, com o gênero dominante representando menos de 50% da produção. Ou seja, "produzir muito" e "ser especialista num gênero" são estratégias distintas, não a mesma coisa.
- **Popularidade e qualidade divergem em quase metade da base.** Dividindo os 4.245 animes com amostra confiável de votos pela mediana de nota e de membros, só 1.450 (34%) são "populares e bem avaliados" ao mesmo tempo. Quase tantos (1.297, 31%) são "pouco populares e mal avaliados", mas 825 títulos são "joias escondidas" (nota acima da mediana, audiência abaixo), um sinal de que a audiência de massa nem sempre acompanha a crítica.
- **Terror é o gênero mais arriscado e o Suspense o mais seguro.** Terror tem a menor nota média da base (6,78), enquanto Suspense lidera (7,35), uma diferença de mais de meio ponto na escala de 10, num mercado com volume de produção relativamente equivalente entre os dois.
- **A sazonalidade concentra os melhores lançamentos no inverno, não no volume de outono.** Outono é a temporada com mais estreias (1.173, 28% do total), mas o inverno, a temporada com menos lançamentos (898), inclui *Gintama: THE FINAL* (nota 9,1), um dos dois animes mais bem avaliados de toda a base. Mais lançamentos não significa mais qualidade concentrada.
- **Crescimento de gênero é desigual e acelerando em direções opostas.** Comparando 2021-2023 com 2024-2026, Romance cresceu 28,5% em número de lançamentos (151 para 194 títulos), enquanto Mecha encolheu 56,5% no mesmo período: o tipo de sinal que orientaria uma decisão de investimento em produção, se este fosse um dashboard de mercado real.
