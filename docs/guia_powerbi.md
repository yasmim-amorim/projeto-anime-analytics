# Guia de Referência — Power BI

Guia de referência para montar o dashboard no Power BI Desktop, conectado ao banco `anime_analytics`. Siga na ordem.

## O que cada métrica significa

- **Total de Membros**: soma de `fato_anime_metricas[members]` de todos os animes filtrados. `members` é a contagem de usuários da AniList que têm aquele anime na própria lista (assistindo, completo, quer assistir etc.) — é uma medida de **alcance/exposição**, não de qualidade. Somar entre vários animes (ex: todos de um gênero) dá o tamanho da audiência combinada daquele grupo, mas cuidado: o mesmo usuário pode ser contado em vários animes diferentes, então não é "quantidade de pessoas únicas".
- **Nota × Membros** (o gráfico de dispersão): compara, pra cada anime ou gênero, se "muita gente assiste" (`members`, eixo X) anda junto com "é bem avaliado" (`score`, eixo Y). Os quatro quadrantes contam uma história: nota alta + membros altos = sucesso de crítica e público; nota alta + membros baixos = "joia escondida"; nota baixa + membros altos = "todo mundo assiste, mas a crítica é morna"; nota baixa + membros baixos = nicho que não pegou.
- **Nota média e volume por ano**: agrupa os animes pelo `ano` de lançamento (não pela data em que você coletou os dados) e calcula, pra cada ano, a média de `score` e a contagem de títulos lançados. Mostra se a "qualidade média" dos lançamentos subiu/caiu ao longo do tempo, e se o volume de produção da indústria cresceu.

## 1. Conectar ao PostgreSQL

1. Abrir o Power BI Desktop → **Obter Dados** → **Banco de Dados** → **Banco de dados PostgreSQL**.
2. **Servidor**: `localhost:5432`
3. **Banco de dados**: `anime_analytics`
4. Modo de conectividade de dados: **Importar**
5. Ao pedir credenciais: usuário `postgres`, senha (a mesma do `.env`).
6. No **Navegador**, marque as 6 tabelas (`dim_anime`, `dim_genero`, `dim_estudio`, `ponte_anime_genero`, `ponte_anime_estudio`, `fato_anime_metricas`) **e as 11 views prontas** listadas abaixo. **Carregar**.

| View | O que traz | Linhas |
|---|---|---|
| `vw_anime_mais_popular_por_genero` | top 5 mais populares de cada gênero (`posicao` 1 a 5) | 85 |
| `vw_anime_melhor_avaliado_por_genero` | top 5 melhor avaliados de cada gênero | 85 |
| `vw_anime_mais_popular_por_estudio` | campeão de popularidade de cada estúdio | 376 |
| `vw_anime_melhor_avaliado_por_estudio` | campeão de nota de cada estúdio | 370 |
| `vw_estudios_no_top100` | quantos títulos de cada estúdio estão no Top 100 global | 43 |
| `vw_anime_mais_popular_por_temporada` | campeão de popularidade de cada temporada (winter/spring/summer/fall) | 4 |
| `vw_anime_melhor_avaliado_por_temporada` | campeão de nota de cada temporada | 4 |
| `vw_quadrante_popularidade_nota` | cada anime classificado em 1 de 4 quadrantes (popularidade × nota) | 4.245 |
| `vw_crescimento_genero` | contagem de lançamentos por gênero, 2021-23 vs 2024-26, com % de crescimento | 17 |
| `vw_ranking_genero_por_nota` | ranking completo (não só top 5) de animes por nota dentro de cada gênero — 1 linha por par (anime, gênero) | ~13.875 |
| `vw_quartil_popularidade` | todos os animes divididos em 4 quartis de popularidade (`members`) | 4.378 |
| `vw_genero_dominante_por_estudio` | 1 linha por estúdio (com `estudio_id`, pra relacionar com `dim_estudio`): gênero mais produzido, quantos títulos nesse gênero, total do catálogo do estúdio e % que o gênero representa | 376 |

