# Product Requirements Document (PRD)

## My AI Bartender

**Document Version**: 2.2
**Last Updated**: January 1, 2026
**Product Owner**: Gene Whitley
**Status**: Release Candidate

---

## Executive Summary

My AI Bartender is an AI-powered mobile bartending assistant that helps users discover, create, and perfect cocktails based on their available ingredients. The app combines a comprehensive offline cocktail database with premium AI features including conversational recommendations, voice-guided instruction, and visual inventory scanning.

### Product Vision

To be the definitive mobile bartending companion that makes craft cocktail creation accessible to everyone, from beginners to enthusiasts, through intelligent AI assistance and an offline-first experience.

### Key Differentiators

1. **Offline-First Design**: Full cocktail database (~621 drinks) available without internet
2. **Cost-Optimized AI**: GPT-4.1-mini for text, Claude Haiku for vision, Azure OpenAI Realtime for voice
3. **Single Subscription**: $9.99/mo or $99.99/yr with 3-day free trial
4. **Voice Guidance**: Real-time voice conversation with AI bartender via WebRTC (subscribers)
5. **Privacy-Focused**: JWT-only authentication, minimal PII collection

---

## Business Objectives

### Primary Goals

1. **Launch MVP** on Android by Q4 2025
2. **Acquire 1,000 users** in first 3 months
3. **Convert 10%** to paid subscribers
4. **Maintain 90% profit margin** on subscription revenue
5. **Achieve 4.5+ star** rating on Play Store

### Success Metrics

| Metric          | Target (3 months) | Target (6 months) | Target (12 months) |
| --------------- | ----------------- | ----------------- | ------------------ |
| Total Users     | 1,000             | 5,000             | 20,000             |
| Subscribers     | 100               | 500               | 2,500              |
| Monthly Revenue | $1,000            | $5,000            | $25,000            |
| Churn Rate      | <15%              | <10%              | <8%                |
| App Rating      | 4.5+              | 4.6+              | 4.7+               |

### Financial Model

**Monthly Revenue Projections (1,000 users):**

- Subscribers (100 @ $9.99): $999
- Voice add-on purchases: ~$50
- **Total Revenue**: ~$1,049/month

**Monthly Costs:**

- Infrastructure (APIM Basic V2 + Functions + DB): ~$200
- AI Services (GPT-4.1-mini + Claude Haiku + Realtime API): ~$80
- **Total Costs**: ~$280/month
- **Profit**: ~$769/month (73% margin)

**At Scale (10,000 users):**

- Revenue: ~$10,000/month
- Costs: ~$800/month
- **Profit**: ~$9,200/month (92% margin)

---

## Target Audience

### Primary Personas

#### 1. **Emma the Enthusiast** (Primary Target - Subscriber)

- **Age**: 28-35
- **Occupation**: Young professional
- **Income**: $60k-90k
- **Behavior**: 
  - Hosts dinner parties 2-3x/month
  - Enjoys craft cocktails but intimidated by complexity
  - Active on Instagram, Pinterest
  - Willing to pay for quality experiences
- **Pain Points**:
  - Overwhelmed by cocktail recipes
  - Doesn't know what to make with home bar ingredients
  - Wants to impress guests but lacks confidence
- **Goals**: 
  - Create impressive cocktails at home
  - Build bartending skills progressively
  - Save money vs. going to bars ($15/drink)

#### 2. **Mark the Beginner** (Secondary - Free to Subscriber)

- **Age**: 21-30
- **Occupation**: College student / Early career
- **Income**: $0-50k
- **Behavior**:
  - New to cocktails, learning basics
  - Budget-conscious
  - Uses mobile for everything
  - Shares on social media
- **Pain Points**:
  - Doesn't know where to start
  - Limited budget for ingredients
  - Intimidated by bartending jargon
- **Goals**:
  - Learn to make simple cocktails
  - Impress friends at parties
  - Eventually build a home bar

#### 3. **Sarah the Sommelier** (Tertiary - Power User)

- **Age**: 35-50
- **Occupation**: Professional bartender / Mixologist
- **Income**: $50k-80k
- **Behavior**:
  - Creates custom cocktail menus
  - Experiments with unusual ingredients
  - Teaches cocktail classes
  - Active in bartending community
- **Pain Points**:
  - Needs inspiration for custom creations
  - Time-consuming to develop new recipes
  - Wants to document and share recipes
- **Goals**:
  - Develop signature cocktails
  - Streamline recipe development
  - Build professional reputation

---

## Product Features

