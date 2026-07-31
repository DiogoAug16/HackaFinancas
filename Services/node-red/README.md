# Node-RED + IBM Cloudant

Este serviço é o único componente que recebe as credenciais do Cloudant. O app
iOS deve chamar o gateway, nunca o Cloudant diretamente.

## Executar localmente

```sh
cd services/node-red
cp .env.example .env
# preencha CLOUDANT_URL, CLOUDANT_APIKEY e CLOUDANT_DATABASE
docker compose up --build
```

O editor fica em `http://localhost:1880`. A porta é limitada a `127.0.0.1`,
portanto não fica acessível pela rede local. Para publicar o gateway, coloque-o
atrás de HTTPS e autenticação antes de expor qualquer rota.

## Contrato do gateway

`GET /v1/health` confirma a comunicação com o banco configurado e retorna
`{"status":"ok","database":"..."}`.

`POST /v1/documents` recebe um objeto JSON e cria um documento no banco
`CLOUDANT_DATABASE`. Retorna a resposta de criação do Cloudant, como
`{"ok":true,"id":"...","rev":"..."}`. O endpoint rejeita arrays e valores
que não sejam objetos.

## Verificação

```sh
npm test
NODE_RED_URL=http://localhost:1880 npm run eval
```

O teste é local e simula o SDK. O eval consulta somente `/v1/health`, sem criar
ou alterar documentos; ele falha se o Node-RED não alcançar o Cloudant.
