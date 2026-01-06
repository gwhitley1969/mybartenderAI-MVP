# Friends via Code - Flutter Implementation Plan

**Status**: Planning Phase
**Date**: November 15, 2025
**Approach**: Test APIs First → Plan Architecture → Implement UI

## Phase 1: Backend API Testing ✅

### Prerequisites

Before starting Flutter implementation, we need to:

1. **Obtain JWT Token from Entra External ID**
   - Use existing MSAL authentication in Flutter app
   - Extract JWT token from auth result
   - Verify token contains required claims (`sub`, `tier`/`subscription_tier`)

2. **Test All Endpoints**
   ```powershell
   .\test-friends-via-code-apis.ps1 -JwtToken "YOUR_JWT_TOKEN"
   ```

3. **Verify Rate Limiting**
   - Confirm 5 requests/minute limit works
   - Verify tier-based quotas (100/1000/5000 per day)
   - Test 429 error handling

### API Testing Checklist

- [ ] GET /v1/users/me (auto-create user profile)
- [ ] PATCH /v1/users/me (update display name)
- [ ] POST /v1/social/invite (create external share)
- [ ] GET /v1/social/invite/{token} (claim invite)
- [ ] POST /v1/social/share-internal (share by alias)
- [ ] GET /v1/social/inbox (view received shares)
- [ ] GET /v1/social/outbox (view sent shares)
- [ ] Test rate limiting (429 responses)
- [ ] Test quota exceeded (429 with quota error)

## Phase 2: Flutter Architecture Design

### Directory Structure

```
mobile/app/lib/src/
├── features/
│   └── friends_via_code/
│       ├── models/
│       │   ├── user_profile.dart
│       │   ├── recipe_share.dart
│       │   ├── share_invite.dart
│       │   └── share_status.dart
│       ├── providers/
│       │   ├── user_profile_provider.dart
│       │   ├── social_share_provider.dart
│       │   └── share_inbox_provider.dart
│       ├── services/
│       │   └── social_service.dart
│       ├── screens/
│       │   ├── user_profile_screen.dart
│       │   ├── share_recipe_screen.dart
│       │   ├── share_inbox_screen.dart
│       │   ├── share_outbox_screen.dart
│       │   └── invite_claim_screen.dart
│       └── widgets/
│           ├── user_alias_display.dart
│           ├── share_card.dart
│           ├── invite_link_card.dart
│           └── share_button.dart
├── services/
│   └── social_service.dart (HTTP client for APIs)
└── config/
    └── app_config.dart (add social API endpoints)
```

### Data Models

#### UserProfile Model
```dart
class UserProfile {
  final String userId;
  final String alias;
  final String? displayName;
  final DateTime createdAt;
  final DateTime lastSeen;

  // Constructor, fromJson, toJson, copyWith
}
```

#### RecipeShare Model
```dart
class RecipeShare {
  final String shareId;
  final String recipeId;
  final String recipeName;
  final RecipeType recipeType;
  final String sharedBy;
  final String? sharedTo;
  final String? message;
  final DateTime sharedAt;
  final ShareStatus status;

  // Constructor, fromJson, toJson
}
```

#### ShareInvite Model
```dart
class ShareInvite {
  final String inviteId;
  final String token;
  final String shareUrl;
  final String recipeId;
  final String recipeName;
  final String? message;
  final String createdBy;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int claimedCount;
  final int maxClaims;

  // Constructor, fromJson, toJson
}
```

### Service Layer

#### SocialService
```dart
class SocialService {
  final BackendService _backendService;
  final AuthService _authService;

  // User Profile
  Future<UserProfile> getUserProfile();
  Future<UserProfile> updateUserProfile(String displayName);

  // Internal Sharing
  Future<RecipeShare> shareRecipeInternal({
    required String recipeId,
    required String recipeName,
    required RecipeType recipeType,
    required String recipientAlias,
    String? message,
  });

  // External Sharing
  Future<ShareInvite> createShareInvite({
    required String recipeId,
    required String recipeName,
    required RecipeType recipeType,
    String? message,
  });

  Future<RecipeShare> claimShareInvite(String token);

  // Inbox/Outbox
  Future<List<RecipeShare>> getInbox({
    int limit = 20,
    int offset = 0,
    ShareStatus? status,
  });

  Future<ShareOutbox> getOutbox({
    int limit = 20,
    int offset = 0,
    ShareType? type,
  });

  // Error handling
  SocialException _handleError(dynamic error);
}
```

### State Management (Riverpod)

#### UserProfileProvider
```dart
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile>>((ref) {
  return UserProfileNotifier(ref.read(socialServiceProvider));
});

class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile>> {
  final SocialService _socialService;

  Future<void> loadProfile();
  Future<void> updateDisplayName(String displayName);
  Future<void> refresh();
}
```

#### SocialShareProvider
```dart
final socialShareProvider = StateNotifierProvider<SocialShareNotifier, SocialShareState>((ref) {
  return SocialShareNotifier(ref.read(socialServiceProvider));
});

class SocialShareNotifier extends StateNotifier<SocialShareState> {
  final SocialService _socialService;

  Future<ShareInvite> createExternalShare(Recipe recipe, String? message);
  Future<RecipeShare> shareInternal(Recipe recipe, String alias, String? message);
  void clearCurrentShare();
}
```

