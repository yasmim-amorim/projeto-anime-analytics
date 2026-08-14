"""
Script de coleta da API Jikan (Etapa 2 do plano de ação — projeto anime).

Coleta os animes mais populares (top ~1.000-1.500), salvando cada página de
resposta bruta em data/raw/jikan/<data>/. A API Jikan não exige autenticação,
mas tem rate limit (~3 req/s, ~60/min) e instabilidade intermitente no upstream
(504 Gateway Timeout observado em testes) — por isso a função central de
chamada implementa espaçamento entre requisições e retry com backoff.
"""

import json
import time
from datetime import date
from pathlib import Path

import requests

BASE_URL = "https://api.jikan.moe/v4"
PASTA_SAIDA = Path("data/raw/jikan") / date.today().isoformat()

LIMITE_PAGINAS = 60          # ~60 páginas x 25 itens = ~1.500 animes
ESPACO_ENTRE_CHAMADAS = 0.5  # segundos, dentro do rate limit de 3 req/s

# Observado empiricamente: um 504 quase sempre significa que a página ainda não
# está no cache da Jikan, e insistir imediatamente não ajuda (o fetch ao vivo no
# MyAnimeList continua falhando por vários segundos). Por isso a passada principal
# falha rápido (poucas tentativas curtas) e delega a recuperação de verdade para
# reprocessar_falhas(), que espera bem mais tempo entre rodadas.
MAX_TENTATIVAS = 2
ESPERA_INICIAL = 3            # segundos, dobra a cada nova tentativa


def chamar_api(url, params=None):
    """Chama a API Jikan com espaçamento e retry/backoff exponencial."""
    tentativa = 0
    espera = ESPERA_INICIAL
    while True:
        tentativa += 1
        try:
            resp = requests.get(url, params=params, timeout=15)
            if resp.status_code in (504, 429):
                raise requests.exceptions.HTTPError(f"status {resp.status_code}")
            resp.raise_for_status()
            time.sleep(ESPACO_ENTRE_CHAMADAS)
            return resp.json()
        except (requests.exceptions.HTTPError, requests.exceptions.ConnectionError,
                requests.exceptions.Timeout) as e:
            if tentativa >= MAX_TENTATIVAS:
                raise
            print(f"  tentativa {tentativa} falhou ({e}), esperando {espera}s...")
            time.sleep(espera)
            espera *= 2


def coletar_generos():
    """Coleta a lista de gêneros/temas/demografias (chamada única)."""
    print("Coletando lista de gêneros...")
    dados = chamar_api(f"{BASE_URL}/genres/anime")
    caminho = PASTA_SAIDA / "generos.json"
    caminho.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"  {len(dados.get('data', []))} gêneros salvos em {caminho}")


def coletar_top_animes():
    """Coleta as páginas de /top/anime até LIMITE_PAGINAS ou até acabar."""
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
            dados = chamar_api(f"{BASE_URL}/top/anime", params={"page": pagina})
        except Exception as e:
            print(f"  FALHOU após {MAX_TENTATIVAS} tentativas: {e}")
            falhas.append(pagina)
            pagina += 1
            continue

        caminho.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding="utf-8")

        qtd_itens = len(dados.get("data", []))
        total_coletado += qtd_itens
        print(f"  {qtd_itens} animes salvos em {caminho}")

        if not dados.get("pagination", {}).get("has_next_page"):
            print("  última página alcançada.")
            break

        pagina += 1

    return falhas, total_coletado


PAUSA_ANTES_DE_REPROCESSAR = 30  # segundos — dá tempo da Jikan cachear a página em segundo plano


def reprocessar_falhas(falhas, pausa=PAUSA_ANTES_DE_REPROCESSAR):
    """Segunda passada: tenta de novo só as páginas que falharam na primeira.

    A Jikan cacheia respostas; um 504 costuma significar que a página ainda não
    está em cache e a busca ao vivo no MyAnimeList falhou. Esperar um pouco antes
    de tentar de novo dá tempo da Jikan terminar de cachear em segundo plano.
    """
    if not falhas:
        return []

    print(f"\nReprocessando {len(falhas)} página(s) que falharam: {falhas}")
    print(f"Aguardando {pausa}s antes de tentar de novo...")
    time.sleep(pausa)
    falhas_persistentes = []
    for pagina in falhas:
        try:
            dados = chamar_api(f"{BASE_URL}/top/anime", params={"page": pagina})
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

    coletar_generos()

    print("\nColetando top animes...")
    falhas, total = coletar_top_animes()

    falhas_persistentes = falhas
    for pausa in (60, 120, 180):
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
