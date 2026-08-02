import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const flows = JSON.parse(await readFile(new URL("flows.json", root), "utf8"));
const manifest = JSON.parse(await readFile(new URL("package.json", root), "utf8"));
const settings = await readFile(new URL("settings.js", root), "utf8");
const find = (id) => flows.find((node) => node.id === id);
const run = (id, message) => new Function("msg", find(id).func)(message);

assert.equal(manifest.dependencies["node-red-contrib-cloudantplus"], "2.0.6");
assert.equal(manifest.dependencies["@ibm-cloud/cloudant"], undefined);
assert.equal(manifest.engines.node, "^20");
assert.equal(manifest.devDependencies["node-red"], "4.1.10");
assert.equal(manifest.scripts["start:local"], "node --env-file=.env ./node_modules/node-red/red.js --userDir . --settings settings.js");
assert.equal(manifest.scripts.eval, "node evals/cloudant-crud.eval.mjs");
assert(settings.includes('flowFile: process.env.FLOWS || "flows.json"'));
assert(!settings.includes("functionGlobalContext"));

assert.equal(find("cloudant-connection")?.type, "cloudantplus");
assert.equal(find("cloudant-connection")?.host, "${CLOUDANT_URL}");
assert.equal(find("cloudant-connection")?.useapikey, true);
assert.equal(find("cloudant-server-info")?.operation, "server");
assert.equal(find("cloudant-database-list")?.operation, "dblist");
assert.equal(find("cloudant-document-in")?.type, "cloudantplus in");
assert.equal(find("cloudant-document-in")?.search, "_all_");
assert.equal(find("cloudant-document-out")?.type, "cloudantplus out");

assert.equal(find("documents-list-in")?.url, "/v1/databases/:database/documents");
assert.equal(find("documents-create-in")?.url, "/v1/databases/:database/documents");
assert.equal(find("document-get-in")?.url, "/v1/databases/:database/documents/:document");
assert.equal(find("document-update-in")?.url, "/v1/databases/:database/documents/:document");
assert.equal(find("document-delete-in")?.url, "/v1/databases/:database/documents/:document");

const invalidRead = run("prepare-document-read", { req: { params: { database: "Invalid Name" } } });
assert.equal(invalidRead[1].statusCode, 400);

const list = run("prepare-document-read", { req: { params: { database: "hackafinancas" }, query: { limit: "2" } } });
assert.equal(list[0].database, "hackafinancas");
assert.equal(list[0].operation, "_all_");
assert.deepEqual(list[0].options, { limit: 2, include_docs: true });

const get = run("prepare-document-read", { req: { params: { database: "hackafinancas", document: "expense-1" } } });
assert.equal(get[0].operation, "_id_");
assert.equal(get[0].payload, "expense-1");

const invalidCreate = run("prepare-document-write", { req: { method: "POST", params: { database: "hackafinancas" } }, payload: [] });
assert.equal(invalidCreate[1].statusCode, 400);

const reservedCreate = run("prepare-document-write", { req: { method: "POST", params: { database: "hackafinancas" } }, payload: { _id: "_design/test" } });
assert.equal(reservedCreate[1].statusCode, 400);

const create = run("prepare-document-write", { req: { method: "POST", params: { database: "hackafinancas" } }, payload: { title: "Coffee" } });
assert.equal(create[0].operation, "insert");
assert.equal(create[0].httpStatus, 201);

const invalidUpdate = run("prepare-document-write", { req: { method: "PUT", params: { database: "hackafinancas", document: "expense-1" } }, payload: { _id: "expense-1" } });
assert.equal(invalidUpdate[1].statusCode, 400);

const update = run("prepare-document-write", { req: { method: "PUT", params: { database: "hackafinancas", document: "expense-1" } }, payload: { _id: "expense-1", _rev: "1-a", title: "Coffee" } });
assert.equal(update[0].httpStatus, 200);

const invalidDelete = run("prepare-document-delete", { req: { params: { database: "hackafinancas", document: "expense-1" }, query: {} } });
assert.equal(invalidDelete[1].statusCode, 400);

const remove = run("prepare-document-delete", { req: { params: { database: "hackafinancas", document: "expense-1" }, query: { rev: "2-b" } } });
assert.equal(remove[0].operation, "delete");
assert.deepEqual(remove[0].payload, { _id: "expense-1", _rev: "2-b" });

console.log("Node-RED Cloudant CRUD flow contract: OK");
