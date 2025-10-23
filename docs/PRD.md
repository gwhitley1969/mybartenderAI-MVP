# Product Requirements Document (PRD)

## MyBartenderAI

**Document Version**: 1.0  
**Last Updated**: October 22, 2025  
**Product Owner**: Gene Whitley  
**Status**: MVP Development

---

## Executive Summary

MyBartenderAI is an AI-powered mobile bartending assistant that helps users discover, create, and perfect cocktails based on their available ingredients. The app combines a comprehensive offline cocktail database with premium AI features including conversational recommendations, voice-guided instruction, and visual inventory scanning.

### Product Vision

To be the definitive mobile bartending companion that makes craft cocktail creation accessible to everyone, from beginners to enthusiasts, through intelligent AI assistance and an offline-first experience.

### Key Differentiators

1. **Offline-First Design**: Full cocktail database (~621 drinks) available without internet
2. **Cost-Optimized AI**: GPT-4o-mini + Azure Speech Services (93% cheaper than alternatives)
3. **Tiered Monetization**: Free, Premium ($4.99/mo), Pro ($9.99/mo) with clear value proposition
4. **Voice Guidance**: Step-by-step cocktail making with natural voice interaction
5. **Privacy-Focused**: No PII collection for free tier users

---

## Business Objectives

### Primary Goals

1. **Launch MVP** on Android by Q4 2025
2. **Acquire 1,000 users** in first 3 months
3. **Convert 10%** to Premium/Pro tier
4. **Maintain 90% profit margin** on subscription revenue
5. **Achieve 4.5+ star** rating on Play Store

### Success Metrics

| Metric          | Target (3 months) | Target (6 months) | Target (12 months) |
| --------------- | ----------------- | ----------------- | ------------------ |
| Total Users     | 1,000             | 5,000             | 20,000             |
| Premium Users   | 100               | 500               | 2,500              |
| Pro Users       | 10                | 75                | 500                |
| Monthly Revenue | $500              | $2,500            | $15,000            |
| Churn Rate      | <15%              | <10%              | <8%                |
| App Rating      | 4.5+              | 4.6+              | 4.7+               |

### Financial Model

**Monthly Revenue Projections (1,000 users):**

- Premium (100 @ $4.99): $499
- Pro (10 @ $9.99): $100
- **Total Revenue**: $599/month

**Monthly Costs:**

- Infrastructure (APIM + Functions + DB): ~$60
- AI Services (GPT-4o-mini + Speech): ~$55
- **Total Costs**: ~$115/month
- **Profit**: ~$484/month (81% margin)

**At Scale (10,000 users):**

- Revenue: ~$6,000/month
- Costs: ~$600/month
- **Profit**: ~$5,400/month (90% margin)

---

## Target Audience

### Primary Personas

#### 1. **Emma the Enthusiast** (Primary Target - Premium)

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

#### 2. **Mark the Beginner** (Secondary - Free to Premium Upgrade)

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

#### 3. **Sarah the Sommelier** (Tertiary - Pro Tier)

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

### Core Features (Free Tier)

#### 1. Offline Cocktail Database

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

#### 2. Basic AI Recommendations (10/month)

**Description**: Limited AI-powered cocktail suggestions based on preferences.

**Functional Requirements**:

- FR2.1: User can ask "What should I make?" in natural language
- FR2.2: GPT-4o-mini provides 3 personalized recommendations
- FR2.3: Limited to 10 AI interactions per month
- FR2.4: Clear upgrade prompt when limit reached

**User Stories**:

- As Mark, I want AI to suggest cocktails so I can discover new drinks
- As Emma, I want to know my remaining AI credits so I can plan when to use them

**Acceptance Criteria**:

- AI response in <2.5 seconds p95
- Recommendations based on user preferences
- Quota displayed prominently in UI
- Upgrade CTA when limit reached

#### 3. Custom Recipe Storage (3 recipes)

**Description**: Save and organize personal cocktail recipes.

**Functional Requirements**:

- FR3.1: Create custom recipe with name, ingredients, instructions
- FR3.2: Add photos to custom recipes
- FR3.3: Edit and delete custom recipes
- FR3.4: Limited to 3 custom recipes in free tier
- FR3.5: Recipes synced to cloud (requires account)

