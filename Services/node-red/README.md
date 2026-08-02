# Node-RED + IBM Cloudant

Este serviço usa `node-red-contrib-cloudantplus`. O app iOS chama o gateway,
nunca o Cloudant diretamente.

## Executar localmente

Sem Docker, instale o Node.js 20 LTS no perfil do usuário e execute:

```sh
cd Services/node-red
cp .env.example .env
# preencha CLOUDANT_URL
npm install
npm run start:local
```

Abra `http://localhost:1880`. No editor, abra o nó de configuração **IBM
Cloudant**, marque **Authenticate with API Key?** e informe a API key. O
Node-RED a salva criptografada com `NODE_RED_CREDENTIAL_SECRET`; ela não entra
no Git nem no app iOS.

Com Docker:

```sh
cd Services/node-red
cp .env.example .env
# preencha CLOUDANT_URL
docker compose up --build
```

A porta fica limitada a `127.0.0.1`. Para publicar o gateway, coloque-o atrás
de HTTPS e autenticação.

## Contrato do gateway

`GET /v1/health` confirma a conexão com a instância Cloudant.

`GET /v1/databases` lista os bancos disponíveis. Não exige nome de banco na
configuração.

`GET /v1/databases/:database/documents?limit=100` lista até 200 documentos.
O parâmetro `limit` é opcional e aceita inteiros de 1 a 200.

`POST /v1/databases/:database/documents` cria um documento JSON. O nome do
banco vem na rota e o CloudantPlus o cria quando a API key tiver permissão.
O corpo pode incluir `_id`, mas não `_rev`.

`GET /v1/databases/:database/documents/:document` retorna um documento,
incluindo `_rev`.

`PUT /v1/databases/:database/documents/:document` substitui um documento. O
corpo precisa conter o mesmo `_id` da rota e o `_rev` atual. Esse requisito
evita que uma edição apague outra edição concorrente.

`DELETE /v1/databases/:database/documents/:document?rev=<rev>` remove um
documento. Passe o `_rev` retornado pelo `GET` ou `PUT`.

O app usa o banco `hackafinancas`. O primeiro cadastro o cria. Em aparelhos
físicos, informe no app o IP da máquina que executa o Node-RED, por exemplo
`http://192.168.0.10:1880`; `localhost` funciona apenas no mesmo computador.

## Verificação

```sh
npm test
NODE_RED_URL=http://localhost:1880 CLOUDANT_EVAL_DATABASE=hackafinancas_eval npm run eval
```

O eval cria, lê, atualiza e remove um documento com ID aleatório no banco
informado. Use um banco exclusivo de avaliação.
