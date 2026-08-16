# Histórico: tentativa com a API Jikan

Segunda fonte de dados do projeto, depois da tentativa com o Mercado Livre (ver [`notas_api_mercadolivre.md`](notas_api_mercadolivre.md)). A Jikan (`https://api.jikan.moe/v4/`) é uma API pública e gratuita que espelha dados do MyAnimeList, sem necessidade de autenticação — funcionou bem na exploração inicial (endpoints `/anime`, `/top/anime`, `/genres/anime` testados com sucesso).

## O problema: instabilidade no upstream

Ao tentar rodar a coleta completa (~1.500 animes, 60 páginas de `/top/anime`), só a primeira página funcionava de forma consistente; as demais retornavam erro **504**. Isso aconteceu em duas tentativas separadas, em datas diferentes (2026-08-14 e 2026-08-16), com o script já implementando espaçamento entre chamadas, retry com backoff exponencial e reprocessamento de falhas em múltiplas rodadas.

## Diagnóstico (2026-08-16)

Para descartar a hipótese de bug no nosso código, testamos a API **diretamente via `curl`**, fora do script Python:

- `curl https://api.jikan.moe/v4/top/anime?page=2` → **504**, corpo: `{"status":504,"type":"BadResponseException","message":"Jikan failed to connect to MyAnimeList. MyAnimeList may be down/unavailable or refuses to connect"}`
- Testado um endpoint alternativo (`/anime?order_by=members&sort=desc&page=N`) em várias páginas — mesmo resultado.
- A única vez que uma chamada teve sucesso foi quando o Cloudflare da Jikan tinha uma cópia "stale" em cache pra aquela página específica (header `X-Cache-Status: STALE`). Sem cache disponível, a Jikan tenta buscar ao vivo no MyAnimeList e o timeout estoura.
- Descartamos rate-limit e bloqueio por User-Agent do nosso lado (testado com header de navegador — mesmo resultado).

**Conclusão:** a Jikan funciona como um proxy que raspa o MyAnimeList sob demanda quando não tem cache. No momento dos testes, essa raspagem ao vivo estava falhando de forma sistemática para a maioria das páginas — um problema do backend da Jikan/MyAnimeList, fora do nosso controle, não um bug de implementação.

## Decisão

Migramos a coleta para a **API AniList** (GraphQL, `graphql.anilist.co`), que serve os dados a partir do próprio banco em vez de raspar o MyAnimeList sob demanda — não sofre desse modo de falha. Testes diretos confirmaram 200 OK de forma consistente em várias páginas (incluindo as que mais falhavam na Jikan) e um rate limit generoso e documentado (30 requisições/minuto).

Script ativo de coleta: [`src/coletar_anilist.py`](../../src/coletar_anilist.py). Script antigo preservado em [`src/historico/coletar_jikan.py`](../../src/historico/coletar_jikan.py). Dados brutos parciais coletados via Jikan preservados em `data/historico_raw/jikan_2026-08-14/`.
