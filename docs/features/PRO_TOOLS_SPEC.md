# Feature Spec: Pro Tools - Precision Instruments

## Overview

The Pro Tools feature provides a curated guide to essential bar tools organized by priority level. Users can browse tools, understand what each does, and see recommendations at different price points. This is a read-only reference feature for beta.

## User Story

As a user, I want to know which bar tools I need to build a proper home bar so I can make quality cocktails with the right equipment.

## Data Structure

### Tool Tiers

```json
{
  "tiers": [
    {
      "id": "essential",
      "title": "Essential",
      "subtitle": "Start Here",
      "description": "The must-haves for any home bar",
      "icon": "star",
      "sortOrder": 1,
      "tools": [...]
    }
  ]
}
```

### Individual Tool

```json
{
  "id": "jigger",
  "name": "Jigger",
  "subtitle": "Japanese Style, 1oz/2oz",
  "description": "A jigger ensures consistent pours every time. The Japanese style has a sleek profile and internal measurement lines.",
  "whyYouNeedIt": "Eyeballing measurements leads to inconsistent drinks. A jigger is the difference between a balanced cocktail and a boozy mess.",
  "whatToLookFor": [
    "Internal measurement lines (½oz, ¾oz marks)",
    "Sturdy construction — thin metal dents easily",
    "Japanese style for precision, American style for speed"
  ],
  "priceRanges": {
    "budget": { "range": "$5-10", "note": "Basic stainless steel" },
    "mid": { "range": "$15-25", "note": "Japanese style with lines" },
    "premium": { "range": "$30-50", "note": "Weighted, copper or gold finish" }
  },
  "imageAsset": "assets/images/tools/jigger.png",
  "sortOrder": 1,
  "tags": ["measuring", "essential", "precision"]
}
```

## Content Structure

Implement these tiers with the specified tools.

### Tier 1: Essential (Start Here)

| Tool               | Subtitle                       |
| ------------------ | ------------------------------ |
| Jigger             | Japanese style, 1oz/2oz        |
| Shaker             | Boston or Cobbler style        |
| Bar Spoon          | Twisted handle, 12 inch        |
| Hawthorne Strainer | Spring-loaded, fits shaker tin |
| Muddler            | Wooden or stainless steel      |
| Citrus Juicer      | Handheld press style           |

### Tier 2: Level Up

| Tool               | Subtitle                   |
| ------------------ | -------------------------- |
| Mixing Glass       | Weighted base, 500-700ml   |
| Fine Mesh Strainer | For double-straining       |
| Channel Knife      | For citrus twists          |
| Julep Strainer     | For stirred drinks         |
| Pour Spouts        | Speed pourers              |
| Ice Cube Trays     | Large format, 2 inch cubes |

### Tier 3: Pro Status

| Tool                | Subtitle                         |
| ------------------- | -------------------------------- |
| Japanese Jigger Set | Multiple sizes                   |
| Lewis Bag & Mallet  | For crushed ice                  |
| Smoking Gun         | For smoked cocktails             |
| Atomizer            | For absinthe rinses and spritzes |
| Fine Scale          | 0.1g precision for bitters       |
| Sous Vide           | For rapid infusions              |

## UI Requirements

### Pro Tools Main Screen

- Vertical list or expandable sections by tier
- Each tier shows: icon, title, subtitle, tool count
- Visual hierarchy — Essential tier should be prominent
- Option A: Accordion/expandable sections
- Option B: Horizontal tier tabs at top

### Tool List (within tier)

- Vertical list of tools
- Each tool shows: image/icon, name, subtitle
- Tapping a tool opens detail view

### Tool Detail Screen

- Tool image or icon at top
- Name and subtitle
- "Why You Need It" section
- "What to Look For" as a bulleted list
- Price ranges displayed as cards or chips:
  - Budget: $X-Y — note
  - Mid: $X-Y — note  
  - Premium: $X-Y — note
- Tags displayed as chips at bottom

## Technical Implementation

### Data Storage

Store tool content as static JSON bundled with the app. For beta, this content is static — no API calls needed.

Suggested location: `assets/data/pro_tools_content.json`

### Images

For beta, use placeholder icons or simple illustrations. Options:

- Use Material icons or Lucide icons as placeholders
- Use a single generic "bar tool" image
- Skip images entirely and use icon + text

Do NOT spend time sourcing product images for beta.

### Files to Create/Modify

**New Files:**

- `lib/features/pro_tools/` — Feature folder
  - `pro_tools_screen.dart` — Main tier list
  - `pro_tools_detail_screen.dart` — Individual tool view
  - `pro_tools_models.dart` — Data models (Tier, Tool, PriceRange)
  - `pro_tools_data.dart` — Static content or loader
