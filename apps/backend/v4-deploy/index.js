// Main entry point for Azure Functions v4
// This file imports all functions to register them with the app

require('./download-images/index.js');
require('./recommend/index.js');
require('./snapshots-latest/index.js');
require('./sync-cocktaildb/index.js');
require('./test-health/index.js');
require('./diagnostic/index.js');