#### ShareInboxProvider
```dart
final shareInboxProvider = StateNotifierProvider<ShareInboxNotifier, AsyncValue<List<RecipeShare>>>((ref) {
  return ShareInboxNotifier(ref.read(socialServiceProvider));
});

class ShareInboxNotifier extends StateNotifier<AsyncValue<List<RecipeShare>>> {
  final SocialService _socialService;

  Future<void> loadInbox({int limit = 20, int offset = 0});
  Future<void> refresh();
  Future<void> markAsViewed(String shareId);
}
```

## Phase 3: UI Implementation

### 3.1 User Profile Screen

**Location**: `lib/src/features/friends_via_code/screens/user_profile_screen.dart`

**Features**:
- Display user alias with copy button
- Display/edit display name
- Show account created date
- Settings section (privacy, notifications)

**UI Elements**:
- AppBar with "Profile" title
- Card showing alias (@adjective-animal-###)
- TextField for display name (editable)
- Save button (only shown when edited)
- Statistics: shares sent, shares received

### 3.2 Share Recipe Screen

**Location**: `lib/src/features/friends_via_code/screens/share_recipe_screen.dart`

**Features**:
- Two tabs: "Share Internally" and "Create Link"
- Internal sharing: search for users by alias
- External sharing: generate shareable link
- Optional message field
- Share preview

**UI Elements**:
- TabBar: "By Alias" | "Share Link"
- Recipe preview card (image, name, type)
- TextField for recipient alias or message
- "Share" button with loading state
- Success dialog with share URL (external) or confirmation (internal)
- Copy to clipboard functionality

### 3.3 Share Inbox Screen

**Location**: `lib/src/features/friends_via_code/screens/share_inbox_screen.dart`

**Features**:
- List of received recipe shares
- Filter by status (pending, accepted, rejected)
- Pull-to-refresh
- Tap to view recipe details
- Mark as viewed
- Accept/reject actions

**UI Elements**:
- AppBar with "Inbox" title and filter button
- ListView of ShareCards
- Empty state when no shares
- Loading indicator
- Error handling with retry

### 3.4 Share Outbox Screen

**Location**: `lib/src/features/friends_via_code/screens/share_outbox_screen.dart`

**Features**:
- Two sections: "Internal Shares" and "Invite Links"
- View share status
- See who claimed invites
- Copy invite URL again
- Delete/revoke invites

**UI Elements**:
- AppBar with "Sent" title
- Sectioned ListView
- Internal shares section
- Invite links section with claim count
- Copy button for invite URLs
- Status badges (pending, accepted, rejected, expired)

### 3.5 Integration Points

#### Recipe Detail Screen
Add "Share" button to recipe detail screen:
```dart
IconButton(
  icon: Icon(Icons.share),
  onPressed: () => _showShareOptions(context, recipe),
)
```

#### Home Screen / Navigation
Add navigation to Friends features:
- Bottom nav item or drawer menu item
- Badge showing unread inbox count
- Quick access to share functionality

#### Deep Linking
Handle invite URLs from web:
```dart
// Route: mybartender://share/invite/{token}
Future<void> _handleInviteLink(String token) async {
  final share = await socialService.claimShareInvite(token);
  // Navigate to recipe detail
}
```

## Phase 4: Error Handling & Edge Cases

### Error Types

1. **Authentication Errors (401)**
   - Token expired → prompt re-login
   - Invalid token → show error, prompt re-login

2. **Rate Limiting (429)**
   - Display user-friendly message
   - Show retry-after time
   - Suggest upgrade to higher tier

3. **Validation Errors (400)**
   - Invalid alias format
   - Self-sharing attempt
   - Missing required fields

4. **Not Found (404)**
   - User alias not found
   - Recipe not found
   - Invite token invalid

5. **Conflict (409)**
   - Duplicate share (already shared recently)

6. **Network Errors**
   - Timeout → retry with exponential backoff
   - No connection → show offline message

### Error Handling Strategy

```dart
class SocialException implements Exception {
  final String code;
  final String message;
  final int? retryAfter;

  SocialException(this.code, this.message, {this.retryAfter});

  static SocialException fromResponse(Response response) {
    final body = jsonDecode(response.body);
    return SocialException(
      body['error'] ?? 'UNKNOWN_ERROR',
      body['message'] ?? 'An unknown error occurred',
      retryAfter: body['retryAfter'],
    );
  }

  String getUserMessage() {
    switch (code) {
      case 'RATE_LIMIT_EXCEEDED':
        return 'You\'ve made too many requests. Please wait ${retryAfter ?? 60} seconds.';
      case 'QUOTA_EXCEEDED':
        return 'You\'ve reached your daily limit. Upgrade for more shares!';
      case 'USER_NOT_FOUND':
        return 'User with this alias not found. Please check the alias and try again.';
      case 'DUPLICATE_SHARE':
        return 'You\'ve already shared this recipe with this user recently.';
      default:
        return message;
    }
  }
}
```

## Phase 5: Testing Strategy

### Unit Tests

```dart
// Test user profile provider
test('UserProfileNotifier loads profile successfully', () async {
  // Arrange, Act, Assert
});

// Test social service
test('SocialService creates external invite', () async {
  // Mock HTTP responses, verify request format
});

// Test error handling
test('SocialService handles rate limit error', () async {
  // Verify 429 responses are properly handled
});
```

### Widget Tests

```dart
testWidgets('ShareRecipeScreen displays recipe preview', (tester) async {
  // Build widget, verify UI elements
});

testWidgets('Share button triggers share action', (tester) async {
  // Tap button, verify provider method called
});
```

### Integration Tests

```dart
testWidgets('Complete share flow: create invite → claim → view inbox', (tester) async {
  // Multi-step flow testing
});
```

## Phase 6: Implementation Timeline

### Week 1: Foundation (5 days)

**Day 1-2: Models & Services**
- [ ] Create data models (UserProfile, RecipeShare, ShareInvite)
- [ ] Implement SocialService with HTTP client
- [ ] Add JWT token extraction from MSAL
- [ ] Test API calls with real tokens

**Day 3-4: State Management**
- [ ] Create Riverpod providers
- [ ] Implement UserProfileProvider
- [ ] Implement SocialShareProvider
- [ ] Implement ShareInboxProvider

**Day 5: Error Handling**
- [ ] Implement SocialException
- [ ] Add error handling to services
- [ ] Create user-friendly error messages
- [ ] Add retry logic for network errors

### Week 2: UI Implementation (5 days)

**Day 1: User Profile Screen**
- [ ] Build profile screen UI
- [ ] Connect to UserProfileProvider
- [ ] Add edit display name functionality
- [ ] Test profile loading and updates

**Day 2: Share Recipe Screen**
- [ ] Build share screen UI with tabs
- [ ] Implement internal share (by alias)
- [ ] Implement external share (invite link)
- [ ] Add copy to clipboard
- [ ] Show success/error states

**Day 3: Inbox & Outbox Screens**
- [ ] Build inbox screen UI
- [ ] Build outbox screen UI
- [ ] Add pull-to-refresh
- [ ] Implement filtering
- [ ] Test data loading

**Day 4: Integration**
- [ ] Add share button to recipe detail
- [ ] Add navigation to Friends features
- [ ] Implement deep linking for invites
- [ ] Add badge for unread inbox count

**Day 5: Polish & Testing**
- [ ] Add loading states and animations
- [ ] Implement empty states
- [ ] Write unit tests
- [ ] Write widget tests
- [ ] Fix bugs and edge cases

### Week 3: Testing & Refinement (3 days)

**Day 1: End-to-End Testing**
- [ ] Test complete share flows
- [ ] Test error scenarios
- [ ] Test rate limiting
- [ ] Test offline behavior

**Day 2: UI Polish**
- [ ] Refine animations
- [ ] Improve error messages
- [ ] Add haptic feedback
- [ ] Optimize performance

**Day 3: Documentation & Deploy**
- [ ] Update README
- [ ] Create user guide
- [ ] Build release APK
- [ ] Beta test with users

## Phase 7: Deployment Checklist

### Before Launch

- [ ] All API endpoints tested and working
- [ ] JWT authentication integrated
- [ ] Error handling comprehensive
- [ ] Rate limiting respected
- [ ] Offline mode handled gracefully
- [ ] Deep linking working
- [ ] All UI screens complete
- [ ] Unit tests passing
- [ ] Widget tests passing
- [ ] Beta testing complete

### Launch

- [ ] Deploy to Play Store (beta channel)
- [ ] Monitor Application Insights for errors
- [ ] Watch for rate limit issues
- [ ] Collect user feedback
- [ ] Fix critical bugs within 24 hours

### Post-Launch

- [ ] Monitor usage metrics
- [ ] Analyze share conversion rates
- [ ] Optimize slow endpoints
- [ ] Add push notifications for shares
- [ ] Plan iOS implementation

## Next Steps

1. **Test Backend APIs** (Today)
   - Run `test-friends-via-code-apis.ps1`
   - Verify all endpoints work
   - Confirm rate limiting active

2. **Create Models** (Tomorrow)
   - Implement data models
   - Add JSON serialization
   - Write unit tests

3. **Build Service Layer** (Day 2-3)
   - Implement SocialService
   - Integrate with BackendService
   - Add error handling

4. **Start UI** (Day 4+)
   - User profile screen first
   - Then share functionality
   - Finally inbox/outbox

## Resources

- **API Documentation**: `docs/FRIENDS-VIA-CODE-API.md`
- **UI Mockups**: `FRIENDS-VIA-CODE-UI-MOCKUPS.md`
- **Backend Status**: `FRIENDS-VIA-CODE-DEPLOYMENT-COMPLETE.md`
- **Testing Script**: `test-friends-via-code-apis.ps1`

---

**Ready to Begin!** Start with Phase 1: Backend API Testing
