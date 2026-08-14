"""
Script de exploração da API pública do Mercado Livre (Etapa 1 do plano).

Objetivo: confirmar os IDs reais das categorias que vamos coletar
(Celulares, Informática, Games) e olhar uma amostra de produtos de cada uma,
para mapear os campos disponíveis antes de escrever o script de coleta de verdade.

IMPORTANTE (ver docs/notas_api.md): o endpoint /sites/MLB/search, usado para
listar produtos por categoria, retornou 403 Forbidden quando testado a partir
do ambiente de desenvolvimento (nuvem). O endpoint /categories/{id} funcionou
normalmente. Rode este script na SUA máquina (rede doméstica no Brasil) para
confirmar se o /search também é bloqueado por lá, ou se é uma restrição
específica de IPs de datacenter/nuvem.
"""

import json

import requests

SITE_ID = "MLB"  # Mercado Livre Brasil
BASE_URL = "https://api.mercadolibre.com"

# IDs de categoria raiz já confirmados via /categories/{id} (ver docs/notas_api.md).
CATEGORIAS_ALVO = {
    "MLB1051": "Celulares e Telefones",
    "MLB1648": "Informática",
    "MLB1144": "Games",
}


def confirmar_categoria(category_id):
    """Confirma nome e metadados de uma categoria pelo ID (endpoint /categories/{id})."""
    resp = requests.get(f"{BASE_URL}/categories/{category_id}", timeout=10)
    resp.raise_for_status()
    return resp.json()


def buscar_amostra_produtos(category_id, limit=5):
    """Busca uma amostra de produtos de uma categoria específica via /sites/MLB/search."""
    params = {"category": category_id, "limit": limit}
    resp = requests.get(f"{BASE_URL}/sites/{SITE_ID}/search", params=params, timeout=10)
    resp.raise_for_status()
    return resp.json()


def main():
    print("=== 1. Confirmando categorias de interesse via /categories/{id} ===")
    for cat_id, nome_esperado in CATEGORIAS_ALVO.items():
        info = confirmar_categoria(cat_id)
        print(f"  {cat_id} -> {info['name']} (itens na categoria: {info.get('total_items_in_this_category')})")

    print("\n=== 2. Buscando amostra de produtos por categoria (/sites/MLB/search) ===")
    for cat_id, nome_esperado in CATEGORIAS_ALVO.items():
        print(f"\n--- Categoria: {nome_esperado} ({cat_id}) ---")
        try:
            resultado = buscar_amostra_produtos(cat_id, limit=3)
        except requests.exceptions.HTTPError as e:
            print(f"  FALHOU: {e}")
            print("  (ver docs/notas_api.md — pode ser bloqueio por IP de nuvem)")
            continue

        print(f"Total de resultados na categoria: {resultado.get('paging', {}).get('total')}")

        for item in resultado.get("results", []):
            print(json.dumps(item, indent=2, ensure_ascii=False)[:1500])
            print("...")


if __name__ == "__main__":
    main()
