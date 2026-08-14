"""
Autenticação OAuth com a API do Mercado Livre.

Fluxo (Etapa 1 revisada — o /sites/MLB/search agora exige token):

1. Crie um app em developers.mercadolivre.com.br/devcenter e preencha no .env:
   ML_CLIENT_ID, ML_CLIENT_SECRET, ML_REDIRECT_URI (a mesma URL cadastrada no app).

2. Rode sem argumentos para gerar o link de autorização:
       venv\\Scripts\\python.exe src\\auth_ml.py
   Abra o link no navegador, faça login/autorize. Você será redirecionado para o
   ML_REDIRECT_URI com "?code=TG-..." na URL — copie esse código (vale ~10 minutos).

3. Rode de novo passando o código como argumento:
       venv\\Scripts\\python.exe src\\auth_ml.py TG-xxxxxxxx
   Isso troca o código por um access_token + refresh_token e salva os dois no .env.
"""

import sys

import requests
from dotenv import dotenv_values, set_key

ENV_PATH = ".env"
TOKEN_URL = "https://api.mercadolibre.com/oauth/token"
AUTH_URL = "https://auth.mercadolivre.com.br/authorization"


def gerar_url_autorizacao(client_id, redirect_uri):
    return f"{AUTH_URL}?response_type=code&client_id={client_id}&redirect_uri={redirect_uri}"


def trocar_code_por_token(client_id, client_secret, redirect_uri, code):
    payload = {
        "grant_type": "authorization_code",
        "client_id": client_id,
        "client_secret": client_secret,
        "code": code,
        "redirect_uri": redirect_uri,
    }
    resp = requests.post(TOKEN_URL, data=payload, timeout=10)
    resp.raise_for_status()
    return resp.json()


def renovar_token(client_id, client_secret, refresh_token):
    """Usa o refresh_token pra gerar um novo access_token sem precisar logar de novo."""
    payload = {
        "grant_type": "refresh_token",
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
    }
    resp = requests.post(TOKEN_URL, data=payload, timeout=10)
    resp.raise_for_status()
    return resp.json()


def main():
    config = dotenv_values(ENV_PATH)
    client_id = config.get("ML_CLIENT_ID")
    client_secret = config.get("ML_CLIENT_SECRET")
    redirect_uri = config.get("ML_REDIRECT_URI")

    if not client_id or not client_secret or not redirect_uri:
        print("Preencha ML_CLIENT_ID, ML_CLIENT_SECRET e ML_REDIRECT_URI no .env antes de rodar.")
        return

    if len(sys.argv) < 2:
        print("=== Passo 1: abra este link no navegador, faça login e autorize ===\n")
        print(gerar_url_autorizacao(client_id, redirect_uri))
        print("\nDepois de autorizar, copie o valor de '?code=' na URL de redirecionamento")
        print("e rode: venv\\Scripts\\python.exe src\\auth_ml.py <code>")
        return

    code = sys.argv[1]
    print("=== Passo 2: trocando o code pelo access_token ===")
    tokens = trocar_code_por_token(client_id, client_secret, redirect_uri, code)

    set_key(ENV_PATH, "ML_ACCESS_TOKEN", tokens["access_token"])
    set_key(ENV_PATH, "ML_REFRESH_TOKEN", tokens["refresh_token"])

    print("Sucesso! access_token e refresh_token salvos no .env.")
    print(f"O access_token expira em {tokens.get('expires_in')} segundos.")
    print("Quando expirar, chame renovar_token() com o refresh_token pra gerar um novo.")


if __name__ == "__main__":
    main()
