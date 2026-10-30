# Google Ads Strategy: Google Play (Android) App Campaigns

**App**: My AI Bartender (`ai.mybartender.mybartenderai`)
**Account**: Xtend-AI, LLC (Google Ads)
**Written**: October 30, 2026
**Scope**: Google Ads App campaigns for Android / Google Play. iOS acquisition belongs in Apple Ads and is out of scope here.

This plan treats the account as a **fresh launch**. The existing "My AI Bartender" campaign has never spent (Oct 23 to 29: $0 cost, 0 conversions), so there is no history to protect.

---

## 1. TL;DR

1. **Don't just give the current campaign a budget.** Its $2.00 target CPA is aimed at a conversion we can't verify, and it has no events from inside the app to learn from. Fix measurement first (section 4), then launch one new campaign.
2. **Don't optimize for installs.** The app is fully paywalled (sign-in, 21+ age check, then `/paywall`). An install-optimized campaign finds the cheapest installers, and most of them stop at the paywall. Bid on an event that happens after the install.
3. **Follow a three-step bidding path**: `sign_up` at a target CPA (launch), then `trial_start` at a target CPA (once about 10 trials a day are affordable), then target ROAS (only at scale, maybe never). Section 5 gives the switch criteria.
4. **The alcohol policy shapes everything.** Google allows cocktail recipe content, but it excludes alcohol from **app install image and video formats** and blocks advertiser-built audiences (remarketing, Customer Match, lookalikes). Expect a text-heavy, Search and Play heavy campaign, possibly marked "Eligible (limited)". Plan creative and budget around that (section 3).
5. **Starter budget**: $30/day (about $900/month) for 60 days, US only, English. Below this, Google can't get the 10 conversions a day it needs to learn.
6. **The listing must say "subscription" before the install.** A hard paywall that surprises people produces uninstalls and 1-star reviews, and both hurt the ads. Section 7.

---

## 2. What we're selling (from the repo)

| Item | Value | Source |
|---|---|---|
| Model | Hard paywall: no free tier since v1.2.0+33 | `CLAUDE.md`, `docs/PRD.md` |
| Trial | 7 days, full feature access, reduced quotas (50K tokens, 10 scans, 30 voice min), auto-converts | `paywall_screen.dart` |
| Price | $3.99/month or $39.99/year | `docs/DEPLOYMENT_STATUS.md` (v1.1.1+32) |
| Billing | RevenueCat (`purchases_flutter`), Google Play Billing 8 | `pubspec.yaml` |
| Hero features | Voice AI bartender (real-time, hands-free), Smart Scanner (photo of bottles to recipes), ~621-recipe offline vault, AI chat, Create Studio, Today's Special, Academy | `docs/ARCHITECTURE.md`, `docs/PRD.md` |
| Audience | Adults 21+ (enforced at sign-up). PRD personas: home entertainers, and 21 to 30 beginners | `docs/PRD.md` |
| First-run funnel | Install, Entra sign-up with age check, paywall, start trial, initial DB sync | `main.dart` router, `paywall_screen.dart` |
| Analytics today | **None that leave the device.** Paywall events (`PaywallShown`, `PaywallPurchaseCompleted`, ...) go only to `developer.log` | `paywall_screen.dart` |
| Deep links | `https://share.mybartenderai.com/cocktail/{id}` (verified App Links), `mybartender://cocktail` | `AndroidManifest.xml` |

The last two rows of the funnel matter most here. Google can't optimize toward a trial it never hears about.

### Unit economics (assumptions: replace with real numbers)

Google takes 15% of subscription revenue. Variable AI cost per subscriber is small (voice is about $0.015/min, capped at 60 min/month).

| Step | Assumption | Result |
|---|---|---|
| Net monthly sub | $3.99 × 0.85 | $3.39/month |
| Net annual sub | $39.99 × 0.85 | $33.99/year |
| Monthly subscriber lifetime | 4 months (guess) | about $13.50 |
| Plan mix | 70% monthly / 30% annual (guess) | **about $20 first-year net per paying subscriber**, about $18 after AI costs |
| Trial to paid | 40% (opt-out trials with a card up front often run 35 to 60%) | **about $7 value per trial start** |
| Install to sign-up | 60% (guess) | |
| Sign-up to trial | 25% (guess, hard paywall) | **15% install to trial, about $1.05 value per install** |

