-- Schema do projeto de análise de anime (API Jikan)
-- Dimensões primeiro, depois pontes N:N, depois fato.

CREATE TABLE dim_anime (
    anime_id            INTEGER PRIMARY KEY,       -- mal_id
    titulo              TEXT NOT NULL,
    titulo_ingles       TEXT,
    titulo_japones      TEXT,
    tipo                TEXT,                      -- TV, Movie, OVA, ONA, Special, Music
    fonte               TEXT,                      -- Manga, Light Novel, Original, Game...
    episodios           INTEGER,
    status              TEXT,                      -- Finished Airing, Currently Airing, Not yet aired
    em_exibicao         BOOLEAN,
    data_inicio_exibicao DATE,
    data_fim_exibicao   DATE,
    duracao_min         NUMERIC,
    classificacao_etaria TEXT,
    ano                 INTEGER,
    temporada            TEXT                      -- winter, spring, summer, fall
);

CREATE TABLE dim_genero (
    genero_id           INTEGER PRIMARY KEY,       -- mal_id do gênero/tema/demografia
    nome_genero          TEXT NOT NULL,
    tipo_classificacao   TEXT NOT NULL              -- genre, explicit_genre, theme, demographic
);

CREATE TABLE dim_estudio (
    estudio_id           INTEGER PRIMARY KEY,       -- mal_id do estúdio
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
    score                NUMERIC,
    scored_by            INTEGER,
    rank                 INTEGER,
    popularity           INTEGER,
    members              INTEGER,
    favorites            INTEGER,
    PRIMARY KEY (anime_id, data_coleta)
);
