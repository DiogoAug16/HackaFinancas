const url = process.env.NODE_RED_URL;

if (!url) {
    console.log("Cloudant health eval skipped: set NODE_RED_URL after starting Node-RED.");
    process.exit(0);
}

const response = await fetch(new URL("/v1/health", url));
const body = await response.json();

if (!response.ok || body.status !== "ok") {
    throw new Error(`Cloudant health eval failed: HTTP ${response.status} ${JSON.stringify(body)}`);
}

console.log(`Cloudant health eval: OK (${body.database})`);