**User Stories**:

- As Emma, I want to save my successful experiments so I can recreate them
- As Mark, I want to store my favorite variations of classic drinks

**Acceptance Criteria**:

- Recipes save in <1 second
- Photos compressed to <500KB
- Recipes persist across devices after login
- Clear "upgrade for more" message at limit

### Premium Features ($4.99/month)

#### 4. AI Bartender Chat (100/month)

**Description**: Conversational AI assistant for cocktail guidance and recommendations.

**Functional Requirements**:

- FR4.1: Unlimited natural language queries (up to 100/month)
- FR4.2: Context-aware recommendations based on inventory
- FR4.3: Ingredient substitution suggestions
- FR4.4: Cocktail history tracking
- FR4.5: Personalized learning of preferences

**User Stories**:

- As Emma, I want to ask "What can I make with gin and lemon?" and get immediate suggestions
- As Mark, I want the AI to remember I don't like sweet drinks

**Acceptance Criteria**:

- Response time <2.5 seconds p95
- Recommendations use user's stated inventory
- Conversation history saved for session
- Preferences learned and applied

#### 5. Voice-Guided Cocktail Making (30 min/month)

**Description**: Step-by-step voice instructions for making cocktails.

**Functional Requirements**:

- FR5.1: Activate voice mode with button press
- FR5.2: Speak naturally to ask questions
- FR5.3: AI responds with voice instructions
- FR5.4: Hands-free operation during cocktail making
- FR5.5: Track usage against 30-minute monthly limit
- FR5.6: Support interruptions and corrections

**User Stories**:

- As Emma, I want to hear step-by-step instructions while making drinks so my hands stay clean
- As Mark, I want to ask "what's next?" without touching my phone

**Acceptance Criteria**:

- Speech recognition accuracy >95%
- End-to-end latency <2 seconds p95
- Voice includes bartending vocabulary
- Clear indication of remaining minutes
- Works with screen off

**Technical Implementation**:

- Client-side Azure Speech SDK (STT/TTS)
- Text processing via GPT-4o-mini
- ~$0.10 cost per 5-minute session

#### 6. Vision Scanning (5 scans/month)

**Description**: Photograph home bar to automatically inventory bottles.

**Functional Requirements**:

- FR6.1: Capture photo of bar or bottles
- FR6.2: AI identifies bottles with >70% confidence
- FR6.3: Add detected items to inventory
- FR6.4: Manual correction/addition of missed items
- FR6.5: Track scan usage against monthly limit

**User Stories**:

- As Emma, I want to photograph my bar so the app knows what I can make
- As Mark, I want quick inventory updates without typing each bottle

**Acceptance Criteria**:

- Detection completes in <5 seconds
- Identifies common spirit brands accurately
- Allows manual editing of results
- Provides confidence scores

#### 7. Custom Recipes (25 recipes)

**Description**: Extended custom recipe storage.

**Functional Requirements**:

- FR7.1: Store up to 25 custom recipes
- FR7.2: AI-enhanced recipe suggestions
- FR7.3: Recipe sharing (future)
- FR7.4: Recipe collections/categories

**User Stories**:

- As Emma, I want to organize recipes by season or occasion
- As Sarah, I want AI to help improve my recipe ratios

### Pro Features ($9.99/month)

#### 8. Unlimited AI Recommendations

**Description**: No limits on AI interactions.

**Functional Requirements**:

- FR8.1: Unlimited AI chat interactions
- FR8.2: Advanced recipe generation
- FR8.3: Batch recommendations for events
- FR8.4: Cocktail pairing suggestions

**User Stories**:

- As Sarah, I want to generate multiple custom cocktails for my menu
- As Emma, I want AI to plan all drinks for my dinner party

#### 9. Extended Voice Assistant (5 hours/month)

**Description**: More voice interaction time for serious users.

**Functional Requirements**:

- FR9.1: 5 hours of voice guidance per month
- FR9.2: Multi-cocktail session support
- FR9.3: Voice recipe dictation
- FR9.4: Priority processing

**User Stories**:

- As Sarah, I want to use voice mode during my cocktail classes
- As Emma, I want voice guidance for my monthly dinner parties

