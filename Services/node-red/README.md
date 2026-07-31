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

`POST /v1/databases/:database/documents` cria um documento JSON. O nome do
banco vem na rota e o CloudantPlus o cria quando a API key tiver permissão.

## Verificação

```sh
npm test
NODE_RED_URL=http://localhost:1880 npm run eval
```

O eval consulta somente `/v1/health`; ele não cria nem altera documentos.
