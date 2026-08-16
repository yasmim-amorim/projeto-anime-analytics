-- Views e queries analíticas sobre o schema de ddl.sql

-- Métricas mais recentes de cada anime (fato_anime_metricas pode acumular
-- várias coletas por anime_id ao longo do tempo).
CREATE OR REPLACE VIEW vw_metricas_atuais AS
SELECT f.*
FROM (
    SELECT
        f.*,
        ROW_NUMBER() OVER (PARTITION BY anime_id ORDER BY data_coleta DESC) AS rn
    FROM fato_anime_metricas f
) f
WHERE rn = 1;


-- Nota média por gênero
CREATE OR REPLACE VIEW vw_nota_media_genero AS
SELECT
    g.genero_id,
    g.nome_genero,
    COUNT(*)                                            AS qtd_animes,
    ROUND(AVG(m.score)::numeric, 2)                     AS nota_media,
    ROUND(STDDEV(m.score)::numeric, 2)                  AS desvio_padrao_nota,
    ROUND(AVG(m.score) FILTER (WHERE m.scored_by >= 1000)::numeric, 2) AS nota_media_amostra_confiavel
FROM dim_genero g
JOIN ponte_anime_genero pg ON pg.genero_id = g.genero_id
JOIN vw_metricas_atuais m ON m.anime_id = pg.anime_id
GROUP BY g.genero_id, g.nome_genero
ORDER BY nota_media DESC;


-- Ranking de estúdios: volume de produções x nota média
CREATE OR REPLACE VIEW vw_ranking_estudios AS
SELECT
    e.estudio_id,
    e.nome_estudio,
    COUNT(*)                             AS qtd_animes,
    ROUND(AVG(m.score)::numeric, 2)      AS nota_media,
    SUM(m.members)                       AS total_membros,
    SUM(m.favorites)                     AS total_favoritos
FROM dim_estudio e
JOIN ponte_anime_estudio pe ON pe.estudio_id = e.estudio_id
JOIN vw_metricas_atuais m ON m.anime_id = pe.anime_id
GROUP BY e.estudio_id, e.nome_estudio
ORDER BY qtd_animes DESC, nota_media DESC;


-- Engajamento do público por gênero (membros/favoritos, fidelização)
CREATE OR REPLACE VIEW vw_engajamento_genero AS
SELECT
    g.genero_id,
    g.nome_genero,
    COUNT(*)                                                       AS qtd_animes,
    SUM(m.members)                                                 AS total_membros,
    SUM(m.favorites)                                                AS total_favoritos,
    ROUND((SUM(m.favorites)::numeric / NULLIF(SUM(m.members), 0)), 4) AS proporcao_favoritos_por_membro
FROM dim_genero g
JOIN ponte_anime_genero pg ON pg.genero_id = g.genero_id
JOIN vw_metricas_atuais m ON m.anime_id = pg.anime_id
GROUP BY g.genero_id, g.nome_genero
ORDER BY proporcao_favoritos_por_membro DESC;


-- Score e popularidade por anime, com gêneros agregados
CREATE OR REPLACE VIEW vw_score_vs_popularidade AS
SELECT
    a.anime_id,
    a.titulo,
    a.tipo,
    a.fonte,
    a.ano,
    m.score,
    m.scored_by,
    m.popularity,
    m.members,
    m.favorites,
    STRING_AGG(g.nome_genero, ', ' ORDER BY g.nome_genero) AS generos
FROM dim_anime a
JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
LEFT JOIN ponte_anime_genero pg ON pg.anime_id = a.anime_id
LEFT JOIN dim_genero g ON g.genero_id = pg.genero_id
GROUP BY a.anime_id, a.titulo, a.tipo, a.fonte, a.ano, m.score, m.scored_by, m.popularity, m.members, m.favorites;