### Core Features (No Subscription Required)

#### 1. Today's Special

**Description**: Daily featured cocktail with push notification reminders.

**Functional Requirements**:

- FR0.1: Select random cocktail each day at midnight (local time)
- FR0.2: Persist selection across app restarts using SharedPreferences
- FR0.3: Display prominently on home screen with cocktail image and name
- FR0.4: Schedule daily push notification at configurable time (default 5:00 PM)
- FR0.5: Deep link from notification to cocktail detail screen
- FR0.6: Work offline once cocktail data is downloaded

**User Stories**:

- As Emma, I want a daily drink suggestion so I have inspiration for happy hour
- As Mark, I want notification reminders so I don't forget to try new cocktails

**Acceptance Criteria**:

- Same cocktail shown all day until midnight
- Notification fires reliably even if app is closed
- Tapping notification opens cocktail detail screen
- Works on Android with battery optimization exemption

#### 2. Offline Cocktail Database

**Description**: Complete database of ~621 cocktails with recipes, images, and instructions.

**Functional Requirements**:

- FR1.1: Download and store full cocktail database locally
- FR1.2: Search by name, ingredient, or category
- FR1.3: Filter by glass type, alcohol type, difficulty
- FR1.4: View detailed recipe with measurements, instructions, images
- FR1.5: Work 100% offline after initial download
- FR1.6: Auto-update when new snapshot available (background sync)

**User Stories**:

- As Emma, I want to browse cocktails offline so I can plan drinks for my party without using data
- As Mark, I want to search for cocktails I can make with vodka so I can use the bottle I have

**Acceptance Criteria**:

- Database downloads in <10 seconds on 10 Mbps connection
- Search returns results in <100ms p95
- All 621 drink images stored locally
- Filters work instantly without network

### Subscriber Features ($9.99/month or $99.99/year)

All features below require an active subscription (3-day free trial available on monthly plan).

#### 2. AI Bartender Chat (1,000,000 tokens/month)

**Description**: Conversational AI assistant for cocktail guidance and recommendations.

**Functional Requirements**:

- FR2.1: Unlimited natural language queries (up to 1M tokens/month)
- FR2.2: Context-aware recommendations based on inventory
- FR2.3: Ingredient substitution suggestions
- FR2.4: Cocktail history tracking
- FR2.5: Personalized learning of preferences

**User Stories**:

- As Emma, I want to ask "What can I make with gin and lemon?" and get immediate suggestions
- As Mark, I want the AI to remember I don't like sweet drinks

**Acceptance Criteria**:

- Response time <2.5 seconds p95
- Recommendations use user's stated inventory
- Conversation history saved for session
- Preferences learned and applied

#### 3. Smart Scanner (100 scans/month)

**Description**: AI-powered bar inventory scanning using Claude Haiku vision model.

**Functional Requirements**:

- FR3.1: Capture photo of bar or bottles
- FR3.2: Claude Haiku analyzes image and identifies bottles
- FR3.3: Add detected items to inventory with confidence scores
- FR3.4: Manual correction/addition of missed items
- FR3.5: Track scan usage against monthly limit

**User Stories**:

- As Emma, I want to photograph my bar so the app knows what I can make
- As Mark, I want quick inventory updates without typing each bottle

**Acceptance Criteria**:

- Detection completes in <5 seconds
- Identifies common spirit brands accurately
- Allows manual editing of results
- Provides confidence scores

**Technical Implementation**:

- Claude Haiku (Anthropic) for vision analysis
- Base64 image encoding for API call
- Cost: ~$0.01 per scan

#### 4. Custom Recipes (Unlimited)

**Description**: Full custom recipe storage with AI refinement.

**Functional Requirements**:

- FR4.1: Unlimited custom recipe storage
- FR4.2: AI-enhanced recipe suggestions via Create Studio
- FR4.3: Recipe sharing via Friends via Code
- FR4.4: Recipe collections/categories

**User Stories**:

- As Emma, I want to organize recipes by season or occasion
- As Sarah, I want AI to help improve my recipe ratios

#### 5. Voice AI Bartender (60 minutes/month)

**Description**: Real-time voice conversation with AI bartender using Azure OpenAI Realtime API.

**Functional Requirements**:

- FR8.1: Press button to start voice session
- FR8.2: Natural voice conversation with AI bartender
- FR8.3: Real-time responses via WebRTC
- FR8.4: Hands-free cocktail guidance
- FR8.5: Track usage against 60-minute monthly limit (active speech time only)
- FR8.6: Option to purchase additional voice minutes (60 min for $5.99)

