# Smart Scanner Implementation Documentation

**Status:** ✅ Completed
**Date:** November 3, 2025
**Feature:** Camera-based ingredient detection and inventory management

## Overview

The Smart Scanner feature allows users to photograph their liquor bottles and automatically identify them using Azure Computer Vision API. Detected ingredients are matched against the cocktail database and can be added to the user's inventory with a single tap.

## Architecture

### Backend Components

#### Azure Computer Vision Service
- **Service Name:** `cv-mba-prod`
- **Tier:** F0 (Free tier - 20 transactions per minute, 5,000 per month)
- **Location:** South Central US
- **Features Used:**
  - Tags detection
  - Description generation
  - Objects detection
  - Brands detection

#### Azure Function: vision-analyze

**Endpoint:** `POST /api/v1/vision/analyze`

**Location:** `apps/backend/v3-deploy/vision-analyze/`

**Files:**
- `index.js` - Main function implementation
- `function.json` - Function configuration and bindings

**Dependencies:**
- `axios` - HTTP client for Computer Vision API calls

**Authentication:**
- Function-level key authentication
- Azure Key Vault integration for Computer Vision credentials

**Request Format:**
```json
{
  "image": "<base64-encoded image data>"
}
```

**Response Format:**
```json
{
  "success": true,
  "detected": [
    {
      "type": "brand|tag|description",
      "name": "Tito's Handmade Vodka",
      "confidence": 0.95
    }
  ],
  "matched": [
    {
      "ingredientName": "Vodka",
      "confidence": 0.95,
      "matchType": "brand"
    }
  ],
  "confidence": 0.85,
  "rawAnalysis": {
    "description": "A bottle of vodka on a counter",
    "tags": ["bottle", "vodka", "alcohol"],
    "brands": ["Tito's"]
  }
}
```

**Ingredient Matching Logic:**

The function uses a hardcoded brand dictionary for MVP:
```javascript
const BRAND_MATCHES = {
  "tito's": "Vodka",
  "absolut": "Vodka",
  "grey goose": "Vodka",
  "jack daniel's": "Whiskey",
  "jim beam": "Bourbon",
  "jose cuervo": "Tequila",
  "patron": "Tequila",
  "bacardi": "Rum",
  "captain morgan": "Rum",
  "tanqueray": "Gin",
  "bombay sapphire": "Gin",
  "hennessy": "Cognac",
  // ... 23 total brands
};
```

Future enhancement: Replace with database query for comprehensive brand recognition.

### Mobile App Components

#### Dependencies Added

**pubspec.yaml:**
```yaml
dependencies:
  image_picker: ^1.0.8  # Camera and gallery access
  image: ^4.2.0         # Image handling
```