#### 10. Advanced Vision (50 scans/month)

**Description**: Frequent inventory updates for active users.

**Functional Requirements**:

- FR10.1: 50 scans per month
- FR10.2: Automatic inventory updates
- FR10.3: Shopping list generation
- FR10.4: Price comparisons (future)

**User Stories**:

- As Sarah, I want to track professional bar inventory changes
- As Emma, I want to scan after each shopping trip

#### 11. Unlimited Custom Recipes

**Description**: No limits on recipe storage.

**Functional Requirements**:

- FR11.1: Unlimited recipe storage
- FR11.2: Advanced organization and tagging
- FR11.3: Recipe collaboration (future)
- FR11.4: Export to PDF/print

**User Stories**:

- As Sarah, I want to document all my professional recipes
- As Emma, I want to create a digital cocktail book

---

## Technical Architecture

### Infrastructure (Azure)

#### API Gateway

- **Service**: Azure API Management (`apim-mba-001`)
- **Location**: South Central US
- **Gateway URL**: https://apim-mba-001.azure-api.net
- **Tier**: Developer (MVP) → Consumption (Production)
- **Purpose**: Tier-based access control, rate limiting, API key management

#### Backend Compute

- **Service**: Azure Functions (`func-mba-fresh`)
- **Plan**: Windows Consumption
- **Runtime**: Node.js 20
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
  - `/snapshots` - Compressed JSON database snapshots
  - `/drink-images` - Cocktail images (~621 images)
- **Access**: SAS tokens (MVP) → Managed Identity (future)

#### Secrets Management

- **Service**: Azure Key Vault
- **Instance**: `kv-mybartenderai-prod`
- **Location**: `rg-mba-dev` resource group
- **Contents**:
  - `COCKTAILDB-API-KEY` - TheCocktailDB API key
  - `OpenAI` - Azure OpenAI API key (GPT-4o-mini)
  - `POSTGRES-CONNECTION-STRING` - Database connection
  - `AZURE-SPEECH-KEY` - Azure Speech Services (future)

#### AI Services

- **Text AI**: Azure OpenAI Service (GPT-4o-mini)
  - Cost: ~$0.007 per conversation
  - Purpose: Recommendations, chat, recipe generation
- **Voice**: Azure Speech Services (planned)
  - Cost: ~$0.10 per 5-minute session
  - Components: Speech-to-Text + Neural Text-to-Speech
- **Vision**: Azure Computer Vision (planned)
  - Cost: ~$1 per 1,000 images
  - Purpose: Bottle detection and classification

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

- `dio` - HTTP client with APIM integration
- `flutter_secure_storage` - Secure key storage
- `flutter_appauth` - Azure AD B2C authentication
- `speech_to_text` - Azure Speech SDK integration
- `flutter_tts` - Text-to-speech
- `camera` - Photo capture for vision features

### Data Flow

#### Cocktail Database Sync

```
1. Timer Function (nightly 03:30 UTC)
   ↓
2. Fetch from TheCocktailDB V2 API
   ↓
3. Normalize and store in PostgreSQL
   ↓
4. Download all drink images to Blob Storage
   ↓
5. Generate compressed JSON snapshot (gzip)
   ↓
6. Upload snapshot to Blob Storage
   ↓
7. Mobile requests snapshot via APIM
   ↓
8. Download, verify SHA256, store locally
```

#### AI Recommendation Flow

```
1. User query in mobile app
   ↓
2. Mobile → APIM (subscription key + JWT)
   ↓
3. APIM validates tier and rate limits
   ↓
4. Forward to Function App
   ↓
5. Function → GPT-4o-mini (Azure OpenAI)
   ↓
6. Response → Function → APIM → Mobile
   ↓
7. Update usage quota in PostgreSQL
```

#### Voice Interaction Flow

