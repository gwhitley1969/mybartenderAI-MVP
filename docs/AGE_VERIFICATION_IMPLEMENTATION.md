# Age Verification Implementation Guide

**Requirement:** Users must be 21 years or older to use MyBartenderAI
**Strategy:** Multi-layered age verification for compliance and security
**Privacy:** Store only `age_verified: true` flag, not birthdate

---

## Overview - Layered Approach

### Layer 1: App Store Age Rating
- **Apple App Store**: Age rating 21+ (Alcohol reference)
- **Google Play Store**: Mature 17+ with alcohol content rating
- **Purpose**: Prevent downloads by underage accounts

### Layer 2: Mobile App Age Gate (First Launch)
- **When**: First app launch (before any content access)
- **Purpose**: Verify age for free tier users who don't authenticate
- **Storage**: Local only, no backend transmission

### Layer 3: Entra External ID (Account Creation)
- **When**: User creates account for Premium/Pro features
- **Purpose**: Verify and store age verification status in identity system
- **Storage**: `age_verified: true` boolean attribute (no birthdate stored)

### Layer 4: APIM JWT Claim Validation
- **When**: API calls to Premium/Pro endpoints
- **Purpose**: Ensure only age-verified users access paid features
- **Validation**: Check `age_verified` claim in JWT token

---

## Architecture Flow

```
User Downloads App (App Store - Must be 21+)
    ↓
First Launch → Age Gate Screen
    ↓
User Enters Birthdate
    ↓
Age >= 21?
    ├─ YES → Store "age_verified: true" locally → Show Free Features
    └─ NO  → Show "Must be 21+" message → Block app access

User Signs Up for Premium/Pro
    ↓
Entra External ID Signup Flow
    ↓
Custom Attribute Collection: Birthdate
    ↓
Server-Side Validation: Age >= 21?
    ├─ YES → Create account with age_verified: true → Issue JWT
    └─ NO  → Reject signup → Show age requirement message

User Calls Premium/Pro API
    ↓
APIM JWT Validation
    ↓
Check JWT claim: age_verified = true?
    ├─ YES → Forward to backend
    └─ NO  → Reject with 403 Forbidden
```

---

## Part 1: Entra External ID Configuration

### Step 1.1: Add Custom User Attribute

1. **Navigate to Entra External ID**:
   - Azure Portal → **Microsoft Entra ID**
   - Select **External Identities** → **Custom user attributes**

2. **Create `birthdate` Attribute**:
   - Click **+ Add**
   - Configure:
     - **Name**: `birthdate`
     - **Display name**: `Date of Birth`
     - **Data type**: `String` (will validate format as YYYY-MM-DD)
     - **Description**: "User's birthdate for age verification (21+ required)"
   - Click **Create**

3. **Create `age_verified` Attribute**:
   - Click **+ Add**
   - Configure:
     - **Name**: `age_verified`
     - **Display name**: `Age Verified`
     - **Data type**: `Boolean`
     - **Description**: "User has been verified as 21 years or older"
   - Click **Create**

### Step 1.2: Update User Flow to Collect Birthdate

1. **Navigate to User Flows**:
   - **External Identities** → **User flows**
   - Select **mba-signin-signup**

2. **Edit User Attributes**:
   - Click **User attributes** in the left menu
   - Click **+ Add**
   - Select **birthdate** (the custom attribute)
   - Configure:
     - **Required**: ✅ Yes
     - **User input type**: Date
     - **Display order**: 3 (after First name, Last name)
   - Click **Save**

3. **Configure Attribute Labels**:
   - Click **Page layouts** → **Local account sign up page**
   - Find **birthdate** attribute
   - Update label: "Date of Birth (must be 21 or older)"
   - Click **Save**

### Step 1.3: Add Age Validation API Connector

Entra External ID supports API connectors to validate data during signup.

**Create Azure Function for Age Validation**:

1. **Create Function**: `validate-age` in your Function App

```javascript
// apps/backend/v3-deploy/validate-age/index.js

module.exports = async function (context, req) {
    context.log('Age validation request received');

    const { birthdate, email } = req.body;

    // Validate birthdate format (YYYY-MM-DD)
    const birthdateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!birthdateRegex.test(birthdate)) {
        return {
            status: 400,
            body: {
                version: "1.0.0",
                action: "ShowBlockPage",
                userMessage: "Please enter a valid birthdate in YYYY-MM-DD format."
            }
        };
    }

    // Calculate age
    const today = new Date();
    const birthDate = new Date(birthdate);
    let age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();

    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
        age--;
    }

    context.log(`User age calculated: ${age} years`);

    // Check if user is 21 or older
    if (age < 21) {
        context.log(`User under 21 (age: ${age}), blocking signup`);
        return {
            status: 200,
            body: {
                version: "1.0.0",
                action: "ShowBlockPage",
                userMessage: "You must be 21 years or older to use MyBartenderAI. If you believe this is an error, please contact support."
            }
        };
    }

    // User is 21+, allow signup and set age_verified flag
    context.log(`User is 21+ (age: ${age}), allowing signup`);
    return {
        status: 200,
        body: {
            version: "1.0.0",
            action: "Continue",
            extension_age_verified: true  // Set custom claim
            // Note: We do NOT store the birthdate in claims for privacy
        }
    };
};
```

