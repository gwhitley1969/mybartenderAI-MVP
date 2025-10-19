const { app } = require("@azure/functions");

app.http('health', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'health',
    handler: async (request, context) => {
        context.log('Health check endpoint called');
        
        return {
            status: 200,
            body: {
                status: 'ok',
                message: 'Azure Functions v4 on Windows Consumption',
                timestamp: new Date().toISOString()
            }
        };
    }
});
