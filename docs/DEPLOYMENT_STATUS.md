# MyBartenderAI Deployment Status

## Current Status: ⚠️ Today's Special rotation + notifications implemented — release APK rebuild pending timezone plugin patch

### Summary

After extensive troubleshooting with Azure Functions v4 on Flex Consumption plan, we successfully pivoted to deploying on Windows Consumption plan (`func-mba-fresh`) using Azure Functions v3 SDK patterns. All functions are now deployed and operational.

**Latest Update (2025-11-10):**

- ✅ Renamed home card to **Today's Special** with daily random cocktail selection & midnight refresh
- ✅ Added `todaysSpecialProvider` caching layer (SharedPreferences) + detail navigation
- ✅ Implemented daily 5 PM notification with custom chime (`todays_special_chime.wav`) using `NotificationService`
- ✅ Added MSAL-safe `getRandomCocktail()` to database service for curated picks
- ❌ Release APK rebuild blocked by outdated `flutter_native_timezone` plugin — namespace & JVM target patches in progress

**Update (2025-11-08):**

- ✅ **Create Studio AI Refine Enhanced** - Now available in edit mode with "Save as New Recipe" option
- ✅ Electric blue (#00D9FF) UI accent for AI Refine button (improved visibility)
- ✅ Three-button dialog in edit mode: "Update This Recipe", "Save as New Recipe", "Keep Original"
- ✅ Bootstrap validation changed from fatal error to warning for missing Azure Function Key
- ✅ **Release APK Built Successfully** with embedded Azure Function Key
- ✅ Fixed app black screen issue caused by StateError on missing environment variables
- ❌ **Voice Bartender REMOVED** - Too expensive for current business model
- 🔄 **Premium EP1 Migration Pending** - Quota increase requested from Microsoft Support
- 🔄 Azure Standard Support purchased ($100/month) for quota management

**Earlier Update (2025-11-03 - Evening):**

- ✅ **Authentication Integration Complete** - Entra External ID fully integrated throughout mobile app
- ✅ GoRouter authentication guards implemented (login/home redirects)
- ✅ JWT token automatic injection in all API calls via Dio interceptors
- ✅ User profile screen with age verification display and sign-out
- ✅ Navigation profile button in home screen header
- ✅ Token refresh logic implemented in auth service
- ✅ All compilation errors resolved (providers barrel file, database service references, API method signatures)
- ✅ Android OAuth redirect scheme configured in build.gradle.kts
- ✅ Full end-to-end authentication flow ready for testing on physical device

**Earlier Update (2025-11-03):**

- ✅ **Create Studio complete** - Full-featured cocktail creation with AI refinement
- ✅ Custom cocktail database methods implemented
- ✅ AI recipe refinement backend endpoint (GPT-4o-mini)
- ✅ Comprehensive cocktail creation/edit form with ingredient management
- ✅ AI refinement dialog with prioritized suggestions
- ✅ Recipe Vault updated to show custom cocktails with badge
- ✅ Full routing and navigation integration
- ~~✅ Voice Bartender complete~~ **REMOVED** (November 8, 2025)
- ~~✅ Speech Services F0 tier deployed~~ **REMOVED** (November 8, 2025)
- ~~✅ Voice UI with real-time transcription~~ **REMOVED** (November 8, 2025)

**Previous Update (2025-10-31):**

- ✅ Azure OpenAI migrated from East US to South Central US
- ✅ AI Bartender chat backend fixed and operational
- ✅ AI Bartender Chat UI complete and fully integrated
- ✅ **Inventory integration with AI Bartender complete** - AI now sees user's bar ingredients
- ✅ Function-level authentication properly configured
- ✅ Conversation tracking with conversationId support
- ✅ Mobile app successfully connected and tested
- ✅ Managed Identity + RBAC for secure Key Vault access

**Previous Update (2025-10-29):**

- Recipe Vault with search, filters, and cocktail detail views fully implemented
- Inventory management system (My Bar) complete with quick-add functionality
- Offline-first SQLite database with Zstandard compression
- "Can Make" filter for cocktails based on user inventory
- Project upgraded to Early Beta status

### Deployed Functions

1. ✅ **GET /api/health**
   
   - Health check endpoint
   - Status: Working (**actually health check not available on the SKU we're using presently**)

2. ✅ **GET /api/v1/snapshots/latest**
   
   - Returns cocktail database snapshot metadata with signed download URL
   - Current snapshot: version 20251014.202149 (621 drinks)
   - Status: Working

3. ✅ **POST /api/v1/recommend**
   
   - AI-powered cocktail recommendations
   - Requires: Function key + JWT authentication
   - Status: Deployed (needs testing)

4. ✅ **POST /api/v1/admin/download-images**
   
   - Downloads cocktail images to Azure Blob Storage
   - Requires: Admin key
   - Status: Deployed (needs testing)

5. ✅ **Timer: sync-cocktaildb**
   
   - Runs daily at 3:30 AM UTC
   - Syncs cocktail data and creates snapshots
   - Status: Deployed (needs manual trigger for initial sync)

6. ✅ **POST /api/v1/ask-bartender-simple**
   
   - AI-powered bartender chat using Azure OpenAI (gpt-4o-mini)
   - Natural language cocktail questions and recommendations
   - **Inventory Integration**: AI receives user's bar ingredients and provides personalized suggestions
   - Requires: Function key
   - Status: ✅ Working - Successfully deployed and tested
   - Azure OpenAI Service: `mybartenderai-scus` (South Central US)
   - Deployment: gpt-4o-mini with 100 TPM capacity
   - Test Results (2025-10-31):
     - ✅ Successfully migrated from East US to South Central US
     - ✅ OpenAI SDK properly configured for Azure OpenAI
     - ✅ Key Vault integration with Managed Identity + RBAC
     - ✅ Mobile app successfully connected and tested
     - ✅ Inventory integration working - AI sees user's bar ingredients
     - ✅ Personalized cocktail recommendations based on available ingredients
     - ✅ Response times: ~1-2 seconds for typical queries

7. ✅ **POST /api/validate-age**

   - Custom Authentication Extension for Entra External ID
   - Server-side age verification (21+) during signup
   - Event Type: OnAttributeCollectionSubmit
   - Authentication: OAuth 2.0 Bearer tokens ✅ ENABLED AND WORKING
   - Supported Authentication Methods:
     - ✅ Email + Password (Entra External ID native)
     - ✅ Google Sign-In (OAuth 2.0 federation)
     - ✅ Facebook Sign-In (OAuth 2.0 federation)
   - Features:
     - OAuth 2.0 token validation using Entra External ID ciamlogin.com domain
     - Content-Type: application/json headers (Entra requirement)
     - Extension attribute handling (GUID-prefixed custom attributes)
     - Multiple date format support (MM/DD/YYYY, MMDDYYYY, YYYY-MM-DD)
     - Privacy-focused (birthdate not stored, only age_verified boolean)
     - Cryptographic token verification (no secrets stored)
     - Works seamlessly with all authentication methods
   - Status: ✅ Deployed, tested, and FULLY OPERATIONAL
   - Test Results (2025-10-26 to 2025-10-27):
     - ✅ OAuth token validation successful (ciamlogin.com JWKS)
     - ✅ Under-21 users successfully BLOCKED
     - ✅ 21+ users successfully ALLOWED and accounts created
     - ✅ All responses include proper Content-Type headers
     - ✅ Security hardening complete
     - ✅ Email signup working
     - ✅ Google sign-in working with age verification
     - ✅ Facebook sign-in working with age verification
     - ✅ Execution time: ~376ms

8. ✅ **POST /api/v1/vision/analyze**

   - Azure Computer Vision integration for bottle identification
   - Analyzes images to detect alcohol brands and types
   - Matches detected items against ingredient database
   - Returns confidence scores and structured detection results
   - Requires: Function key
   - Status: ✅ Deployed and operational
   - Azure Computer Vision Service: `cv-mba-prod` (F0 free tier, South Central US)
   - Features:
     - Base64 and URL image input support
     - Tags, Description, Objects, and Brands detection
     - Automatic brand name matching (23 common spirits/liqueurs)
     - Confidence scoring for each detection
     - Integration with Azure Key Vault for credentials
   - Test Status: Ready for physical device testing
   - Deployed: 2025-11-03

9. ✅ **GET /api/v1/speech/token**

   - Azure Speech Services token endpoint for voice features
   - Returns ephemeral tokens (10 minutes) for client-side speech processing
   - Requires: Function key
   - Status: ✅ Deployed and operational
   - Azure Speech Services: `speech-mba-prod` (F0 free tier, South Central US)
   - Features:
     - Token exchange (API key → ephemeral token)
     - No API key exposed to mobile clients

10. ✅ **POST /api/v1/create-studio/refine**

   - AI-powered cocktail recipe refinement using Azure OpenAI (gpt-4o-mini)
   - Analyzes custom cocktail recipes and provides professional feedback
   - Returns structured suggestions with priority levels (high/medium/low)
   - Generates refined recipe with improved name, ingredients, and instructions
   - Requires: Function key
   - Status: ✅ Deployed and operational
   - Azure OpenAI Service: `mybartenderai-scus` (South Central US)
   - Features:
     - Professional mixologist feedback
     - Ingredient balance analysis
     - Technique and instruction improvements
     - Glass type recommendations
     - Category classification verification
     - JSON response format for easy UI integration
     - Structured suggestions (name, ingredients, instructions, glass, balance)
   - Deployed: 2025-11-03
     - Client-side Speech-to-Text and Text-to-Speech
     - 93% cost savings vs OpenAI Realtime API
     - Integration with Azure Key Vault for credentials
   - Deployed: 2025-11-03
   - Cost: FREE (5 hours/month on F0 tier)

### Flutter Mobile App Integration

**Status:** ✅ Successfully Connected to Azure Backend

#### Completed Components (2025-10-29)

1. ✅ **Design System**
   
   - Complete color palette matching UI mockups (dark theme with purple/navy backgrounds)
   - Typography system with 30+ text styles
   - Spacing system based on 4px grid
   - Reusable component library (FeatureCard, AppBadge, SectionHeader, RecipeCard, CompactRecipeCard)
   - Files: `mobile/app/lib/src/theme/*` and `mobile/app/lib/src/widgets/*`

2. ✅ **Home Screen**
   
   - Rebuilt to match design mockups exactly
   - App header with branding and user level badges
   - AI Cocktail Concierge section with voice and create buttons
   - Lounge Essentials grid (Smart Scanner, Recipe Vault, My Bar, Taste Profile)
   - Master Mixologist section with Elite features
   - Today's Special recommendation card with daily rotation + cocktail detail shortcut
   - File: `mobile/app/lib/src/features/home/home_screen.dart`

3. ✅ **Backend Connection**
   
   - Backend service configured with Dio HTTP client
   - Riverpod providers for state management
   - Successfully connecting to `https://func-mba-fresh.azurewebsites.net/api`
   - Fetching cocktail snapshot data (621 drinks)
   - Backend status indicator (for development)
   - Files: `mobile/app/lib/src/services/backend_service.dart`, `mobile/app/lib/src/providers/backend_provider.dart`

4. ✅ **Backend API Fix**
   
   - Fixed Content-Type header issue in `/api/v1/snapshots/latest` endpoint
   - Now properly returns `application/json` instead of `text/plain`
   - Deployed to Azure Function App

5. ✅ **Recipe Vault (2025-10-29)**
   
   - Full cocktail database browsing with grid view
   - Real-time search functionality
   - Category and alcoholic filters
   - "Can Make" filter based on user inventory
   - Snapshot sync with progress indicator
   - Cocktail detail screen with ingredients, instructions, metadata
   - Quick-add ingredients to inventory from detail screen
   - Files: `mobile/app/lib/src/features/recipe_vault/*`

6. ✅ **Inventory Management - My Bar (2025-10-29)**
   
   - User ingredient tracking with local SQLite storage
   - Add ingredients screen with search
   - Delete ingredients with confirmation
   - Ingredient count display
   - Notes support for each ingredient
   - Integration with Recipe Vault "Can Make" filter
   - Quick-add from cocktail detail screens
   - Files: `mobile/app/lib/src/features/my_bar/*`, `mobile/app/lib/src/providers/inventory_provider.dart`

7. ✅ **Offline-First Database (2025-10-29)**
   
   - SQLite database with sqflite
   - Zstandard compression/decompression for snapshots
   - PRAGMA user_version for database versioning
   - Automatic snapshot download and extraction
   - Local cocktail queries with filters
   - Files: `mobile/app/lib/src/services/database_service.dart`, `mobile/app/lib/src/providers/cocktail_provider.dart`

8. ✅ **AI Bartender Chat UI (2025-10-31)**

   - Complete chat interface with message history
   - Typing indicator during AI responses
   - Quick action buttons for common questions
   - Conversation persistence with conversationId tracking
   - User inventory integration for personalized recommendations
   - Function-level authentication with function keys
   - Backend conversation ID generation and tracking
   - Error handling with user-friendly messages
   - GoRouter integration for navigation
   - Files:
     - `mobile/app/lib/src/features/ask_bartender/chat_screen.dart`
     - `mobile/app/lib/src/api/ask_bartender_api.dart`
     - `apps/backend/v3-deploy/ask-bartender-simple/index.js`

9. ✅ **Smart Scanner - Camera Inventory (2025-11-03)**

   - Azure Computer Vision integration for bottle recognition
   - Camera and gallery image selection
   - Real-time image analysis with confidence scores
   - Automatic ingredient matching against database
   - Manual selection/deselection of detected items
   - Integration with My Bar inventory system
   - Backend vision-analyze endpoint
   - Complete UI with image preview and results display
   - Error handling and user feedback
   - Azure Resources:
     - Azure Computer Vision: `cv-mba-prod` (F0 free tier, South Central US)
     - Key Vault secrets: AZURE-CV-KEY, AZURE-CV-ENDPOINT
   - Files:
     - Backend: `apps/backend/v3-deploy/vision-analyze/index.js`
     - Mobile API: `mobile/app/lib/src/api/vision_api.dart`
     - Mobile UI: `mobile/app/lib/src/features/smart_scanner/smart_scanner_screen.dart`
     - Mobile Provider: `mobile/app/lib/src/providers/vision_provider.dart`
   - Dependencies Added:
     - `image_picker: ^1.0.8` - Camera and gallery access
     - `image: ^4.2.0` - Image handling and processing
     - `axios` - Backend HTTP client for Computer Vision API
   - Permissions Added:
     - Android: CAMERA, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE
     - iOS: NSCameraUsageDescription, NSPhotoLibraryUsageDescription
   - Status: ✅ Fully implemented and deployed (requires physical device for full camera testing)

10. ✅ **Voice Bartender - Azure Speech Services (2025-11-03)**

   - Azure Speech Services integration for voice interaction
   - Client-side Speech-to-Text and Text-to-Speech processing
   - Real-time transcription during voice input
   - AI response with natural voice playback
   - Conversation history with visual chat bubbles
   - Integration with existing ask-bartender backend
   - Inventory-aware voice responses
   - Backend speech-token endpoint for secure token exchange
   - Azure Resources:
     - Azure Speech Services: `speech-mba-prod` (F0 free tier, South Central US)
     - Key Vault secrets: AZURE-SPEECH-KEY, AZURE-SPEECH-REGION
   - Files:
     - Backend: `apps/backend/v3-deploy/speech-token/index.js`
     - Mobile Services: `mobile/app/lib/src/services/speech_service.dart`, `mobile/app/lib/src/services/tts_service.dart`
     - Mobile UI: `mobile/app/lib/src/features/voice_bartender/voice_bartender_screen.dart`
     - Mobile Provider: `mobile/app/lib/src/providers/voice_provider.dart`
   - Dependencies Added:
     - `speech_to_text: ^7.0.0` - Device speech recognition
     - `flutter_tts: ^4.2.0` - Device text-to-speech
   - Dependencies Removed (cost optimization):
     - `flutter_webrtc`, `record`, `audioplayers`, `web_socket_channel` (OpenAI Realtime API)
   - Permissions: Microphone access (already configured)
   - Architecture: Client-side speech processing → Text API → Client-side TTS
   - Cost Savings: 93% vs OpenAI Realtime API (~$0.10 vs ~$1.50 per 5-min session)
   - Status: ✅ Fully implemented and deployed (UI ready, requires microphone permission for testing)

11. ✅ **Create Studio - Custom Cocktail Creation (2025-11-03)**

   - Full-featured cocktail creation with AI-powered refinement
   - Complete form with name, category, glass, instructions, ingredients
   - Dynamic ingredient list with add/remove capabilities
   - AI recipe refinement using GPT-4o-mini
   - Custom cocktail storage in local SQLite database
   - Integration with Recipe Vault (custom cocktails shown with badge)
   - Edit and delete custom cocktails
   - Professional UI with validation and error handling
   - Backend refine-cocktail endpoint for AI suggestions
   - Azure Resources:
     - Azure OpenAI: `mybartenderai-scus` (South Central US, gpt-4o-mini)
     - Key Vault secrets: AZURE-OPENAI-API-KEY, AZURE-OPENAI-ENDPOINT
   - Files:
     - Backend: `apps/backend/v3-deploy/refine-cocktail/index.js`
     - Mobile API: `mobile/app/lib/src/api/create_studio_api.dart`
     - Mobile UI: `mobile/app/lib/src/features/create_studio/create_studio_screen.dart`, `edit_cocktail_screen.dart`
     - Mobile Widgets: `widgets/ingredient_list.dart`, `widgets/refinement_dialog.dart`
     - Mobile Provider: `mobile/app/lib/src/providers/custom_cocktails_provider.dart`
     - Database Methods: Added to `database_service.dart` (getCustomCocktails, updateCustomCocktail, deleteCustomCocktail)
   - Dependencies Added:
     - `uuid: ^4.5.1` - UUID generation for custom cocktail IDs
   - Features:
     - Create custom cocktails with full details
     - AI refinement with prioritized suggestions (high/medium/low)
     - Edit existing custom cocktails
     - Delete custom cocktails with confirmation
     - Custom badge display in Recipe Vault
     - Ingredient management with measures
     - Category, glass type, and alcoholic type dropdowns
     - Multi-line instructions field
     - Navigation from home screen "Create" button
   - Status: ✅ Fully implemented and deployed

12. ✅ **Entra External ID Authentication Integration (2025-11-03)**

   - Full authentication flow integrated throughout mobile app
   - GoRouter with authentication guards and automatic redirects
   - JWT token management with automatic refresh
   - Secure token storage with flutter_secure_storage
   - User profile screen with account management
   - Profile navigation from home screen header
   - Sign-out with confirmation dialog
   - Age verification status display
   - Token injection in all API calls via Dio interceptors
   - Support for Email, Google, and Facebook authentication
   - Files:
     - Auth Services: `mobile/app/lib/src/services/auth_service.dart`, `token_storage_service.dart`
     - Auth Models: `mobile/app/lib/src/models/user.dart`, `auth_state.dart`
     - Auth Config: `mobile/app/lib/src/config/auth_config.dart`
     - Auth Providers: `mobile/app/lib/src/providers/auth_provider.dart`
     - Router: `mobile/app/lib/main.dart` (GoRouter with auth guards)
     - Backend Service: `mobile/app/lib/src/services/backend_service.dart` (JWT injection)
     - Profile UI: `mobile/app/lib/src/features/profile/profile_screen.dart`
     - Login UI: `mobile/app/lib/src/features/auth/login_screen.dart`
     - Android Config: `mobile/app/android/app/build.gradle.kts` (OAuth redirect scheme)
   - Dependencies Added:
     - `flutter_appauth: ^7.0.0` - OAuth 2.0 / OpenID Connect client
     - `flutter_secure_storage: ^9.2.2` - Encrypted token storage
     - `jwt_decoder: ^2.0.1` - JWT token parsing
   - Android Configuration:
     - OAuth redirect scheme: `com.mybartenderai.app`
     - Manifest intent filter for OAuth callbacks
     - Build configuration with manifest placeholders
   - Status: ✅ Fully integrated and ready for device testing

13. ✅ **Release APK Build (2025-11-03)**

   - Successfully built release APK for sideloading
   - File: `mobile/app/build/app/outputs/flutter-apk/app-release.apk`
   - Size: 51.5MB
   - Build Configuration:
     - Debug-signed (suitable for testing, not Play Store)
     - Target SDK: Flutter's default
     - Min SDK: Flutter's default
     - OAuth redirect scheme configured
   - Resolved Build Issues:
     - Created missing `providers.dart` barrel export file
     - Fixed `databaseProvider` → `databaseServiceProvider` references
     - Fixed `askBartender()` → `ask()` API method call
     - Fixed `state.location` → `state.matchedLocation` in GoRouter
     - Fixed `CachedCocktailImage` widget parameters
     - Fixed `Iterable.asMap()` → `List.asMap()` conversion
     - Added OAuth redirect scheme manifest placeholder
   - Installation: Ready for sideloading on Android devices via USB, cloud storage, or email
   - Status: ✅ Build successful, ready for testing

#### Pending Work
- 📋 AI-powered cocktail recommendations with JWT authentication (backend endpoint deployed, mobile integration pending)
- 📋 Taste profile preferences (UI design pending)
- 📋 Play Store release signing configuration
- 📋 iOS build and TestFlight deployment

### Deployment Journey

#### Phase 1: v4 Migration Attempt (func-cocktaildb2 - Flex Consumption)

- Attempted to migrate to Azure Functions v4 SDK for Flex Consumption plan
- Resolved initial issues:
  - Fixed GitHub Actions to deploy correct folder
  - Implemented lazy initialization for services using Key Vault references
  - Fixed import paths and removed v3 artifacts
- Result: Functions briefly worked but subsequent deployments failed with "0 functions loaded"

#### Phase 2: Revert to Windows Consumption (func-mba-fresh)

- Created new Windows Consumption plan function app
- Discovered that Windows Consumption with runtime v4 requires v3 SDK patterns
- Key fixes:
  - Each function needs `function.json` with bindings
  - Use `module.exports = async function(context, req)` pattern
  - Output binding name must match code usage (res vs $return)

#### Phase 3: Azure OpenAI Migration (2025-10-31)

- **Problem**: Azure OpenAI service was in East US while all other resources were in South Central US
- **Solution**: Created new Azure OpenAI service in South Central US for better co-location
- **Actions taken**:
  1. Created `mybartenderai-scus` Azure OpenAI service in South Central US
  2. Deployed gpt-4o-mini model with 100 TPM capacity
  3. Created new Key Vault secret: `AZURE-OPENAI-API-KEY`
  4. Updated Key Vault secret: `AZURE-OPENAI-ENDPOINT` to point to new service
  5. Granted Function App Managed Identity "Key Vault Secrets User" role via RBAC
  6. Fixed OpenAI Node.js SDK configuration for Azure OpenAI compatibility
  7. Updated `ask-bartender-simple` endpoint with proper Azure OpenAI configuration
  8. Updated mobile app to use `/api/v1/ask-bartender-simple` endpoint
  9. Deleted old East US OpenAI service
- **Key Fix**: The issue was with OpenAI SDK configuration - needed to set:
  - `baseURL`: `${endpoint}/openai/deployments/${deployment}`
  - `defaultQuery`: `{ 'api-version': '2024-10-21' }`
  - `defaultHeaders`: `{ 'api-key': apiKey }`
- **Result**: AI Bartender chat now fully operational with Azure OpenAI in South Central US

### Key Learnings

1. **Azure Functions Runtime vs SDK Versions**:
   
   - Runtime v4 (`FUNCTIONS_EXTENSION_VERSION=~4`) can run both v3 and v4 SDK code
   - Windows Consumption plans work best with v3 SDK patterns
   - Linux Flex Consumption plans require v4 SDK patterns

2. **v3 SDK Pattern Requirements**:
   
   - Each function needs a `function.json` file with bindings
   - Function code uses `module.exports = async function(context, req)`
   - Response is set via `context.res = { status, body }`
   - Output binding name in function.json must match code (e.g., "res" not "$return")

3. **Deployment Best Practices**:
   
   - Use `az functionapp deployment source config-zip` for reliable deployments
   - Avoid "dirty deployment" issues from residual files
   - Test functions work locally before deploying

### Next Steps

1. **Convert remaining functions to v3 pattern**:
   
   - [ ] recommend function
   - [ ] sync-cocktaildb function  
   - [ ] download-images function

2. **Test complete API functionality**:
   
   - [ ] Test JWT authentication on recommend endpoint
   - [ ] Verify timer trigger for sync-cocktaildb
   - [ ] Test image download capabilities

3. **Production readiness**:
   
   - [ ] Set up proper CI/CD pipeline
   - [ ] Configure monitoring and alerts
   - [ ] Document API endpoints for mobile team

### Environment Configuration

Function App: `func-mba-fresh`

- **Plan**: Windows Consumption
- **Runtime**: Node.js 20 LTS (will be retired by Microsoft 04/2026, must move to 22 LTS)
- **Functions Runtime**: ~4
- **Location**: South Central US

Key Settings:

- `BLOB_STORAGE_CONNECTION_STRING`: ✅ Configured
- `PG_CONNECTION_STRING`: ✅ Configured
- `SNAPSHOT_CONTAINER_NAME`: ✅ Set to "snapshots"
- `OPENAI_API_KEY`: ✅ Configured (Key Vault: AZURE-OPENAI-API-KEY)
- `AZURE_OPENAI_ENDPOINT`: ✅ Configured (Key Vault: AZURE-OPENAI-ENDPOINT)
- `AZURE_OPENAI_DEPLOYMENT`: ✅ Set to "gpt-4o-mini"
- `COCKTAILDB-API-KEY`: ✅ Configured

Azure OpenAI Configuration:

- **Service Name**: `mybartenderai-scus`
- **Location**: South Central US
- **Model Deployment**: gpt-4o-mini
- **Capacity**: 100 Tokens Per Minute (TPM)
- **API Version**: 2024-10-21
- **Key Vault Integration**: Managed Identity with RBAC (Key Vault Secrets User role)

### Deployment Commands

```bash
# From apps/backend/v3-deploy directory
func azure functionapp publish func-mba-fresh --javascript

# Or using zip deployment
az functionapp deployment source config-zip -g rg-mba-prod -n func-mba-fresh --src deployment.zip
```

### Resources

- [Azure Functions v3 to v4 Migration](https://learn.microsoft.com/en-us/azure/azure-functions/functions-node-upgrade-v4)
- [Azure Functions Hosting Plans](https://learn.microsoft.com/en-us/azure/azure-functions/functions-scale)
- [Function.json Reference](https://learn.microsoft.com/en-us/azure/azure-functions/functions-bindings-http-webhook-trigger?tabs=javascript)
