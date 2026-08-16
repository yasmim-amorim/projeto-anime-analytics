# Histórico: fontes de dados abandonadas

Este projeto passou por duas mudanças de fonte de dados antes de chegar na API atual (**AniList**). Cada pivô ficou documentado em detalhe, por decisão deliberada — mostra o processo de investigação, não só o resultado final.

## 1. Mercado Livre (e-commerce)

O projeto começou como uma análise de e-commerce usando a API pública do Mercado Livre (celulares, informática e games). Durante a investigação:

- Criamos uma aplicação no DevCenter do Mercado Livre e completamos o fluxo OAuth completo (`auth_ml.py`), incluindo verificação de identidade da conta.
- Mesmo com token válido e conta verificada, os endpoints de catálogo/busca (`/sites/MLB/search`, `/items/{id}`, `/highlights`) retornaram consistentemente `403 PA_UNAUTHORIZED_RESULT_FROM_POLICIES`.
- A causa raiz, confirmada na documentação oficial do Mercado Livre: acesso a catálogo/busca de produtos exige aprovação no **Developer Partner Program**, que tem como requisito um GMV mínimo de R$ 2.500.000/mês em vendas de vendedores usando a solução — inviável para um projeto pessoal de portfólio.

Detalhes completos da investigação: [`notas_api_mercadolivre.md`](notas_api_mercadolivre.md). Plano de ação original: [`plano-de-acao-mercadolivre.md`](plano-de-acao-mercadolivre.md).

## 2. Jikan (anime, MyAnimeList)

O projeto foi migrado para a **API Jikan** (dados de anime do MyAnimeList), pública e sem autenticação. Funcionou bem na exploração inicial, mas a coleta em escala (~1.500 animes) esbarrou em instabilidade sistemática do backend da Jikan ao tentar raspar o MyAnimeList ao vivo para páginas fora do cache.

Diagnóstico completo (incluindo testes diretos via `curl` que descartaram bug no nosso código): [`notas_api_jikan.md`](notas_api_jikan.md).

## Fonte atual: AniList

O projeto foi migrado para a **API AniList** (GraphQL, `graphql.anilist.co`) — serve os dados a partir do próprio banco em vez de raspar o MyAnimeList sob demanda, e não apresentou o mesmo problema de instabilidade. Plano ativo: [`plano-de-acao-projeto-anime.md`](../../plano-de-acao-projeto-anime.md), na raiz do repositório.
