import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

const root = new URL("../", import.meta.url);
const flows = JSON.parse(await readFile(new URL("flows.json", root), "utf8"));
const manifest = JSON.parse(await readFile(new URL("package.json", root), "utf8"));
const settings = await readFile(new URL("settings.js", root), "utf8");
const documentNode = flows.find((node) => node.id === "create-document");
const healthNode = flows.find((node) => node.id === "health-check");

assert.equal(manifest.dependencies["@ibm-cloud/cloudant"], "0.9.2");
assert.equal(manifest.engines.node, "^20");
assert.equal(manifest.devDependencies["node-red"], "4.1.10");
assert.equal(manifest.scripts["start:local"], "node --env-file=.env ./node_modules/node-red/red.js --userDir . --settings settings.js");
assert(settings.includes('flowFile: process.env.FLOWS || "flows.json"'));
assert(documentNode?.func.includes("postDocument"), "document flow must save through the Cloudant SDK");
assert(healthNode?.func.includes("getDatabaseInformation"), "health flow must verify Cloudant");

async function run(nodeConfig, payload, environment, service) {
    const messages = [];
    const errors = [];
    let finish;
    const done = new Promise((resolve) => { finish = resolve; });
    const fn = new Function("msg", "env", "global", "node", nodeConfig.func);
    fn(
        { payload },
        { get: (key) => environment[key] },
        { get: (key) => key === "CloudantV1" ? service : undefined },
        { send: (message) => messages.push(message), error: (message) => errors.push(message), done: finish }
    );
    await done;
    return { messages, errors };
}

const configured = {
    CLOUDANT_DATABASE: "hackafinancas",
    CLOUDANT_URL: "https://example.cloudant.com",
    CLOUDANT_APIKEY: "test-key"
};
const response = { result: { ok: true, id: "expense-1", rev: "1-a" }, status: 201 };
let saved;
const service = {
    newInstance: () => ({
        postDocument: async (request) => { saved = request; return response; },
        getDatabaseInformation: async () => ({ result: { db_name: "hackafinancas" } })
    })
};

const invalid = await run(documentNode, [], configured, service);
assert.equal(invalid.messages[0][1].statusCode, 400);

const missing = await run(documentNode, { amount: 10 }, {}, service);
assert.equal(missing.messages[0][1].statusCode, 503);

const created = await run(documentNode, { type: "expense", amount: 10 }, configured, service);
assert.deepEqual(saved, { db: "hackafinancas", document: { type: "expense", amount: 10 } });
assert.equal(created.messages[0][0].statusCode, 201);
assert.deepEqual(created.messages[0][0].payload, response.result);

const healthy = await run(healthNode, undefined, configured, service);
assert.equal(healthy.messages[0].statusCode, 200);
assert.deepEqual(healthy.messages[0].payload, { status: "ok", database: "hackafinancas" });

console.log("Node-RED Cloudant flow contract: OK");
