-- Schema for the anime analytics project (AniList API, GraphQL)
-- Dimensions first, then N:N bridge tables, then the fact table.
-- Data source: graphql.anilist.co (see src/coletar_anilist.py)
--
-- Reset script: the DROPs below make this file safe to run again (e.g. for
-- a schema migration), but they are destructive — everything is wiped,
-- including the history accumulated in fato_anime_metricas. Only run this
-- on initial setup or when the schema purpose changes. For day-to-day loads
-- (without losing history), use src/carga_sql.py, which does an upsert.

DROP TABLE IF EXISTS ponte_anime_genero CASCADE;
DROP TABLE IF EXISTS ponte_anime_estudio CASCADE;
DROP TABLE IF EXISTS fato_anime_metricas CASCADE;
DROP TABLE IF EXISTS dim_anime CASCADE;
DROP TABLE IF EXISTS dim_genero CASCADE;
DROP TABLE IF EXISTS dim_estudio CASCADE;

CREATE TABLE dim_anime (
    anime_id            INTEGER PRIMARY KEY,       -- AniList id
    titulo              TEXT NOT NULL,
    titulo_ingles       TEXT,
    titulo_japones      TEXT,
    tipo                TEXT,                      -- TV, MOVIE, OVA, ONA, SPECIAL, MUSIC (AniList's "format")
    fonte               TEXT,                      -- MANGA, LIGHT_NOVEL, ORIGINAL, GAME... (AniList's "source")
    episodios           INTEGER,
    status              TEXT,                      -- FINISHED, RELEASING, NOT_YET_RELEASED, CANCELLED, HIATUS
    em_exibicao         BOOLEAN,
    data_inicio_exibicao DATE,
    data_fim_exibicao   DATE,
    duracao_min         NUMERIC,
    ano                 INTEGER,
    temporada            TEXT                      -- winter, spring, summer, fall
);

-- No surrogate id: AniList doesn't provide a genre id, and generating a
-- sequential one by alphabetical order on every collection run would be
-- unstable (it shifts if the set of genres changes between runs).
-- nome_genero is the natural, stable key instead.
CREATE TABLE dim_genero (
    nome_genero          TEXT PRIMARY KEY
);

CREATE TABLE dim_estudio (
    estudio_id           INTEGER PRIMARY KEY,       -- AniList studio id (only studios with isAnimationStudio=true)
    nome_estudio          TEXT NOT NULL
);

CREATE TABLE ponte_anime_genero (
    anime_id            INTEGER REFERENCES dim_anime(anime_id),
    nome_genero          TEXT REFERENCES dim_genero(nome_genero),
    PRIMARY KEY (anime_id, nome_genero)
);

CREATE TABLE ponte_anime_estudio (
    anime_id            INTEGER REFERENCES dim_anime(anime_id),
    estudio_id           INTEGER REFERENCES dim_estudio(estudio_id),
    PRIMARY KEY (anime_id, estudio_id)
);

CREATE TABLE fato_anime_metricas (
    anime_id            INTEGER REFERENCES dim_anime(anime_id),
    data_coleta          DATE NOT NULL,
    score                NUMERIC,                  -- AniList's averageScore (0-100), converted to a 0-10 scale
    scored_by            INTEGER,                  -- sum of stats.scoreDistribution (AniList doesn't expose a direct count)
    rank                 INTEGER,                  -- rankings[type=RATED, allTime=true].rank
    popularity           INTEGER,                  -- rankings[type=POPULAR, allTime=true].rank
    members              INTEGER,                  -- AniList's "popularity" field (count of users with the anime on their list)
    favorites             INTEGER,                  -- AniList's favourites
    PRIMARY KEY (anime_id, data_coleta)
);