**User Stories**:

- As Sarah, I want to use voice mode during my cocktail classes
- As Emma, I want voice guidance for my monthly dinner parties

**Acceptance Criteria**:

- Sub-second latency via WebRTC
- Natural conversational flow
- Clear indication of remaining minutes
- Works with screen off

**Technical Implementation**:

- Azure OpenAI Realtime API with gpt-realtime-mini
- WebRTC for low-latency audio streaming
- Ephemeral session tokens from `voice-session` function
- Cost: ~$0.06/min input, ~$0.24/min output

#### 6. Voice Add-On Purchase ($5.99 for 60 minutes)

**Description**: Subscribers can purchase additional voice minutes.

**Functional Requirements**:

- FR6.1: Purchase 60 minutes of voice AI for $5.99
- FR6.2: Minutes never expire (carry over indefinitely)
- FR6.3: Google Play Billing consumable purchase
- FR6.4: Included minutes consumed first, then purchased balance

**User Stories**:

- As Emma, I want to buy extra voice minutes for my dinner party
- As Sarah, I want to stock up on voice minutes for cocktail classes

**Acceptance Criteria**:

- Purchase completes in <3 seconds
- Minutes credited immediately after verification
- Clear display of included vs. purchased minutes remaining

---

## Technical Architecture

### Infrastructure (Azure)

#### API Gateway

- **Service**: Azure API Management (`apim-mba-002`)
- **Location**: South Central US
- **Gateway URL**: https://apim-mba-002.azure-api.net
- **Tier**: Basic V2 (~$150/month)
- **Purpose**: JWT validation, rate limiting, backend routing

#### Backend Compute

- **Service**: Azure Functions (`func-mba-fresh`)
- **Plan**: Premium Consumption (Elastic Premium)
- **Runtime**: Node.js 22
- **URL**: https://func-mba-fresh.azurewebsites.net (behind APIM)

#### Database

- **Service**: Azure Database for PostgreSQL
- **Instance**: `pg-mybartenderdb`
- **Tier**: Basic (MVP) → Flexible Server (Production)
- **Purpose**: Authoritative cocktail data, user data, usage tracking

#### Storage

- **Service**: Azure Blob Storage
- **Account**: `mbacocktaildb3`
- **Containers**:
  - `/snapshots` - Zstandard-compressed JSON database snapshots (~172KB)
  - `/drink-images` - Cocktail images (~621 images)
- **Access**: Managed Identity (RBAC)

#### Secrets Management

- **Service**: Azure Key Vault
- **Instance**: `kv-mybartenderai-prod`
- **Location**: `rg-mba-dev` resource group
- **Access**: Managed Identity with RBAC (Key Vault Secrets User role)
- **Contents**:
  - `AZURE-OPENAI-API-KEY` - Azure OpenAI API key
  - `AZURE-OPENAI-ENDPOINT` - Azure OpenAI endpoint
  - `CLAUDE-API-KEY` - Anthropic Claude API key (Smart Scanner)
  - `POSTGRES-CONNECTION-STRING` - Database connection
  - `SOCIAL-ENCRYPTION-KEY` - Social sharing encryption
  - `REVENUECAT-PUBLIC-API-KEY` - RevenueCat SDK initialization
  - `REVENUECAT-WEBHOOK-SECRET` - Webhook signature verification

#### AI Services

- **Text AI**: Azure OpenAI Service (GPT-4.1-mini)
  - Instance: `mybartenderai-scus` (South Central US)
  - Cost: ~$0.15/1M input tokens, ~$0.60/1M output tokens
  - Purpose: Recommendations, chat, recipe generation
- **Voice AI**: Azure OpenAI Realtime API (gpt-4o-realtime-preview)
  - Technology: WebRTC with ephemeral session tokens
  - Cost: ~$0.06/min input, ~$0.24/min output
  - Purpose: Real-time voice bartender conversation (subscribers)
- **Vision AI**: Claude Haiku (Anthropic)
  - Purpose: Smart Scanner - bottle/ingredient detection
  - Cost: ~$0.01 per scan

### Mobile Application

#### Framework

- **Platform**: Flutter 3.0+
- **Target OS**: Android (Phase 1), iOS (Phase 2)
- **Minimum SDK**: Android 7.0 (API 24), iOS 13.0

#### Architecture Pattern

- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Structure**: Feature-first clean architecture
- **Database**: SQLite (sqflite package)

#### Key Packages

