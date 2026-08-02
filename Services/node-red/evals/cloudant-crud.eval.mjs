import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";

const gateway = process.env.NODE_RED_URL;
const database = process.env.CLOUDANT_EVAL_DATABASE;

if (!gateway || !database) {
    console.log("Cloudant CRUD eval skipped: set NODE_RED_URL and CLOUDANT_EVAL_DATABASE.");
    process.exit(0);
}

const base = new URL(`/v1/databases/${encodeURIComponent(database)}/documents/`, gateway);
const id = `eval-${randomUUID()}`;
let revision;

async function request(path = "", options) {
    return fetch(new URL(path, base), options);
}

try {
    const health = await fetch(new URL("/v1/health", gateway));
    assert.equal(health.status, 200);

    const created = await request("", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ _id: id, eval: true, value: "created" })
    });
    assert.equal(created.status, 201);

    const listed = await request("?limit=200");
    assert.equal(listed.status, 200);
    assert((await listed.json()).documents.some((document) => document._id === id));

    const read = await request(id);
    assert.equal(read.status, 200);
    const document = await read.json();
    assert.equal(document.value, "created");
    revision = document._rev;

    const updated = await request(id, {
        method: "PUT",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ...document, value: "updated" })
    });
    assert.equal(updated.status, 200);
    revision = (await updated.json()).rev;

    const removed = await request(`${id}?rev=${encodeURIComponent(revision)}`, { method: "DELETE" });
    assert.equal(removed.status, 204);
    revision = undefined;

    const missing = await request(id);
    assert(!missing.ok);
    console.log("Cloudant CRUD eval: OK");
} finally {
    if (revision) {
        await request(`${id}?rev=${encodeURIComponent(revision)}`, { method: "DELETE" });
    }
}
