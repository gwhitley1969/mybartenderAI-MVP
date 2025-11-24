# Smart Scanner Migration: GPT-4.1 to Claude Haiku 4.5

**Date**: November 24, 2025
**Status**: ✅ Complete
**Function**: `vision-analyze`

## Problem Statement

The Smart Scanner feature was using Azure Computer Vision / GPT-4.1 for bottle detection, but we needed to switch to Claude Haiku 4.5 via Azure AI Foundry for improved accuracy and consistency.

## Technical Challenges Encountered

### 1. Deployment Caching Issues

After updating the code and deploying, the function logs still showed:
```
[Information] Calling Computer Vision API...
```

Instead of the expected:
```
[Information] Calling Claude Haiku 4.5...
```

**Root Cause**: Azure Functions v4 uses a **bundled `index.js`** file at the root of `backend/functions/` that contains ALL functions using the `app.http()` registration pattern. Individual function folders are NOT used by the runtime.

### 2. Critical Discovery: Bundled Function Architecture

The Azure Functions v4 programming model bundles all functions into a single `index.js` file:
- Location: `backend/functions/index.js` (87,827 bytes)
- Contains all 25+ functions registered with `app.http()`
- Individual function folders (like `vision-analyze/`) are NOT used at runtime
- Deleting this bundled file breaks the ENTIRE Function App

**Lesson Learned**: Never delete the bundled `index.js` - it's the master file that runs all functions.

### 3. Azure Functions v4 Logging

Azure Functions v4 uses different logging methods:
- ❌ `context.log.error()` - Does NOT work in v4
- ✅ `context.error()` - Correct v4 method
- ✅ `context.log()` - Works for info logging

### 4. Claude Response JSON Parsing

Claude returned JSON wrapped in markdown code blocks with explanatory text:
```
```json
{"bottles": [...]}
```
Here's what I found in the image...
```

**Fix**: Added regex extraction to handle markdown-wrapped JSON:
```javascript
const jsonBlockMatch = cleanedResponse.match(/```(?:json)?\s*([\s\S]*?)```/);
if (jsonBlockMatch) {
    cleanedResponse = jsonBlockMatch[1].trim();
}
```

## Solution Implemented

### Azure Key Vault Secrets Added

| Secret Name | Value |
|-------------|-------|
| `CLAUDE-API-KEY` | API key for Azure AI Foundry |
| `CLAUDE-ENDPOINT` | `https://blueb-midjmnz5-eastus2.services.ai.azure.com/anthropic/v1/messages` |

### Function App Settings Updated

```
CLAUDE_API_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/CLAUDE-API-KEY/)
CLAUDE_ENDPOINT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/CLAUDE-ENDPOINT/)
```

### Code Changes in `backend/functions/index.js`

Updated the vision-analyze function (lines 1596-1987) to:

1. **Use Anthropic Messages API format**:
```javascript
const requestBody = {
    model: "claude-haiku-4-5",
    max_tokens: 1024,
    system: systemPrompt,
    messages: [{
        role: "user",
        content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: base64Data } },
            { type: "text", text: userPrompt }
        ]
    }]
};
```

2. **Correct headers for Azure AI Foundry**:
```javascript
headers: {
    'x-api-key': claudeApiKey,
    'anthropic-version': '2023-06-01',
    'Content-Type': 'application/json'
}
```

3. **Extract JSON from markdown code blocks**
4. **Use v4-compatible logging** (`context.error()` instead of `context.log.error()`)

## Testing Results

### Test 1: Blank Image
- Input: Empty/white image
- Output: `{"bottles": []}`
- Result: ✅ Correct empty response

### Test 2: Johnnie Walker Black Label
- Input: Photo of Johnnie Walker bottle
- Output:
```json
{
  "bottles": [{
    "name": "Johnnie Walker Black Label",
    "type": "Scotch Whisky",
    "brand": "Johnnie Walker",
    "confidence": 0.98,
    "estimatedFullness": 0.85,
    "position": { "x": 0.5, "y": 0.5 }
  }]
}
```
- Result: ✅ High confidence detection (98%)

## Architecture Reference

```
Mobile App
    ↓
Azure Front Door (share.mybartenderai.com)
    ↓
Azure API Management (apim-mba-002)
    ↓
Azure Functions (func-mba-fresh)
    → vision-analyze (Claude Haiku 4.5)
    → ask-bartender-simple (GPT-4o-mini)
    → other functions...
```

## Files Modified

| File | Changes |
|------|---------|
| `backend/functions/index.js` | Updated vision-analyze function to use Claude Haiku 4.5 |
| `backend/functions/vision-analyze/function.json` | Route configuration (unchanged) |
| `backend/functions/vision-analyze/index.js` | Individual file (NOT used by runtime) |

## Key Takeaways

1. **Azure Functions v4 uses bundled `index.js`** - Always modify this file, not individual function folders
2. **Never delete the bundled `index.js`** - It will break ALL functions
3. **Use `context.error()` in v4** - Not `context.log.error()`
4. **Claude returns markdown-wrapped JSON** - Parse accordingly
5. **Test through Front Door** - Not direct function URLs (which require function keys)

## Related Documentation

- [Azure AI Foundry Claude Integration](https://learn.microsoft.com/en-us/azure/ai-services/)
- [Anthropic Messages API](https://docs.anthropic.com/claude/reference/messages)
- [Azure Functions v4 Programming Model](https://learn.microsoft.com/en-us/azure/azure-functions/functions-node-upgrade-v4)