Todas já estão aplicadas no banco `anime_analytics` (rodei `sql/queries_analiticas.sql` de novo depois de adicioná-las).

> Se pedir para instalar o driver do Npgsql, aceite — é necessário pra conectar no Postgres.

## 2. Relacionamentos (aba Modelo)

Crie estes relacionamentos (arrastando campo com campo, ou em **Gerenciar Relacionamentos**):

| De | Para | Cardinalidade | Direção do filtro |
|---|---|---|---|
| `dim_anime[anime_id]` | `fato_anime_metricas[anime_id]` | 1 : N | Único (padrão) |
| `dim_genero[nome_genero]` | `ponte_anime_genero[nome_genero]` | 1 : N | Único (padrão) |
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

Generos Cobertos = DISTINCTCOUNT(dim_genero[nome_genero])

Estudios Cobertos = DISTINCTCOUNT(dim_estudio[estudio_id])

Ranking Popularidade (anime) =
RANKX(ALL(dim_anime[anime_id]), CALCULATE(SUM(fato_anime_metricas[members])), , DESC)

Ranking Nota (anime) =
RANKX(ALL(dim_anime[anime_id]), CALCULATE(AVERAGE(fato_anime_metricas[score])), , DESC)

Qtd Animes por Estudio (contexto) = DISTINCTCOUNT(dim_anime[anime_id])

Popularidade Media (estudio) = AVERAGE(fato_anime_metricas[members])

