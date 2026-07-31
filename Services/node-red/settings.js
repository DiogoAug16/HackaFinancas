const { CloudantV1 } = require("@ibm-cloud/cloudant");

if (!process.env.NODE_RED_CREDENTIAL_SECRET) {
    throw new Error("NODE_RED_CREDENTIAL_SECRET is required");
}

module.exports = {
    credentialSecret: process.env.NODE_RED_CREDENTIAL_SECRET,
    flowFile: process.env.FLOWS || "flows.json",
    functionGlobalContext: { CloudantV1 }
};
