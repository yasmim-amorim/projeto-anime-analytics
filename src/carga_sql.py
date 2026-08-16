"""
Carga dos dados tratados no PostgreSQL.

Lê os CSVs gerados por tratar_dados.py e carrega no banco, respeitando a ordem:
dimensões -> pontes (N:N) -> fato. Usa "replace" nas dimensões/pontes (a coleta
mais recente refaz a foto do catálogo) e "append" na fato, já que o grão inclui
data_coleta (permite acumular séries históricas em coletas futuras).
"""

from pathlib import Path

import pandas as pd
from dotenv import dotenv_values
from sqlalchemy import create_engine, text

PASTA_PROCESSED = Path("data/processed")

TABELAS_DIMENSAO = ["dim_anime", "dim_genero", "dim_estudio"]
TABELAS_PONTE = ["ponte_anime_genero", "ponte_anime_estudio"]
TABELA_FATO = "fato_anime_metricas"


def carregar_engine():
    config = dotenv_values(".env")
    return create_engine(config["DATABASE_URL"])


def carregar_tabela(engine, nome):
    caminho = PASTA_PROCESSED / f"{nome}.csv"
    df = pd.read_csv(caminho)
    df.to_sql(nome, engine, if_exists="append", index=False, method="multi", chunksize=500)
    return len(df)


def main():
    engine = carregar_engine()

    with engine.begin() as conn:
        for nome in TABELAS_PONTE + TABELAS_DIMENSAO + [TABELA_FATO]:
            conn.execute(text(f"TRUNCATE TABLE {nome} CASCADE"))
        print("Tabelas limpas (TRUNCATE) antes da carga.")

    print("\nCarregando dimensões...")
    for nome in TABELAS_DIMENSAO:
        qtd = carregar_tabela(engine, nome)
        print(f"  {nome}: {qtd} linhas carregadas")

    print("\nCarregando pontes...")
    for nome in TABELAS_PONTE:
        qtd = carregar_tabela(engine, nome)
        print(f"  {nome}: {qtd} linhas carregadas")

    print("\nCarregando fato...")
    qtd = carregar_tabela(engine, TABELA_FATO)
    print(f"  {TABELA_FATO}: {qtd} linhas carregadas")

    print("\nValidando contagens no banco...")
    with engine.connect() as conn:
        for nome in TABELAS_DIMENSAO + TABELAS_PONTE + [TABELA_FATO]:
            resultado = conn.execute(text(f"SELECT COUNT(*) FROM {nome}")).scalar()
            print(f"  {nome}: {resultado} linhas no banco")


if __name__ == "__main__":
    main()