- `dio` - HTTP client with JWT interceptors
- `flutter_secure_storage` - Secure token storage
- `flutter_appauth` - Entra External ID OAuth 2.0 + PKCE
- `jwt_decoder` - JWT token decoding
- `flutter_webrtc` - WebRTC for Voice AI
- `camera` - Photo capture for Smart Scanner

### Data Flow

#### Cocktail Database Sync

```
1. PostgreSQL (authoritative source)
   ↓
2. Generate JSON snapshot (Zstandard compressed, ~172KB)
   ↓
3. Upload snapshot to Azure Blob Storage
   ↓
4. Mobile requests snapshot via APIM (JWT authenticated)
   ↓
5. Download, verify SHA256, store in local SQLite
```

**Note**: Timer-triggered sync from TheCocktailDB is DISABLED. Using static database copy.

#### AI Recommendation Flow (JWT-Only Authentication)

```
1. User query in mobile app
   ↓
2. Mobile → APIM (Authorization: Bearer <JWT>)
   ↓
3. APIM validate-jwt policy verifies token
   ↓
4. Forward to Function App with X-User-Id header
   ↓
5. Function checks user entitlement in PostgreSQL
   ↓
6. Function → GPT-4.1-mini (Azure OpenAI)
   ↓
7. Response → Function → APIM → Mobile
```

#### Voice AI Flow (Subscribers Only)

```
1. User presses Voice Bartender button
   ↓
2. Mobile → voice-session function (JWT authenticated)
   ↓
3. Function validates paid entitlement, returns ephemeral WebRTC token
   ↓
4. Mobile connects directly to Azure OpenAI Realtime API
   ↓
5. Real-time voice conversation via WebRTC
   ↓
6. Session ends, usage tracked in PostgreSQL
```

---

## User Experience

### Onboarding Flow

#### First Launch

1. **Welcome Screen**
   - Value proposition
   - "Get Started" CTA
2. **Feature Tour**
   - Swipeable cards showing key features
   - Skip option
3. **Database Download**
   - Progress indicator
   - "Why offline?" explanation
4. **Subscription Prompt**
   - Feature overview for subscribers
   - "Start 3-day free trial" CTA
5. **Optional Sign-In**
   - Sign in required for subscription features
   - Local features work without sign-in

#### Subscription Upgrade Flow

1. **Trigger Points**:
   - Attempt subscriber feature (voice/vision/AI chat)
   - From settings menu
2. **Subscribe Screen**:
   - Feature list (voice, AI, scanner, custom recipes)
   - Monthly ($9.99) and Annual ($99.99) options
   - "Start 3-Day Free Trial" CTA (monthly)
   - Compliance text about trial auto-conversion
3. **Payment**:
   - Google Play / App Store via RevenueCat
   - Instant activation

### Core User Flows

#### Find a Cocktail (Free)

```
Home → Search/Browse → Select Drink → View Recipe → Make It
```

- **Time**: 30 seconds
- **Touches**: 3-4
- **Network**: None required

#### AI Recommendation (Subscribers)

```
Home → Ask Bartender → Type/Speak Query → View Suggestions → Select → Make It
```

- **Time**: 15 seconds
- **Touches**: 2-3
- **Network**: Required

#### Voice-Guided Making (Subscribers)

```
Home → Select Drink → Start Voice Mode → Follow Instructions → Complete
```

- **Time**: 5-10 minutes (depending on cocktail)
- **Interaction**: Voice only
- **Network**: Required for initial query, then optional

#### Inventory Scanning (Subscribers)

```
Home → My Bar → Scan → Capture Photo → Review Detected → Confirm → Updated
```

- **Time**: 30 seconds
- **Touches**: 4-5
- **Network**: Required

### UI/UX Principles

#### Design Language