#### Permissions Configured

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>MyBartenderAI needs camera access to scan your bar inventory</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>MyBartenderAI needs photo library access to select photos of your bar</string>
```

#### API Client

**File:** `mobile/app/lib/src/api/vision_api.dart`

**Classes:**
- `VisionApi` - HTTP client for vision-analyze endpoint
- `VisionAnalysisResponse` - Response model
- `DetectedItem` - Individual detection result
- `MatchedIngredient` - Matched database ingredient
- `RawAnalysis` - Raw Computer Vision data

**Key Method:**
```dart
Future<VisionAnalysisResponse> analyzeImage(Uint8List imageBytes) async {
  final base64Image = base64Encode(imageBytes);
  final response = await _dio.post<Map<String, dynamic>>(
    '/v1/vision/analyze',
    data: {'image': base64Image},
  );
  return VisionAnalysisResponse.fromJson(response.data!);
}
```

#### UI Screen

**File:** `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart`

**Features:**
- Camera button - Opens device camera
- Gallery button - Opens photo gallery
- Image preview after selection
- Processing indicator during analysis
- Confidence score display
- List of detected bottles with checkboxes
- Auto-selection of high-confidence matches (>70%)
- Manual selection/deselection
- Batch add to inventory
- Error handling with user-friendly messages
- AI description display (for debugging)

**State Management:**
```dart
class _SmartScannerScreenState extends ConsumerState<SmartScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  Uint8List? _imageBytes;
  VisionAnalysisResponse? _analysisResult;
  final Set<String> _selectedIngredients = {};

  // ... methods
}
```

**Key Methods:**
- `_pickImage(ImageSource source)` - Handle camera/gallery selection
- `_analyzeImage(Uint8List bytes)` - Call backend API for analysis
- `_addToInventory()` - Add selected ingredients to user's bar

#### Provider

**File:** `mobile/app/lib/src/providers/vision_provider.dart`

**Provider:**
```dart
final visionApiProvider = Provider<VisionApi>((ref) {
  final config = ref.watch(envConfigProvider);
  final interceptors = ref.watch(dioInterceptorsProvider);
  final dio = createBaseDio(config: config, interceptors: interceptors);
  return VisionApi(dio);
});
```

#### Navigation

**Router Update** (`mobile/app/lib/main.dart`):
```dart
GoRoute(
  path: 'smart-scanner',
  builder: (BuildContext context, GoRouterState state) {
    return const SmartScannerScreen();
  },
),
```

**Home Screen Integration** (`mobile/app/lib/src/features/home/home_screen.dart`):
```dart
FeatureCard(
  icon: Icons.camera_alt,
  title: 'Smart Scanner',
  subtitle: 'Identify premium ingredients',
  iconColor: AppColors.iconCirclePurple,
  onTap: () {
    context.go('/smart-scanner');
  },
),
```

## Azure Setup

### 1. Create Computer Vision Resource

```bash
az cognitiveservices account create \
  --name cv-mba-prod \
  --resource-group rg-mba-prod \
  --kind ComputerVision \
  --sku F0 \
  --location southcentralus \
  --yes
```

### 2. Store Credentials in Key Vault

```bash
# Get Computer Vision key
CV_KEY=$(az cognitiveservices account keys list \
  --name cv-mba-prod \
  --resource-group rg-mba-prod \
  --query key1 -o tsv)

# Store in Key Vault
az keyvault secret set \
  --vault-name kv-mybartenderai-prod \
  --name AZURE-CV-KEY \
  --value "$CV_KEY"

# Store endpoint
az keyvault secret set \
  --vault-name kv-mybartenderai-prod \
  --name AZURE-CV-ENDPOINT \
  --value "https://southcentralus.api.cognitive.microsoft.com/"
```

### 3. Update Function App Settings

```bash
az functionapp config appsettings set \
  --name func-mba-fresh \
  --resource-group rg-mba-prod \
  --settings \
    "AZURE_CV_KEY=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-CV-KEY/)" \
    "AZURE_CV_ENDPOINT=@Microsoft.KeyVault(SecretUri=https://kv-mybartenderai-prod.vault.azure.net/secrets/AZURE-CV-ENDPOINT/)"
```

## Deployment

### Backend Deployment

```bash
cd apps/backend/v3-deploy
npm install axios  # If not already installed
func azure functionapp publish func-mba-fresh --javascript
```

### Mobile App Build

```bash
cd mobile/app
flutter pub get
flutter build apk --release  # Android
# or
flutter build ios --release  # iOS (requires Mac)
```

## Testing

### Backend Testing

Test the vision-analyze endpoint:

```bash
# Test with a base64-encoded image
curl -X POST https://func-mba-fresh.azurewebsites.net/api/v1/vision/analyze \
  -H "Content-Type: application/json" \
  -H "x-functions-key: YOUR_FUNCTION_KEY" \
  -d '{"image": "BASE64_ENCODED_IMAGE_DATA"}'
