-- Analytical views and queries on top of the ddl.sql schema

-- Latest metrics for each anime (fato_anime_metricas can accumulate
-- several collection runs per anime_id over time).
CREATE OR REPLACE VIEW vw_metricas_atuais AS
SELECT f.*
FROM (
    SELECT
        f.*,
        ROW_NUMBER() OVER (PARTITION BY anime_id ORDER BY data_coleta DESC) AS rn
    FROM fato_anime_metricas f
) f
WHERE rn = 1;


-- Average score per genre
CREATE OR REPLACE VIEW vw_nota_media_genero AS
SELECT
    g.nome_genero,
    COUNT(*)                                            AS qtd_animes,
    ROUND(AVG(m.score)::numeric, 2)                     AS nota_media,
    ROUND(STDDEV(m.score)::numeric, 2)                  AS desvio_padrao_nota,
    ROUND(AVG(m.score) FILTER (WHERE m.scored_by >= 1000)::numeric, 2) AS nota_media_amostra_confiavel
FROM dim_genero g
JOIN ponte_anime_genero pg ON pg.nome_genero = g.nome_genero
JOIN vw_metricas_atuais m ON m.anime_id = pg.anime_id
GROUP BY g.nome_genero
ORDER BY nota_media DESC;


-- Studio ranking: production volume vs average score
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


-- Audience engagement per genre (members/favorites, loyalty)
CREATE OR REPLACE VIEW vw_engajamento_genero AS
SELECT
    g.nome_genero,
    COUNT(*)                                                       AS qtd_animes,
    SUM(m.members)                                                 AS total_membros,
    SUM(m.favorites)                                                AS total_favoritos,
    ROUND((SUM(m.favorites)::numeric / NULLIF(SUM(m.members), 0)), 4) AS proporcao_favoritos_por_membro
FROM dim_genero g
JOIN ponte_anime_genero pg ON pg.nome_genero = g.nome_genero
JOIN vw_metricas_atuais m ON m.anime_id = pg.anime_id
GROUP BY g.nome_genero
ORDER BY proporcao_favoritos_por_membro DESC;


-- Score and popularity per anime, with aggregated genres
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
LEFT JOIN dim_genero g ON g.nome_genero = pg.nome_genero
GROUP BY a.anime_id, a.titulo, a.tipo, a.fonte, a.ano, m.score, m.scored_by, m.popularity, m.members, m.favorites;


-- Top 5 most popular anime (highest member count) of each genre.
-- Filtering posicao = 1 in Power BI gives the "champion" of each genre; posicao <= 5 gives the full ranking.
CREATE OR REPLACE VIEW vw_anime_mais_popular_por_genero AS
SELECT nome_genero, titulo, members, score, posicao
FROM (
    SELECT
        g.nome_genero, a.titulo, m.members, m.score,
        ROW_NUMBER() OVER (PARTITION BY g.nome_genero ORDER BY m.members DESC, a.anime_id) AS posicao
    FROM dim_genero g
    JOIN ponte_anime_genero pg ON pg.nome_genero = g.nome_genero
    JOIN dim_anime a ON a.anime_id = pg.anime_id
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
) ranking
WHERE posicao <= 5;


-- Top 5 best-rated anime of each genre (reliable sample: scored_by >= 500).
-- Score ties are broken by scored_by (the most-voted among the tied ones),
-- so the ranking is deterministic instead of depending on row physical order.
CREATE OR REPLACE VIEW vw_anime_melhor_avaliado_por_genero AS
SELECT nome_genero, titulo, score, members, posicao
FROM (
    SELECT
        g.nome_genero, a.titulo, m.score, m.members,
        ROW_NUMBER() OVER (PARTITION BY g.nome_genero ORDER BY m.score DESC, m.scored_by DESC, a.anime_id) AS posicao
    FROM dim_genero g
    JOIN ponte_anime_genero pg ON pg.nome_genero = g.nome_genero
    JOIN dim_anime a ON a.anime_id = pg.anime_id
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
    WHERE m.scored_by >= 500 AND m.score IS NOT NULL
) ranking
WHERE posicao <= 5;


-- Full ranking of anime within each genre, by score (every position,
-- not just the top 5 from vw_anime_melhor_avaliado_por_genero).
CREATE OR REPLACE VIEW vw_ranking_genero_por_nota AS
SELECT
    g.nome_genero,
    a.titulo,
    m.score,
    RANK() OVER (PARTITION BY g.nome_genero ORDER BY m.score DESC) AS posicao_no_genero
FROM dim_genero g
JOIN ponte_anime_genero pg ON pg.nome_genero = g.nome_genero
JOIN dim_anime a ON a.anime_id = pg.anime_id
JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
ORDER BY g.nome_genero, posicao_no_genero;

-- Popularity brackets (quartiles) for every anime, by member count.
CREATE OR REPLACE VIEW vw_quartil_popularidade AS
SELECT
    a.titulo,
    m.popularity,
    m.members,
    NTILE(4) OVER (ORDER BY m.members DESC) AS quartil_popularidade -- 1 = most popular