- **Style**: Modern, clean, premium feel
- **Colors**: 
  - Primary: Deep Navy (#1a2332)
  - Accent: Gold (#d4af37)
  - Background: Off-white (#f8f9fa)
- **Typography**: 
  - Headers: Playfair Display (serif, elegant)
  - Body: Inter (sans-serif, readable)
- **Imagery**: High-quality cocktail photography

#### Key Screens

**Home Screen**:

- Large hero image (cocktail of the day)
- Quick actions: Search, Ask AI, My Bar, Favorites
- Featured collections (e.g., "Classic Cocktails", "Summer Drinks")
- Subscribe prompt (if not subscribed)

**Search/Browse**:

- Prominent search bar
- Category filters (pills)
- Grid of cocktail cards with images
- Quick add to favorites

**Cocktail Detail**:

- Large hero image
- Name and description
- Ingredients list with measurements
- Step-by-step instructions
- "Start Voice Mode" button (Subscribers)
- Save to favorites
- Share button

**AI Chat**:

- Chat interface with bubbles
- Voice input button
- Quick suggestions ("What's refreshing?", "Use my bar")
- Conversation history
- Quota indicator at top

**My Bar**:

- List of current inventory
- "Scan Bar" button (Subscribers)
- Manual add option
- "What can I make?" button
- Shopping list (future)

**Settings**:

- Account info
- Subscription management
- Notification preferences
- Database update
- Feedback/support

---

## Business Model

### Monetization Strategy

#### Subscription Model

- **Free (No Subscription)**: Full offline database only
- **Paid Subscription**: All AI features, voice, scanner, unlimited recipes ($9.99/mo or $99.99/yr)
- **Voice Add-On**: +60 minutes for $5.99 (subscribers only)

#### Revenue Streams

1. **Primary**: Subscription revenue (95% of revenue)
2. **Secondary** (Future): 
   - Affiliate links to liquor retailers (5%)
   - Sponsored cocktails from brands
   - Premium recipes from professional bartenders

### Pricing Strategy

#### Competitive Analysis

| Competitor        | Price           | Features                          |
| ----------------- | --------------- | --------------------------------- |
| Cocktail Flow     | $4.99/mo        | AI recommendations, no voice      |
| Mixel             | Free + $9.99/mo | Large database, basic AI          |
| Highball          | $2.99/mo        | Simple recipes, no AI             |
| **MyBartenderAI** | **$9.99/mo**    | **AI + Voice AI + Smart Scanner** |

#### Value Proposition

- **vs. Cocktail Flow**: Same price, adds voice guidance
- **vs. Mixel**: Half the price, more AI features
- **vs. Highball**: 66% more expensive, but 10x more features
- **vs. Going to bars**: Save $15/drink, pays for itself in 1 drink

### Customer Acquisition

#### Marketing Channels

1. **Organic** (40% of users):
   
   - App Store Optimization (ASO)
   - Content marketing (blog, YouTube)
   - Social media (Instagram, TikTok)
   - Word of mouth

2. **Paid** (30% of users):
   
   - Google Ads (search: "cocktail app")
   - Facebook/Instagram ads (targeting entertaining enthusiasts)
   - Influencer partnerships (bartenders, food bloggers)

3. **Partnerships** (20% of users):
   
   - Liquor brands (Diageo, Pernod Ricard)
   - Cocktail recipe sites (Liquor.com, Difford's Guide)
   - Bar equipment retailers

4. **PR** (10% of users):
   
   - Tech press (Product Hunt, TechCrunch)
   - Lifestyle media (Bon Appétit, Food & Wine)
   - App review sites

#### Launch Strategy

**Phase 1: Soft Launch (Month 1)**

- Android beta on Google Play (100 users)
- Collect feedback and iterate
- Bug fixes and polish

**Phase 2: Public Launch (Month 2)**

- Full Android release
- PR campaign
- Social media launch
- Initial paid advertising

**Phase 3: Growth (Months 3-6)**

- Influencer partnerships
- Paid acquisition scaling
- Content marketing
- Feature updates

**Phase 4: iOS Launch (Month 6)**

- iOS version release
- Cross-platform sync
- Renewed PR push

---

## Competitive Analysis

### Direct Competitors

#### Cocktail Flow

- **Strengths**: Clean UI, AI recommendations, large user base
- **Weaknesses**: No voice, expensive ($9.99/mo), limited offline
- **Our Advantage**: Voice guidance, lower price, better offline

#### Mixel

- **Strengths**: Huge database, social features, beautiful design
- **Weaknesses**: Clunky AI, no voice, expensive Pro tier
- **Our Advantage**: Better AI (GPT-4.1-mini), voice features, value

#### Highball

- **Strengths**: Simple, affordable, good for beginners
- **Weaknesses**: No AI, limited features, small database
- **Our Advantage**: Advanced AI, comprehensive features

### Indirect Competitors

#### Recipe Websites (Liquor.com, Difford's)

- **Strengths**: Free, huge content, trusted brands
- **Weaknesses**: Not mobile-optimized, no AI, no offline
- **Our Advantage**: Mobile-first, AI-powered, offline

#### YouTube Bartenders

- **Strengths**: Free, visual learning, personality-driven
- **Weaknesses**: Not searchable, no personalization, passive
- **Our Advantage**: Interactive, personalized, hands-free voice

---

## Go-to-Market Strategy

### Launch Timeline

#### Q4 2025: Development Complete ✅

- ✅ Core infrastructure (APIM Basic V2, Functions, Database)
- ✅ Flutter app development (offline database, search)
- ✅ AI integration (GPT-4.1-mini recommendations)
- ✅ Voice AI (Azure OpenAI Realtime API)
- ✅ Smart Scanner (Claude Haiku)
- ✅ Authentication (Entra External ID with age verification)
- ✅ Release candidate ready

#### Q1 2026: Launch & Growth

- **Month 1**: Android public launch on Google Play
- **Month 2**: User acquisition, feedback collection
- **Month 3**: iOS development begins

#### Q2 2026: iOS Launch

- **Month 4-5**: iOS app development
- **Month 6**: iOS app launch on App Store

### Success Criteria

#### Month 1 Post-Launch

- 100 downloads
- 10% conversion to Subscriber
- <5 critical bugs
- 4.0+ rating

#### Month 3 Post-Launch

- 1,000 downloads
- 10% conversion to Subscriber
- <2 critical bugs
- 4.5+ rating
- $500/month revenue

#### Month 6 Post-Launch

- 5,000 downloads
- 12% conversion to Subscriber
- 0 critical bugs
- 4.6+ rating
- $2,500/month revenue

#### Month 12 Post-Launch

- 20,000 downloads
- 15% conversion to Subscriber
- 4.7+ rating
- $15,000/month revenue
- iOS app launched
- Featured in App Store

---

## Technical Requirements

### Performance Requirements

#### Mobile App

- **Launch Time**: <2 seconds cold start
- **Search**: <100ms for local database queries
- **AI Response**: <2.5 seconds p95
- **Voice Latency**: <2 seconds end-to-end
- **App Size**: <100MB after initial download

#### Backend

- **API Latency**: <500ms p95 via APIM
- **Database**: <100ms query response time
- **Uptime**: 99.9% SLA
- **Snapshot Generation**: <3 minutes

### Scalability Requirements

#### Current (MVP)

- **Users**: 1,000
- **Requests**: ~10,000/day
- **Data**: 10GB storage
- **Cost**: $60-70/month

#### Near-term (6 months)

- **Users**: 10,000
- **Requests**: ~100,000/day
- **Data**: 50GB storage
- **Cost**: $200-300/month

#### Long-term (12 months)

- **Users**: 50,000
- **Requests**: ~500,000/day
- **Data**: 200GB storage
- **Cost**: $800-1,000/month

### Security Requirements

#### Authentication

- Entra External ID (mybartenderai.ciamlogin.com)
- JWT-only authentication (no APIM subscription keys on client)
- APIM validate-jwt policy validates signature, expiration, audience
- Social login (Google, Apple) + Email/Password
- Age verification (21+) via Custom Authentication Extension
- OAuth 2.0 + PKCE for mobile security

#### Data Protection

- All communication over HTTPS
- Encryption at rest (Azure Storage)
- No PII for non-subscriber users
- GDPR compliance
- User data export capability

#### Payment Security

- Google Play Billing (PCI-compliant)
- No credit card data stored
- Subscription receipts validated server-side

### Compliance Requirements

#### Privacy

- GDPR compliant (EU users)
- CCPA compliant (California users)
- Privacy policy published and accessible
- Data retention policy (90 days for opted-in data)

#### Content

- Age gate (21+ in US, 18+ in most countries)
- Responsible drinking messaging
- No glorification of excessive consumption

#### Legal

- Terms of Service
- End User License Agreement (EULA)
- Content licensing (TheCocktailDB attribution)
- Music licensing (if background music added)

---

## Risks & Mitigation

### Technical Risks

#### Risk 1: Azure Costs Exceed Projections

- **Likelihood**: Medium
- **Impact**: High
- **Mitigation**: 
  - Start with conservative APIM Consumption tier
  - Implement aggressive caching
  - Monitor costs daily in development
  - Set Azure budget alerts
  - Have fallback to cheaper AI models

#### Risk 2: Windows Consumption Plan Limitations

- **Likelihood**: High (already known)
- **Impact**: Medium
- **Mitigation**:
  - Use SAS tokens for MVP (documented)
  - Plan migration to Linux or Premium plan
  - Budget for plan upgrade when scaling

#### Risk 3: GPT-4.1-mini Quality Issues

- **Likelihood**: Low
- **Impact**: Medium
- **Mitigation**:
  - Extensive testing during development
  - Implement prompt engineering best practices
  - Have fallback prompts for poor responses
  - Monitor quality metrics

#### Risk 4: Voice Recognition Accuracy

- **Likelihood**: Medium
- **Impact**: Medium
- **Mitigation**:
  - Use Azure Speech custom vocabulary
  - Implement error correction prompts
  - Provide text fallback option
  - Test with diverse accents

### Business Risks

#### Risk 5: Low Conversion Rate (Free → Subscriber)

- **Likelihood**: Medium
- **Impact**: High
- **Mitigation**:
  - A/B test subscribe prompts
  - Offer 3-day free trial
  - Implement referral program
  - Focus on subscriber feature value

#### Risk 6: High User Churn

- **Likelihood**: Medium
- **Impact**: High
- **Mitigation**:
  - Regular feature updates
  - Engagement emails
  - In-app notifications
  - Churn surveys to understand why
  - Win-back campaigns

#### Risk 7: App Store Rejection

- **Likelihood**: Low
- **Impact**: High
- **Mitigation**:
  - Strict age verification
  - Responsible drinking messaging
  - Follow all platform guidelines
  - Legal review before submission

### Market Risks

#### Risk 8: Competitor Launches Similar Features

- **Likelihood**: Medium
- **Impact**: Medium
- **Mitigation**:
  - Focus on execution quality
  - Build user loyalty early
  - Continuous innovation
  - Patent/trademark key features

#### Risk 9: TheCocktailDB API Changes

- **Likelihood**: Low
- **Impact**: High
- **Mitigation**:
  - Maintain local database copy
  - Diversify data sources
  - Build own cocktail database over time
  - Licensing agreement with TheCocktailDB

---

## Roadmap

### Phase 1: MVP (Q4 2025) ✅ COMPLETE

- ✅ Core infrastructure (APIM Basic V2, Functions, PostgreSQL, Storage)
- ✅ Cocktail database with offline SQLite
- ✅ GPT-4.1-mini integration for AI Bartender
- ✅ Flutter mobile app (offline database, search, browse)
- ✅ AI recommendations with entitlement-based quotas
- ✅ JWT-only authentication via Entra External ID
- ✅ Age verification (21+) with Custom Authentication Extension
- ✅ Android release candidate

### Phase 2: Voice Features (Q4 2025) ✅ COMPLETE

- ✅ Azure OpenAI Realtime API integration
- ✅ Voice AI Bartender via WebRTC (Subscribers: 60 min/month + $5.99/60 min add-ons)
- ✅ Real-time conversational voice interface
- ✅ Ephemeral session token architecture
- ✅ Voice UI implementation

### Phase 3: Vision Features (Q4 2025) ✅ COMPLETE

- ✅ Claude Haiku integration for Smart Scanner
- ✅ Bar inventory scanning (Subscribers: 100/month)
- ✅ Bottle detection and classification
- ✅ Auto inventory updates
- ✅ My Bar inventory management

### Phase 4: iOS Launch (Q1 2026) - UPCOMING

- 🚧 iOS app development
- 🚧 URL scheme configuration in Info.plist
- ✅ Apple Sign-In integration
- 🚧 iOS-specific UI polish
- 🚧 App Store optimization

### Phase 5: Social Features (Q3 2026)

- Recipe sharing
- User profiles
- Follow bartenders
- Like and comment on recipes
- Leaderboards (most creative)

### Phase 6: Advanced AI (Q3 2026)

- Cocktail pairing suggestions (food, mood, occasion)
- Custom cocktail generation
- Ingredient substitution engine
- Taste profile learning
- Seasonal recommendations

### Phase 7: Monetization Expansion (Q4 2026)

- Affiliate links to retailers
- Sponsored cocktails
- Premium recipes from pro bartenders
- Bar equipment recommendations
- Masterclass integrations

### Phase 8: Enterprise Features (Q1 2027)

- Professional bar inventory management
- Menu planning tools
- Cost calculator
- Staff training module
- Restaurant/bar partnerships

---

## Appendices

### Appendix A: Glossary

**APIM**: Azure API Management - Gateway service for API tier management  
**GPT-4.1-mini**: OpenAI's cost-optimized language model  
**SAS Token**: Shared Access Signature - Temporary Azure Storage credential  
**Managed Identity**: Azure AD identity for service-to-service authentication  
**JWT**: JSON Web Token - Authentication token format  
**TheCocktailDB**: Free cocktail API and database  
**Consumption Plan**: Azure serverless pay-per-execution hosting  
**Riverpod**: Flutter state management library  
**GoRouter**: Flutter declarative routing library

### Appendix B: Key Metrics Definitions

**Monthly Active Users (MAU)**: Unique users who open app in 30-day period  
**Conversion Rate**: % of Free users who subscribe
**Churn Rate**: % of paying users who cancel in a month  
**Average Revenue Per User (ARPU)**: Total revenue / total users  
**Customer Acquisition Cost (CAC)**: Marketing spend / new users  
**Lifetime Value (LTV)**: Average revenue per user over lifetime  
**LTV:CAC Ratio**: Target 3:1 for sustainable growth

### Appendix C: API Endpoints Summary

**Public (No Auth)**:

- `GET /api/v1/cocktails/preview/{id}` - Public cocktail preview (for sharing)
- `GET /api/health` - Health check

**Authenticated (JWT Required)**:

- `GET /api/v1/snapshots/latest` - Download cocktail database snapshot
- `POST /api/v1/ask-bartender-simple` - AI Bartender chat
- `POST /api/v1/recommend` - AI cocktail recommendations
- `POST /api/v1/create-studio/refine` - Refine custom cocktails
- `GET /api/v1/users/me` - Get current user profile and entitlement

**Subscriber Features (paid entitlement required)**:

- `POST /api/v1/vision/analyze` - Smart Scanner (100 scans/month)
- `POST /api/v1/voice/session` - Voice AI session token (60 min/month included)
- `GET /api/v1/voice/quota` - Voice minutes remaining
- `POST /api/v1/voice/purchase` - Purchase voice minutes ($5.99/60 min add-on)

**Subscription Management**:

- `GET /api/v1/subscription/config` - RevenueCat SDK configuration
- `GET /api/v1/subscription/status` - User subscription status and entitlement
- `POST /api/v1/subscription/webhook` - RevenueCat server-to-server webhook (signature auth)

**Social Features**:

- `POST /api/v1/social/share` - Share cocktail with friend
- `POST /api/v1/social/invite` - Send friend invitation
- `GET /api/v1/social/inbox` - Received shares
- `GET /api/v1/social/outbox` - Sent shares

**Authentication**:

- `POST /api/v1/auth/exchange` - Token exchange
- `POST /api/v1/auth/rotate` - Token rotation

### Appendix D: Cost Breakdown (Per 1,000 Users)

**Infrastructure (Fixed)**:

- APIM Basic V2: ~$150/month
- Azure Functions (Premium Consumption): ~$20/month
- PostgreSQL Flexible Server: ~$30/month
- Blob Storage: ~$2/month
- Key Vault: ~$1/month
- Azure Front Door: ~$5/month
- **Subtotal**: ~$208/month

**Variable Costs (100 Subscribers)**:

- GPT-4.1-mini (AI Bartender): ~$30/month
- Claude Haiku (Smart Scanner): ~$5/month
- Azure OpenAI Realtime (Voice AI): ~$40/month
- **Subtotal**: ~$75/month

**Total Cost**: ~$283/month
**Revenue** (100 Subscribers @ $9.99, voice add-on purchases): ~$1,050/month
**Profit**: ~$767/month (73% margin)

**Note**: Margins improve significantly at scale as infrastructure costs are largely fixed.

---

## Document History

| Version | Date         | Author       | Changes                                                                                                                                                                                                                      |
| ------- | ------------ | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1.0     | Oct 22, 2025 | Gene Whitley | Initial PRD creation                                                                                                                                                                                                         |
| 2.0     | Dec 21, 2025 | Gene Whitley | Updated for Release Candidate status: corrected pricing, tier quotas, technical architecture (JWT-only auth, Claude Haiku for vision, Azure OpenAI Realtime for voice), marked Phases 1-3 complete                           |
| 3.0     | Feb 13, 2026 | Gene Whitley | Subscription model migration: replaced Free/Premium/Pro tiers with binary paid/none entitlement model, updated pricing ($9.99/mo, $99.99/yr), voice add-on ($5.99/60 min), updated quotas to match RevenueCat implementation |
| 2.1     | Dec 23, 2025 | Gene Whitley | Added subscription system (RevenueCat integration): Key Vault secrets, subscription management endpoints, voice-purchase endpoint                                                                                            |
| 2.2     | Jan 1, 2026  | Gene Whitley | Added Today's Special feature with push notifications, deep linking, and idempotent scheduling                                                                                                                               |

---

**Document Status**: RELEASE CANDIDATE
**Last Updated**: January 1, 2026