**What this means**: break-even is about **$7 per trial** or **about $1 per install**. US Android CPIs for lifestyle apps commonly run $1 to $3, so buying installs blindly loses money. Bidding on actions after the install is not optional. The single number that decides whether paid acquisition works is **trial to paid**. Pull it from RevenueCat (Charts, Trial Conversion) before day 30.

---

## 3. Policy constraints (read before building anything)

Google's [Alcohol policy](https://support.google.com/adspolicy/answer/6012382?hl=en) allows "alcohol recipes" as accessory content, and the US, UK, Canada and Australia are allowed countries. But the policy also says:

- **"Alcohol ads are not allowed in app install image or video formats"**, along with discovery ads, consumer ratings annotations and Gmail ads. If Google classifies this app's ads as alcohol, the image and video assets will likely be disapproved or limited, and delivery leans toward Search and Google Play text placements.
- Ads must not target or appeal mainly to people under the legal purchase age. No minors drinking, and no themes, characters or music that mainly appeal to minors.
- No suggestion that alcohol improves social, sexual, sporting or mental success or removes inhibitions. No encouragement of excessive drinking. No drinking before activities that need sobriety. No emphasis on high strength.

[Alcohol in personalized advertising](https://support.google.com/adspolicy/answer/16701854?hl=en) treats alcohol as a sensitive interest category: **no advertiser-curated audiences** (Customer Match, your data segments, audience expansion, lookalikes). In practice:

- **App engagement (re-engagement) campaigns aimed at lapsed trials are probably not available.** Plan on win-back through Today's Special notifications and email instead.
- Google's own predefined audiences are still allowed.

**How to handle it**

1. Build the text assets first (section 6). They are the part guaranteed to serve.
2. Upload images and videos anyway, then check each asset's policy status 24 to 48 hours later (Ad assets, Status column).
3. If an asset is disapproved for Alcohol, appeal once only if it really doesn't promote alcohol. Otherwise remove it. **Don't try to disguise the product to get past review.** Repeated violations can suspend the account, which would also hurt Clique Pix if it shares the account.
4. If video can't run in the app campaign, use it organically (YouTube Shorts, Play listing promo video, creator posts) instead.

I could not confirm from documentation how Google will classify this particular app. The first week of the campaign will tell us. Write down what the policy status shows.

---

## 4. Step 0: Fix the current campaign and measurement (week 0, no spend)

### 4a. The existing campaign

The screenshot from Oct 30 shows: campaign **My AI Bartender**, Ad group 1, Enabled, status **Not eligible**, **budget 0.0**, **Target CPA $2.00**, and the banner "None of your ads are running", with ads paused.

Do this:

1. **Find out what the $2.00 CPA is aimed at.** Open Goals, Conversions, Summary. If the only action is "Google Play install" or "Google Play in-app purchase", a $2 target either buys junk installs or is too low to ever win a trial.
2. **Leave this campaign paused, or remove it.** Google's guidance is to start a **new** campaign for a new goal rather than edit an old one, because a goal change resets learning anyway. Name the new one by convention (section 5).
3. **Check Billing.** "Not eligible" plus a 0 budget can also hide a missing payment method. Billing, Summary must show an active payment profile.
4. **Check Policy Manager** (Tools, Policy manager) for any alcohol-related disapproval already on the account.

### 4b. Link accounts

| Link | Where | Why |
|---|---|---|
| Google Play to Google Ads | Play Console, Setup, Linked services (or Google Ads, Tools, Linked accounts) | Installs and first Play purchases are measured automatically, with no SDK ([doc](https://support.google.com/google-ads/answer/6255257?hl=en)) |
| Firebase (GA4) to Google Ads | Firebase console, Project settings, Integrations, Google Ads | Imports `sign_up` and `trial_start` as conversions |
| Firebase to Google Play | Firebase console, Integrations, Google Play | Play revenue and installs in GA4 |

Play linking alone has gaps for us. It measures installs and in-app purchases, but "subscriptions record only the first purchase and its first payment value". It isn't clear that a $0 trial start registers as a purchase at all, and it can't see sign-up. So the app needs an analytics SDK.

### 4c. App instrumentation (code change, separate PR)

Add the Firebase Analytics SDK only (no Firebase backend; Azure stays the backend):

- `firebase_core` and `firebase_analytics` in `pubspec.yaml`, plus `google-services.json` (Android) and `GoogleService-Info.plist` (iOS, for later). Check the current versions with Context7 when implementing.
- Log these events (the paywall's `developer.log` lines show exactly where):

| Event | When | Fire from | Google Ads use |
|---|---|---|---|
| `first_open` | automatic | SDK | secondary (observation only) |
| `sign_up` | first successful sign-in on a new account (age check passed) | auth flow, after Entra sign-in | **primary at launch** |
| `paywall_view` | `/paywall` shown | `PaywallShown` site | secondary |
| `trial_start` | purchase completed with an intro or trial period | `PaywallPurchaseCompleted` site when `_showTrialCta` was true | **primary in phase 2** |
| `purchase` (with `value`, `currency`) | trial converts or a direct paid purchase | RevenueCat to Firebase integration (server side) | phase 3 (tROAS) |

- **RevenueCat**: turn on the [Firebase integration](https://www.revenuecat.com/docs/integrations/third-party-integrations/firebase-integration) and call `Purchases.setFirebaseAppInstanceID(...)` after Firebase starts. It sends `rc_trial_start`, `purchase` (renewals carry `is_trial_conversion: true`), `rc_cancellation` and `rc_expiration` with revenue. Pick **one** source for trial start as the Google Ads primary conversion (the client-side `trial_start` is faster; `rc_trial_start` is more trustworthy) and keep the other secondary, so trials aren't counted twice.
- **Compliance follow-ups** (they block a release if forgotten):
  - Play Console **Data safety**: add "App interactions" and "Device or other IDs" (advertising ID), collected and shared for analytics and advertising.
  - `com.google.android.gms.permission.AD_ID`: Firebase Analytics adds it through manifest merge. Answer the Play Console "Advertising ID" declaration as **Yes**.
  - **Privacy policy** (`website/privacy.html`, `docs/PRIVACY_POLICY.md`): name Google Analytics for Firebase and Google Ads measurement.
  - Consent: US-only targeting needs no Consent Mode at launch. Before adding the UK or EU, implement Consent Mode v2.
- Verify in Firebase **DebugView** that each event fires once per real action, then mark `sign_up` as a conversion in GA4 and import it into Google Ads.

---

## 5. Campaign structure and bidding

### 5a. Structure

Keep it to **one campaign at a time** until it is spending its whole budget profitably. Several small campaigns split an already thin conversion volume.

| | Phase 1 (launch) | Phase 2 | Phase 3 (optional) |
|---|---|---|---|
| Name | `MBA-AND-US-ACi-SignUp-tCPA` | `MBA-AND-US-ACi-Trial-tCPA` | `MBA-AND-US-ACi-Value-tROAS` |
| Type | App campaign, App installs subtype | same | same |
| Optimize for | In-app actions: `sign_up` | In-app actions: `trial_start` | In-app action value |
| Bid strategy | Target CPA (Maximize conversions with no target for the first ~7 days is fine) | Target CPA | Target ROAS |
| Locations | United States (presence only) | US, then add Canada | US, CA, then UK and AU (with Consent Mode) |
| Language | English | English | English |
| Ad groups | 1 to 2 (section 6) | 2 to 3 themes | same |
| Budget | $30/day | ≥ 10× tCPA (about $70/day) | scale-dependent |

**Why not "Install volume"?** Google's own example sizes tCPI from install-to-purchase economics, and ours are about $1 per install. The cheapest installs come from AdMob game placements, and those users don't create an account. Use Install volume only as a fallback, if `sign_up` can't reach 10 a day at an affordable budget. Even then choose **"Users likely to perform an in-app action"**, with a tCPI about 20% above an "All users" baseline, per [Google's goal guide](https://support.google.com/google-ads/answer/6167156?hl=en).

**Why `sign_up` first instead of `trial_start`?** Google wants the optimization event to be completed by **at least 10 different users per day** in the campaign. At a $30/day budget, trials will be around 3 to 5 a day. Sign-ups will be roughly 4× that. Sign-up is the closest common event to the trial, and it has already passed the 21+ age check, which is a useful quality filter in its own right.

### 5b. Starting targets

| Bid | Starting target | Rationale |
|---|---|---|
| Phase 1 tCPA (`sign_up`) | **$2.50 to $3.00**, or no target for week 1 and then set it to the observed CPA | Value per sign-up is about $7 × 25% sign-up to trial ≈ $1.75 at break-even. Start higher so it learns, then step down. Accept losing money on the first 60 days of learning, and budget it as research. |
| Phase 2 tCPA (`trial_start`) | **$6 to $7** | Under the ~$7 value per trial |
| Phase 3 tROAS | Start at observed ROAS, not the goal | Setting it too high starves delivery |

Budget rules from [Google's App campaign best practices](https://support.google.com/google-ads/answer/14104492?hl=en): daily budget **≥ 10× tCPA** for in-app action campaigns, and **≥ 50× tCPI** for install campaigns. At $30/day, the highest tCPA that rule supports is $3. That is why phase 1 bids on `sign_up`.

### 5c. When to switch (gates)

| From, to | Switch when **all** are true |
|---|---|
| Phase 0 to 1 | `sign_up` verified in DebugView and imported. Play linked. Billing active. At least 5 headlines and 5 descriptions approved |
| Phase 1 to 2 | ≥ 100 `sign_up` conversions on the campaign. Sign-up to trial rate measured (≥ 2 weeks of data). Trial to paid rate measured in RevenueCat. Budget of about $70/day affordable for 30 days |
| Phase 2 to 3 | ≥ 10 trial starts a day sustained, `purchase` values arriving from RevenueCat (net of Google's fee) **or** a per-plan predicted value on `trial_start`. Conversion window set to capture about 90% of value (under 30 days; the 7-day trial plus first charge fits) |
| Any, fallback | Phase 1 can't exceed 5 `sign_up`s a day after 3 weeks at $30/day: test Install volume with "users likely to perform an in-app action", or pause paid and work on the listing (section 7) |

**Value-based shortcut (phase 3 without waiting for renewals)**: send `trial_start` with a predicted value by plan, for example annual trial ≈ $33.99 × trial-to-paid rate and monthly trial ≈ $13.50 × trial-to-paid rate. That lets tROAS favor users who pick annual. Update the values quarterly from RevenueCat data.

### 5d. Learning-phase rules

- Wait for **7 to 14 days** and **about 100 conversions** before judging a new campaign or a significant change. Judge in-app action campaigns on 30-day windows, not daily swings.
- Change **one thing at a time**: bid, budget or assets. Move bids and budgets in steps of no more than about 15 to 20%, at most once a week.
- For a new goal, **start a new campaign**. Don't edit the conversion action on a running one.
- Watch the status column: "Limited by budget" means raise the budget or lower the tCPA. "Limited by target" (bid-constrained) means raise the tCPA.
- Swap the weakest asset ("Low" performance label) about every 2 weeks, never all of them at once.

---

## 6. Creative asset checklist

Specs from [App campaigns specs](https://support.google.com/google-ads/answer/17091671?hl=en). Aim for Ad Strength **"Good" or better**. Keep text in English to match the language targeting (Google doesn't translate it).

### Text (required, serves no matter how the alcohol policy applies)

**Headlines**: 5, ≤ 30 characters each

| # | Headline | Chars |
|---|---|---|
| 1 | Your AI Bartender, On Call | 26 |
| 2 | Hands-Free Voice Bartender | 26 |
| 3 | Scan Your Bar, Get Recipes | 26 |
| 4 | What Can I Make Tonight? | 24 |
| 5 | Try It Free for 7 Days | 22 |
| alt | 600+ Cocktails, Works Offline | 29 |

**Descriptions**: 5, ≤ 90 characters each

| # | Description | Chars |
|---|---|---|
| 1 | Ask a live voice bartender what to make, then mix along hands-free, step by step. | 81 |
| 2 | Snap a photo of your bottles and get cocktails you can make tonight with what you have. | 87 |
| 3 | Over 600 classic and modern recipes that work offline, plus AI help to riff on any drink. | 89 |
| 4 | 7-day free trial, then $3.99/month or $39.99/year. Cancel anytime in Google Play. | 81 |
| 5 | Learn real bar technique and build a better home bar. For adults 21 and over. | 77 |

Description 4 is deliberate. It costs some clicks and saves money: people who won't pay $3.99 after a trial filter themselves out before you pay for their install.

Copy rules: nothing about getting drunk, partying harder, confidence, attraction or "impressing" people. Nothing about strength. Use "home bartending", "technique" and "what to make" framing.

### Images (optional; may be limited by the alcohol policy)

| Ratio | Size | Count |
|---|---|---|
| Landscape 1.91:1 | 1200 × 628 | 3+ |
| Square 1:1 | 1200 × 1200 | 3+ |
| Portrait 4:5 | 1200 × 1500 | 3+ |

JPG or PNG, ≤ 5 MB. Up to 20 of each. Content: **real app UI** (the voice screen with a live transcript, a scanner result listing found bottles, a recipe card) on a dark brand background with a 4 to 6 word caption. Put the product in hands and on bar tops, not people drinking. No faces that could read as under 25.

### Video (optional; may be limited by the alcohol policy; uploaded to YouTube, unlisted is fine)

| Orientation | Length | Count |
|---|---|---|
| Vertical 9:16 | 10 to 30 s (max 60) | 2+ (priority: Shorts) |
| Horizontal 16:9 | 15 to 30 s | 1+ |
| Square 1:1 | 15 s | 1+ |

Suggested scripts (screen recording plus voiceover, phone-shot is fine):

1. **"What can I make?"** (15 s): pan across 4 bottles, Smart Scanner identifies them, 3 cocktail cards appear. End card: "7-day free trial".
2. **"Talk to your bartender"** (20 s): hands busy shaking, user asks by voice "What's next?", the app answers. Hook in the first 2 seconds: the question spoken out loud.
3. **"Offline vault"** (10 s): scroll the 600+ recipes in airplane mode.

### HTML5

Skip in phases 1 and 2. It adds production work, and it is display inventory that the alcohol policy is likely to restrict.

### Ad groups

- **Phase 1**: 1 ad group (everything above).
- **Phase 2**: split into **Voice** (headlines 1, 2 and voice video) and **Scanner / What can I make** (headlines 3, 4 and scanner video), each pointing to a matching Custom Store Listing (section 7) if Play allows linking CSLs to App campaign ad groups. Check the ad group "Store listing" option when you set it up.

---

## 7. Store listing (ASO) changes that affect ad performance

App campaigns send most people to the Play listing, and Google uses listing conversion and post-install quality as signals. Fix these **before** spending.

| # | Change | Why it matters for ads |
|---|---|---|
| 1 | **State the model in the short description (80 chars)**, for example: "Voice AI bartender + bar scanner. 7-day free trial, then subscription." | Pre-qualifies installers. A hard-paywall surprise produces uninstalls and 1-star reviews, which Play's AI review summaries now amplify. `DEPLOYMENT_STATUS.md` already flags this as a submission requirement |
| 2 | **Title (30 chars)**: keep the brand and add one keyword if there's room, for example "My AI Bartender: Cocktails" (26) | Search placements match on listing text |
| 3 | **First 2 screenshots = the two ad hooks**: (1) voice bartender, (2) scan your bar. Caption: 4 to 6 words, top third. Portrait 1080 × 1920 | Matches what the ad promised. Mismatch kills install rate |
| 4 | **Feature graphic 1024 × 500** and **promo video** (reuse the vertical ad video if it's free of policy issues) | Shown on many Play surfaces. Video autoplay lifts conversion |
| 5 | **Full description (4000 chars)**: lead with a 2-line plain-language summary an LLM can quote. Include a "Pricing" paragraph (trial, $3.99, $39.99, cancel in Play) and "For adults 21+" | Policy clarity and conversational-AI discovery |
| 6 | **Store listing experiment** (Play Console, Grow, Store listing experiments): test one variable at a time, screenshot 1 first. Run 7+ days at 50/50 | Every listing conversion point lowers effective CPI |
| 7 | **Custom Store Listings** (phase 2): one for "Voice" and one for "Scanner", matching the ad groups | Message match between ad and listing |
| 8 | **Ratings**: reply to every review from the last 90 days, especially paywall complaints ("it's not free"). The in-app review system (`docs/IN_APP_REVIEW_SYSTEM.md`) already prompts only after win moments; keep it that way | Rating shows in the ad on Play and affects install rate |
| 9 | **Content rating / target audience** in Play Console: confirm "alcohol references" and an adult target age group are set | Consistency with the ads' age requirements, and avoids policy flags |
| 10 | **Android vitals**: crash and ANR rate below Play's bad-behavior thresholds before launch | Paid users who hit crashes rate low. Play also demotes on vitals |

Baseline to record before launch (Play Console, Grow, Store performance): **store listing visitors**, **acquisition (install) conversion rate**, by traffic source. That separates "the ad is bad" from "the listing is bad" later.

---

## 8. 30 / 60 / 90-day measurement plan

### Fill in before day 0 (Gene)

| Metric | Where | Value |
|---|---|---|
| Play listing conversion rate (visitors to installs), last 30 days | Play Console, Store performance | ___ |
| Installs a day (organic) | Play Console | ___ |
| Install to sign-up % | Firebase (after 4c) or Entra sign-ups ÷ installs | ___ |
| Paywall to trial % | RevenueCat, Charts, Initial Conversion | ___ |
| Trial to paid % | RevenueCat, Charts, Trial Conversion | ___ |
| Monthly vs annual mix | RevenueCat | ___ |
| Monthly subscriber retention (month 2, 3) | RevenueCat, Subscription Retention | ___ |
| D1 / D7 retention | Play Console, Retained installers, or Firebase | ___ |

### Weekly dashboard (one row per week; Sheets or Docs is fine)

Spend · impressions · installs · CPI · `sign_up` · cost per sign-up · `trial_start` · cost per trial · trials converted to paid (lagged 7 days) · cost per paid sub · Play listing conversion rate · new 1-star reviews mentioning "paywall/free".

### Days 0 to 30: Instrument, launch, learn

- Week 0: everything in section 4, and the listing changes 1 to 5 from section 7. Record baselines.
- Day 1: launch phase 1 at $30/day. Check the policy status of every asset after 48 hours and record how the alcohol policy applied.
- Days 1 to 14: **don't touch bids.** Fix only disapprovals and broken tracking.
- Day 14: first read. Is `sign_up` ≥ 10 a day? Is CPA within 2× of target? Is install to sign-up for paid users close to organic (if it's far lower, placements are junk)?
- Day 30 **decision**: continue if cost per trial ≤ $10 and trending down. Otherwise make one change (tCPA, or replace the 2 weakest assets) and run 14 more days.
- Start a Play store listing experiment (screenshot 1).

### Days 31 to 60: Tune toward trials

- First real trial to paid cohort from paid users (trials started days 1 to 30). Compare with organic. **If paid users convert at under half the organic rate, the campaign is buying the wrong people.** Revisit creative and the pricing disclosure before spending more.
- Lower tCPA in ≤ 15% steps while volume holds.
- Add ad group 2 (Voice vs Scanner) and Custom Store Listings.
- Day 60 **decision**: if ≥ 10 trials a day are affordable and cost per trial ≤ about $7, launch phase 2 as a **new** campaign. Run phase 1 alongside it for 2 weeks, then shift budget over. If not, hold at phase 1 or pause paid and put the money into listing and creator content.

### Days 61 to 90: Prove payback

- Cost per **paid** subscriber vs first-year net value (about $18). Target ≤ 1.0× for continued spend, ≤ 0.6× to scale.
- If profitable: increase budget by ≤ 20% a week, and add Canada (same policy, same language).
- If annual mix from paid users is high: set up predicted-value `trial_start` and test phase 3 tROAS in a new campaign.
- Day 90 **decision**: scale, hold, or stop. Write the outcome into this doc (section 9).

### Kill criteria (stop spend and fix the product or listing first)

- Cost per trial > 2× value per trial ($14+) after 30 days and 2 rounds of changes.
- Paid trial to paid < 20%.
- Rating drops below 4.0 or 1-star "paywall" reviews spike during the campaign.

---

## 9. Decision log

| Date | Decision | Data behind it |
|---|---|---|
| 2026-10-30 | Plan written. Existing campaign (budget 0, tCPA $2, ads paused, never served) to stay paused and be replaced by `MBA-AND-US-ACi-SignUp-tCPA` after measurement is in place | Screenshot of Google Ads, Oct 23 to 29: $0 cost, 0 conversions |

---

## References

- Google Ads: [Best practices for App campaigns](https://support.google.com/google-ads/answer/14104492?hl=en)
- Google Ads: [Set up App campaigns depending on your goal](https://support.google.com/google-ads/answer/6167156?hl=en)
- Google Ads: [App campaigns specs and format requirements](https://support.google.com/google-ads/answer/17091671?hl=en)
- Google Ads: [Measure app conversions with Google Play](https://support.google.com/google-ads/answer/6255257?hl=en)
- Google Ads policy: [Alcohol](https://support.google.com/adspolicy/answer/6012382?hl=en) and [Alcohol in personalized advertising](https://support.google.com/adspolicy/answer/16701854?hl=en)
- RevenueCat: [Firebase integration](https://www.revenuecat.com/docs/integrations/third-party-integrations/firebase-integration)
