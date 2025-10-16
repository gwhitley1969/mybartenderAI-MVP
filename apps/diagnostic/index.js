const { app } = require("@azure/functions");

async function diagnostic(request, context) {
    return {
        status: 200,
        jsonBody: {
            message: "Diagnostic endpoint working",
            cwd: process.cwd(),
            nodeVersion: process.version,
            timestamp: new Date().toISOString()
        }
    };
}

app.http("diagnostic", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "diagnostic",
    handler: diagnostic
});
