"""
Integrity validation for the cleaned CSVs in data/processed/.

Runs after tratar_dados.py (and either before or after carga_sql.py) and
fails loudly if it finds a duplicate primary key, an orphan FK, or a null in
a required column — so a future re-collection catches a regression
automatically instead of relying on manual checking.
"""

from pathlib import Path

import pandas as pd

PASTA_PROCESSED = Path("data/processed")


def carregar_tabelas():
    nomes = [
        "dim_anime", "dim_estudio", "dim_genero",
        "ponte_anime_genero", "ponte_anime_estudio", "fato_anime_metricas",
    ]
    return {nome: pd.read_csv(PASTA_PROCESSED / f"{nome}.csv") for nome in nomes}


def validar(tabelas):
    da, de, dg = tabelas["dim_anime"], tabelas["dim_estudio"], tabelas["dim_genero"]
    pg, pe, fa = tabelas["ponte_anime_genero"], tabelas["ponte_anime_estudio"], tabelas["fato_anime_metricas"]

    erros = []

    # Duplicate primary keys
    if da["anime_id"].duplicated().any():
        erros.append("dim_anime: duplicate anime_id")
    if de["estudio_id"].duplicated().any():
        erros.append("dim_estudio: duplicate estudio_id")
    if dg["nome_genero"].duplicated().any():
        erros.append("dim_genero: duplicate nome_genero")
    if pg.duplicated(subset=["anime_id", "nome_genero"]).any():
        erros.append("ponte_anime_genero: duplicate (anime_id, nome_genero) pair")
    if pe.duplicated(subset=["anime_id", "estudio_id"]).any():
        erros.append("ponte_anime_estudio: duplicate (anime_id, estudio_id) pair")
    if fa.duplicated(subset=["anime_id", "data_coleta"]).any():
        erros.append("fato_anime_metricas: duplicate (anime_id, data_coleta) pair")

    # Orphan foreign keys
    if (~pg["anime_id"].isin(da["anime_id"])).any():
        erros.append("ponte_anime_genero: orphan anime_id (no match in dim_anime)")
    if (~pg["nome_genero"].isin(dg["nome_genero"])).any():
        erros.append("ponte_anime_genero: orphan nome_genero (no match in dim_genero)")
    if (~pe["anime_id"].isin(da["anime_id"])).any():
        erros.append("ponte_anime_estudio: orphan anime_id (no match in dim_anime)")
    if (~pe["estudio_id"].isin(de["estudio_id"])).any():
        erros.append("ponte_anime_estudio: orphan estudio_id (no match in dim_estudio)")
    if (~fa["anime_id"].isin(da["anime_id"])).any():
        erros.append("fato_anime_metricas: orphan anime_id (no match in dim_anime)")

    # Required columns (NOT NULL in the schema) with missing values
    if da["titulo"].isnull().any():
        erros.append("dim_anime: null titulo (required column)")
    if de["nome_estudio"].isnull().any():
        erros.append("dim_estudio: null nome_estudio (required column)")
    if fa["data_coleta"].isnull().any():
        erros.append("fato_anime_metricas: null data_coleta (required column)")

    return erros


def main():
    tabelas = carregar_tabelas()
    for nome, df in tabelas.items():
        print(f"  {nome}: {len(df)} linhas carregadas")

    erros = validar(tabelas)
    if erros:
        raise SystemExit("Validação falhou:\n- " + "\n- ".join(erros))

    print("\nValidação OK: 0 duplicados, 0 órfãos, colunas obrigatórias preenchidas.")


if __name__ == "__main__":
    main()
