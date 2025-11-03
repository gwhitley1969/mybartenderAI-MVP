# Smart Scanner - Quick Implementation Guide for Sonnet

## Overview
Implement camera-based inventory scanning using Azure Computer Vision to identify bottles and add them to user's "My Bar" inventory.

## Implementation Order

### Step 1: Azure Setup (30 minutes)
```bash
# 1.1 Create Computer Vision resource
az cognitiveservices account create \
  --name cv-mba-prod \
  --resource-group rg-mba-prod \
  --kind ComputerVision \
  --sku F0 \
  --location southcentralus \
  --yes

# 1.2 Get credentials and add to Key Vault
az cognitiveservices account keys list --name cv-mba-prod --resource-group rg-mba-prod
az keyvault secret set --vault-name kv-mybartenderai-prod --name AZURE-CV-KEY --value "<key>"
az keyvault secret set --vault-name kv-mybartenderai-prod --name AZURE-CV-ENDPOINT --value "https://cv-mba-prod.cognitiveservices.azure.com/"

# 1.3 Update Function App settings
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings \
    "AZURE_CV_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-CV-KEY/)" \
    "AZURE_CV_ENDPOINT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-CV-ENDPOINT/)"
```

### Step 2: Backend Implementation (1 hour)

1. Create folder: `apps/backend/v3-deploy/vision-analyze/`
2. Add `index.js` (see SMART_SCANNER_IMPLEMENTATION_PLAN.md for full code)
3. Add `function.json` with route `v1/vision/analyze`
4. Install axios: `npm install axios`
5. Deploy: `func azure functionapp publish func-mba-fresh --javascript`

### Step 3: Flutter Integration (2 hours)

1. **Add dependencies** to `mobile/app/pubspec.yaml`:
   ```yaml
   image_picker: ^1.0.8
   image: ^4.2.0
   ```

2. **Add permissions**:
   - Android: Update `AndroidManifest.xml` with CAMERA permission
   - iOS: Update `Info.plist` with NSCameraUsageDescription

3. **Create files**:
   - `lib/src/api/vision_api.dart` - API client
   - `lib/src/features/smart_scanner/smart_scanner_screen.dart` - UI
   - `lib/src/providers/vision_provider.dart` - State management

4. **Update router** in `lib/src/app/router.dart`:
   ```dart
   GoRoute(
     path: '/smart-scanner',
     name: 'smart-scanner',
     builder: (context, state) => const SmartScannerScreen(),
   ),
   ```

5. **Update home screen** navigation for Smart Scanner card

### Step 4: Testing (30 minutes)

1. Test camera permissions
2. Test photo capture and gallery selection
3. Test with sample bottles
4. Verify ingredient matching
5. Confirm inventory updates

## Key Files to Create/Modify

### Backend (2 files)
- ✅ `apps/backend/v3-deploy/vision-analyze/index.js` - Main function
- ✅ `apps/backend/v3-deploy/vision-analyze/function.json` - Configuration

### Flutter (5 files)
- ✅ `mobile/app/lib/src/api/vision_api.dart` - API service
- ✅ `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart` - UI
- ✅ `mobile/app/lib/src/providers/vision_provider.dart` - Provider
- ✅ `mobile/app/lib/src/app/router.dart` - Add route (MODIFY)
- ✅ `mobile/app/lib/src/features/home/home_screen.dart` - Update navigation (MODIFY)

### Configuration (3 files)
- ✅ `mobile/app/pubspec.yaml` - Add dependencies (MODIFY)
- ✅ `mobile/app/android/app/src/main/AndroidManifest.xml` - Permissions (MODIFY)
- ✅ `mobile/app/ios/Runner/Info.plist` - Permissions (MODIFY)

## Testing Endpoints

```bash
# Test vision endpoint
curl -X POST https://func-mba-fresh.azurewebsites.net/api/v1/vision/analyze \
  -H "x-functions-key: YOUR_FUNCTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"imageUrl": "https://example.com/bottle.jpg"}'
```

## Common Bottle Brands to Support

The backend should recognize:
- Absolut Vodka
- Jack Daniels
- Smirnoff
- Bacardi
- Captain Morgan
- Grey Goose
- Patron
- Hennessy
- Johnnie Walker
- Jim Beam
- Tanqueray
- Bombay Sapphire
- Jose Cuervo
- Jameson
- Baileys
- Kahlua
- Southern Comfort

## Success Metrics
- 70%+ accuracy on common brands
- < 5 second analysis time
- Smooth UX with clear feedback
- Successful inventory integration

## Notes for Sonnet
1. Full implementation details are in `docs/SMART_SCANNER_IMPLEMENTATION_PLAN.md`
2. Use existing patterns from Ask Bartender and My Bar features
3. Function key is already in main.dart from previous work
4. Test with emulator first before physical device
5. Start with single bottle detection, then expand to multiple

Good luck with the implementation!