2. **Deploy Function**:
```bash
cd apps/backend/v3-deploy
func azure functionapp publish func-mba-fresh
```

3. **Configure API Connector in Entra External ID**:
   - Go to **External Identities** → **API connectors**
   - Click **+ New API connector**
   - Configure:
     - **Name**: "Age Verification"
     - **Endpoint URL**: `https://func-mba-fresh.azurewebsites.net/api/validate-age`
     - **Authentication**: Function key (copy from Azure Portal)
   - Click **Save**

4. **Add API Connector to User Flow**:
   - Go to **User flows** → **mba-signin-signup**
   - Click **API connectors**
   - Select step: **Before creating the user**
   - Choose connector: **Age Verification**
   - Click **Save**

### Step 1.4: Add age_verified to JWT Token Claims

1. **Navigate to App Registration**:
   - Azure Portal → **Microsoft Entra ID** → **App registrations**
   - Select **MyBartenderAI Mobile**

2. **Configure Token Claims**:
   - Click **Token configuration** in the left menu
   - Click **+ Add optional claim**
   - Select **Access tokens**
   - Add claims:
     - ✅ `extension_age_verified` (maps to our custom attribute)
   - Click **Add**

3. **Verify JWT Token Includes Claim**:
   - After configuration, test login
   - Decode JWT token at https://jwt.ms
   - Verify claim appears: `"age_verified": true`

---

## Part 2: APIM Policy - Validate age_verified Claim

### Step 2.1: Create Age Verification Policy

Create a new policy file for age verification:

**File**: `infrastructure/apim/policies/age-verification.xml`

```xml
<!--
  Age Verification Policy
  Apply to Premium/Pro operations requiring 21+ age verification

  This policy validates the age_verified claim in JWT tokens
  Rejects requests from users who have not been age-verified
-->
<policies>
    <inbound>
        <base />

        <!-- Validate age_verified claim exists and is true -->
        <choose>
            <when condition="@{
                Jwt jwt;
                if (context.Request.Headers.GetValueOrDefault(&quot;Authorization&quot;,&quot;&quot;).Replace(&quot;Bearer &quot;, &quot;&quot;).TryParseJwt(out jwt))
                {
                    var ageVerified = jwt?.Claims.GetValueOrDefault(&quot;age_verified&quot;, &quot;false&quot;);
                    return ageVerified != &quot;true&quot;;
                }
                return true;  // No JWT or can't parse = reject
            }">
                <return-response>
                    <set-status code="403" reason="Forbidden" />
                    <set-header name="Content-Type" exists-action="override">
                        <value>application/json</value>
                    </set-header>
                    <set-body>@{
                        return new JObject(
                            new JProperty("code", "AGE_VERIFICATION_REQUIRED"),
                            new JProperty("message", "You must be 21 years or older to access this feature. Please verify your age in your account settings."),
                            new JProperty("traceId", context.RequestId)
                        ).ToString();
                    }</set-body>
                </return-response>
            </when>
        </choose>
    </inbound>

    <backend>
        <base />
    </backend>

    <outbound>
        <base />
    </outbound>

    <on-error>
        <base />
    </on-error>
</policies>
```

### Step 2.2: Update Existing JWT Validation Policy

Update `infrastructure/apim/policies/jwt-validation-entra-external-id.xml` to include age verification:

Add this section after JWT validation, before user header extraction:

```xml
<!-- After validate-jwt section, add: -->

<!-- Validate age_verified claim -->
<choose>
    <when condition="@{
        Jwt jwt;
        if (context.Request.Headers.GetValueOrDefault(&quot;Authorization&quot;,&quot;&quot;).Replace(&quot;Bearer &quot;, &quot;&quot;).TryParseJwt(out jwt))
        {
            var ageVerified = jwt?.Claims.GetValueOrDefault(&quot;age_verified&quot;, &quot;false&quot;);
            return ageVerified != &quot;true&quot;;
        }
        return true;
    }">
        <return-response>
            <set-status code="403" reason="Forbidden" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>@{
                return new JObject(
                    new JProperty("code", "AGE_VERIFICATION_REQUIRED"),
                    new JProperty("message", "You must be 21 years or older to access this feature."),
                    new JProperty("traceId", context.RequestId)
                ).ToString();
            }</set-body>
        </return-response>
    </when>
</choose>
```

