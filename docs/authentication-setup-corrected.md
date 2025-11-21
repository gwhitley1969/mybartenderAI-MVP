# MyBartenderAI Authentication Setup

## Current Status

The backend functions (`func-mba-fresh`) are deployed and operational behind Azure API Management (`apim-mba-001`). Authentication is handled in two layers:

1. **APIM Layer**: API subscription keys for tier-based access control
2. **Function Layer**: JWT validation via Azure AD B2C (Entra External ID) for user identity

## Temporary Solution for Testing

We've created test endpoints that bypass JWT authentication:
- `/v1/ask-bartender-test` - No JWT required, still requires APIM subscription key
- `/v1/ask-bartender-simple` - Simplified version for testing
- `/v1/realtime-token-test` - Legacy endpoint (will be replaced by Azure Speech)

## Authentication Architecture

### Layer 1: APIM Subscription Keys
**Purpose**: Tier-based access control (Free/Premium/Pro)

**How it works**:
1. User signs up for MyBartenderAI
2. Backend provisions APIM subscription key based on tier
3. Mobile app stores subscription key securely
4. All API calls include: `Ocp-Apim-Subscription-Key: <key>` header

**APIM validates**:
- Valid subscription key
- Subscription is active (not expired/revoked)
- Rate limits per tier (100/day Free, 1000/day Premium, Unlimited Pro)
- Product access (Free tier blocked from Premium endpoints)

### Layer 2: JWT Tokens (User Identity)
**Purpose**: User authentication and authorization

**How it works**:
1. User logs in via Azure AD B2C (social or email/password)
2. B2C returns JWT token with user claims
3. APIM validates JWT signature and expiry
4. Function receives validated user ID in headers

## Azure AD B2C Setup Required

### 1. Configure Azure Function App

Add these environment variables to `func-mba-fresh`:

```bash
# Your B2C tenant name (e.g., "mybartenderai")
ENTRA_TENANT_ID=<your-b2c-tenant-name>.onmicrosoft.com

# The Application (client) ID from your B2C app registration
ENTRA_EXPECTED_AUDIENCE=<your-b2c-app-client-id>

# The B2C issuer URL
ENTRA_ISSUER=https://<your-b2c-tenant-name>.b2clogin.com/<your-b2c-tenant-name>.onmicrosoft.com/<your-sign-in-policy>/v2.0
```

**Example configuration**:
```bash
az functionapp config appsettings set \
  -n func-mba-fresh \
  -g rg-mba-prod \
  --settings \
    "ENTRA_TENANT_ID=mybartenderai.onmicrosoft.com" \
    "ENTRA_EXPECTED_AUDIENCE=12345678-1234-1234-1234-123456789012" \
    "ENTRA_ISSUER=https://mybartenderai.b2clogin.com/mybartenderai.onmicrosoft.com/B2C_1_signupsignin/v2.0"
```

### 2. Configure APIM JWT Validation Policy

In APIM (`apim-mba-001`), add JWT validation to all protected endpoints:

```xml
<policies>
  <inbound>
    <!-- Validate JWT token -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
      <openid-config url="https://<tenant>.b2clogin.com/<tenant>.onmicrosoft.com/<policy>/v2.0/.well-known/openid-configuration" />
      <audiences>
        <audience><client-id></audience>
      </audiences>
      <issuers>
        <issuer>https://<tenant>.b2clogin.com/<tenant-id>/v2.0/</issuer>
      </issuers>
    </validate-jwt>
    
    <!-- Validate subscription key -->
    <check-header name="Ocp-Apim-Subscription-Key" failed-check-httpcode="401" failed-check-error-message="Missing subscription key" />
    
    <!-- Rate limiting by tier -->
    <choose>
      <when condition="@(context.Subscription.Name == 'Free')">
        <rate-limit calls="100" renewal-period="86400" />
      </when>
      <when condition="@(context.Subscription.Name == 'Premium')">
        <rate-limit calls="1000" renewal-period="86400" />
      </when>
      <!-- Pro tier: unlimited -->
    </choose>
    
    <!-- Forward user ID to backend -->
    <set-header name="X-User-Id" exists-action="override">
      <value>@(context.Request.Headers.GetValueOrDefault("Authorization","").AsJwt()?.Subject)</value>
    </set-header>
  </inbound>
</policies>
```

### 3. Flutter App Authentication Flow

#### Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter_appauth: ^6.0.2
  flutter_secure_storage: ^9.0.0
  dio: ^5.4.0
```

#### Configure B2C Settings
```dart
// lib/src/config/auth_config.dart
class AuthConfig {
  static const String b2cTenant = 'mybartenderai';
  static const String clientId = '<your-b2c-app-client-id>';
  static const String redirectUri = 'com.mybartenderai.app://auth';
  static const String signInPolicy = 'B2C_1_signupsignin';
  
  static String get authority =>
      'https://$b2cTenant.b2clogin.com/$b2cTenant.onmicrosoft.com/$signInPolicy';
  
  static String get discoveryUrl =>
      '$authority/v2.0/.well-known/openid-configuration';
}
```

#### Implement Authentication Service
```dart
// lib/src/services/auth_service.dart
class AuthService {
  final FlutterAppAuth _appAuth = FlutterAppAuth();
  final FlutterSecureStorage _storage = FlutterSecureStorage();
  
