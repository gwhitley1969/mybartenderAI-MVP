# In-App Review System — My AI Bartender

**Last Updated**: March 14, 2026
**Version**: 1.0.6+27

## Overview

The in-app review system prompts users to rate the app on Google Play or the Apple App Store after positive "win moment" interactions. It uses a two-step UX: a pre-prompt dialog ("Are you enjoying My AI Bartender?") routes happy users to the OS review dialog and unhappy users to a feedback email. A manual "Rate & Review" button on the Profile screen allows users to leave a review at any time.

## Architecture

### Core Service

**`ReviewService`** (`lib/src/services/review_service.dart`) — Singleton with `WidgetsBindingObserver` mixin.

- Manages session tracking, win moment recording, eligibility checks, and prompt display
- Persists all state in SharedPreferences (survives app restarts)
- Initialized in `AuthNotifier._initializeAppLifecycle()` (`auth_provider.dart`)
- Riverpod provider: `reviewServiceProvider` (`review_provider.dart`)

### Prompting Strategy: Hybrid Direct + Deferred

Two prompting mechanisms handle the different contexts where win moments occur:

| Strategy | When Used | How It Works |
|----------|-----------|-------------|
| **Direct** | User stays on screen (has stable BuildContext) | `maybePromptForReview(context)` called immediately after `recordWinMoment()` |
| **Deferred** | User navigates away or trigger lacks BuildContext | `setPendingPrompt()` sets a persistent flag; HomeScreen checks and consumes it on init/resume |

**Why two strategies?** Some triggers fire in Riverpod providers (no BuildContext), inside `dispose()` (screen is being torn down), or immediately before `Navigator.pop()` (context about to be destroyed). These cannot safely show a dialog — they use the deferred path instead.

### Deferred Prompt Flow

```
Win Moment Trigger (provider/dispose/pre-pop)
  → ReviewService.setPendingPrompt()
    → SharedPreferences: review_pending_prompt = true

HomeScreen init / app resume
  → _checkPendingReview() (800ms delay)
    → ReviewService.checkPendingPrompt(context)
      → Reads + clears flag
      → context.mounted check
      → maybePromptForReview(context)
        → isEligible() check
        → ReviewPromptDialog.show(context)
```

HomeScreen acts as the deferred prompt consumer because:
- All `context.go()` navigation unmounts HomeScreen, so `initState` fires on every return
- `WidgetsBindingObserver.didChangeAppLifecycleState(resumed)` handles the case where the user backgrounds/foregrounds while on HomeScreen
- A guard flag (`_isCheckingReview`) prevents concurrent checks during rapid foreground/background cycles
- The 800ms delay lets the screen render and any snackbars from the previous screen appear first

## Eligibility Gates

All 6 conditions must pass before a review prompt is shown:

| # | Condition | Threshold | Rationale |
|---|-----------|-----------|-----------|
| 1 | Total sessions | >= 2 | User has returned to the app |
| 2 | Distinct days | >= 1 day since first session | User has used the app on 2+ calendar days |
| 3 | Win moments | >= 1 recorded | User has experienced value |
| 4 | Lifetime prompts | < 3 | Don't over-ask |
| 5 | Prompt cooldown | 30 days since last prompt | Respect user attention |
| 6 | Unhappy cooldown | 60 days since "Not really" | Extra respect for dissatisfied users |

**Practical timeline**: A new user can first see the review prompt on **Day 2** of app usage (earliest), after completing at least one win moment action.

## Win Moment Triggers (9 Total)

| # | Type | Location | Strategy | Trigger Condition |
|---|------|----------|----------|-------------------|
| 1 | `scannerSuccess` | `smart_scanner_screen.dart` | Deferred | After successful image analysis and ingredient addition |
| 2 | `createStudioSave` | `edit_cocktail_screen.dart` | Deferred | After inserting/updating a custom cocktail |
| 3 | `sharingSuccess` | `share_recipe_dialog.dart` | Deferred | After successful recipe share |
| 4 | `favoritesThreshold` | `favorites_provider.dart` | Deferred | When favorites count >= 3 |
| 5 | `aiChatSave` | `chat_screen.dart` | Direct | After 3 successful AI chat responses |
| 6 | `voiceSessionComplete` | `voice_ai_provider.dart` | Deferred | Voice session duration >= 45 seconds |
| 7 | `recipeDetailView` | `cocktail_detail_screen.dart` | Direct | First recipe detail view per screen instance |
| 8 | `canMakeFilterUsed` | `recipe_vault_screen.dart` | Direct | When user toggles "Can Make with My Bar" filter on |
| 9 | `academyLessonComplete` | `academy_lesson_screen.dart` | Deferred | Academy lesson viewed >= 30 seconds (in `dispose()`) |

**Note**: `recordWinMoment()` is idempotent per type — each type is recorded only once (stored as a JSON list of type names in SharedPreferences). This means viewing 100 recipes still only records `recipeDetailView` once. However, `maybePromptForReview()` is called on every trigger to check if eligibility conditions are met.

## Two-Step UX Flow

