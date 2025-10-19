const { app } = require("@azure/functions");
app.http("diagnostic", {
    methods: ["GET"],
    authLevel: "anonymous",
    route: "diagnostic",
    handler: async (request, context) => ({
        status: 200,
        jsonBody: { working: true, timestamp: new Date().toISOString() }
    })
});
