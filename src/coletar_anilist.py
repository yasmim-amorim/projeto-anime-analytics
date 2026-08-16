"""
Coleta dos animes mais populares (top 5.000) via GraphQL (graphql.anilist.co),
salvando cada página de resposta bruta em data/raw/anilist/<data>/. Não exige
autenticação, mas tem rate limit de 30 requisições/minuto (ver header
X-RateLimit-Limit da resposta).
"""

import json
import time
from datetime import date
from pathlib import Path

import requests

URL = "https://graphql.anilist.co"
PASTA_SAIDA = Path("data/raw/anilist") / date.today().isoformat()

PER_PAGE = 50
LIMITE_PAGINAS = 100         # 100 páginas x 50 itens = 5.000 animes (teto de profundidade
                              # de paginação da API AniList: page * perPage <= 5000)
ESPACO_ENTRE_CHAMADAS = 2.2  # segundos — mantém margem sob o limite de 30 req/min

MAX_TENTATIVAS = 3
ESPERA_INICIAL = 5           # segundos, dobra a cada nova tentativa

QUERY = """
query ($page: Int, $perPage: Int) {
  Page(page: $page, perPage: $perPage) {
    pageInfo { hasNextPage total }
    media(type: ANIME, sort: POPULARITY_DESC) {
      id
      title { romaji english native }
      format
      source
      episodes
      status
      startDate { year month day }
      endDate { year month day }
      duration
      averageScore
      isAdult
      season
      seasonYear
      genres
      favourites
      popularity
      studios { nodes { id name isAnimationStudio } }
      rankings { rank type context allTime }
      stats { scoreDistribution { score amount } }
    }
  }
}
"""


def chamar_api(pagina):
    """Chama a API AniList (GraphQL) com espaçamento e retry/backoff exponencial."""
    tentativa = 0
    espera = ESPERA_INICIAL
    while True:
        tentativa += 1
        try:
            resp = requests.post(
                URL,
                json={"query": QUERY, "variables": {"page": pagina, "perPage": PER_PAGE}},
                timeout=20,
            )
            if resp.status_code == 429:
                raise requests.exceptions.HTTPError("status 429 (rate limit)")
            resp.raise_for_status()
            time.sleep(ESPACO_ENTRE_CHAMADAS)
            return resp.json()["data"]["Page"]
        except (requests.exceptions.HTTPError, requests.exceptions.ConnectionError,
                requests.exceptions.Timeout) as e:
            if tentativa >= MAX_TENTATIVAS:
                raise
            print(f"  tentativa {tentativa} falhou ({e}), esperando {espera}s...")
            time.sleep(espera)
            espera *= 2


def coletar_top_animes():
    falhas = []
    pagina = 1
    total_coletado = 0

    while pagina <= LIMITE_PAGINAS:
        caminho = PASTA_SAIDA / f"anime_pagina_{pagina:03d}.json"
        if caminho.exists():
            print(f"Página {pagina} já coletada anteriormente, pulando.")
            pagina += 1
            continue

        print(f"Coletando página {pagina}...")
        try:
            dados = chamar_api(pagina)
        except Exception as e:
            print(f"  FALHOU após {MAX_TENTATIVAS} tentativas: {e}")
            falhas.append(pagina)
            pagina += 1
            continue

        caminho.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding="utf-8")

        qtd_itens = len(dados.get("media", []))
        total_coletado += qtd_itens
        print(f"  {qtd_itens} animes salvos em {caminho}")

        if not dados.get("pageInfo", {}).get("hasNextPage"):
            print("  última página alcançada.")
            break

        pagina += 1

    return falhas, total_coletado


def reprocessar_falhas(falhas, pausa=30):
    if not falhas:
        return []

    print(f"\nReprocessando {len(falhas)} página(s) que falharam: {falhas}")
    print(f"Aguardando {pausa}s antes de tentar de novo...")
    time.sleep(pausa)
    falhas_persistentes = []
    for pagina in falhas:
        try:
            dados = chamar_api(pagina)
            caminho = PASTA_SAIDA / f"anime_pagina_{pagina:03d}.json"
            caminho.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"  página {pagina} recuperada com sucesso.")
        except Exception as e:
            print(f"  página {pagina} falhou de novo: {e}")
            falhas_persistentes.append(pagina)

    return falhas_persistentes


def main():
    PASTA_SAIDA.mkdir(parents=True, exist_ok=True)
    print(f"Salvando dados brutos em: {PASTA_SAIDA}\n")

    print("Coletando top animes...")
    falhas, total = coletar_top_animes()

    falhas_persistentes = falhas
    for pausa in (30, 60):
        if not falhas_persistentes:
            break
        falhas_persistentes = reprocessar_falhas(falhas_persistentes, pausa=pausa)

    caminho_falhas = PASTA_SAIDA / "falhas.json"
    caminho_falhas.write_text(json.dumps(falhas_persistentes), encoding="utf-8")

    print(f"\nConcluído. ~{total} animes coletados.")
    if falhas_persistentes:
        print(f"Atenção: {len(falhas_persistentes)} página(s) continuam com falha — ver {caminho_falhas}")
    else:
        print("Nenhuma falha persistente.")


if __name__ == "__main__":
    main()
