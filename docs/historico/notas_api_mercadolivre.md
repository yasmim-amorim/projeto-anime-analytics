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

**Confirmado em 2026-08-14:** rodamos `src/explorar_api.py` também na máquina local
(rede doméstica, Brasil) e `/sites/MLB/search` retornou o mesmo 403. Ou seja, **não é
bloqueio por IP de datacenter/nuvem** — é uma restrição do próprio endpoint, que hoje
em dia exige autenticação (OAuth) mesmo para buscas simples. `/categories/{id}` segue
público e funcionando normalmente.

**Atualização 2026-08-14:** app criado no DevCenter, fluxo OAuth completo (client_id,
client_secret, authorization code → access_token + refresh_token, tudo salvo no
`.env`). Mesmo com `Authorization: Bearer <token>` válido, `/sites/MLB/search`
continua retornando o mesmo 403 `PA_UNAUTHORIZED_RESULT_FROM_POLICIES`.

Causa confirmada na documentação oficial do Mercado Livre
(`developers.mercadolivre.com.br/pt_br/erro-403`), na lista de validações para erro 403:

> "Validar dados dos usuários: o usuário deve ter concluído o processo de validação
> de dados."

Isso bate com a tela de verificação de identidade (Mercado Pago Shield / biometria
facial) que apareceu durante o cadastro do app. Descartamos a hipótese de bloqueio por
faixa de IP: o recurso de allowlist de IP (`Gerenciar IPs de um aplicativo`) é exclusivo
para "integradores whitelisted", não se aplica a apps comuns como o nosso.

**Atualização 2026-08-14 (parte 2):** usuária completou a verificação de identidade no
Mercado Pago. `GET /users/me` passou a responder 200 normalmente (conta ativa, email
confirmado, sem restrições pendentes). Mesmo assim, `/sites/MLB/search`,
`/items/{id}` e `/highlights/MLB/category/{id}` continuam retornando o mesmo
`PA_UNAUTHORIZED_RESULT_FROM_POLICIES`.

**Conclusão:** o bloqueio não é (ou não é mais) sobre a conta — é sobre a categoria de
endpoints de catálogo/busca de produtos como um todo, que parece exigir aprovação
como parceiro (ver "Developer Partner Program" no rodapé de
developers.mercadolivre.com.br) e não está disponível apenas criando um app comum
no DevCenter. `/categories/{id}` e `/users/me` (endpoints "genéricos") continuam
públicos e funcionando.

**Decisão tomada:** seguir o projeto com um dataset de exemplo realista (celulares,
informática, games), documentando essa limitação de acesso à API como um achado
técnico real do projeto. Se a aprovação de parceiro for obtida no futuro, os dados de
exemplo são substituídos pelos reais sem redesenhar o pipeline.

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