```

### Mobile App Testing

#### Emulator Testing (Limited)
1. Navigate to Smart Scanner from home screen
2. Click "Take Photo" - Uses emulator's virtual camera (test pattern)
3. Click "Choose Photo" - Access emulator's photo gallery
4. Verify UI flow and backend integration

#### Physical Device Testing (Full)
1. Install APK on Android device
2. Grant camera and storage permissions
3. Take photo of actual liquor bottles
4. Verify correct brand/ingredient detection
5. Test adding detected items to inventory

## Known Limitations

1. **Brand Recognition:** Currently limited to 23 hardcoded brands for MVP
   - **Future Enhancement:** Query actual database for comprehensive matching

2. **Free Tier Limits:**
   - 20 transactions per minute
   - 5,000 transactions per month
   - **Upgrade Path:** Standard tier (S1) if usage exceeds limits

3. **Image Quality:**
   - Best results with clear, well-lit photos
   - Single bottle per photo recommended
   - Label should be visible and facing camera

4. **Testing Constraints:**
   - Full camera functionality requires physical device
   - Emulator can only test UI flow and API integration

## Cost Analysis

### Azure Computer Vision (F0 Tier)
- **Cost:** FREE
- **Limits:** 20 calls/min, 5,000 calls/month
- **Sufficient for:** MVP and early beta testing

### Estimated Usage (Per User)
- Average: 2-3 scans per session
- Typical: 1-2 sessions per week
- Monthly: 8-12 scans per user

### Scaling Costs
If upgrading to S1 (Standard tier):
- **Price:** $1.00 per 1,000 transactions
- **Example:** 100 users × 12 scans/month = 1,200 transactions = $1.20/month

## Future Enhancements

### Phase 2 Features
1. **Multi-bottle detection** - Identify multiple bottles in one photo
2. **Database brand matching** - Replace hardcoded dictionary with database queries
3. **Barcode scanning** - UPC code recognition for precise matching
4. **Batch inventory** - Scan entire bar shelves at once
5. **Historical tracking** - Track scanned items over time
6. **Confidence tuning** - Adjustable threshold for auto-selection

### Advanced Features
1. **Custom brand addition** - Allow users to add unrecognized brands
2. **OCR integration** - Read text from labels directly
3. **AR overlay** - Real-time camera overlay with ingredient names
4. **Community contributions** - Crowdsource brand/ingredient mappings

## Troubleshooting

### Common Issues

**Issue:** "Failed to analyze image"
- **Cause:** Backend API timeout or Computer Vision quota exceeded
- **Solution:** Check Function App logs, verify Key Vault access, check quota

**Issue:** No bottles detected
- **Cause:** Poor image quality or unrecognized brand
- **Solution:** Retake photo with better lighting, try different angle

**Issue:** Camera permission denied
- **Cause:** User denied camera permission
- **Solution:** Prompt user to enable in device settings

**Issue:** Incorrect ingredient matches
- **Cause:** Brand not in dictionary or ambiguous detection
- **Solution:** Manual deselection, will improve with database matching

## Files Modified/Created

### Backend
- ✅ `apps/backend/v3-deploy/vision-analyze/index.js` (NEW)
- ✅ `apps/backend/v3-deploy/vision-analyze/function.json` (NEW)
- ✅ `apps/backend/v3-deploy/package.json` (MODIFIED - added axios)
- ✅ `apps/backend/v3-deploy/package-lock.json` (MODIFIED)

### Mobile App
- ✅ `mobile/app/lib/src/api/vision_api.dart` (NEW)
- ✅ `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart` (NEW)
- ✅ `mobile/app/lib/src/providers/vision_provider.dart` (NEW)
- ✅ `mobile/app/lib/main.dart` (MODIFIED - added route)
- ✅ `mobile/app/lib/src/features/home/home_screen.dart` (MODIFIED - navigation)
- ✅ `mobile/app/pubspec.yaml` (MODIFIED - dependencies)
- ✅ `mobile/app/pubspec.lock` (MODIFIED)
- ✅ `mobile/app/android/app/src/main/AndroidManifest.xml` (MODIFIED - permissions)
- ✅ `mobile/app/ios/Runner/Info.plist` (MODIFIED - permissions)

### Documentation
- ✅ `docs/DEPLOYMENT_STATUS.md` (UPDATED)
- ✅ `docs/SMART_SCANNER_IMPLEMENTATION.md` (NEW - this file)

## Conclusion

The Smart Scanner feature is **fully implemented and deployed** to the Azure backend. The mobile app UI is complete and ready for testing. While emulator testing is limited to UI flow verification, the feature is production-ready and awaiting physical device testing for full camera functionality validation.

**Next Steps:**
1. Test on physical Android device
2. Validate brand detection accuracy
3. Collect user feedback during beta testing
4. Consider upgrading from hardcoded brands to database queries
5. Monitor Computer Vision API usage and upgrade tier if needed