-- Top 5 animes mais populares (maior número de membros) de cada gênero.
-- Filtrar posicao = 1 no Power BI dá o "campeão" de cada gênero; posicao <= 5 dá o ranking completo.
CREATE OR REPLACE VIEW vw_anime_mais_popular_por_genero AS
SELECT nome_genero, titulo, members, score, posicao
FROM (
    SELECT
        g.nome_genero, a.titulo, m.members, m.score,
        ROW_NUMBER() OVER (PARTITION BY g.genero_id ORDER BY m.members DESC, a.anime_id) AS posicao
    FROM dim_genero g
    JOIN ponte_anime_genero pg ON pg.genero_id = g.genero_id
    JOIN dim_anime a ON a.anime_id = pg.anime_id
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
) ranking
WHERE posicao <= 5;


-- Top 5 animes mais bem avaliados de cada gênero (amostra confiável: scored_by >= 500).
-- Empates em score são desempatados por scored_by (o mais votado entre os empatados),
-- pra ranking ficar determinístico em vez de depender da ordem física das linhas.
CREATE OR REPLACE VIEW vw_anime_melhor_avaliado_por_genero AS
SELECT nome_genero, titulo, score, members, posicao
FROM (
    SELECT
        g.nome_genero, a.titulo, m.score, m.members,
        ROW_NUMBER() OVER (PARTITION BY g.genero_id ORDER BY m.score DESC, m.scored_by DESC, a.anime_id) AS posicao
    FROM dim_genero g
    JOIN ponte_anime_genero pg ON pg.genero_id = g.genero_id
    JOIN dim_anime a ON a.anime_id = pg.anime_id
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    WHERE m.scored_by >= 500 AND m.score IS NOT NULL
) ranking
WHERE posicao <= 5;


-- Ranking de animes dentro de cada gênero, por nota
SELECT
    g.nome_genero,
    a.titulo,
    m.score,
    RANK() OVER (PARTITION BY g.genero_id ORDER BY m.score DESC) AS posicao_no_genero
FROM dim_genero g
JOIN ponte_anime_genero pg ON pg.genero_id = g.genero_id
JOIN dim_anime a ON a.anime_id = pg.anime_id
JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
ORDER BY g.nome_genero, posicao_no_genero;

-- Faixas de popularidade (quartis)
SELECT
    a.titulo,
    m.popularity,
    m.members,
    NTILE(4) OVER (ORDER BY m.members DESC) AS quartil_popularidade -- 1 = mais popular
FROM dim_anime a
JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
ORDER BY quartil_popularidade, m.members DESC;

-- Quadrante de popularidade x nota de cada anime (amostra confiável: scored_by >= 1000).
-- Divide por mediana de score e de membros em vez de tercis fixos — dá 4 grupos
-- balanceados (~50/50 em cada eixo), prontos pra colorir um scatter no Power BI.
CREATE OR REPLACE VIEW vw_quadrante_popularidade_nota AS
WITH base AS (
    SELECT a.anime_id, a.titulo, m.score, m.members
    FROM dim_anime a
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    WHERE m.scored_by >= 1000 AND m.score IS NOT NULL
),
medianas AS (
    SELECT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY score)   AS mediana_score,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY members) AS mediana_members
    FROM base
)
SELECT
    b.anime_id, b.titulo, b.score, b.members,
    CASE
        WHEN b.members >= md.mediana_members AND b.score >= md.mediana_score THEN 'Popular e bem avaliado'
        WHEN b.members >= md.mediana_members AND b.score <  md.mediana_score THEN 'Popular e avaliação baixa'
        WHEN b.members <  md.mediana_members AND b.score >= md.mediana_score THEN 'Pouco popular e bem avaliado'
        ELSE 'Pouco popular e avaliação baixa'
    END AS quadrante
FROM base b CROSS JOIN medianas md;


-- Anime mais popular de cada estúdio
CREATE OR REPLACE VIEW vw_anime_mais_popular_por_estudio AS
SELECT nome_estudio, titulo, members, score
FROM (
    SELECT
        e.nome_estudio, a.titulo, m.members, m.score,
        ROW_NUMBER() OVER (PARTITION BY e.estudio_id ORDER BY m.members DESC, a.anime_id) AS posicao
    FROM dim_estudio e
    JOIN ponte_anime_estudio pe ON pe.estudio_id = e.estudio_id
    JOIN dim_anime a ON a.anime_id = pe.anime_id
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
) ranking
WHERE posicao = 1;


