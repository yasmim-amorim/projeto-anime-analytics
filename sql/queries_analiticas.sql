-- Camada analítica em SQL (Etapa 6 do plano de ação — projeto anime)
-- Views + queries analíticas sobre o schema de sql/ddl.sql

-- ============================================================
-- View base: métricas mais recentes de cada anime
-- (fato_anime_metricas pode acumular várias coletas por anime_id
--  ao longo do tempo; as views analíticas trabalham sobre a "foto" mais atual)
-- ============================================================
CREATE OR REPLACE VIEW vw_metricas_atuais AS
SELECT f.*
FROM (
    SELECT
        f.*,
        ROW_NUMBER() OVER (PARTITION BY anime_id ORDER BY data_coleta DESC) AS rn
    FROM fato_anime_metricas f
) f
WHERE rn = 1;


-- ============================================================
-- 1. Nota média por gênero
-- ============================================================
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


-- ============================================================
-- 2. Ranking de estúdios: volume x qualidade média
-- ============================================================
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


-- ============================================================
-- 3. Engajamento do público por gênero (membros/favoritos, fidelização)
-- ============================================================
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


-- ============================================================
-- 4. Score x popularidade por anime (base para o "cult vs hype")
-- ============================================================
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


-- ============================================================
-- Queries analíticas avuls as (window functions)
-- ============================================================

-- 5. Ranking de animes dentro de cada gênero, por nota (RANK())
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

-- 6. Faixas de popularidade (quartis) via NTILE()
SELECT
    a.titulo,
    m.popularity,
    m.members,
    NTILE(4) OVER (ORDER BY m.members DESC) AS quartil_popularidade -- 1 = mais popular
FROM dim_anime a
JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
ORDER BY quartil_popularidade, m.members DESC;

-- 7. "Cult" (nota alta, popularidade baixa) vs "Hype" (popularidade alta, nota mediana)
--    usa NTILE por popularidade e nota pra classificar cada anime nos dois eixos
WITH classificado AS (
    SELECT
        a.titulo,
        m.score,
        m.members,
        NTILE(3) OVER (ORDER BY m.score DESC)   AS faixa_nota,      -- 1 = nota mais alta
        NTILE(3) OVER (ORDER BY m.members DESC) AS faixa_popularidade -- 1 = mais popular
    FROM dim_anime a
    JOIN vw_metricas_atuais m ON m.anime_id = a.anime_id
)
SELECT
    titulo, score, members,
    CASE
        WHEN faixa_nota = 1 AND faixa_popularidade = 3 THEN 'cult (nota alta, pouco popular)'
        WHEN faixa_nota >= 2 AND faixa_popularidade = 1 THEN 'hype (muito popular, nota mediana)'
        ELSE 'outro'
    END AS classificacao
FROM classificado
ORDER BY faixa_nota, faixa_popularidade;
