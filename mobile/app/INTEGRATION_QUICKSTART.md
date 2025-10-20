# Flutter App Integration Quick Start

**Backend URL**: `https://func-mba-fresh.azurewebsites.net/api`  
**Status**: ✅ Backend is live and operational

## Immediate Setup Steps

### 1. Update Environment Configuration

Create `lib/src/config/env_config.dart`:
```dart
class EnvConfig {
  static const String apiBaseUrl = 'https://func-mba-fresh.azurewebsites.net/api';
  static const String functionKey = ''; // Add your function key here for testing
}
```

**⚠️ Important**: Never commit function keys to Git. Use environment variables or secure storage for production.

### 2. Test Backend Connection

Run this test to verify connectivity:
```dart
// In your main.dart or a test file
import 'package:dio/dio.dart';

void testBackendConnection() async {
  final dio = Dio();
  
  try {
    // Test health endpoint (no auth required)
    final response = await dio.get('https://func-mba-fresh.azurewebsites.net/api/health');
    print('Health check: ${response.data}');
    
    // Test snapshot endpoint
    final snapshotResponse = await dio.get('https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest-mi');
    print('Snapshot available: ${snapshotResponse.data['snapshotVersion']}');
  } catch (e) {
    print('Error: $e');
  }
}
```

### 3. Available Endpoints for Testing

#### No Authentication Required:
- `GET /health` - Health check
- `GET /v1/snapshots/latest-mi` - Get snapshot metadata

#### Function Key Required:
Add header: `x-functions-key: YOUR_FUNCTION_KEY`
- `POST /v1/ask-bartender-simple` - Natural language queries
- `POST /v1/realtime/token-simple` - Get Realtime API token

### 4. Test Ask Bartender Feature

```dart
Future<void> testAskBartender() async {
  final dio = Dio();
  dio.options.headers['x-functions-key'] = 'YOUR_FUNCTION_KEY';
  
  final response = await dio.post(
    'https://func-mba-fresh.azurewebsites.net/api/v1/ask-bartender-simple',
    data: {
      'message': 'Suggest a refreshing gin cocktail',
      'context': {
        'preferences': {
          'favoriteSpirits': ['gin'],
          'flavorProfile': ['citrus', 'refreshing']
        }
      }
    },
  );
  
  print('Bartender says: ${response.data['response']}');
}
```

### 5. Download Cocktail Database

```dart
Future<void> downloadSnapshot() async {
  final dio = Dio();
  
  // 1. Get metadata
  final metadataResponse = await dio.get(
    'https://func-mba-fresh.azurewebsites.net/api/v1/snapshots/latest-mi'
  );
  
  final signedUrl = metadataResponse.data['signedUrl'];
  final sha256 = metadataResponse.data['sha256'];
  
  // 2. Download snapshot
  final downloadResponse = await dio.get(
    signedUrl,
    options: Options(responseType: ResponseType.bytes),
  );
  
  // 3. Verify and save
  // TODO: Implement SHA256 verification
  // TODO: Decompress and save to local database
  
  print('Downloaded ${downloadResponse.data.length} bytes');
}
```

### 6. Voice Feature Testing

```dart
Future<void> getRealtimeToken() async {
  final dio = Dio();
  dio.options.headers['x-functions-key'] = 'YOUR_FUNCTION_KEY';
  
  final response = await dio.post(
    'https://func-mba-fresh.azurewebsites.net/api/v1/realtime/token-simple',
    data: {},
  );
  
  final token = response.data['token'];
  print('Got Realtime API token: ${token.substring(0, 20)}...');
  
  // Use this token to connect to OpenAI Realtime WebSocket
  // wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01
}
```

## Current Backend Status

- ✅ **621 cocktails** in database
- ✅ **Snapshot size**: ~71KB (compressed)
- ✅ **Managed Identity** configured for secure storage access
- ✅ **User Delegation SAS** for temporary download URLs

## Common Issues & Solutions

### CORS Errors
The backend has CORS enabled for all origins. If you still get CORS errors:
1. Check if you're using the correct URL
2. Ensure you're not sending preflight-triggering headers
3. Use the simple endpoints (`-simple` suffix) for testing

### 401 Unauthorized
- Check that you're including the `x-functions-key` header
- Verify the function key is correct
- Some endpoints require admin keys (like download-images)

### 503 Service Unavailable
- This usually means no data is available
- Run the sync function to populate data
- Check Application Insights for errors

## Next Steps

1. **Test all endpoints** using the examples above
2. **Implement proper error handling** for network failures
3. **Set up secure key storage** (don't hardcode keys!)
4. **Build the offline database** functionality
5. **Implement the UI** according to the mockup

## Support

- Backend logs: Check Azure Application Insights
- API documentation: See `/spec/openapi.yaml`
- Architecture details: See `/docs/ARCHITECTURE.md`
