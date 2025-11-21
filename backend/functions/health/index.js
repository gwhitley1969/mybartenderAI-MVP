module.exports = async function (context, req) {
    context.log('Health check endpoint called');
    
    context.res = {
        status: 200,
        body: {
            status: 'ok',
            message: 'Azure Functions v3 on Windows Consumption',
            timestamp: new Date().toISOString()
        }
    };
};