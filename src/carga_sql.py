"""
Carga dos dados tratados no PostgreSQL.

Lê os CSVs gerados por tratar_dados.py e faz upsert no banco (dimensões,
pontes e fato), sempre por staging table + INSERT ... ON CONFLICT. Nada aqui
usa TRUNCATE: um TRUNCATE CASCADE em dim_anime arrastaria fato_anime_metricas
junto (tem FK pra dim_anime), apagando o histórico de coletas anteriores —
exatamente o que este script existe pra preservar. Rodar de novo com uma
coleta nova soma histórico na fato e atualiza as dimensões/pontes sem perder
nada.
"""

from pathlib import Path

import pandas as pd
from dotenv import dotenv_values
from sqlalchemy import create_engine, text

PASTA_PROCESSED = Path("data/processed")

# (nome da tabela, colunas da chave primária, colunas a atualizar em caso de conflito, colunas de data)
# `parse_dates` importa: sem isso, colunas de data viram texto no staging e o
# INSERT ... SELECT tenta jogar texto direto numa coluna DATE, o que o Postgres
# não converte implicitamente.
TABELAS = [
    ("dim_anime", ["anime_id"], [
        "titulo", "titulo_ingles", "titulo_japones", "tipo", "fonte", "episodios",
        "status", "em_exibicao", "data_inicio_exibicao", "data_fim_exibicao",
        "duracao_min", "ano", "temporada",
    ], ["data_inicio_exibicao", "data_fim_exibicao"]),
    ("dim_genero", ["nome_genero"], [], []),
    ("dim_estudio", ["estudio_id"], ["nome_estudio"], []),
    ("ponte_anime_genero", ["anime_id", "nome_genero"], [], []),
    ("ponte_anime_estudio", ["anime_id", "estudio_id"], [], []),
    ("fato_anime_metricas", ["anime_id", "data_coleta"], [
        "score", "scored_by", "rank", "popularity", "members", "favorites",
    ], ["data_coleta"]),
]


def carregar_engine():
    config = dotenv_values(".env")
    return create_engine(config["DATABASE_URL"])


def upsert_tabela(engine, nome, chave, colunas_update, colunas_data):
    caminho = PASTA_PROCESSED / f"{nome}.csv"
    df = pd.read_csv(caminho, parse_dates=colunas_data or None)
    staging = f"stg_{nome}"

    with engine.begin() as conn:
        df.to_sql(staging, conn, if_exists="replace", index=False, method="multi", chunksize=500)

        colunas = list(df.columns)
        colunas_sql = ", ".join(colunas)
        chave_sql = ", ".join(chave)

        if colunas_update:
            set_sql = ", ".join(f"{c} = EXCLUDED.{c}" for c in colunas_update)
            conflito_sql = f"ON CONFLICT ({chave_sql}) DO UPDATE SET {set_sql}"
        else:
            conflito_sql = f"ON CONFLICT ({chave_sql}) DO NOTHING"

        conn.execute(text(f"""
            INSERT INTO {nome} ({colunas_sql})
            SELECT {colunas_sql} FROM {staging}
            {conflito_sql}
        """))
        conn.execute(text(f"DROP TABLE {staging}"))

    return len(df)


def main():
    engine = carregar_engine()

    for nome, chave, colunas_update, colunas_data in TABELAS:
        qtd = upsert_tabela(engine, nome, chave, colunas_update, colunas_data)
        print(f"  {nome}: {qtd} linhas processadas (upsert)")

    print("\nValidando contagens no banco...")
    with engine.connect() as conn:
        for nome, _, _, _ in TABELAS:
            resultado = conn.execute(text(f"SELECT COUNT(*) FROM {nome}")).scalar()
            print(f"  {nome}: {resultado} linhas no banco")


if __name__ == "__main__":
    main()