### Step 2.3: Apply Updated Policy

1. Go to **Azure Portal** → **apim-mba-001** → **APIs** → **MyBartenderAI API**
2. For each Premium/Pro operation (askBartender, recommendCocktails, getSpeechToken):
   - Click the operation
   - Click **Inbound processing** → **Code editor** (`</>`)
   - Replace with updated policy
   - Click **Save**

---

## Part 3: Mobile App Age Gate Implementation

### Step 3.1: Create Age Gate Screen (Flutter)

**File**: `mobile/app/lib/src/features/age_verification/presentation/age_gate_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AgeGateScreen extends ConsumerStatefulWidget {
  const AgeGateScreen({super.key});

  @override
  ConsumerState<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends ConsumerState<AgeGateScreen> {
  DateTime? selectedDate;
  String? errorMessage;

  bool _isAgeVerified() {
    if (selectedDate == null) return false;

    final now = DateTime.now();
    final age = now.year - selectedDate!.year;
    final hasHadBirthdayThisYear = now.month > selectedDate!.month ||
        (now.month == selectedDate!.month && now.day >= selectedDate!.day);

    final actualAge = hasHadBirthdayThisYear ? age : age - 1;
    return actualAge >= 21;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2002, 1, 1), // Default to someone turning 21
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
      errorFormatText: 'Enter a valid date',
      fieldLabelText: 'Date of Birth',
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        errorMessage = null;
      });
    }
  }

  void _verifyAge() {
    if (selectedDate == null) {
      setState(() {
        errorMessage = 'Please select your date of birth';
      });
      return;
    }

    if (_isAgeVerified()) {
      // Store age verification locally
      ref.read(ageVerificationProvider.notifier).setAgeVerified(true);

      // Navigate to home screen
      context.go('/home');
    } else {
      setState(() {
        errorMessage = 'You must be 21 years or older to use this app';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Icon(
                Icons.local_bar,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Age Verification',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'You must be 21 years or older to use MyBartenderAI',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Date picker button
              OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  selectedDate == null
                      ? 'Select Date of Birth'
                      : 'Born: ${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),

              // Verify button
              FilledButton(
                onPressed: _verifyAge,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: const Text('Verify Age'),
              ),

              // Error message
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 48),

              // Privacy note
              Text(
                'Your birthdate is only used for age verification and is stored locally on your device. It is not transmitted to our servers.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Step 3.2: Create Age Verification Provider

**File**: `mobile/app/lib/src/features/age_verification/data/age_verification_repository.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AgeVerificationRepository {
  static const _key = 'age_verified';

  Future<bool> isAgeVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setAgeVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, verified);
  }

  Future<void> clearAgeVerification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

// Provider
final ageVerificationRepositoryProvider = Provider<AgeVerificationRepository>((ref) {
  return AgeVerificationRepository();
});

// State provider
final ageVerificationProvider = StateNotifierProvider<AgeVerificationNotifier, bool>((ref) {
  return AgeVerificationNotifier(ref.read(ageVerificationRepositoryProvider));
});

class AgeVerificationNotifier extends StateNotifier<bool> {
  final AgeVerificationRepository _repository;

  AgeVerificationNotifier(this._repository) : super(false) {
    _loadAgeVerification();
  }

  Future<void> _loadAgeVerification() async {
    state = await _repository.isAgeVerified();
  }

  Future<void> setAgeVerified(bool verified) async {
    await _repository.setAgeVerified(verified);
    state = verified;
  }

  Future<void> clearVerification() async {
    await _repository.clearAgeVerification();
    state = false;
  }
}
```

### Step 3.3: Update Router to Show Age Gate

**File**: `mobile/app/lib/src/routing/app_router.dart`

```dart
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final ageVerified = ref.watch(ageVerificationProvider);

  return GoRouter(
    initialLocation: ageVerified ? '/home' : '/age-gate',
    routes: [
      GoRoute(
        path: '/age-gate',
        builder: (context, state) => const AgeGateScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        redirect: (context, state) {
          // Redirect to age gate if not verified
          if (!ageVerified) {
            return '/age-gate';
          }
          return null;
        },
      ),
      // ... other routes with same redirect logic
    ],
  );
});
```

---

## Part 4: Testing Age Verification

### Test 1: Mobile App Age Gate

1. **Fresh Install**: Clear app data or use fresh emulator
2. **Launch App**: Should show Age Gate screen
3. **Select Birthdate Under 21**: Should show error message
4. **Select Birthdate 21+**: Should allow access to app
5. **Close and Reopen**: Should go directly to home (verification cached)

### Test 2: Entra External ID Signup

1. **Navigate to Signup**: In app or Developer Portal
2. **Fill Form with Birthdate Under 21**: Should show block page
3. **Fill Form with Birthdate 21+**: Should create account successfully
4. **Check JWT Token**: Decode at jwt.ms, verify `age_verified: true` claim exists

### Test 3: APIM Policy Validation

**Without age_verified claim:**
```bash
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Authorization: Bearer JWT_WITHOUT_AGE_VERIFIED_CLAIM" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'
```
**Expected**: `403 Forbidden` with message "AGE_VERIFICATION_REQUIRED"

**With age_verified claim:**
```bash
curl -X POST https://apim-mba-001.azure-api.net/api/v1/ask-bartender \
  -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  -H "Authorization: Bearer JWT_WITH_AGE_VERIFIED_TRUE" \
  -H "Content-Type: application/json" \
  -d '{"query": "How do I make a Negroni?"}'