Titulos Bem Avaliados =
CALCULATE(
    DISTINCTCOUNT(dim_anime[anime_id]),
    fato_anime_metricas[score] >= 8,
    fato_anime_metricas[scored_by] >= 500
)
```

A `Qtd Animes por Estudio` mede quantos animes o estúdio em foco tem, dentro do filtro ativo. Usada com um slicer numérico ("mínimo de animes"), evita que um estúdio com 1 título de nota alta apareça no topo do ranking por qualidade — com 110 dos 376 estúdios tendo só 1 anime na base, esse filtro é necessário, não cosmético.

`Titulos Bem Avaliados` define "bem avaliado" como nota ≥ 8 com pelo menos 500 votos — critério meu, ajustável. Serve pra responder "qual temporada tem mais títulos bem avaliados" (basta uma coluna com essa medida, eixo = `dim_anime[temporada]`).

## 4.1 Trazendo animes de verdade pro dashboard (não só números agregados)

**Top N sem escrever DAX** — pra "top 10 mais populares de todos os tempos" ou "top 10 melhor avaliados", não precisa de medida nenhuma: crie uma tabela com `dim_anime[titulo]` e `Total de Membros` (ou `Nota Media Confiavel`), clique nos "..." do campo no painel **Filtros** → **Tipo de filtro: Top N** → `10` → arraste `Total de Membros` pra "Por valor". O Power BI atualiza a lista sozinho conforme os slicers da página mudam.

**Top 5 / campeão de cada grupo (gênero, estúdio, temporada)** — isso já não dá pra fazer só com Top N (precisa de "top N *dentro de cada* grupo", uma coisa por linha da dimensão), então são as 8 views ranqueadas da tabela acima. Todas seguem o mesmo padrão: uma `ROW_NUMBER() OVER (PARTITION BY ...)` no SQL, sem precisar de relacionamento nenhum no Power BI — arraste os campos direto numa tabela.
- Gênero: filtrar `posicao = 1` dá o campeão único; `posicao <= 5` (sem filtro, é o que a view já traz) dá o ranking completo.
- Estúdio e Temporada: só têm campeão único (posicao=1 já embutido na view), porque com 376 estúdios um "top 5 de cada" viraria uma tabela de quase 2 mil linhas — pouco útil pra visualizar.

Exemplos reais que essas views trazem: o anime mais popular de todos é **Shingeki no Kyojin** (1.042.783 membros), mas olhando por gênero o campeão muda — em Comedy é **Boku no Hero Academia**, em Sci-Fi é **One Punch Man**, em Slice of Life é **Koe no Katachi**. Já o melhor avaliado (nota, não popularidade) muda de novo: **Sousou no Frieren** e **Gintama: THE FINAL** dividem o topo geral (9,1), mas em Mecha quem lidera é **Code Geass: Hangyaku no Lelouch R2** (8,7). Por temporada, o campeão de popularidade também muda: primavera é Shingeki no Kyojin, outono é Jujutsu Kaisen, verão é Tokyo Ghoul, inverno é Shingeki no Kyojin: The Final Season.

**Quadrante popularidade × nota** — `vw_quadrante_popularidade_nota` classifica cada um dos 4.245 animes da amostra confiável (`scored_by ≥ 1000`) em 4 grupos, dividindo por **mediana** (não tercil) de nota e de membros, pra dar grupos de tamanho parecido:

| Quadrante | Qtd. animes |
|---|---|
| Popular e bem avaliado | 1.450 |
| Pouco popular e avaliação baixa | 1.297 |
| Pouco popular e bem avaliado | 825 |
| Popular e avaliação baixa | 673 |

Pra usar: gráfico de dispersão com `titulo` (ou `anime_id`) nos detalhes, eixo X `members`, eixo Y `score`, **legenda = `quadrante`** — o Power BI colore os 4 grupos automaticamente. É o "popularidade × avaliação, 4 grupos" que você pediu, já pronto sem precisar de medida DAX nenhuma.

## 4.2 Gênero dominante por estúdio (gênero × estúdio sem repetir dado)

Cruzar gênero e estúdio direto nas tabelas-ponte é arriscado: como um anime pode ter vários gêneros **e** vários estúdios ao mesmo tempo, uma medida como `Total de Membros` numa matriz `nome_estudio` × `nome_genero` conta o mesmo anime uma vez em cada combinação gênero-estúdio que ele participa — correto dentro de cada célula, mas fácil de ler errado como "número de animes" se você não prestar atenção (ver ressalva no fim desta seção).

`vw_genero_dominante_por_estudio` resolve isso resumindo pra **1 linha por estúdio**, sem duplicar nenhum anime:
- Pra cada par (estúdio, gênero), conta `DISTINCT anime_id` — um anime com 2 gêneros do mesmo estúdio entra em 2 pares diferentes (um por gênero, o que é correto), mas nunca é contado 2x dentro do **mesmo** par.
- Usa `ROW_NUMBER()` pra pegar só o gênero de maior contagem de cada estúdio (empate desempatado por ordem alfabética do gênero, pra ser determinístico).
- Traz também `total_titulos` (catálogo inteiro do estúdio) e `percentual_do_catalogo` (quanto do catálogo aquele gênero representa) — assim dá pra distinguir um estúdio genuinamente especializado (ex: 75% do catálogo num gênero só) de um que só "lidera por pouco" entre vários gêneros parecidos.

**Como montar o gráfico de barras:**
1. Adicione um slicer numérico sobre `total_titulos` (ex: mínimo 8) — sem isso, estúdios com 1-2 títulos aparecem "100% especializados" só por acaso, o que é ruído, não sinal (mesmo cuidado já usado em `Nota Media` por estúdio, seção 4).
2. Gráfico de **barras** (colunas): eixo X = `nome_estudio`, valor = `qtd_no_genero` (ou `percentual_do_catalogo`, se quiser mostrar proporção em vez de volume absoluto), **legenda/cor = `genero_dominante`**.
3. Ordene as barras por `total_titulos` decrescente, pra mostrar primeiro os estúdios mais relevantes (maior catálogo).

Exemplo real (estúdios com ≥ 8 títulos, ordenado por catálogo): **Toei Animation** é o mais especializado do topo — 75,7% do catálogo (143 de 189 títulos) é Action. **bones** também é bem concentrado em Action (74,8%). Já **A-1 Pictures** e **TMS Entertainment**, apesar de Action também ser o gênero dominante, ficam abaixo de 50% — sinal de catálogo mais diversificado, não um estúdio "de um gênero só".

> Ressalva pra não confundir números: essa view mede **quantidade de títulos**, não popularidade nem nota. Um estúdio "especialista" em Action pode ter títulos pouco populares — se quiser cruzar especialização com sucesso, combine esse gráfico com `Popularidade Media (estudio)` ou `Nota Media Confiavel` (seção 4) no mesmo painel.

## 5. Páginas do dashboard

Cada pergunta abaixo está marcada com a fonte: **[nativo]** = só arrastar campos/medidas no Power BI, sem SQL novo; **[view]** = usa uma das views da seção 1; **[def.]** = eu defini um critério que não estava óbvio no pedido (marcado explicitamente, pra você poder mudar).

### Página 1 — Visão Geral de Animes

| Pergunta | Como responder |
|---|---|
| Top 10 mais populares de sempre | **[nativo]** Tabela `titulo` + `Total de Membros`, filtro Top N = 10 |
| Top 10 melhor avaliados de sempre | **[nativo]** Tabela `titulo` + `Nota Media Confiavel`, filtro Top N = 10 |
| Top 10 mais populares atualmente | **[nativo][def.]** Mesma tabela de populares + filtro `ano = 2026`. É aproximação, não trending real — ver seção "Sobre 'mais popular no momento'" |
| Nota média da base | **[nativo]** Card com `Nota Media` |
| Quantos animes na base | **[nativo]** Card com `Total de Animes` (4.378) |
| Ano com mais lançamentos | **[nativo]** Gráfico de linha/coluna `ano` × `Total de Animes` — response real: **2018** (228 títulos), seguido de 2016 e 2023 (216 cada) |
| Formatos com mais títulos | **[nativo]** Barras `tipo` × `Total de Animes` — TV lidera disparado (2.567), depois Filme (658) |
| Animes mais favoritados | **[nativo]** Tabela `titulo` + `Total de Favoritos`, Top N = 10 — real: **ONE PIECE** lidera (109.197 favoritos), seguido de HUNTER×HUNTER (97.629) e Shingeki no Kyojin (86.458) |
| Relação popularidade × avaliação | **[view]** Scatter usando `vw_quadrante_popularidade_nota` (ver seção 4.1) — 4 grupos, cores automáticas por `quadrante` |

**Gráficos da página:** barras horizontais (top populares, top avaliados), ranking/tabela ("em alta agora"), linha (animes por ano), barras (formatos), **donut** (`status` — 4.206 `FINISHED`, 101 `NOT_YET_RELEASED`, 69 `RELEASING`, 2 `CANCELLED`), scatter com legenda por quadrante.

### Página 2 — Animes por Gênero

Filtro de página: slicer `dim_genero[nome_genero]`.

| Pergunta | Como responder |
|---|---|
| Top 5 mais populares de cada gênero | **[view]** `vw_anime_mais_popular_por_genero`, filtrar `posicao <= 5` |
| Top 5 melhor avaliados de cada gênero | **[view]** `vw_anime_melhor_avaliado_por_genero`, filtrar `posicao <= 5` |
| Top 5 "em maior popularidade" de cada gênero | **[def.]** Interpretei como a mesma pergunta que a primeira (popularidade = `members`) — se você quis dizer outra coisa (ex: crescimento de popularidade), me avisa que ajusto |
| Nota média de cada gênero | **[nativo]** Já existe: `vw_nota_media_genero` |
| Gênero com maior/menor nota média | **[nativo]** Ordenar a tabela de nota média — real: maior é **Thriller** (7,35), menor é **Horror** (6,78) |
| Como a popularidade dos gêneros mudou ao longo dos anos | **[nativo]** Gráfico de linhas: eixo `ano`, legenda `nome_genero`, valor `Total de Membros` (funciona porque as duas pontes já têm direção "Ambos") |
| Quais gêneros mais cresceram nos últimos anos | **[view][def.]** `vw_crescimento_genero` — comparo 2024-2026 vs 2021-2023 (definição minha, ajustável no SQL). Real: **Romance** cresceu mais (+28,5%, de 151 pra 194 títulos), **Mecha** encolheu mais (-56,5%) |
| Gênero com mais lançamentos atualmente | **[nativo][def.]** Contagem por gênero filtrando `ano = 2026` (mesma aproximação da página 1) |

### Página 3 — Estúdios

| Pergunta | Como responder |
|---|---|
| Top 10 que mais produziram | **[nativo]** Já existe: barras por `Total de Animes` |
| Top 10 com maior nota média | **[nativo]** Já existe, com filtro mínimo de 8 animes (ver seção 4) |
| Top 10 com maior popularidade média | **[nativo]** Nova medida `Popularidade Media (estudio)`, mesmo filtro de mínimo |
| Estúdios com mais animes no Top 100 | **[view]** `vw_estudios_no_top100` — real: **Production I.G**, **A-1 Pictures** e **bones** empatados na liderança (11 cada), depois MAPPA (9) |
| Anime mais popular de cada estúdio | **[view]** `vw_anime_mais_popular_por_estudio` (376 linhas — sugiro tabela com busca/slicer de estúdio, não gráfico) |
| Anime melhor avaliado de cada estúdio | **[view]** `vw_anime_melhor_avaliado_por_estudio` (370 linhas — 6 estúdios não têm título com `scored_by ≥ 500`) |
| Estúdio com mais lançamentos nos últimos anos | **[nativo][def.]** Slicer `ano ≥ 2024` + tabela `Total de Animes` por estúdio, Top N |
| Quais gêneros cada estúdio mais produz (visão completa) | **[nativo]** Matriz: linhas `nome_estudio` (com slicer pra escolher 1 de cada vez, senão fica 376×17 células), colunas `nome_genero`, valor = contagem |
| Estúdio "especialista": qual gênero domina o catálogo de cada estúdio | **[view]** `vw_genero_dominante_por_estudio` — ver "4.2 Gênero dominante por estúdio" abaixo |

### Página 4 — Temporadas

Filtros de página: slicer `dim_anime[ano]` (2013-2027) e slicer `dim_anime[temporada]`.

| Pergunta | Como responder |
|---|---|
| Temporada com mais lançamentos / quantos por temporada | **[nativo]** Já existe: barras `temporada` × `Total de Animes` — real: outono lidera (1.173), inverno é o menor (898) |
| Temporada com maior popularidade média | **[nativo]** Barras `temporada` × `AVERAGE(members)` |
| Anime mais popular de cada temporada | **[view]** `vw_anime_mais_popular_por_temporada` — real: primavera → Shingeki no Kyojin, outono → Jujutsu Kaisen, verão → Tokyo Ghoul, inverno → Shingeki no Kyojin: The Final Season |
| Melhor avaliado de cada temporada | **[view]** `vw_anime_melhor_avaliado_por_temporada` — real: outono → Sousou no Frieren (9,1), inverno → Gintama: THE FINAL (9,1), primavera → Fullmetal Alchemist (9,0), verão → Chainsaw Man: Reze-hen (9,0) |
| Top 5 populares/avaliados da temporada selecionada | **[nativo]** Tabela com Top N = 5, respeitando o slicer `temporada` da página |
| Gêneros que dominam cada temporada | **[nativo]** Matriz `temporada` × `nome_genero`, valor = contagem |
| Estúdio que mais lançou em cada temporada | **[nativo]** Matriz `temporada` × `nome_estudio` (ou Top N por temporada) |
| Temporada com mais títulos bem avaliados | **[nativo][def.]** Medida `Titulos Bem Avaliados` (nota ≥ 8, ≥ 500 votos — critério meu) por `temporada` |
| Como o número de lançamentos mudou ao longo dos anos | **[nativo]** Mesmo gráfico da Página 1 (linha por `ano`) |
| "Qual foi o anime mais popular do Summer 2025?" (exemplo de pergunta ad-hoc) | **[nativo]** Aplicar os dois slicers da página (`ano = 2025`, `temporada = summer`) sobre a tabela Top N de populares — funciona pra qualquer combinação ano+temporada, não precisa de view nova |

**Filtros globais (todas as páginas):** `dim_anime[tipo]`, `dim_anime[fonte]`, `dim_anime[status]`, `dim_anime[ano]`, `dim_anime[temporada]`, `dim_genero[nome_genero]`, `dim_estudio[nome_estudio]`. (`classificacao_etaria` foi removida do schema — ver CLAUDE.md; não existe mais como coluna, não só "sempre vazia".)

## Sobre as abas de Mangá

Você pediu duas abas de mangá (Visão Geral e Por Gênero) — isso eu **não construí ainda** porque exige um pipeline paralelo inteiro, não só views novas: a coleta hoje só busca `media(type: ANIME, ...)` na AniList; mangá é `type: MANGA`, com campos diferentes (`chapters`/`volumes` em vez de `episodes`/`duration`, sem `studios`) e precisaria de um schema próprio (`dim_manga`, `fato_manga_metricas`, ponte com `dim_genero`). É um projeto do tamanho do que já existe pra anime, rodado em paralelo. Fica registrado aqui como pendente — ver conversa sobre isso pra decidir se entra nesta fase ou depois.

## 6. Aparência e tema visual

O Power BI aplica cores/fontes por meio de um arquivo de tema (**Exibir → Temas → Procurar temas**, formato `.json`). É esse arquivo que padroniza cores dos gráficos, fundo dos cards e tipografia em todas as páginas de uma vez — é o mecanismo certo pra separar "design visual" de "montagem dos gráficos", não uma ferramenta de design externa (ver observação abaixo sobre isso).

## Sobre "mais popular no momento"

`members` e `popularity` (a coluna de ranking) são medidas **acumuladas desde sempre** — quantas pessoas colocaram aquele anime na lista ao longo de toda a história dele na AniList, não uma "tendência desta semana/mês" (a AniList tem um campo `trending` pra isso, mas ele não está no nosso schema — deixamos de fora conscientemente, pra não exigir recoletar os 5.000 animes de novo só por causa disso).

Aproximação adotada: uma visual "Em alta agora" com filtro de `ano`/`temporada` fixado no mais recente (2026) + tabela ordenada por `Total de Membros`. Isso mostra o que está bombando *entre os lançamentos recentes*, não o trending real da comunidade — vale deixar essa ressalva escrita no próprio dashboard (um texto pequeno abaixo do card já resolve), pra não prometer uma leitura que os dados não sustentam.

## Atualizando os dados

Se a coleta rodar de novo (`coletar_anilist.py` → `tratar_dados.py` → `carga_sql.py`), não é preciso refazer nada no Power BI — só clicar em **Atualizar** depois de recarregar o banco.

`carga_sql.py` faz **upsert** (via staging table + `INSERT ... ON CONFLICT`), não `TRUNCATE`: rodar de novo atualiza dimensões/pontes e *soma* uma nova linha por anime em `fato_anime_metricas` (chave `anime_id + data_coleta`), sem apagar coletas antigas. Rodar duas vezes no mesmo dia não duplica nada nem quebra — a segunda vez só atualiza os mesmos valores no lugar (testado). `sql/ddl.sql`, por outro lado, **é destrutivo** (`DROP TABLE ... CASCADE` no topo) — só rodar na configuração inicial ou se o schema mudar de propósito; nunca como parte do fluxo normal de recoleta.
