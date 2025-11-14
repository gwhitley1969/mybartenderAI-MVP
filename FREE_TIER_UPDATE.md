# Free Tier Update - November 2024

## Overview
Free tier users now receive limited AI features to let them experience the MyBartenderAI capabilities before upgrading.

## Free Tier Benefits (Updated)

### Previous (No AI)
- ❌ No AI interactions
- ❌ No camera scanning
- ✅ Local cocktail database only

### New (Limited AI)
- ✅ **10,000 tokens per month** for AI conversations
- ✅ **2 scans per month** for bottle detection
- ✅ Full access to local cocktail database
- ✅ Basic AI bartender chat
- ✅ Limited recipe recommendations

## Tier Comparison

| Feature | Free | Premium ($4.99/mo) | Pro ($8.99/mo) |
|---------|------|-------------------|----------------|
| **AI Tokens/Month** | 10,000 | 300,000 | 1,000,000 |
| **Camera Scans/Month** | 2 | 30 | 100 |
| **Local Database** | ✅ Unlimited | ✅ Unlimited | ✅ Unlimited |
| **AI Chat** | ✅ Basic | ✅ Full | ✅ Enhanced |
| **Voice Features** | ❌ | ✅ | ✅ |
| **Custom Recipes** | ❌ | ✅ | ✅ |
| **Priority Support** | ❌ | ❌ | ✅ |

## Implementation Changes

### Backend Updates
✅ `auth-exchange` function updated to return Free tier quotas
✅ Quota helper returns 10K tokens and 2 scans for Free tier
✅ AI access enabled for Free tier with limits

### Mobile App Updates
✅ `ApimSubscriptionService` defaults updated
✅ AI access check allows Free tier users
✅ Error messages updated to be tier-aware

### APIM Configuration
✅ Free tier product quota: 10,000 calls/month
✅ Rate limit: 20 calls/minute for Free tier
✅ Dual authentication still required

## User Experience

### Free Tier User Journey
1. **Sign up** → Automatically assigned Free tier
2. **First AI chat** → Works immediately (10K tokens available)
3. **Try scanner** → 2 free scans to test feature
4. **Hit limits** → Friendly upgrade prompt with clear benefits
5. **Upgrade** → Seamless transition to Premium/Pro

### Quota Exhaustion Messages
- **Tokens exhausted**: "You've used your 10,000 free tokens this month. Upgrade to Premium for 300,000 tokens!"
- **Scans exhausted**: "You've used both free scans. Upgrade to Premium for 30 scans per month!"

## Marketing Benefits

1. **Lower barrier to entry** - Users can try AI features immediately
2. **Feature discovery** - Users experience value before paying
3. **Conversion driver** - Limited quotas encourage upgrades
4. **Competitive advantage** - More generous than competitors' free tiers
5. **Word of mouth** - Free users can share AI cocktail creations

## Technical Notes

- Quotas reset on the 1st of each month at midnight UTC
- Token counting based on GPT-4o-mini tokenization
- Scans count each camera capture, not each bottle detected
- Free tier subscriptions auto-created on first sign-in
- No credit card required for Free tier

## Monitoring

Track these metrics for Free tier:
- Conversion rate to paid tiers
- Average time to quota exhaustion
- Feature usage patterns
- User retention after hitting limits

## Future Considerations

Potential adjustments based on usage data:
- Adjust token limits if too restrictive/generous
- Add daily limits to prevent burst usage
- Special promotions (e.g., "Try Premium free for 7 days")
- Referral bonuses (extra tokens for inviting friends)

---

*Effective Date: November 14, 2024*
*This change makes MyBartenderAI more accessible while maintaining clear value proposition for paid tiers*