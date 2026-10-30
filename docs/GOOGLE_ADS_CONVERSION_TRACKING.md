# Google Ads Conversion Tracking (Android)

**Status**: code done (Android); console setup pending (Oct 30, 2026)
**Scope**: Google Ads App campaigns on Google Play. iOS is off for now (see [iOS](#ios-later)).

This doc covers which in-app events Google Ads can optimize on, where each one is logged in the app, and the console steps that have to be done by hand before any conversion shows up in Google Ads.

---

## 1. Audit: what existed before this change

| Piece | Before | Effect on Google Ads |
|---|---|---|
| Firebase / Google Analytics for Firebase | **None.** No `firebase_*` packages, no `google-services.json`, no `GoogleService-Info.plist` | Google Ads could see **no** in-app event: no sign-up, no trial, no engagement |
| Google Ads SDK / attribution partner (AppsFlyer, Adjust, Branch) | None | Same as above |
| Play Install Referrer | Not read directly | Firebase reads it itself (it ships inside the measurement SDK), so no separate code is needed |
| Paywall "analytics" | `developer.log('event=Paywall…', name: 'Analytics')` | Writes only to the device log. Nothing leaves the phone |
| Purchases | RevenueCat (`purchases_flutter`), Play Billing 8 | RevenueCat knew about trials and renewals, but nothing passed them on to Google |

**What Google Ads could optimize on before this change:** only **installs**. When the Play Console is linked to Google Ads, Google Play reports first opens and installs without an SDK. That is the only conversion an App campaign could use. Anything deeper (Target CPA on a sign-up or trial) recorded **0 conversions**.

### The campaign screenshot (Oct 29, 2026)

- Campaign **My AI Bartender** has status **Not eligible** and a **$0.00 budget**, so it hasn't served. That is why it shows 0 conversions, separate from the tracking gap.
- **Target CPA $2.00** fits **installs** only. If the campaign moves to optimizing on `trial_start` (below), a trial costs many installs, so the target must rise to match what a trial is worth. A $2 target on a trial event would starve the campaign.

---

## 2. Events the app now logs

All events go to **Google Analytics for Firebase (GA4)** through `lib/src/services/analytics_service.dart`. Every call is fire-and-forget and can never break a user flow. Until `google-services.json` is added, the service is a no-op.

> **Event names are a contract** with the Google Ads conversion actions imported from them. Renaming one silently stops that conversion.

| Event | Type | Fires when | Parameters | Logged in |
|---|---|---|---|---|
| `first_open` | Automatic | First launch after install | — | Firebase SDK |
| `sign_up` | GA4 recommended | First interactive sign-in **on this install** | `method=entra_external_id` | `auth_provider.dart` → `signIn()` |
| `login` | GA4 recommended | Every interactive sign-in | `method` | same |
| `paywall_view` | Custom | `/paywall` is shown | `trial_eligible` (0/1) | `paywall_screen.dart` |
| `trial_start` | Custom | Paywall purchase result shows the `paid` entitlement in its **trial** period | `plan` (monthly/annual), `product_id`, `currency`, `price` | `paywall_screen.dart` → `logSubscriptionPurchase` |
| `in_app_purchase` | Automatic | A Play purchase completes (subscription or voice minutes) | price, currency, product | Firebase SDK |
| `app_store_subscription_convert` / `_renew` | Automatic | Trial converts or a subscription renews | — | Firebase (from the store) |
| `ai_chat_reply` | Custom | AI Bartender answers a chat message | — | `chat_screen.dart` |
| `bar_scan_complete` | Custom | Smart Scanner results are added to My Bar | `items_added` | `smart_scanner_screen.dart` |
| `voice_session_complete` | Custom | A Voice AI session ends | `duration_sec` | `voice_ai_provider.dart` |
| `recipe_created` | Custom | A new Create Studio recipe is saved (not on edits) | — | `edit_cocktail_screen.dart` |
| `share` | GA4 recommended | A recipe card is shared (not counted if dismissed) | `content_type=recipe`, `item_id`, `method` | `recipe_card_share_service.dart` |

Also wired:

- **RevenueCat → Google Analytics**: the app sets RevenueCat's `$firebaseAppInstanceId` attribute (`subscription_service.dart`). Once the integration is turned on (step 6), RevenueCat sends **server-side** events to GA4: `purchase` (initial purchase, renewals **and trial conversions**, with `value` and `currency`), `rc_trial_start`, `rc_cancellation`, `rc_expiration` and others. This matters because trials convert on day 7, often while the app is closed.
- **Account deletion** calls `resetAnalyticsData()`, so later events aren't tied to the deleted user.
- **No user ID** is sent to Google (no Entra `sub`, no email), in line with the PII-minimal policy.

### Notes on the choices

- **`sign_up` means "first sign-in on this install."** Entra External ID uses one hosted flow for sign-up and sign-in (with the 21+ check inside it), so the app can't tell a brand-new account from a returning one. For a user fresh from an ad, this is the sign-up. A reinstall by an existing user also counts once.
- **`trial_start` has no `value` parameter** on purpose: a trial earns nothing until it converts. Give the conversion action a static value in Google Ads instead (step 5).
- **No client-side `purchase` event**, to avoid double counting with Firebase's automatic `in_app_purchase` and RevenueCat's server-side `purchase`.

---

## 3. Which conversions to use in Google Ads

| Conversion | Role | Why |
|---|---|---|
| Google Play installs (`first_open`) | **Primary at launch** | Highest volume. Bidding needs volume to learn |
| `sign_up` | **Primary at launch**, or secondary | Shows the install became a real user |
| `trial_start` | **Primary in phase 2** | The real business event (the app is fully paywalled). Move to it once it has steady daily volume |
| `purchase` (RevenueCat) | Secondary, then value bidding | Real revenue, including trial conversions |
| `paywall_view`, engagement events | Secondary (observe only) | Funnel diagnostics. Don't optimize on them |

**Import only one trial event and one purchase event**, or Google Ads counts each one twice:

- Trials: import **`trial_start`**, not `rc_trial_start`.
- Purchases: import **`purchase`** (RevenueCat) **or** `in_app_purchase` (Firebase), not both. `purchase` is preferred because it includes trial conversions and renewals. One caveat: Firebase notes that Google Ads attributes Measurement Protocol (server-sent) events only when they match device IDs collected by the Firebase SDK. After step 6, check that `purchase` conversions are attributed to campaigns. If they aren't, switch to `in_app_purchase` plus `app_store_subscription_convert`.

Google's guidance for in-app action bidding is a steady volume of conversions per day (it cites about 10). Until `trial_start` gets there, optimize on installs or `sign_up`.

---

## 4. Console steps Gene must do by hand

### Step 1: Create the Firebase project and Android app

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project** (for example `my-ai-bartender`). **Enable Google Analytics** when asked, and create a new GA4 property, or pick an existing one.
2. In the project, **Add app → Android**. Package name: `ai.mybartender.mybartenderai`. The SHA-1 is optional (Analytics doesn't need it).
3. Download **`google-services.json`** and put it at `mobile/app/android/app/google-services.json`. It isn't a secret (it identifies the app; it doesn't authorize anything), so commit it, which keeps fresh clones building with analytics on.
4. Skip the "Add Firebase SDK" Gradle steps in the wizard. This PR already does them, and the Google Services plugin turns on automatically once the file exists.

### Step 2: Build and check events in DebugView

1. Clean build: `& $flutter clean; & $flutter run` (Flutter 3.47.7). Without the JSON file the Gradle log says `google-services.json not found: building without Firebase Analytics`. With it, that line is gone.
2. Turn on debug mode: `adb shell setprop debug.firebase.analytics.app ai.mybartender.mybartenderai`
3. Firebase console → **Analytics → DebugView**. Sign in, open the paywall, start a trial with a Play test account, chat once and scan once. You should see `first_open`, `login`, `sign_up`, `paywall_view`, `trial_start`, `ai_chat_reply` and the others.
4. Turn debug mode off: `adb shell setprop debug.firebase.analytics.app .none.`

### Step 3: Mark key events in GA4

GA4 (analytics.google.com) → **Admin → Events** (or **Key events**). Mark as **key events**: `sign_up`, `trial_start` and `purchase`. A custom event appears in this list only after it has fired at least once, so do step 2 first. You can also create the key event by name ahead of time.

### Step 4: Link Firebase, Google Ads and Google Play

1. Firebase console → **Project settings → Integrations → Google Ads → Link** → pick the Xtend-AI, LLC Google Ads account. Turn on personalized advertising when asked.
2. GA4 → **Admin → Product links → Google Ads links** should now show the link. Turn on **auto-tagging** and **personalized advertising** there.
3. Google Ads → **Tools → Data manager** (or **Linked accounts**) → **Google Play** → link the Play developer account. This gives install conversions and Play purchase data even without Firebase.

### Step 5: Import conversions into Google Ads

Google Ads → **Goals → Conversions → Summary → + New conversion action → App → Google Analytics 4 properties (Firebase)** → select:

| Conversion action | Goal category | Primary / Secondary | Count | Value |
|---|---|---|---|---|
| `sign_up` | Sign-up | Primary (launch) | One | None, or a static $1 |
| `trial_start` | Subscribe (or Start trial) | **Secondary at launch, Primary in phase 2** | One | Static: monthly price × your trial-to-paid rate (for example $3.99 × 40% ≈ $1.60) |
| `purchase` | Purchase | Secondary | Every | Use the value from the event |

Don't import `rc_trial_start`, `in_app_purchase` or `paywall_view` as primary. Then in the campaign: **Settings → Bidding** → set the conversion to optimize for, and raise the Target CPA to fit that event (see section 1).

### Step 6: Turn on RevenueCat → Google Analytics

1. GA4 → **Admin → Data streams → (Android stream)** → copy the **Firebase App ID**. On the same page open **Measurement Protocol API secrets → Create**, and copy the secret.
2. RevenueCat dashboard → **Project settings → Integrations → Firebase (Google Analytics)** → enter the Android App ID and API secret. Pick USD reporting and whether revenue is gross or net (gross matches what Google Ads shows elsewhere).
3. The app already sets `$firebaseAppInstanceId` on every sign-in, so nothing else is needed in code. Check a sandbox purchase in GA4 DebugView or Realtime.

### Step 7: Play Console declarations (required before release)

The Firebase SDK adds the `com.google.android.gms.permission.AD_ID` permission through manifest merging. Play checks for this.

1. **Play Console → App content → Advertising ID**: answer **Yes**, the app uses the advertising ID, for **Analytics** and **Advertising or marketing**.
2. **App content → Data safety**: add **App activity → App interactions** (and **Other actions**), and **Device or other IDs**. They are collected, not shared (Google acting as a processor for analytics), used for **Analytics** and **Advertising or marketing**, and processed ephemerally: no. Optional: no (collection is always on).
3. Upload the release with the new Data safety answers in the same rollout. A mismatch can get the update rejected.

### Step 8: Privacy policy

Update `PRIVACY_POLICY.md` and `website/privacy.html`. They currently say nothing about analytics or advertising measurement. Add that the app uses **Google Analytics for Firebase** to measure app usage and ad performance. It collects app interactions and device identifiers (including the Android advertising ID), and shares them with Google to measure and improve the app's ads. Link Google's partner policy (policies.google.com/technologies/partner-sites), and explain that users can reset or delete their advertising ID in Android settings.

### Step 9 (only if you advertise in the EEA/UK): consent

Google requires consent mode v2 signals (`ad_storage`, `analytics_storage`, `ad_user_data`, `ad_personalization`) for EEA/UK users. The app doesn't set any today (Firebase then treats everything as granted). If the campaigns stay US-only, nothing is needed. Before targeting the EEA/UK, add a consent prompt and call `FirebaseAnalytics.instance.setConsent(...)`.

---

## 5. iOS (later)

iOS is off on purpose: `AnalyticsService.initialize()` returns early on iOS, and there is no `GoogleService-Info.plist`. To turn it on:

1. In Firebase, add an iOS app (bundle ID from Xcode), download `GoogleService-Info.plist` and add it to `ios/Runner` in Xcode.
2. Remove the `Platform.isAndroid` guard in `AnalyticsService.initialize()`.
3. On the Mac, `pod install`. The Podfile already sets `$FirebaseAnalyticsWithoutAdIdSupport = true`, so there is no IDFA and no App Tracking Transparency prompt.
4. Update the **App Store privacy label** (Usage data and Identifiers, used for Analytics) before submitting.

Even before step 2, the next iOS build links the Firebase pods. Run `pod install` on the Mac after pulling this change.

---

## 6. Verifying in production

- **Firebase → Analytics → Events / Realtime**: events arrive within minutes, and within a day in the reports.
- **Google Ads → Goals → Conversions**: each imported action shows **Recording conversions** within about 24 hours of the first event after linking.
- If an action stays **Inactive**: check that the GA4 ↔ Google Ads link is active, that the event is a key event, and that the release with `google-services.json` is the one users actually have.
