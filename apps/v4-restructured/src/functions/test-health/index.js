const { app } = require("@azure/functions");

async function health(request, context) {
    context.log('Health check endpoint called');
    
    return {
        status: 200,
        jsonBody: {
            status: 'ok',
            message: 'Azure Functions v4 is running',
            timestamp: new Date().toISOString(),
            nodeVersion: process.version,
            functionRuntime: process.env.FUNCTIONS_WORKER_RUNTIME,
            environment: {
                hasHost: require('fs').existsSync('./host.json'),
                hasPackageJson: require('fs').existsSync('./package.json'),
                cwd: process.cwd()
            }
        }
    };
}

app.http('health', {
    methods: ['GET'],
    authLevel: 'anonymous',
    route: 'health',
    handler: health
});