-- Anime mais bem avaliado de cada estúdio (amostra confiável: scored_by >= 500)
CREATE OR REPLACE VIEW vw_anime_melhor_avaliado_por_estudio AS
SELECT nome_estudio, titulo, score, members
FROM (
    SELECT
        e.nome_estudio, a.titulo, m.score, m.members,
        ROW_NUMBER() OVER (PARTITION BY e.estudio_id ORDER BY m.score DESC, m.scored_by DESC, a.anime_id) AS posicao
    FROM dim_estudio e
    JOIN ponte_anime_estudio pe ON pe.estudio_id = e.estudio_id
    JOIN dim_anime a ON a.anime_id = pe.anime_id
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    WHERE m.scored_by >= 500 AND m.score IS NOT NULL
) ranking
WHERE posicao = 1;


-- Quantos títulos de cada estúdio estão entre os 100 animes mais populares da base
CREATE OR REPLACE VIEW vw_estudios_no_top100 AS
WITH top100 AS (
    SELECT a.anime_id
    FROM dim_anime a
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    ORDER BY m.members DESC, a.anime_id
    LIMIT 100
)
SELECT e.nome_estudio, COUNT(*) AS qtd_no_top100
FROM dim_estudio e
JOIN ponte_anime_estudio pe ON pe.estudio_id = e.estudio_id
JOIN top100 t ON t.anime_id = pe.anime_id
GROUP BY e.nome_estudio
ORDER BY qtd_no_top100 DESC;


-- Anime mais popular de cada temporada (winter/spring/summer/fall, agregando todos os anos)
CREATE OR REPLACE VIEW vw_anime_mais_popular_por_temporada AS
SELECT temporada, titulo, members, score
FROM (
    SELECT
        a.temporada, a.titulo, m.members, m.score,
        ROW_NUMBER() OVER (PARTITION BY a.temporada ORDER BY m.members DESC, a.anime_id) AS posicao
    FROM dim_anime a
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    WHERE a.temporada IS NOT NULL
) ranking
WHERE posicao = 1;


-- Anime mais bem avaliado de cada temporada (amostra confiável: scored_by >= 500)
CREATE OR REPLACE VIEW vw_anime_melhor_avaliado_por_temporada AS
SELECT temporada, titulo, score, members
FROM (
    SELECT
        a.temporada, a.titulo, m.score, m.members,
        ROW_NUMBER() OVER (PARTITION BY a.temporada ORDER BY m.score DESC, m.scored_by DESC, a.anime_id) AS posicao
    FROM dim_anime a
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    WHERE a.temporada IS NOT NULL AND m.scored_by >= 500 AND m.score IS NOT NULL
) ranking
WHERE posicao = 1;


-- Crescimento de lançamentos por gênero: últimos 3 anos completos (2024-2026) vs os 3 anteriores (2021-2023).
-- Período fixo (não relativo a CURRENT_DATE) pra não mudar sozinho a cada execução;
-- ajustar os anos aqui quando rodar em outro momento. 2026 ainda não fechou o ano.
CREATE OR REPLACE VIEW vw_crescimento_genero AS
WITH contagem AS (
    SELECT
        g.nome_genero,
        COUNT(*) FILTER (WHERE a.ano BETWEEN 2024 AND 2026) AS qtd_recente,
        COUNT(*) FILTER (WHERE a.ano BETWEEN 2021 AND 2023) AS qtd_anterior
    FROM dim_genero g
    JOIN ponte_anime_genero pg ON pg.genero_id = g.genero_id
    JOIN dim_anime a ON a.anime_id = pg.anime_id
    GROUP BY g.nome_genero
)
SELECT
    nome_genero, qtd_anterior, qtd_recente,
    ROUND(((qtd_recente - qtd_anterior)::numeric / NULLIF(qtd_anterior, 0)) * 100, 1) AS crescimento_pct
FROM contagem
ORDER BY crescimento_pct DESC NULLS LAST;
