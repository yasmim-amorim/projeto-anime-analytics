# Notas de exploração da API do Mercado Livre

## ⚠️ Achado importante: `/sites/MLB/search` bloqueado neste ambiente

Testado em 2026-08-14, a partir do ambiente de desenvolvimento (nuvem):

| Endpoint | Status | Observação |
|---|---|---|
| `GET /categories/{id}` | ✅ 200 | Funciona sem autenticação |
| `GET /sites/MLB` | ❌ 403 `PA_UNAUTHORIZED_RESULT_FROM_POLICIES` | Bloqueado |
| `GET /sites/MLB/categories` | ❌ 403 `PA_UNAUTHORIZED_RESULT_FROM_POLICIES` | Bloqueado |
| `GET /sites/MLB/search?...` | ❌ 403 `forbidden` | Bloqueado — **é o endpoint que precisamos para listar produtos por categoria** |

Hipótese mais provável: o Mercado Livre aplica um `PolicyAgent` anti-abuso que bloqueia
tráfego vindo de IPs de datacenter/nuvem para os endpoints `/sites/{site}/*`, mas libera
endpoints de leitura simples como `/categories/{id}`.

**Próximo passo (ação da usuária, fora deste ambiente):** rodar `src/explorar_api.py`
na sua própria máquina, com rede doméstica no Brasil, e confirmar se `/sites/MLB/search`
funciona por lá. Dois cenários:

1. **Funciona localmente** → confirma que era bloqueio por IP de nuvem; a coleta (Etapa 2)
   deve ser feita sempre a partir de uma máquina local/residencial, não de um servidor
   em nuvem genérico.
2. **Também falha localmente** → o Mercado Livre pode ter restringido esse endpoint para
   exigir autenticação (OAuth). Nesse caso, o próximo passo é criar uma aplicação em
   [developers.mercadolivre.com.br](https://developers.mercadolivre.com.br) para obter
   `client_id`/`client_secret` e gerar um `access_token`, e passar
   `Authorization: Bearer <token>` nas chamadas.

## Categorias confirmadas (via `/categories/{id}`, que funciona sem restrição)

| ID | Nome | Itens na categoria (momento do teste) |
|---|---|---|
| `MLB1051` | Celulares e Telefones | 7.288.256 |
| `MLB1648` | Informática | 6.987.164 |
| `MLB1144` | Games | 709.237 |

Observação: `MLB1051` é a categoria pai "Celulares e Telefones"; dentro dela existe a
subcategoria `MLB1055` "Celulares e Smartphones", mais específica para o nosso recorte
(evita telefones fixos, acessórios avulsos etc.). Vale revisar se usamos o pai ou a
subcategoria na coleta.

## Campos esperados no `/sites/MLB/search` (baseado na documentação pública da API,
a confirmar com uma resposta real assim que o bloqueio for resolvido)

Cada item em `results[]` normalmente traz:

- `id`, `title`, `condition` (`new`/`used`)
- `price`, `original_price` (quando em promoção), `currency_id`
- `sold_quantity`
- `seller.id` (é preciso uma segunda chamada a `/users/{seller_id}` para nome/reputação completos)
- `shipping.free_shipping`
- `address.state_name` / `city_name`
- `attributes[]` (specs técnicas variam por categoria)

**Não vem pronto na busca:** avaliação/nota do produto e número de avaliações —
isso normalmente exige uma chamada separada a `/reviews/item/{item_id}` (ou
`/items/{item_id}` para detalhes adicionais). Precisa confirmar isso quando o
endpoint de busca voltar a responder.

## Paginação e limites (segundo documentação pública, a validar na prática)

- `/sites/MLB/search` aceita `offset` e `limit` (limit máximo geralmente 50 por página).
- Limite histórico de ~1000 resultados acessíveis por combinação de filtros (mesmo que
  `paging.total` mostre um número maior) — se confirmado, a estratégia de amostragem
  precisa quebrar a coleta por subcategoria/faixa de preço para não perder produtos.

## Amostragem planejada (a refinar após validar o endpoint de busca)

- Por categoria: ~200–300 produtos por coleta (dentro do limite de 1000/consulta).
- Frequência: coleta diária durante 3–4 semanas, para gerar série histórica de preços
  suficiente para a Etapa 9 (insights) sem exigir automação complexa no início.
