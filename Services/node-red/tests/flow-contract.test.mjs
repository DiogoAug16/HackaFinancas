import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const flows = JSON.parse(await readFile(new URL("flows.json", root), "utf8"));
const manifest = JSON.parse(await readFile(new URL("package.json", root), "utf8"));
const settings = await readFile(new URL("settings.js", root), "utf8");
const find = (id) => flows.find((node) => node.id === id);

assert.equal(manifest.dependencies["node-red-contrib-cloudantplus"], "2.0.6");
assert.equal(manifest.dependencies["@ibm-cloud/cloudant"], undefined);
assert.equal(manifest.engines.node, "^20");
assert.equal(manifest.devDependencies["node-red"], "4.1.10");
assert.equal(manifest.scripts["start:local"], "node --env-file=.env ./node_modules/node-red/red.js --userDir . --settings settings.js");
assert(settings.includes('flowFile: process.env.FLOWS || "flows.json"'));
assert(!settings.includes("functionGlobalContext"));

const connection = find("cloudant-connection");
assert.equal(connection?.type, "cloudantplus");
assert.equal(connection?.host, "${CLOUDANT_URL}");
assert.equal(connection?.useapikey, true);
assert.equal(find("cloudant-server-info")?.operation, "server");
assert.equal(find("cloudant-database-list")?.operation, "dblist");
assert.equal(find("cloudant-document-out")?.type, "cloudantplus out");
assert.equal(find("documents-in")?.url, "/v1/databases/:database/documents");

function run(nodeConfig, message) {
    return new Function("msg", nodeConfig.func)(message);
}

const validateTarget = find("validate-document-target");
const invalidName = run(validateTarget, { req: { params: { database: "Invalid Name" } }, payload: {} });
assert.equal(invalidName[1].statusCode, 400);

const invalidDocument = run(validateTarget, { req: { params: { database: "hackafinancas" } }, payload: [] });
assert.equal(invalidDocument[1].statusCode, 400);

const document = { req: { params: { database: "hackafinancas" } }, payload: { amount: 10 } };
const validDocument = run(validateTarget, document);
assert.equal(validDocument[0].database, "hackafinancas");

console.log("Node-RED CloudantPlus flow contract: OK");
