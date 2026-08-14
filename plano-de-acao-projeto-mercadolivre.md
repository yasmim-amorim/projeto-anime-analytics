# Plano de Ação — Projeto de Portfólio: Análise de E-commerce (API Mercado Livre)

## Contexto do projeto

Projeto de portfólio para vaga de Analista de Dados, demonstrando o ciclo completo:
**Coleta (API) → Armazenamento → SQL → Tratamento → Modelagem → Power BI → Documentação/GitHub**

**Categorias de coleta definidas:**
- Celulares e Smartphones
- Informática
- Games/Consoles

**Pergunta de negócio central:** Como preços, avaliações e vendedores se comportam entre categorias de tecnologia no Mercado Livre, e como isso varia ao longo do tempo?

### Perguntas de negócio que o dashboard vai responder

Perguntas do tipo que um analista de e-commerce, category manager ou comprador realmente faz no dia a dia — é isso que dá "propósito" ao dashboard, em vez de ser só gráfico bonito:

**Preço e competitividade**
- Qual categoria (celulares, informática ou games) tem os preços mais voláteis no período analisado?
- Quais produtos tiveram queda ou alta de preço mais expressiva nas últimas semanas?
- Existe diferença de preço médio entre produtos novos e usados em cada categoria?
- Quais promoções são "reais" (queda efetiva) e quais são "preço inflado antes do desconto"?

**Vendedores e concorrência**
- Lojas oficiais praticam preços mais altos ou mais baixos que vendedores terceiros?
- Quais vendedores concentram o maior volume de vendas em cada categoria?
- Existe relação entre reputação do vendedor e o preço praticado?
- Vendedores com frete grátis vendem mais que os sem frete grátis?

**Comportamento do consumidor / demanda**
- Quais produtos têm mais avaliações (maior "prova social") dentro de cada categoria?
- Produtos mais avaliados são também os mais baratos, ou o preço não é o fator decisivo?
- Existe relação entre nota de avaliação e quantidade vendida?
- Qual categoria tem o público mais exigente (notas mais baixas ou mais críticas)?

**Estratégia de categoria (visão de negócio)**
- Qual das três categorias (celulares, informática, games) tem maior potencial de margem, com base na dispersão de preços?
- Em qual categoria a oferta de produtos novos supera a de usados, e isso está mudando ao longo do tempo?
- Se eu fosse revender um produto de tecnologia hoje, em qual categoria e faixa de preço eu teria mais chance de competir?

Essas perguntas devem guiar diretamente os KPIs, os filtros e as páginas do Power BI — cada página do dashboard deveria "responder" a um grupo dessas perguntas.

**Stack:** Python (requests, pandas) → PostgreSQL (ou SQLite) → SQL → Power BI → Git/GitHub

---

## Etapa 0 — Setup do ambiente
- [ ] Criar repositório no GitHub (`projeto-ecommerce-mercadolivre` ou similar)
- [ ] Criar estrutura de pastas local (ver seção "Estrutura do repositório")
- [ ] Configurar ambiente Python (venv) e instalar bibliotecas: `requests`, `pandas`, `sqlalchemy`, `psycopg2` (ou `sqlite3`, nativo)
- [ ] Instalar/configurar PostgreSQL (ou decidir por SQLite se preferir simplicidade)
- [ ] Instalar Power BI Desktop

## Etapa 1 — Exploração da API do Mercado Livre
- [ ] Testar endpoints públicos de busca por categoria/termo
- [ ] Identificar os IDs de categoria (ex: celulares, informática, games) via endpoint de categorias
- [ ] Mapear os campos retornados (preço, título, vendedor, avaliação, frete, etc.)
- [ ] Definir a amostra: quantos produtos por categoria, com que frequência coletar
- [ ] Documentar limites da API (rate limit, paginação)

## Etapa 2 — Script de coleta (Python)
- [ ] Criar função de coleta por categoria com paginação
- [ ] Salvar resposta bruta (JSON) em `data/raw/`, organizada por data de coleta
- [ ] Adicionar tratamento de erros (timeout, falha de conexão, categoria vazia)
- [ ] Testar coleta manual algumas vezes antes de automatizar
- [ ] (Opcional) Automatizar execução periódica (cron, Task Scheduler, ou rotina manual diária durante X semanas) para construir série histórica

## Etapa 3 — Modelagem do banco de dados
- [ ] Desenhar o modelo estrela: tabela fato + dimensões
  - `fato_precos`: item_id, data_coleta, preço, preço_original, quantidade_vendida, avaliação, num_avaliações
  - `dim_produto`: item_id, título, categoria_id, condição
  - `dim_categoria`: categoria_id, nome_categoria, subcategoria
  - `dim_vendedor`: vendedor_id, nome, tipo_loja (oficial/terceiro), localização
  - `dim_tempo`: data, ano, mês, dia, dia_da_semana
