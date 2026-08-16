"""
Tratamento dos dados brutos coletados da API AniList (Etapa 4 do plano).

Lê todos os anime_pagina_*.json da coleta mais recente em data/raw/anilist/<data>/,
normaliza os campos aninhados (genres, studios, rankings, stats) e gera os
DataFrames finais (um por tabela do schema), salvando como CSV em data/processed/.
"""

import json
from pathlib import Path

import pandas as pd

PASTA_RAW = Path("data/raw/anilist")
PASTA_PROCESSED = Path("data/processed")


def pasta_coleta_mais_recente():
    pastas = sorted(p for p in PASTA_RAW.iterdir() if p.is_dir())
    if not pastas:
        raise FileNotFoundError("Nenhuma coleta encontrada em data/raw/anilist/")
    return pastas[-1]


def carregar_animes_brutos(pasta_coleta):
    """Carrega e concatena o campo 'media' de todas as páginas coletadas."""
    animes = []
    for arquivo in sorted(pasta_coleta.glob("anime_pagina_*.json")):
        with open(arquivo, encoding="utf-8") as f:
            pagina = json.load(f)
        animes.extend(pagina["media"])
    return animes


def parsear_data(data_parcial):
    """Monta uma data a partir de {year, month, day} da AniList (mês/dia podem faltar)."""
    if not data_parcial or not data_parcial.get("year"):
        return None
    ano = data_parcial["year"]
    mes = data_parcial.get("month") or 1
    dia = data_parcial.get("day") or 1
    return f"{ano:04d}-{mes:02d}-{dia:02d}"


def extrair_ranking(rankings, tipo):
    """Pega o rank all-time de um tipo (RATED ou POPULAR) da lista de rankings."""
    for r in rankings or []:
        if r.get("type") == tipo and r.get("allTime"):
            return r.get("rank")
    return None


def construir_dim_anime(animes):
    linhas = []
    for a in animes:
        titulo = a.get("title") or {}
        inicio = a.get("startDate") or {}
        fim = a.get("endDate") or {}
        linhas.append({
            "anime_id": a["id"],
            "titulo": titulo.get("romaji"),
            "titulo_ingles": titulo.get("english"),
            "titulo_japones": titulo.get("native"),
            "tipo": a.get("format"),
            "fonte": a.get("source"),
            "episodios": a.get("episodes"),
            "status": a.get("status"),
            "em_exibicao": a.get("status") == "RELEASING",
            "data_inicio_exibicao": parsear_data(inicio),
            "data_fim_exibicao": parsear_data(fim),
            "duracao_min": a.get("duration"),
            "classificacao_etaria": "Adult" if a.get("isAdult") else None,
            "ano": a.get("seasonYear"),
            "temporada": a["season"].lower() if a.get("season") else None,
        })
    df = pd.DataFrame(linhas).drop_duplicates(subset="anime_id")
    for col in ("data_inicio_exibicao", "data_fim_exibicao"):
        df[col] = pd.to_datetime(df[col], errors="coerce").dt.date
    return df


def construir_genero_tabelas(animes):
    """AniList só tem uma lista simples de nomes de gênero (sem id nem tema/demografia)."""
    nomes_generos = sorted({g for a in animes for g in (a.get("genres") or [])})
    id_por_nome = {nome: i + 1 for i, nome in enumerate(nomes_generos)}

    df_genero = pd.DataFrame(
        [{"genero_id": gid, "nome_genero": nome} for nome, gid in id_por_nome.items()]
    )

    pontes = [
        {"anime_id": a["id"], "genero_id": id_por_nome[g]}
        for a in animes
        for g in (a.get("genres") or [])
    ]
    df_ponte = pd.DataFrame(pontes).drop_duplicates()
    return df_genero, df_ponte


def construir_estudio_tabelas(animes):
    """Só considera estúdios de animação de fato (isAnimationStudio=true) —
    a AniList também lista produtoras/editoras junto em 'studios'."""
    estudios = {}
    pontes = []
    for a in animes:
        nodes = (a.get("studios") or {}).get("nodes") or []
        for e in nodes:
            if not e.get("isAnimationStudio"):
                continue
            estudios[e["id"]] = {"estudio_id": e["id"], "nome_estudio": e["name"]}
            pontes.append({"anime_id": a["id"], "estudio_id": e["id"]})

    df_estudio = pd.DataFrame(estudios.values())
    df_ponte = pd.DataFrame(pontes).drop_duplicates()
    return df_estudio, df_ponte


def construir_fato_metricas(animes, data_coleta):
    linhas = []
    for a in animes:
        distribuicao = (a.get("stats") or {}).get("scoreDistribution") or []
        media_score = a.get("averageScore")
        linhas.append({
            "anime_id": a["id"],
            "data_coleta": data_coleta,
            "score": media_score / 10.0 if media_score is not None else None,
            "scored_by": sum(d["amount"] for d in distribuicao) if distribuicao else None,
            "rank": extrair_ranking(a.get("rankings"), "RATED"),
            "popularity": extrair_ranking(a.get("rankings"), "POPULAR"),
            "members": a.get("popularity"),
            "favorites": a.get("favourites"),
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
