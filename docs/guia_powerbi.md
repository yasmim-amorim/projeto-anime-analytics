# Guia Power BI — Etapas 7 e 8

Guia de referência para montar o dashboard no Power BI Desktop, conectado ao banco `anime_analytics`. Siga na ordem.

## 1. Conectar ao PostgreSQL

1. Abrir o Power BI Desktop → **Obter Dados** → **Banco de Dados** → **Banco de dados PostgreSQL**.
2. **Servidor**: `localhost:5432`
3. **Banco de dados**: `anime_analytics`
4. Modo de conectividade de dados: **Importar**
5. Ao pedir credenciais: usuário `postgres`, senha (a mesma do `.env`).
6. No **Navegador**, marque as 6 tabelas: `dim_anime`, `dim_genero`, `dim_estudio`, `ponte_anime_genero`, `ponte_anime_estudio`, `fato_anime_metricas`. **Carregar**.

> Se pedir para instalar o driver do Npgsql, aceite — é necessário pra conectar no Postgres.

## 2. Relacionamentos (aba Modelo)

Crie estes relacionamentos (arrastando campo com campo, ou em **Gerenciar Relacionamentos**):

| De | Para | Cardinalidade | Direção do filtro |
|---|---|---|---|
| `dim_anime[anime_id]` | `fato_anime_metricas[anime_id]` | 1 : N | Único (padrão) |
| `dim_genero[genero_id]` | `ponte_anime_genero[genero_id]` | 1 : N | Único (padrão) |
| `dim_anime[anime_id]` | `ponte_anime_genero[anime_id]` | 1 : N | **Ambos** ⚠️ |
| `dim_estudio[estudio_id]` | `ponte_anime_estudio[estudio_id]` | 1 : N | Único (padrão) |
| `dim_anime[anime_id]` | `ponte_anime_estudio[anime_id]` | 1 : N | **Ambos** ⚠️ |

As duas marcadas "Ambos" são essenciais — sem isso, filtrar por gênero ou estúdio não vai refletir nos números do dashboard (é o padrão de "tabela-ponte" para relação N:N).

## 3. Tabela calendário (DAX)

Nova Tabela:
```dax
DimData = CALENDAR(MIN(dim_anime[ano]) & "-01-01", MAX(dim_anime[ano]) & "-12-31")
```
(Opcional — só necessário se for usar inteligência temporal por mês/trimestre. Para a maioria das análises, `dim_anime[ano]` e `dim_anime[temporada]` já bastam.)

## 4. Medidas DAX

Crie uma tabela só de medidas primeiro (Modelagem → Nova Tabela → digite só `Medidas = {}`), depois adicione estas Novas Medidas nela:

```dax
Total de Animes = DISTINCTCOUNT(dim_anime[anime_id])

Nota Media = AVERAGE(fato_anime_metricas[score])

Nota Media Confiavel =
CALCULATE(AVERAGE(fato_anime_metricas[score]), fato_anime_metricas[scored_by] >= 1000)

Total de Membros = SUM(fato_anime_metricas[members])

Total de Favoritos = SUM(fato_anime_metricas[favorites])

Proporcao Favoritos por Membro =
DIVIDE(SUM(fato_anime_metricas[favorites]), SUM(fato_anime_metricas[members]))

Generos Cobertos =
CALCULATE(DISTINCTCOUNT(dim_genero[genero_id]), dim_genero[tipo_classificacao] = "genre")

Estudios Cobertos = DISTINCTCOUNT(dim_estudio[estudio_id])

Ranking Popularidade (anime) =
RANKX(ALL(dim_anime[anime_id]), CALCULATE(SUM(fato_anime_metricas[members])), , DESC)

Ranking Nota (anime) =
RANKX(ALL(dim_anime[anime_id]), CALCULATE(AVERAGE(fato_anime_metricas[score])), , DESC)
```

## 5. Páginas do dashboard

**Página 1 — Visão Geral**
- Cards: `Total de Animes`, `Nota Media`, `Total de Membros`, `Generos Cobertos`, `Estudios Cobertos`
- Gráfico de colunas: distribuição de animes por `dim_anime[tipo]`

**Página 2 — Análise por Gênero**
- Tabela ou gráfico de barras: `dim_genero[nome_genero]` x `Nota Media` (filtrar `tipo_classificacao = "genre"`)
- Gráfico de dispersão (scatter): eixo X `Total de Membros`, eixo Y `Nota Media`, por gênero — identifica "cult vs hype"
- Filtro de página: `dim_genero[tipo_classificacao]`

**Página 3 — Análise por Estúdio**
- Tabela: `dim_estudio[nome_estudio]`, `Total de Animes`, `Nota Media`, `Total de Membros`, ordenada por volume
- Gráfico de barras: top 10 estúdios por `Total de Animes`

**Página 4 — Evolução por Ano/Temporada**
- Gráfico de linhas: `dim_anime[ano]` x `Nota Media`
- Gráfico de colunas empilhadas: `dim_anime[ano]` x contagem de animes, cor por `dim_anime[temporada]`

**Página 5 — Explorador de Dados**
- Tabela detalhada: título, tipo, fonte, ano, nota, membros, favoritos, gêneros
- Filtros livres: gênero, estúdio, tipo, fonte, ano, status

**Filtros globais (todas as páginas):** `dim_anime[tipo]`, `dim_anime[fonte]`, `dim_anime[status]`, `dim_anime[classificacao_etaria]`, `dim_anime[ano]`, `dim_anime[temporada]`, `dim_genero[nome_genero]`, `dim_estudio[nome_estudio]`

## Nota sobre o tamanho da amostra

Com ~25 animes coletados até agora, os gráficos vão ficar "magros" (poucas barras, poucos pontos). Isso é esperado — o dashboard funciona igual quando a coleta tiver mais dados (basta rodar `carga_sql.py` de novo depois de coletar mais). Não precisa refazer nada no Power BI, só clicar em **Atualizar** depois de recarregar o banco.