### Step 1: Pre-Prompt Dialog (`ReviewPromptDialog`)

```
┌──────────────────────────────────┐
│          🍸 (cocktail icon)       │
│                                  │
│     Are you enjoying             │
│     My AI Bartender?             │
│                                  │
│   Your feedback helps us improve!│
│                                  │
│  [Not really]          [Yes!]    │
└──────────────────────────────────┘
```

### Step 2: Outcome Branching

| User Action | Result |
|-------------|--------|
| Taps "Yes!" | OS-native review dialog (`InAppReview.requestReview()`) or store listing fallback |
| Taps "Not really" | Opens feedback email (`support@xtend-ai.com`) + records unhappy signal (60-day cooldown) |
| Dismisses dialog | No action, but lifetime prompt count still increments |

## Profile Screen: Manual Review Button

A "Rate & Review" card is placed between the Notifications and Verification Status sections on the Profile screen. It:

- Uses `ReviewService.openStoreForReview()` which **bypasses all eligibility checks** (user-initiated)
- Calls `InAppReview.requestReview()` if available, falls back to `openStoreListing(appStoreId: '6758023541')`
- Styled consistently with `_buildHelpSupportCard`: amber star icon (`Icons.star_outline_rounded`, `AppColors.iconCircleOrange`), chevron, card background

## SharedPreferences Keys

| Key | Type | Purpose |
|-----|------|---------|
| `review_total_sessions` | int | Total session count (debounced to 30 min) |
| `review_first_session_date` | String (ISO 8601) | First ever session timestamp |
| `review_last_session_start` | String (ISO 8601) | Last session start (for debounce) |
| `review_last_prompt_at` | String (ISO 8601) | Last prompt timestamp (for 30-day cooldown) |
| `review_lifetime_prompts` | int | Total prompts shown (for lifetime cap) |
| `review_last_unhappy_at` | String (ISO 8601) | Last unhappy signal (for 60-day cooldown) |
| `review_win_moments` | String (JSON array) | List of recorded win moment type names |
| `review_pending_prompt` | bool | Deferred prompt flag (set by triggers, consumed by HomeScreen) |

All keys are cleared by `ReviewService.clearAll()` (used for testing and account reset).

## File Inventory

### Core Files
- `lib/src/services/review_service.dart` — Core singleton (eligibility, persistence, prompting, deferred mechanism)
- `lib/src/providers/review_provider.dart` — Riverpod providers (`reviewServiceProvider`, `reviewEligibleProvider`)
- `lib/src/widgets/review_prompt_dialog.dart` — Pre-prompt dialog widget

### Trigger Files (9 win moment sites)
- `lib/src/features/smart_scanner/smart_scanner_screen.dart` — `scannerSuccess` (deferred)
- `lib/src/features/create_studio/edit_cocktail_screen.dart` — `createStudioSave` (deferred)
- `lib/src/features/create_studio/widgets/share_recipe_dialog.dart` — `sharingSuccess` (deferred)
- `lib/src/providers/favorites_provider.dart` — `favoritesThreshold` (deferred)
- `lib/src/features/ask_bartender/chat_screen.dart` — `aiChatSave` (direct)
- `lib/src/providers/voice_ai_provider.dart` — `voiceSessionComplete` (deferred)
- `lib/src/features/recipe_vault/cocktail_detail_screen.dart` — `recipeDetailView` (direct)
- `lib/src/features/recipe_vault/recipe_vault_screen.dart` — `canMakeFilterUsed` (direct)
- `lib/src/features/academy/academy_lesson_screen.dart` — `academyLessonComplete` (deferred, fire-and-forget in dispose)

### Consumer Files
- `lib/src/features/home/home_screen.dart` — Deferred prompt consumer (WidgetsBindingObserver)
- `lib/src/features/profile/profile_screen.dart` — Manual "Rate & Review" button

### Initialization
- `lib/src/providers/auth_provider.dart` — `ReviewService.instance.initialize()` in `AuthNotifier`

## Debugging

All review events are logged with `developer.log('[REVIEW] ...')`. Monitor on Android via:

```bash
adb logcat | grep -i REVIEW
```

Key log messages:
- `[REVIEW] Session recorded: total=N, distinct_days=N`
- `[REVIEW] Win moment recorded: type=scannerSuccess`
- `[REVIEW] Pending prompt flag set`
- `[REVIEW] Pending prompt flag consumed`
- `[REVIEW] Eligibility check: eligible=true/false, reason=...`
- `[REVIEW] Pre-prompt shown`
- `[REVIEW] User response: yes / not_really`
- `[REVIEW] OS review dialog requested`
- `[REVIEW] Manual store review requested from Profile`

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0+12 | Feb 17, 2026 | Initial implementation: ReviewService, 6 win moments, pre-prompt dialog, eligibility gates |
| 1.0.6+27 | Mar 14, 2026 | Bug fix: 3 root causes fixed (missing prompt calls, race condition, no deferred mechanism). Added 3 new win moments (9 total). Hybrid direct + deferred prompting. Profile "Rate & Review" button. |
