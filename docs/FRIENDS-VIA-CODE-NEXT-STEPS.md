# Friends via Code - Next Steps

**Status**: ✅ Backend Complete | 📋 Mobile App Integration Ready
**Date**: November 16, 2025

## Current State

### ✅ Completed

- **Backend Infrastructure**: All 8 Azure Functions deployed and operational
- **Database Schema**: 5 tables created with migration file
- **APIM Configuration**: 7 operations with JWT authentication, rate limiting, tier-based quotas
- **Static Website**: Azure Blob Storage $web container configured
- **CDN**: Azure Front Door Standard deployed with custom domain
- **SSL Certificate**: Validated and deployed to `https://share.mybartenderai.com`
- **Monitoring**: Application Insights with custom queries and dashboard
- **Documentation**: Complete API docs, deployment guides, troubleshooting
- **Planning**: Flutter implementation plan with 3-week timeline

### 📋 Ready to Begin

Mobile app integration following the **test-first approach** you selected.

---

## Phase 1: Backend API Testing (Start Here)

### Prerequisites

You need a JWT token from Entra External ID to test the APIs.

#### Option A: Azure CLI (Quickest for testing)

```bash
# Login to Entra External ID tenant
az login --tenant a82813af-1054-4e2d-a8ec-c6b9c2908c91 --allow-no-subscriptions

# Get access token
az account get-access-token --resource 04551003-a57c-4dc2-97a1-37e0b3d1a2f6 --query accessToken -o tsv
```

#### Option B: Flutter App (Production method)

1. Run the Flutter app
2. Sign in with Google, Facebook, or Email
3. Extract token from `AuthService` (add debug logging if needed)

**Tip**: See `get-jwt-token.ps1` for detailed instructions on all methods.

### Testing Script

Once you have a JWT token, run:

```powershell
.\test-friends-via-code-apis.ps1 -JwtToken "YOUR_JWT_TOKEN_HERE"
```

### Expected Results

The script will test:
- ✅ GET /v1/users/me (auto-creates profile)
- ✅ PATCH /v1/users/me (update display name)
- ✅ POST /v1/social/invite (create external share)
- ✅ GET /v1/social/invite/{token} (claim invite)
- ✅ GET /v1/social/outbox (view sent shares)
- ✅ GET /v1/social/inbox (view received shares)
- ✅ Rate limiting (expects 429 after 5 requests)

