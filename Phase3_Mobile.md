# Phase 3: Mobile App — RevenueCat, Paywall, Gating & Voice UX

You are Claude Code acting as a senior engineer on "My AI Bartender".

## Context

Phase 2 updated the backend to use a single `paid` entitlement with voice minutes tracking. This phase updates the Flutter mobile app to match: RevenueCat integration, paywall UI, feature gating, and voice minutes display.

## Decisions (these are final — do not change them)

| Decision                             | Value                                                                                                            |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| RevenueCat entitlement ID            | `paid`                                                                                                           |
| Monthly product                      | $7.99/month with 3-day free trial (trial configured in App Store Connect / Google Play Console, not in app code) |
| Annual product                       | $79.99/year (no trial)                                                                                           |
| Voice add-on product ID              | `voice_minutes_60` (platform-specific IDs are fine, e.g., `voice_minutes_60_ios`)                                |
| Voice add-on type                    | Consumable (non-subscription IAP)                                                                                |
| Non-subscribers can buy voice packs? | No                                                                                                               |
| User-facing label for subscribers    | "Subscriber"                                                                                                     |
| Low-minutes upsell threshold         | Show modal when < 5 minutes remaining                                                                            |

## Task A: RevenueCat integration update

Update the RevenueCat configuration in code:

### Entitlements

- Single entitlement: `paid`
- Remove any references to `free`, `premium`, or `pro` entitlement IDs

### Offerings / packages

- Monthly package: auto-renewable subscription with 3-day trial
- Annual package: auto-renewable subscription, no trial
- Voice add-on: consumable IAP, `voice_minutes_60`

### Entitlement check

Replace all tier-checking logic with a single pattern:

```dart
// Wherever the app checks subscription status:
bool isPaid = customerInfo.entitlements.all['paid']?.isActive ?? false;
```

### Restore purchases

- Ensure restore purchases flow works and refreshes entitlement state
- After restore, call the backend sync endpoint to reconcile server-side state
- Handle consumables appropriately (RevenueCat tracks non-consumable history; for consumables, rely on backend ledger as source of truth)

## Task B: Paywall UI

Redesign the paywall/subscription screen with exactly these CTAs:

### Primary CTA (monthly with trial)

```
Start 3-Day Free Trial
Then $7.99/month. Cancel anytime.
```

### Secondary CTA (annual)

```
$79.99/year
Save over 15% — best value
```

### Additional elements

- "Restore Purchases" link/button
- Brief feature list showing what subscribers get (voice conversations, AI concierge, scanner, etc.)
- Compliance text: trial auto-converts to $7.99/month unless canceled before trial ends

### Voice add-on purchase (only visible to subscribers)

- This should appear on the voice/Talk screen, NOT on the main paywall
- Show: "Need more voice time? +60 minutes for $4.99"
- Only display if `entitlement == paid`

## Task C: Feature gating

Find every place in the Flutter app that checks for Free/Premium/Pro and refactor:

### Pattern to use everywhere

```dart
if (isPaid) {
  // Unlock: voice/Talk, scanner, higher AI quotas, all features
} else {
  // Show paywall or limited experience
}
```

### Specific changes

- Remove any `if (tier == 'premium')` or `if (tier == 'pro')` checks
- Remove any tier enum/class that defines Free/Premium/Pro — replace with a boolean `isPaid` or equivalent
- Update any Riverpod providers that expose tier state to expose `isPaid` boolean and `subscriptionStatus` (trialing/active/expired/none)

### UI copy changes

- Replace all instances of "Pro tier", "Pro feature", "Pro only", "Premium" with "Subscriber" or "Subscribers"
- Examples: "Pro Feature" → "Subscriber Feature", "Upgrade to Pro" → "Subscribe", "Pro members get..." → "Subscribers get..."

## Task D: Voice minutes display

### Voice/Talk screen

Show remaining voice time to the user:

```
Voice Time Remaining
XX:XX included | XX:XX purchased | XX:XX total
```

(Format as minutes:seconds or just minutes — use whatever pattern exists in the app)

### Fetch minutes from backend

- Call `get_remaining_voice_minutes` endpoint on Talk screen load
- Cache the result in local state but always treat server as source of truth
- After each voice session ends, refresh the balance from the backend

### Low-minutes upsell

When total remaining < 5 minutes, show a modal or banner:

```
Running low on voice time!
+60 minutes for $4.99
[Buy Now]  [Maybe Later]
```

### Zero-minutes block

When total remaining <= 0:

- Disable the "Start conversation" button
- Show: "You've used all your voice minutes this cycle. Buy more to continue."
- Show the purchase CTA for the +60 minute pack

## Task E: Post-purchase sync

After any purchase (subscription or consumable):

1. RevenueCat confirms purchase
2. App calls backend sync/verify endpoint with user ID
3. Backend verifies with RevenueCat API and updates entitlement + voice minutes
4. App refreshes local state from backend response

Ensure this flow handles:

- Network failures (retry with exponential backoff, or queue for next app launch)
- App killed during purchase (reconcile on next app start)

## Output format

After completing all changes, provide:

1. List of files created or modified (with one-line description of each change)
2. Any RevenueCat dashboard configuration steps I need to do manually
3. Any App Store Connect / Google Play Console configuration needed (product setup, trial config)
4. Known edge cases or limitations

## Constraints

- Do NOT modify backend code — that was Phase 2.
- Do NOT update documentation files — that is Phase 4.
- Do NOT refactor database connection logic, authentication flows, or unrelated code.
- Preserve existing Riverpod patterns — update providers, don't replace the state management approach.
- If a file has both subscription-related and unrelated code, only change the subscription parts.
- Keep changes small, safe, and reversible.