- `assets/data/pro_tools_content.json` — Tool content

**Modify:**

- Main navigation to add Pro Tools entry point
- `pubspec.yaml` to add asset reference if needed

## Constraints

- Follow existing app architecture patterns
- Use existing theme colors, typography, and spacing
- No backend API calls — all content is local for beta
- No affiliate links for beta (legal/compliance review needed first)
- No e-commerce integration
- Use icons instead of product photos for beta

## Out of Scope for Beta

- Affiliate links to purchase tools
- User reviews or ratings
- "I own this" checklist
- Price tracking or deal alerts
- Brand-specific recommendations
- Comparison feature
- Search within Pro Tools

## Sample Content for Implementation

Here's detailed content for the Essential tier to get started:

### Jigger

- **Why You Need It:** Eyeballing measurements leads to inconsistent drinks. A jigger is the difference between a balanced cocktail and a boozy mess.
- **What to Look For:** Internal measurement lines, sturdy construction, Japanese style for precision
- **Budget:** $5-10 (Basic stainless steel)
- **Mid:** $15-25 (Japanese style with lines)
- **Premium:** $30-50 (Weighted, copper or gold finish)

### Boston Shaker

- **Why You Need It:** The Boston shaker is the industry standard. Two pieces, no built-in strainer, maximum volume for shaking.
- **What to Look For:** 18oz and 28oz tin combo, or tin + tempered mixing glass, weighted bottom for stability
- **Budget:** $10-15 (Basic tins)
- **Mid:** $20-35 (Weighted tins)
- **Premium:** $40-60 (Koriko weighted set)

### Bar Spoon

- **Why You Need It:** Stirring with a regular spoon introduces too much dilution and aeration. A bar spoon's twisted handle lets you stir smoothly.
- **What to Look For:** 12 inch length, twisted shaft, weighted end, comfortable grip
- **Budget:** $5-8 (Basic twisted)
- **Mid:** $12-20 (Japanese style, teardrop end)
- **Premium:** $25-40 (Handmade, custom finish)

### Hawthorne Strainer

- **Why You Need It:** Keeps ice and large particles out of your drink when pouring from a shaker.
- **What to Look For:** Tight spring coil, fits your shaker tin, comfortable finger rest
- **Budget:** $5-8 (Basic)
- **Mid:** $12-18 (Tighter spring, better fit)
- **Premium:** $25-35 (Buswell or similar pro brand)

### Muddler

- **Why You Need It:** Releases oils from herbs and juice from fruit. Essential for mojitos, old fashioneds, and smashes.
- **What to Look For:** Flat bottom (not toothed), comfortable grip, long enough for a mixing glass
- **Budget:** $5-10 (Basic wood)
- **Mid:** $12-20 (Stainless steel)
- **Premium:** $25-40 (Weighted, ergonomic)

### Citrus Juicer

- **Why You Need It:** Fresh citrus is non-negotiable for quality cocktails. Bottled juice tastes flat.
- **What to Look For:** Handheld press style, handles lemons and limes, sturdy hinge
- **Budget:** $10-15 (Basic press)
- **Mid:** $20-30 (Heavy duty, enamel coated)
- **Premium:** $35-50 (Commercial grade)

## Acceptance Criteria

- [x] User can view list of tool tiers
- [x] User can see tools within each tier
- [x] User can tap a tool to see full details
- [x] Tool detail shows description, tips, and price ranges
- [x] UI matches existing app theme
- [x] Content loads from local JSON (no network required)
- [x] Feature is accessible from main navigation

---

## Implementation Status: COMPLETE (November 2025)

See `PRO_TOOLS_IMPLEMENTATION_PLAN.md` for full implementation details.

**Files Created:**
- `lib/src/features/pro_tools/models/pro_tools_models.dart`
- `lib/src/features/pro_tools/data/pro_tools_repository.dart`
- `lib/src/features/pro_tools/pro_tools_screen.dart`
- `lib/src/features/pro_tools/pro_tools_tier_screen.dart`
- `lib/src/features/pro_tools/pro_tool_detail_screen.dart`
- `lib/src/features/pro_tools/widgets/tool_card.dart`
- `lib/src/features/pro_tools/widgets/price_range_card.dart`
- `assets/data/pro_tools_content.json`

**Content:** 18 tools across 3 tiers (Essential, Level Up, Pro Status)

---

## Notes for Claude Code

- Check existing project structure before creating new folders
- Look at how other features (especially Academy if built first) are organized and follow that pattern
- Use existing navigation patterns
- Use Material icons or Lucide icons as tool image placeholders
- Populate all three tiers with at least 4-6 tools each
- Make the content genuinely useful — this is a reference users will return to
