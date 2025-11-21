module.exports = async function (context, req) {
    const diagnostics = {
        endpoint: {
            exists: !!process.env.AZURE_OPENAI_ENDPOINT,
            value: process.env.AZURE_OPENAI_ENDPOINT || 'NOT_SET',
            isKeyVaultRef: (process.env.AZURE_OPENAI_ENDPOINT || '').startsWith('@Microsoft.KeyVault')
        },
        apiKey: {
            exists: !!process.env.OPENAI_API_KEY,
            length: process.env.OPENAI_API_KEY ? process.env.OPENAI_API_KEY.length : 0,
            prefix: process.env.OPENAI_API_KEY ? process.env.OPENAI_API_KEY.substring(0, 8) + '...' : 'NOT_SET',
            isKeyVaultRef: (process.env.OPENAI_API_KEY || '').startsWith('@Microsoft.KeyVault')
        },
        deployment: {
            exists: !!process.env.AZURE_OPENAI_DEPLOYMENT,
            value: process.env.AZURE_OPENAI_DEPLOYMENT || 'NOT_SET'
        }
    };

    context.res = {
        status: 200,
        headers: {
            'Content-Type': 'application/json'
        },
        body: diagnostics
    };
};