- [ ] Escrever script DDL (`sql/ddl.sql`) com criação de tabelas, chaves primárias e estrangeiras
- [ ] Criar banco (Postgres ou SQLite) e rodar o DDL

## Etapa 4 — Tratamento e transformação (Python/pandas)
- [ ] Carregar os JSONs brutos e normalizar em DataFrame
- [ ] Remover duplicados e outliers (preços inconsistentes)
- [ ] Padronizar tipos de dados (preço numérico, datas como datetime, texto padronizado)
- [ ] Criar colunas derivadas: desconto percentual, faixa de preço, dia da semana da coleta
- [ ] Tratar valores nulos (frete, avaliação, vendedor)
- [ ] Separar dados tratados em DataFrames correspondentes às tabelas fato/dimensão

## Etapa 5 — Carga no banco de dados
- [ ] Criar script de carga (`src/carga_sql.py`) usando SQLAlchemy
- [ ] Popular dimensões primeiro, depois a fato (respeitando integridade referencial)
- [ ] Validar carga (contagem de linhas, checagem de nulos pós-carga)

## Etapa 6 — Camada analítica em SQL
- [ ] Criar views para as métricas principais (ex: `vw_preco_medio_categoria`, `vw_evolucao_precos`)
- [ ] Escrever queries analíticas (`sql/queries_analiticas.sql`):
  - Preço médio por categoria/subcategoria
  - Variação percentual de preço no período
  - Ranking de vendedores por volume/reputação
  - Correlação avaliação x quantidade vendida
  - Uso de `JOIN`, `GROUP BY`, `WINDOW FUNCTIONS` (ex: `LAG()` para variação dia a dia)

## Etapa 7 — Conexão e modelagem no Power BI
- [ ] Conectar Power BI ao banco de dados
- [ ] Validar relacionamentos entre fato e dimensões (modelo estrela)
- [ ] Criar tabela calendário (`DimData`) para inteligência temporal
- [ ] Criar medidas DAX para os KPIs principais

## Etapa 8 — Construção das páginas do dashboard
- [ ] **Página 1 — Visão Geral**: cards de KPI + tendência geral de preços
- [ ] **Página 2 — Análise por Categoria**: comparação de preço/volume/avaliação entre categorias
- [ ] **Página 3 — Análise de Vendedores**: reputação, volume, ticket médio, loja oficial x terceiros
- [ ] **Página 4 — Evolução Temporal**: série histórica, variação percentual, maiores oscilações
- [ ] **Página 5 — Explorador de Dados**: tabela detalhada com filtros livres
- [ ] Adicionar filtros globais: categoria, faixa de preço, condição, frete grátis, período
- [ ] Revisar identidade visual (cores, fontes, layout consistente entre páginas)

## Etapa 9 — Insights e storytelling
- [ ] Levantar 3–5 insights reais encontrados nos dados
- [ ] Anotar decisões técnicas relevantes tomadas ao longo do projeto (e por quê)

## Etapa 10 — Documentação
- [ ] Escrever `README.md` completo: objetivo, arquitetura, como rodar, prints, insights, tecnologias
- [ ] Adicionar diagrama simples do fluxo (API → Python → SQL → Power BI)
- [ ] Capturar prints do dashboard finalizado

## Etapa 11 — Publicação no GitHub
- [ ] Organizar repositório conforme estrutura abaixo
- [ ] Subir código, SQL, `.pbix` e documentação
- [ ] Revisar `.gitignore` (evitar subir credenciais/dados sensíveis)

## Etapa 12 — Divulgação (currículo, LinkedIn, portfólio)
- [ ] Escrever bullet de currículo com resultado quantificado
- [ ] Criar post no LinkedIn com prints + insights + link do GitHub
- [ ] Adicionar projeto à página de portfólio pessoal (se houver)

---

## Estrutura do repositório

```
projeto-ecommerce-mercadolivre/
├── README.md
├── data/
│   ├── raw/
│   └── processed/
├── src/
│   ├── coleta_api.py
│   ├── tratamento.py
│   └── carga_sql.py
├── sql/
│   ├── ddl.sql
│   └── queries_analiticas.sql
├── dashboard/
│   └── projeto.pbix
└── docs/
    └── prints/
```

## Observações para próximas sessões
- Categorias já definidas — não reabrir essa decisão sem necessidade
- O usuário ainda está aprendendo essas tecnologias — priorizar explicações práticas e passo a passo, não apenas entregar código pronto
- Fonte de dados: API pública do Mercado Livre (sem autenticação para busca de produtos)
- Próxima etapa natural após este plano: Etapa 1 (exploração da API) ou Etapa 3 (modelagem do banco)