**What to look for:**
- All tests should return 200/201 responses
- User profile should be auto-created with system-generated alias (@adjective-animal-###)
- Rate limiting should kick in on 6th request (429 response)
- Your user alias will be displayed at the end

### Troubleshooting

**401 Unauthorized**: Token expired or invalid
- Obtain a fresh token
- Verify token contains `sub` claim

**429 Too Many Requests**: Rate limit working correctly
- This is expected behavior
- Wait 60 seconds before retrying

**500 Internal Server Error**: Backend issue
- Check Application Insights: `.\infrastructure\monitoring\check-social-metrics.ps1`
- Review function logs in Azure Portal

---

## Phase 2: Flutter Implementation (After API Testing)

### Week 1: Foundation (5 days)

**Day 1-2: Models & Services**
- Create data models (`UserProfile`, `RecipeShare`, `ShareInvite`)
- Implement `SocialService` with HTTP client
- Extract JWT token from MSAL in Flutter app
- Test API calls with real tokens

**Files to create:**
```
mobile/app/lib/src/features/friends_via_code/
├── models/
│   ├── user_profile.dart
│   ├── recipe_share.dart
│   └── share_invite.dart
└── services/
    └── social_service.dart
```

**Day 3-4: State Management**
- Create Riverpod providers
- Implement `UserProfileProvider`
- Implement `SocialShareProvider`
- Implement `ShareInboxProvider`

**Files to create:**
```
mobile/app/lib/src/features/friends_via_code/
└── providers/
    ├── user_profile_provider.dart
    ├── social_share_provider.dart
    └── share_inbox_provider.dart
```

**Day 5: Error Handling**
- Implement `SocialException` class
- Add error handling to services
- Create user-friendly error messages
- Add retry logic for network errors

### Week 2: UI Implementation (5 days)

**Day 1: User Profile Screen**
- Build profile screen UI
- Display system-generated alias with copy button
- Edit display name functionality
- Show account statistics

**Day 2: Share Recipe Screen**
- Two tabs: "By Alias" and "Share Link"
- Internal sharing (search by alias)
- External sharing (generate invite link)
- Copy to clipboard functionality

**Day 3: Inbox & Outbox Screens**
- Inbox: List received shares, filter by status
- Outbox: View sent shares and invite links
- Pull-to-refresh functionality
- Status badges (pending, accepted, rejected)

**Day 4: Integration**
- Add share button to recipe detail screen
- Add navigation to Friends features in home screen
- Implement deep linking for invite URLs
- Add badge for unread inbox count

**Day 5: Polish & Testing**
- Add loading states and animations
- Implement empty states
- Write unit tests
- Fix bugs

### Week 3: Testing & Launch (3 days)

**Day 1: End-to-End Testing**
- Test complete share flows
- Test error scenarios
- Test rate limiting and quotas
- Test offline behavior

**Day 2: UI Polish**
- Refine animations
- Improve error messages
- Add haptic feedback
- Optimize performance

**Day 3: Documentation & Deploy**
- Update README
- Create user guide
- Build release APK
- Beta test with users

---

## Resources

### Documentation

- **Implementation Plan**: `FRIENDS-VIA-CODE-FLUTTER-IMPLEMENTATION-PLAN.md`
- **API Documentation**: `docs/FRIENDS-VIA-CODE-API.md`
- **Deployment Summary**: `FRIENDS-VIA-CODE-DEPLOYMENT-COMPLETE.md`
- **UI Mockups**: `FRIENDS-VIA-CODE-UI-MOCKUPS.md`
- **Feature Spec**: `FEATURE-FriendsViaCode.md`

### Scripts

- **Get JWT Token**: `get-jwt-token.ps1`
- **Test APIs**: `test-friends-via-code-apis.ps1`
- **Monitor Metrics**: `infrastructure/monitoring/check-social-metrics.ps1`

### API Endpoints

**Base URL**: `https://apim-mba-001.azure-api.net/api`

All endpoints require:
- `Authorization: Bearer <JWT_TOKEN>` header
- `Ocp-Apim-Subscription-Key` header (get from environment variable)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/v1/users/me` | Get user profile (auto-creates) |
| PATCH | `/v1/users/me` | Update display name |
| POST | `/v1/social/share-internal` | Share recipe by alias |
| POST | `/v1/social/invite` | Create external share link |
| GET | `/v1/social/invite/{token}` | Claim invite |
| GET | `/v1/social/inbox` | View received shares |
| GET | `/v1/social/outbox` | View sent shares |

### Rate Limits

- **Burst Protection**: 5 requests/minute
- **Daily Quota**:
  - Free: 100 requests/day
  - Premium: 1,000 requests/day
  - Pro: 5,000 requests/day

---

## Your Action Items

### Immediate (Today)

1. **Obtain JWT Token**
   ```bash
   # Run the helper script for instructions
   .\get-jwt-token.ps1
   ```

2. **Test Backend APIs**
   ```powershell
   .\test-friends-via-code-apis.ps1 -JwtToken "YOUR_TOKEN"
   ```

3. **Verify Results**
   - Note your user alias (e.g., `@happy-dolphin-742`)
   - Confirm all endpoints return 200/201
   - Verify rate limiting works (429 on 6th request)

### This Week

4. **Create Flutter Models**
   - Reference: `FRIENDS-VIA-CODE-FLUTTER-IMPLEMENTATION-PLAN.md` Phase 2

5. **Implement SocialService**
   - Use existing `BackendService` as reference
   - Add JWT token extraction from `AuthService`

6. **Build First Provider**
   - Start with `UserProfileProvider`
   - Test profile loading and updates

### Next Week

7. **Build UI Screens**
   - User Profile Screen (Day 1)
   - Share Recipe Screen (Day 2)
   - Inbox/Outbox Screens (Day 3)

8. **Integration**
   - Add share buttons to existing screens
   - Wire up navigation
   - Test end-to-end flows

---

## Success Criteria

### Phase 1 Complete When:
- [ ] All API tests pass
- [ ] User profile auto-created successfully
- [ ] External invite created and claimed
- [ ] Rate limiting confirmed working
- [ ] No 500 errors in Application Insights

### Phase 2 Complete When:
- [ ] All Flutter models implemented
- [ ] SocialService tested with real APIs
- [ ] All Riverpod providers working
- [ ] Error handling comprehensive
- [ ] Unit tests passing

### Phase 3 Complete When:
- [ ] All 5 UI screens implemented
- [ ] Deep linking working
- [ ] Share flows tested end-to-end
- [ ] Widget tests passing
- [ ] Beta APK built and tested

---

## Questions or Issues?

### Monitoring
```powershell
# Check API health
.\infrastructure\monitoring\check-social-metrics.ps1
```

### Documentation
- **Troubleshooting**: `TROUBLESHOOTING_DOCUMENTATION.md`
- **Monitoring Setup**: `infrastructure/monitoring/MONITORING-SETUP.md`
- **API Reference**: `docs/FRIENDS-VIA-CODE-API.md`

### Application Insights
- Portal: https://portal.azure.com
- Resource: `func-mba-fresh`
- Query recent errors, performance metrics, usage patterns

---

## Cost Reminder

**New Monthly Costs from Friends via Code:**
- Azure Front Door Standard: ~$35/month
- Functions (incremental): ~$0-5/month
- Storage (static website): <$1/month
- Application Insights (logs): ~$2-3/month

**Total New Cost**: ~$38-44/month

**Current Total Infrastructure**: ~$125/month

---

**Ready to Begin!** Start by obtaining a JWT token and running the API tests.

Good luck with the implementation! 🚀