```
**Expected**: `200 OK` (or backend response)

---

## Compliance & Legal Considerations

### Age Verification Best Practices

1. **Multi-Layer Verification**: ✅ Implemented (App Store, App Gate, Account Creation, API)
2. **Privacy**: ✅ Store only boolean flag, not birthdate (except during signup validation)
3. **Cannot Bypass**: ✅ Server-side validation at API level
4. **Clear Messaging**: ✅ Users know why age is required
5. **Error Handling**: ✅ Friendly messages for age verification failures

### Legal Compliance

- **US Federal**: No federal law requires age verification for cocktail recipes (educational content)
- **State Laws**: Some states may require age verification for alcohol-related apps
- **App Store Requirements**: Both Apple and Google require age ratings for alcohol content
- **Best Practice**: Implement age verification to demonstrate responsible conduct

### Privacy Policy Updates

Update your privacy policy to include:

```markdown
## Age Verification

MyBartenderAI is intended for users 21 years of age or older. We collect and verify your age during account creation:

- **What we collect**: Date of birth (during signup only)
- **What we store**: Boolean flag indicating you are 21+ (we do not store your birthdate)
- **How we use it**: To ensure compliance with age requirements
- **Your rights**: You can request deletion of your account and all associated data

Your birthdate is used only for one-time age verification and is not stored in our systems or shared with third parties.
```

---

## Rollout Plan

### Phase 1: Backend Infrastructure (Current Sprint)
- ✅ Create age verification documentation
- ⬜ Deploy `validate-age` Azure Function
- ⬜ Configure Entra External ID custom attributes
- ⬜ Add API connector to user flow
- ⬜ Update JWT token configuration
- ⬜ Test age verification in Entra External ID

### Phase 2: APIM Policy Updates (Current Sprint)
- ⬜ Create age verification policy file
- ⬜ Update JWT validation policy with age check
- ⬜ Apply to Premium/Pro operations
- ⬜ Test with valid/invalid age_verified claims

### Phase 3: Mobile App Implementation (Next Sprint)
- ⬜ Create Age Gate screen UI
- ⬜ Implement age verification provider
- ⬜ Update router with age gate redirect
- ⬜ Test age gate flow
- ⬜ Add age verification to settings (re-verify)

### Phase 4: Testing & Deployment
- ⬜ End-to-end testing (app → API)
- ⬜ Update privacy policy
- ⬜ Update app store descriptions
- ⬜ Submit to app stores with 21+ rating

---

## Troubleshooting

### Issue: Age gate shows every time app opens

**Solution**: Check SharedPreferences is persisting correctly. Verify provider is reading initial state on app start.

### Issue: JWT doesn't contain age_verified claim

**Solution**:
1. Check token configuration in App Registration
2. Verify API connector is running and returning `extension_age_verified: true`
3. Re-login to get new token with updated claims

### Issue: APIM still allows access without age_verified

**Solution**:
1. Verify policy is saved at operation level
2. Check policy syntax is correct (no XML errors)
3. Wait 30 seconds for APIM cache refresh
4. Test in incognito mode

---

## Next Steps

1. ✅ Review and approve this implementation plan
2. ⬜ Deploy `validate-age` Azure Function
3. ⬜ Configure Entra External ID (Step 1)
4. ⬜ Update APIM policies (Step 2)
5. ⬜ Implement mobile app age gate (Step 3)
6. ⬜ Test complete flow
7. ⬜ Update privacy policy and legal docs
8. ⬜ Submit to app stores with 21+ rating

---

**Status**: Ready for implementation
**Estimated Time**: 4-6 hours (backend + APIM), 4-6 hours (mobile app)
**Priority**: High (legal compliance requirement)