  Future<AuthResult> signIn() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AuthConfig.clientId,
          AuthConfig.redirectUri,
          discoveryUrl: AuthConfig.discoveryUrl,
          scopes: ['openid', 'profile', 'email'],
          // Leave offline_access out; MSAL acquires refresh tokens without it.
        ),
      );
      
      if (result != null) {
        await _storeTokens(result);
        return AuthResult.success(result.idToken!);
      }
      return AuthResult.failed('Login cancelled');
    } catch (e) {
      return AuthResult.failed(e.toString());
    }
  }
  
  Future<void> _storeTokens(TokenResponse response) async {
    await _storage.write(key: 'id_token', value: response.idToken);
    await _storage.write(key: 'access_token', value: response.accessToken);
    await _storage.write(key: 'refresh_token', value: response.refreshToken);
  }
  
  Future<String?> getIdToken() async {
    return await _storage.read(key: 'id_token');
  }
  
  Future<void> signOut() async {
    await _storage.deleteAll();
  }
}
```

#### Update API Client with Authentication
```dart
// lib/src/api/api_client.dart
class ApiClient {
  final Dio _dio;
  final AuthService _authService;
  
  ApiClient(this._authService) : _dio = Dio(
    BaseOptions(
      baseURL: 'https://apim-mba-001.azure-api.net/api',
    ),
  ) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add APIM subscription key
        options.headers['Ocp-Apim-Subscription-Key'] = await _getSubscriptionKey();
        
        // Add JWT token
        final idToken = await _authService.getIdToken();
        if (idToken != null) {
          options.headers['Authorization'] = 'Bearer $idToken';
        }
        
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 - token expired, try refresh
        if (error.response?.statusCode == 401) {
          // Attempt token refresh
          await _authService.refreshToken();
          
          // Retry original request
          final opts = error.requestOptions;
          final idToken = await _authService.getIdToken();
          opts.headers['Authorization'] = 'Bearer $idToken';
          
          try {
            final response = await _dio.fetch(opts);
            handler.resolve(response);
          } catch (e) {
            handler.reject(e as DioException);
          }
        } else {
          handler.next(error);
        }
      },
    ));
  }
  
  Future<String> _getSubscriptionKey() async {
    // Retrieve from secure storage
    // This is provisioned during signup based on tier
    final storage = FlutterSecureStorage();
    return await storage.read(key: 'apim_subscription_key') ?? '';
  }
}
```

## User Signup Flow

### Backend Endpoint: POST /v1/auth/register
```javascript
// Function: register-user
module.exports = async function (context, req) {
  const { email, tier } = req.body;
  
  // 1. Create user in database
  const userId = await createUser(email, tier);
  
  // 2. Provision APIM subscription
  const subscriptionKey = await provisionAPIMSubscription(userId, tier);
  
  // 3. Return subscription key to mobile app
  context.res = {
    status: 200,
    body: {
      userId,
      subscriptionKey,
      tier
    }
  };
};
```

### APIM Subscription Provisioning
```javascript
// Provision APIM subscription for new user
async function provisionAPIMSubscription(userId, tier) {
  const client = new ApiManagementClient(credentials, subscriptionId);
  
  // Map tier to APIM product
  const productId = {
    'free': 'free-tier',
    'premium': 'premium-tier',
    'pro': 'pro-tier'
  }[tier];
  
  // Create subscription
  const subscription = await client.subscription.createOrUpdate(
    'rg-mba-prod',
    'apim-mba-001',
    `user-${userId}`,
    {
      displayName: `User ${userId} - ${tier}`,
      scope: `/products/${productId}`,
      state: 'active'
    }
  );
  
  return subscription.primaryKey;
}
```

## Testing Without Full Authentication

### For Development/Testing
Use the test endpoints that bypass JWT:
- Base URL: `https://apim-mba-001.azure-api.net/api`
- Required header: `Ocp-Apim-Subscription-Key: <test-key>`
- Test endpoints: `/v1/ask-bartender-test`, `/v1/snapshots/latest`

### Get Test APIM Subscription Key
1. Navigate to APIM Developer Portal: https://apim-mba-001.developer.azure-api.net
2. Sign in with Azure account
3. Go to "Products" → "Free Tier"
4. Subscribe and copy the subscription key

## Next Steps

### 1. Create Azure AD B2C Tenant
```bash
# Create B2C tenant
az ad b2c tenant create \
  --resource-name mybartenderai \
  --location "United States" \
  --display-name "MyBartenderAI"
```

### 2. Register Mobile App
1. Go to Azure AD B2C → App registrations
2. Create new registration:
   - Name: MyBartenderAI Mobile
   - Redirect URI: `com.mybartenderai.app://auth`
   - Platform: Public client/native
3. Copy Application (client) ID

### 3. Configure User Flows
Create sign-in/sign-up user flow:
- Name: B2C_1_signupsignin
- Identity providers: Email, Google, Microsoft
- User attributes: Email, Display name
- Application claims: User ID, Email, Display name

### 4. Update Configuration
- Add B2C settings to Function App
- Add JWT validation policy to APIM
- Configure Flutter app with B2C client ID

### 5. Test End-to-End
1. Mobile app: Sign in with B2C
2. Retrieve JWT token
3. Call protected endpoint via APIM
4. Verify user ID forwarded to Function
5. Verify rate limiting works per tier

## Troubleshooting

### Common Issues

**401 Unauthorized from APIM**:
- Check subscription key is valid and not expired
- Verify subscription is active
- Check tier has access to the endpoint

**JWT validation fails**:
- Verify B2C configuration in APIM policy
- Check token hasn't expired
- Verify audience matches client ID

**Rate limit exceeded (429)**:
- Check current tier's rate limit
- Upgrade tier if needed
- Wait for renewal period

## Security Best Practices

1. **Never hardcode keys**: Use secure storage for subscription keys
2. **Token refresh**: Implement automatic JWT refresh before expiry
3. **Logout**: Clear all tokens and keys from secure storage
4. **HTTPS only**: All communication over HTTPS
5. **Certificate pinning**: Consider for production
6. **Key rotation**: APIM subscription keys can be regenerated if compromised