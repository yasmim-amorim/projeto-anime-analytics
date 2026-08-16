-- Schema do projeto de análise de anime (API AniList, GraphQL)
-- Dimensões primeiro, depois pontes N:N, depois fato.
-- Fonte de dados: graphql.anilist.co (ver src/coletar_anilist.py)

CREATE TABLE dim_anime (
    anime_id            INTEGER PRIMARY KEY,       -- id da AniList
    titulo              TEXT NOT NULL,
    titulo_ingles       TEXT,
    titulo_japones      TEXT,
    tipo                TEXT,                      -- TV, MOVIE, OVA, ONA, SPECIAL, MUSIC (format da AniList)
    fonte               TEXT,                      -- MANGA, LIGHT_NOVEL, ORIGINAL, GAME... (source da AniList)
    episodios           INTEGER,
    status              TEXT,                      -- FINISHED, RELEASING, NOT_YET_RELEASED, CANCELLED, HIATUS
    em_exibicao         BOOLEAN,
    data_inicio_exibicao DATE,
    data_fim_exibicao   DATE,
    duracao_min         NUMERIC,
    classificacao_etaria TEXT,                     -- 'Adult' quando isAdult=true, senão NULL (AniList não tem rating tipo PG-13/R como o MAL)
    ano                 INTEGER,
    temporada            TEXT                      -- winter, spring, summer, fall
);

CREATE TABLE dim_genero (
    genero_id           INTEGER PRIMARY KEY,       -- id surrogate gerado no tratamento (AniList não tem id de gênero)
    nome_genero          TEXT NOT NULL UNIQUE
);

CREATE TABLE dim_estudio (
    estudio_id           INTEGER PRIMARY KEY,       -- id do estúdio na AniList (só estúdios com isAnimationStudio=true)
    nome_estudio          TEXT NOT NULL
);

CREATE TABLE ponte_anime_genero (
    anime_id            INTEGER REFERENCES dim_anime(anime_id),
    genero_id           INTEGER REFERENCES dim_genero(genero_id),
    PRIMARY KEY (anime_id, genero_id)
);

CREATE TABLE ponte_anime_estudio (
    anime_id            INTEGER REFERENCES dim_anime(anime_id),
    estudio_id           INTEGER REFERENCES dim_estudio(estudio_id),
    PRIMARY KEY (anime_id, estudio_id)
);

CREATE TABLE fato_anime_metricas (
    anime_id            INTEGER REFERENCES dim_anime(anime_id),
    data_coleta          DATE NOT NULL,
    score                NUMERIC,                  -- averageScore da AniList (0-100) convertido para escala 0-10
    scored_by            INTEGER,                  -- soma de stats.scoreDistribution (AniList não expõe contagem direta)
    rank                 INTEGER,                  -- rankings[type=RATED, allTime=true].rank
    popularity           INTEGER,                  -- rankings[type=POPULAR, allTime=true].rank
    members              INTEGER,                  -- popularity da AniList (contagem de usuários com o anime na lista)
    favorites             INTEGER,                  -- favourites da AniList
    PRIMARY KEY (anime_id, data_coleta)
);