```
1. User presses mic button
   ↓
2. Azure Speech SDK (client): Record audio
   ↓
3. Speech-to-Text (client): Transcribe
   ↓
4. Text → APIM → Function App
   ↓
5. Function → GPT-4o-mini
   ↓
6. Text response → Mobile
   ↓
7. Text-to-Speech (client): Play audio
   ↓
8. Update voice minutes in PostgreSQL
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
4. **Tier Selection**
   - Free / Premium / Pro comparison
   - Start with Free (no payment required)
5. **Optional Sign-In**
   - Continue as guest (limited features)
   - Sign in for cloud sync

#### Premium Upgrade Flow

1. **Trigger Points**:
   - Hit Free tier limit (10 AI recommendations)
   - Attempt Premium feature (voice/vision)
   - From settings menu
2. **Upgrade Screen**:
   - Feature comparison table
   - Pricing clearly displayed
   - Testimonials/reviews
   - "Start 7-day free trial" CTA
3. **Payment**:
   - Google Play Billing
   - Instant activation

### Core User Flows

#### Find a Cocktail (Free)

```
Home → Search/Browse → Select Drink → View Recipe → Make It
```

- **Time**: 30 seconds
- **Touches**: 3-4
- **Network**: None required

#### AI Recommendation (Premium)

```
Home → Ask Bartender → Type/Speak Query → View Suggestions → Select → Make It
```

- **Time**: 15 seconds
- **Touches**: 2-3
- **Network**: Required

#### Voice-Guided Making (Premium)

```
Home → Select Drink → Start Voice Mode → Follow Instructions → Complete
```

- **Time**: 5-10 minutes (depending on cocktail)
- **Interaction**: Voice only
- **Network**: Required for initial query, then optional

#### Inventory Scanning (Premium)

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
- Tier upgrade prompt (if Free)

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
- "Start Voice Mode" button (Premium)
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
- "Scan Bar" button (Premium)
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

#### Freemium Model

- **Free Tier**: Full offline database, limited AI (10/month)
- **Premium Tier**: AI + Voice + Vision + More recipes
- **Pro Tier**: Unlimited everything + priority support

#### Revenue Streams

1. **Primary**: Subscription revenue (95% of revenue)
2. **Secondary** (Future): 
   - Affiliate links to liquor retailers (5%)
   - Sponsored cocktails from brands
   - Premium recipes from professional bartenders

### Pricing Strategy

#### Competitive Analysis

| Competitor        | Price           | Features                     |
| ----------------- | --------------- | ---------------------------- |
| Cocktail Flow     | $4.99/mo        | AI recommendations, no voice |
| Mixel             | Free + $9.99/mo | Large database, basic AI     |
| Highball          | $2.99/mo        | Simple recipes, no AI        |
| **MyBartenderAI** | **$4.99/mo**    | **AI + Voice + Vision**      |

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
- **Our Advantage**: Better AI (GPT-4o-mini), voice features, value

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

#### Q4 2025: MVP Development

- **Week 1-4**: Core infrastructure (APIM, Functions, Database)
- **Week 5-8**: Flutter app development (offline database, search)
- **Week 9-12**: AI integration (GPT-4o-mini recommendations)
- **Week 13**: Beta testing with 10 users
- **Week 14**: Bug fixes and polish
- **Week 15**: Soft launch on Google Play
- **Week 16**: Public launch

#### Q1 2026: Growth & Voice

- **Month 1**: User acquisition, feedback collection
- **Month 2**: Azure Speech Services integration
- **Month 3**: Voice feature beta, marketing push

#### Q2 2026: Vision & iOS

- **Month 4**: Azure Computer Vision integration
- **Month 5**: Vision feature beta
- **Month 6**: iOS app development and launch

### Success Criteria

#### Month 1 Post-Launch

- 100 downloads
- 10% conversion to Premium
- <5 critical bugs
- 4.0+ rating

#### Month 3 Post-Launch

- 1,000 downloads
- 10% conversion to Premium
- <2 critical bugs
- 4.5+ rating
- $500/month revenue

#### Month 6 Post-Launch

- 5,000 downloads
- 12% conversion to Premium
- 0 critical bugs
- 4.6+ rating
- $2,500/month revenue

#### Month 12 Post-Launch

- 20,000 downloads
- 15% conversion to Premium
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

- Azure AD B2C (Entra External ID)
- JWT tokens with <15 minute expiry
- Automatic token refresh
- Social login (Google, Microsoft)

#### Data Protection

- All communication over HTTPS
- Encryption at rest (Azure Storage)
- No PII for Free tier users
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

#### Risk 3: GPT-4o-mini Quality Issues

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

#### Risk 5: Low Conversion Rate (Free → Premium)

- **Likelihood**: Medium
- **Impact**: High
- **Mitigation**:
  - A/B test upgrade prompts
  - Offer 7-day free trial
  - Implement referral program
  - Focus on Premium feature value

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

### Phase 1: MVP (Q4 2025) - CURRENT

- ✅ Core infrastructure (APIM, Functions, PostgreSQL, Storage)
- ✅ Cocktail database sync from TheCocktailDB
- ✅ GPT-4o-mini integration
- 🚧 Flutter mobile app (offline database, search, browse)
- 🚧 Basic AI recommendations (Free: 10/month)
- 🚧 APIM tier configuration (Free/Premium/Pro)
- 🚧 Authentication (Azure AD B2C)
- 🚧 Android beta launch

### Phase 2: Voice Features (Q1 2026)

- Azure Speech Services integration
- Voice-guided cocktail making (Premium: 30 min/month)
- Custom bartending vocabulary
- Hands-free operation
- Voice UI polish

### Phase 3: Vision Features (Q2 2026)

- Azure Computer Vision integration
- Bar inventory scanning (Premium: 5 scans/month)
- Bottle detection and classification
- Auto inventory updates
- Shopping list generation

### Phase 4: iOS Launch (Q2 2026)

- iOS app development
- Cross-platform sync
- Apple Sign-In
- iOS-specific UI polish
- App Store optimization

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
**GPT-4o-mini**: OpenAI's cost-optimized language model  
**SAS Token**: Shared Access Signature - Temporary Azure Storage credential  
**Managed Identity**: Azure AD identity for service-to-service authentication  
**JWT**: JSON Web Token - Authentication token format  
**TheCocktailDB**: Free cocktail API and database  
**Consumption Plan**: Azure serverless pay-per-execution hosting  
**Riverpod**: Flutter state management library  
**GoRouter**: Flutter declarative routing library

### Appendix B: Key Metrics Definitions

**Monthly Active Users (MAU)**: Unique users who open app in 30-day period  
**Conversion Rate**: % of Free users who upgrade to Premium/Pro  
**Churn Rate**: % of paying users who cancel in a month  
**Average Revenue Per User (ARPU)**: Total revenue / total users  
**Customer Acquisition Cost (CAC)**: Marketing spend / new users  
**Lifetime Value (LTV)**: Average revenue per user over lifetime  
**LTV:CAC Ratio**: Target 3:1 for sustainable growth

### Appendix C: API Endpoints Summary

**Public (No Auth)**:

- `GET /api/health` - Health check

**Free Tier**:

- `GET /api/v1/snapshots/latest` - Download cocktail database
- `POST /api/v1/ask-bartender` - AI recommendations (10/month)

**Premium Tier**:

- `POST /api/v1/ask-bartender` - AI recommendations (100/month)
- `GET /api/v1/speech/token` - Voice assistant token (30 min/month)
- `POST /api/v1/vision/scan` - Bottle scanning (5/month)

**Pro Tier**:

- All Premium endpoints with higher/unlimited quotas

**Admin**:

- `POST /api/v1/admin/sync` - Trigger database sync

### Appendix D: Cost Breakdown (Per 1,000 Users)

**Infrastructure**:

- APIM Developer: $50/month
- Azure Functions: $0.20/month
- PostgreSQL: $30/month
- Blob Storage: $1/month
- Key Vault: $0.03/month
- **Subtotal**: $81.23/month

**Variable Costs (100 Premium users)**:

- GPT-4o-mini: $40/month (100 users × $0.40)
- Azure Speech: $10/month (100 users × $0.10)
- Vision (future): $5/month
- **Subtotal**: $55/month

**Total Cost**: $136/month  
**Revenue** (100 Premium @ $4.99, 10 Pro @ $9.99): $599/month  
**Profit**: $463/month (77% margin)

---

## Document History

| Version | Date         | Author      | Changes              |
| ------- | ------------ | ----------- | -------------------- |
| 1.0     | Oct 22, 2025 | [Your Name] | Initial PRD creation |

---

**Document Status**: APPROVED FOR DEVELOPMENT  
**Next Review**: November 22, 2025
