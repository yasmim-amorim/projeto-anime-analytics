# Histórico: tentativa com a API do Mercado Livre

Este projeto começou como uma análise de e-commerce usando a API pública do Mercado Livre (celulares, informática e games). Durante a investigação:

- Criamos uma aplicação no DevCenter do Mercado Livre e completamos o fluxo OAuth completo (`auth_ml.py`), incluindo verificação de identidade da conta.
- Mesmo com token válido e conta verificada, os endpoints de catálogo/busca (`/sites/MLB/search`, `/items/{id}`, `/highlights`) retornaram consistentemente `403 PA_UNAUTHORIZED_RESULT_FROM_POLICIES`.
- A causa raiz, confirmada na documentação oficial do Mercado Livre: acesso a catálogo/busca de produtos exige aprovação no **Developer Partner Program**, que tem como requisito um GMV mínimo de R$ 2.500.000/mês em vendas de vendedores usando a solução — inviável para um projeto pessoal de portfólio.

Detalhes completos da investigação: [`notas_api_mercadolivre.md`](notas_api_mercadolivre.md). Plano de ação original: [`plano-de-acao-mercadolivre.md`](plano-de-acao-mercadolivre.md).

O projeto foi migrado para a **API Jikan** (dados de anime do MyAnimeList), que é pública e não exige autenticação. Plano ativo: [`plano-de-acao-projeto-anime.md`](../../plano-de-acao-projeto-anime.md), na raiz do repositório.
