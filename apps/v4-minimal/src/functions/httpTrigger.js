const { app } = require("@azure/functions");

app.http("HttpExample", {
    methods: ["GET", "POST"],
    authLevel: "anonymous",
    handler: async (request, context) => {
        context.log("HTTP function processed request.");
        return { body: "Hello from Flex Consumption!" };
    }
});