FROM dim_anime a
JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
ORDER BY quartil_popularidade, m.members DESC;

-- Popularity x score quadrant for each anime (reliable sample: scored_by >= 1000).
-- Splits by median score and median members instead of fixed thirds — gives
-- 4 balanced groups (~50/50 on each axis), ready to color a scatter plot in Power BI.
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


-- Most popular anime of each studio
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


-- Best-rated anime of each studio (reliable sample: scored_by >= 500)
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


-- How many titles of each studio are among the 100 most popular anime in the dataset
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


-- Most popular anime of each season (winter/spring/summer/fall, aggregating every year)
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


-- Best-rated anime of each season (reliable sample: scored_by >= 500)
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


-- Growth in releases per genre: last 3 full years (2024-2026) vs the previous 3 (2021-2023).
-- Fixed period (not relative to CURRENT_DATE) so it doesn't shift on its own between runs;
-- adjust the years here when running this at a different point in time. 2026 hasn't closed yet.
CREATE OR REPLACE VIEW vw_crescimento_genero AS
WITH contagem AS (
    SELECT
        g.nome_genero,
        COUNT(*) FILTER (WHERE a.ano BETWEEN 2024 AND 2026) AS qtd_recente,
        COUNT(*) FILTER (WHERE a.ano BETWEEN 2021 AND 2023) AS qtd_anterior
    FROM dim_genero g
    JOIN ponte_anime_genero pg ON pg.nome_genero = g.nome_genero
    JOIN dim_anime a ON a.anime_id = pg.anime_id
    GROUP BY g.nome_genero
)
SELECT
    nome_genero, qtd_anterior, qtd_recente,
    ROUND(((qtd_recente - qtd_anterior)::numeric / NULLIF(qtd_anterior, 0)) * 100, 1) AS crescimento_pct
FROM contagem
ORDER BY crescimento_pct DESC NULLS LAST;


-- Dominant genre of each studio (1 row per studio, for a bar chart).
-- Each studio-genre pair counts DISTINCT anime_id: an anime with several genres
-- from the same studio ends up in several pairs (one per genre, correctly), but
-- is never counted twice within the SAME pair — that's what avoids double-counting.
CREATE OR REPLACE VIEW vw_genero_dominante_por_estudio AS
WITH pares AS (
    SELECT
        e.estudio_id,
        e.nome_estudio,
        g.nome_genero,
        COUNT(DISTINCT pe.anime_id) AS qtd_no_genero
    FROM dim_estudio e
    JOIN ponte_anime_estudio pe ON pe.estudio_id = e.estudio_id
    JOIN ponte_anime_genero pg ON pg.anime_id = pe.anime_id
    JOIN dim_genero g ON g.nome_genero = pg.nome_genero
    GROUP BY e.estudio_id, e.nome_estudio, g.nome_genero
),
total_estudio AS (
    SELECT e.estudio_id, COUNT(DISTINCT pe.anime_id) AS total_titulos
    FROM dim_estudio e
    JOIN ponte_anime_estudio pe ON pe.estudio_id = e.estudio_id
    GROUP BY e.estudio_id
),
ranking AS (
    SELECT
        p.estudio_id,
        p.nome_estudio,
        p.nome_genero,
        p.qtd_no_genero,
        t.total_titulos,
        ROW_NUMBER() OVER (PARTITION BY p.estudio_id ORDER BY p.qtd_no_genero DESC, p.nome_genero) AS posicao
    FROM pares p
    JOIN total_estudio t ON t.estudio_id = p.estudio_id
)
SELECT
    estudio_id,
    nome_estudio,
    nome_genero AS genero_dominante,
    qtd_no_genero,
    total_titulos,
    ROUND((qtd_no_genero::numeric / total_titulos) * 100, 1) AS percentual_do_catalogo
FROM ranking
WHERE posicao = 1
ORDER BY total_titulos DESC;


-- Summary sheet for each studio (1 row per studio): dominant genre, title
-- volume, average score and the most popular anime — joins 3 views that
-- already exist, each of them 1:1 with the studio, so no row gets duplicated.
-- Feeds a detail card in Power BI that only reacts to the Studio slicer.
CREATE OR REPLACE VIEW vw_ficha_estudio AS
SELECT
    gd.estudio_id,
    gd.nome_estudio,
    gd.genero_dominante,
    gd.qtd_no_genero,
    gd.total_titulos,
    re.nota_media,
    re.total_membros,
    mp.titulo  AS anime_mais_popular,
    mp.members AS anime_mais_popular_membros
FROM vw_genero_dominante_por_estudio gd
JOIN vw_ranking_estudios re ON re.estudio_id = gd.estudio_id
LEFT JOIN vw_anime_mais_popular_por_estudio mp ON mp.nome_estudio = gd.nome_estudio;
