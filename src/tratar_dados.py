"""
Tratamento dos dados brutos coletados da API Jikan (Etapa 4 do plano).

Lê todos os anime_pagina_*.json da coleta mais recente em data/raw/jikan/<data>/,
normaliza os campos aninhados (genres, studios, themes, demographics) e gera os
DataFrames finais (um por tabela do schema), salvando como CSV em data/processed/.
"""

import json
import re
from pathlib import Path

import pandas as pd

PASTA_RAW = Path("data/raw/jikan")
PASTA_PROCESSED = Path("data/processed")


def pasta_coleta_mais_recente():
    pastas = sorted(p for p in PASTA_RAW.iterdir() if p.is_dir())
    if not pastas:
        raise FileNotFoundError("Nenhuma coleta encontrada em data/raw/jikan/")
    return pastas[-1]


def carregar_animes_brutos(pasta_coleta):
    """Carrega e concatena o campo 'data' de todas as páginas coletadas."""
    animes = []
    for arquivo in sorted(pasta_coleta.glob("anime_pagina_*.json")):
        with open(arquivo, encoding="utf-8") as f:
            pagina = json.load(f)
        animes.extend(pagina["data"])
    return animes


def parsear_duracao_minutos(texto):
    """Converte texto tipo '1 hr 45 min per ep' / '24 min per ep' em minutos (float)."""
    if not texto:
        return None
    horas = re.search(r"(\d+)\s*hr", texto)
    minutos = re.search(r"(\d+)\s*min", texto)
    total = 0
    encontrou = False
    if horas:
        total += int(horas.group(1)) * 60
        encontrou = True
    if minutos:
        total += int(minutos.group(1))
        encontrou = True
    return total if encontrou else None


def construir_dim_anime(animes):
    linhas = []
    for a in animes:
        linhas.append({
            "anime_id": a["mal_id"],
            "titulo": a.get("title"),
            "titulo_ingles": a.get("title_english"),
            "titulo_japones": a.get("title_japanese"),
            "tipo": a.get("type"),
            "fonte": a.get("source"),
            "episodios": a.get("episodes"),
            "status": a.get("status"),
            "em_exibicao": a.get("airing"),
            "data_inicio_exibicao": (a.get("aired") or {}).get("from"),
            "data_fim_exibicao": (a.get("aired") or {}).get("to"),
            "duracao_min": parsear_duracao_minutos(a.get("duration")),
            "classificacao_etaria": a.get("rating"),
            "ano": a.get("year"),
            "temporada": a.get("season"),
        })
    df = pd.DataFrame(linhas).drop_duplicates(subset="anime_id")
    for col in ("data_inicio_exibicao", "data_fim_exibicao"):
        df[col] = pd.to_datetime(df[col], utc=True, errors="coerce").dt.date
    return df


def construir_genero_tabelas(animes):
    """Unifica genres/explicit_genres/themes/demographics em dim_genero + ponte."""
    generos = {}
    pontes = []
    campos_e_tipos = [
        ("genres", "genre"),
        ("explicit_genres", "explicit_genre"),
        ("themes", "theme"),
        ("demographics", "demographic"),
    ]
    for a in animes:
        for campo, tipo in campos_e_tipos:
            for g in a.get(campo) or []:
                generos[g["mal_id"]] = {
                    "genero_id": g["mal_id"],
                    "nome_genero": g["name"],
                    "tipo_classificacao": tipo,
                }
                pontes.append({"anime_id": a["mal_id"], "genero_id": g["mal_id"]})

    df_genero = pd.DataFrame(generos.values())
    df_ponte = pd.DataFrame(pontes).drop_duplicates()
    return df_genero, df_ponte


def construir_estudio_tabelas(animes):
    estudios = {}
    pontes = []
    for a in animes:
        for e in a.get("studios") or []:
            estudios[e["mal_id"]] = {"estudio_id": e["mal_id"], "nome_estudio": e["name"]}
            pontes.append({"anime_id": a["mal_id"], "estudio_id": e["mal_id"]})

    df_estudio = pd.DataFrame(estudios.values())
    df_ponte = pd.DataFrame(pontes).drop_duplicates()
    return df_estudio, df_ponte


def construir_fato_metricas(animes, data_coleta):
    linhas = []
    for a in animes:
        linhas.append({
            "anime_id": a["mal_id"],
            "data_coleta": data_coleta,
            "score": a.get("score"),
            "scored_by": a.get("scored_by"),
            "rank": a.get("rank"),
            "popularity": a.get("popularity"),
            "members": a.get("members"),
            "favorites": a.get("favorites"),
        })
    return pd.DataFrame(linhas).drop_duplicates(subset=["anime_id", "data_coleta"])


def main():
    pasta_coleta = pasta_coleta_mais_recente()
    data_coleta = pasta_coleta.name
    print(f"Tratando coleta de {data_coleta}...")

    animes = carregar_animes_brutos(pasta_coleta)
    print(f"{len(animes)} animes carregados (antes de deduplicar)")

    df_dim_anime = construir_dim_anime(animes)
    df_dim_genero, df_ponte_anime_genero = construir_genero_tabelas(animes)
    df_dim_estudio, df_ponte_anime_estudio = construir_estudio_tabelas(animes)
    df_fato = construir_fato_metricas(animes, data_coleta)

    PASTA_PROCESSED.mkdir(parents=True, exist_ok=True)
    tabelas = {
        "dim_anime": df_dim_anime,
        "dim_genero": df_dim_genero,
        "ponte_anime_genero": df_ponte_anime_genero,
        "dim_estudio": df_dim_estudio,
        "ponte_anime_estudio": df_ponte_anime_estudio,
        "fato_anime_metricas": df_fato,
    }
    for nome, df in tabelas.items():
        caminho = PASTA_PROCESSED / f"{nome}.csv"
        df.to_csv(caminho, index=False)
        print(f"  {nome}: {len(df)} linhas -> {caminho}")


if __name__ == "__main__":
    main()
