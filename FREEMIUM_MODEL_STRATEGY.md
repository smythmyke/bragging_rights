# Bragging Rights: Freemium Model Strategy

**Document Version:** 1.0
**Last Updated:** 2025-01-06
**Status:** Ready for Implementation

---

## Executive Summary

This document outlines the complete freemium monetization strategy for Bragging Rights, including:
- Two-tier pricing model (Free + $1.99/mo Premium)
- Legal compliance framework for prize competitions
- Revenue projections and cost analysis
- Implementation roadmap

**Key Metrics:**
- **Premium Price:** $1.99/month ($19.99/year)
- **Gross Margin:** 92% per premium subscriber
- **Break-even:** 100-150 premium subscribers
- **Legal Structure:** Skill-based competition with free entry (no gambling license required)

---

## Table of Contents

1. [Pricing Tiers](#pricing-tiers)
2. [Revenue Model](#revenue-model)
3. [Legal Framework](#legal-framework)
4. [Implementation Roadmap](#implementation-roadmap)
5. [Technical Requirements](#technical-requirements)
6. [Marketing Strategy](#marketing-strategy)
7. [Legal Compliance Checklist](#legal-compliance-checklist)
8. [Risk Mitigation](#risk-mitigation)

---

## Pricing Tiers

### Free Tier: "Bragging Rights Basic"

**Scoring System:**
- ✅ Simple pick scoring (record-based underdogs)
- ✅ Confidence multipliers (1-5 stars)
- ✅ Underdog bonuses based on team/fighter records
- ✅ All sports and events

**Features:**
- ✅ Join all pool types (Quick Play, Regional, Private)
- ✅ Compete for Bragging Rights (BR) in-app currency
- ✅ Basic leaderboards
- ✅ Daily BR bonuses
- ✅ Referral rewards
- ✅ Achievement system

**BR Earning (Free):**
- Daily login: 50 BR
- Complete profile: 100 BR (one-time)
- Refer friend: 200 BR per referral
- Watch video ad: 25 BR (max 5/day = 125 BR)
- Weekly streak bonus: 100 BR
- Achievement unlocks: 50-500 BR

**BR Purchase (Optional):**
- $0.99 = 100 BR
- $4.99 = 600 BR (20% bonus)
- $9.99 = 1,500 BR (50% bonus)

**Pool Entry Costs:**
- 10 BR pools (accessible within 1 day free play)
- 50 BR pools (accessible within 1 week free play)
- 100 BR pools (accessible within 2 weeks free play)

**Value Proposition:** "Prove your sports knowledge - completely free"

**Cost to Company:** $0/month per user

---

### Premium Tier: "Odds Edge" ($1.99/month)

**Everything in Free Tier, PLUS:**

**Scoring System:**
- ✅ Real Vegas odds integration
- ✅ Precise underdog bonuses from live betting lines
- ✅ Line shopping across multiple sportsbooks
- ✅ Historical odds trends

**Exclusive Features:**
- ✅ Odds-based premium pools (higher BR prizes)
- ✅ Edge Intelligence AI-powered picks
- ✅ Live odds tracking and alerts
- ✅ Advanced analytics dashboard
- ✅ Early access to major event pools (UFC PPV, playoffs)
- ✅ Priority customer support
- ✅ Ad-free experience
- ✅ Eligible for monthly premium competitions (win up to 6 weeks free)

**Monthly Premium Challenge:**
- Top 10 premium subscribers each month
- Prizes (tiered - in WEEKS, MAXIMUM 6 WEEKS):
  - 1st place: 6 weeks free premium ($11.94 value)
  - 2nd place: 4 weeks free premium ($7.96 value)
  - 3rd place: 2 weeks free premium ($3.98 value)
  - 4th-10th place: 1 week free premium ($1.99 value each)
- Qualification: Active picks in 10+ pools/month
- Skill-based ranking system
- **Auto-Subscribe Feature:** Winners see pre-checked opt-in to continue at $1.99/month after free weeks end

**Annual Option:**
- Monthly: $1.99 × 12 = $23.88/year
- **Annual: $19.99/year** (save $3.89 = 16% discount)

**7-Day Free Trial:** All new premium subscribers

**Value Proposition:** "Get the sharpest edge with real-time Vegas lines"

**Cost to Company:** ~$0.15/month per user (100 API calls/month)

**Gross Margin:** $1.84/user (92%)

---

## Revenue Model

### Cost Structure

**Per Premium User:**
- The Odds API: 100 calls/month × $0.0015 = **$0.15/month**
- Apple/Google IAP fee: $1.99 × 30% = **$0.60/month**
- **Net revenue per user: $1.24/month**

**Fixed Costs:**
- Firebase/Firestore: $25-50/month (scales with usage)
- Server costs: $20-50/month
- Legal compliance: $1,000/year (~$83/month)
- **Total fixed: ~$150/month**

**Break-even:** 150 ÷ $1.24 = **121 premium subscribers**

---

### Revenue Projections

**Assumptions:**
- 10,000 Monthly Active Users (MAU)
- Premium conversion rate: 2% conservative, 5% moderate, 10% optimistic

#### Conservative Scenario (2% conversion)

| Metric | Value |
|--------|-------|
| Free users | 9,800 |
| Premium subscribers | 200 |
| **Monthly revenue** | **$398** |
| API costs | $30 |
| IAP fees (30%) | $120 |
| Fixed costs | $150 |
| **Net profit** | **$98/month** |
| **Annual profit** | **$1,176** |

---

#### Moderate Scenario (5% conversion)

| Metric | Value |
|--------|-------|
| Free users | 9,500 |
| Premium subscribers | 500 |
| **Monthly revenue** | **$995** |
| API costs | $75 |
| IAP fees (30%) | $299 |
| Fixed costs | $150 |
| **Net profit** | **$471/month** |
| **Annual profit** | **$5,652** |

---

#### Optimistic Scenario (10% conversion)

| Metric | Value |
|--------|-------|
| Free users | 9,000 |
| Premium subscribers | 1,000 |
| **Monthly revenue** | **$1,990** |
| API costs | $150 |
| IAP fees (30%) | $597 |
| Fixed costs | $150 |
| **Net profit** | **$1,093/month** |
| **Annual profit** | **$13,116** |

---

### Scalability Analysis

**At 50,000 MAU (5% conversion = 2,500 premium):**
- Monthly revenue: $4,975
- API costs: $375
- IAP fees: $1,493
- Fixed costs: $200
- **Net profit: $2,907/month ($34,884/year)**

**At 100,000 MAU (5% conversion = 5,000 premium):**
- Monthly revenue: $9,950
- API costs: $750
- IAP fees: $2,985
- Fixed costs: $250
- **Net profit: $5,965/month ($71,580/year)**

---

## Legal Framework

### Why This is Legal (Not Gambling)

**Gambling requires ALL 3 elements:**
1. **Prize** ✓ (Yes - premium subscription credits)
2. **Chance** ✗ (NO - skill-based sports prediction)
3. **Consideration** ✗ (NO - free entry available)

**Your app = Skill-based competition with free entry**

---

### Legal Classification: Sweepstakes + Loyalty Program

#### For Free Users: "Skill-Based Sweepstakes"

**Structure:**
- Free entry methods available (daily BR, referrals, ads)
- Optional BR purchase for convenience
- Skill-based winner selection (correct picks)
- Prizes: BR credits, premium trials, achievement trophies

**Legal precedent:** DraftKings, FanDuel free contests

**Key requirement:** "NO PURCHASE NECESSARY" prominently displayed

---

#### For Premium Users: "Loyalty Rewards Program"

**Structure:**
- Participants are paying customers ($1.99/month)
- Monthly leaderboard competition
- Top 3 winners receive 12-month subscription extension
- Prize = $23.88 promotional credit (non-withdrawable)
- Cannot be transferred or converted to cash

**Legal precedent:**
- Microsoft Rewards (points → Xbox Game Pass)
- Starbucks Rewards (stars → free coffee)
- Credit card loyalty programs

**Classification:** Customer retention program, not gambling

---

### Prize Structure (Legal)

#### For Free Users:
- ✅ BR currency (unlimited earning, no cash value)
- ✅ Premium trials (7 days)
- ✅ Achievement trophies and badges
- ✅ Seasonal competitions (top 100 win 2-4 weeks premium)

#### For Premium Users:
- ✅ BR currency bonuses
- ✅ Prize winnings in FREE WEEKS (1, 2, 4, or 6 weeks MAXIMUM)
- ✅ Monthly leaderboard prizes (top 10 winners)
- ✅ Early access to exclusive pools
- ✅ Priority features
- ✅ Auto-subscribe option after prize period (opt-out available)

**Prize Value Tiers (Weekly-Based, CAPPED AT 6 WEEKS):**
- 1 week free premium: $1.99 value
- 2 weeks free premium: $3.98 value
- 4 weeks free premium: $7.96 value
- 6 weeks free premium: $11.94 value (MAXIMUM)
- **All prizes well under $600/year threshold** (even winning max prize 50x = $597, just under $600)

#### NEVER Offer:
- ❌ Cash withdrawals
- ❌ Cash equivalents (gift cards without proper license)
- ❌ Transferable prizes
- ❌ Crypto or payment processor credits

---

### State-by-State Compliance

**Clear in 45 states:** Skill-based + free entry = legal

**Requires review in 5 states:**
- Arizona
- Iowa
- Louisiana
- Montana
- Washington

**Recommendation:**
- Phase 1: Geo-block these 5 states
- Phase 2: Get legal review for each state ($500-1,000 per state)
- Phase 3: Enable after compliance confirmed

---

### Age Requirements

**Minimum age: 18+**

**Rationale:**
- Industry standard for skill gaming
- Avoids COPPA complications (13-18)
- Reduces legal risk
- Easier app store approval

**Implementation:**
- Age gate on signup
- Date of birth verification
- Optional ID verification for high-value prizes (future)

---

## Legal Compliance Checklist

### Required Documents

#### 1. Official Rules (Public-facing)

**Must include:**
- ✅ Eligibility requirements (age, location)
- ✅ Entry methods (free and paid)
- ✅ Prize descriptions (type, value, restrictions)
- ✅ Winner selection criteria (skill-based formula)
- ✅ Approximate odds of winning
- ✅ Entry deadlines and pool close times
- ✅ Dispute resolution process
- ✅ Sponsor information (company name, address)
- ✅ Privacy policy reference
- ✅ Void where prohibited statement

**Location:** Accessible via app footer and website

**Template:** See `OFFICIAL_RULES_TEMPLATE.md` (to be created)

---

#### 2. Terms of Service Updates

**Add sections for:**
- ✅ BR currency has no cash value
- ✅ Premium credits are non-transferable
- ✅ Account selling/trading prohibited
- ✅ Prize forfeiture for TOS violations
- ✅ Right to substitute prizes of equal value
- ✅ Tax responsibility (user's obligation)
- ✅ Termination rights for abuse

---

#### 3. Privacy Policy Updates

**Add disclosures for:**
- ✅ Winner information collection
- ✅ Prize fulfillment data usage
- ✅ Leaderboard display (public usernames)
- ✅ Age verification methods
- ✅ Third-party odds data providers

---

### Regulatory Filings

**Federal:**
- ✅ None required (skill-based, no gambling license needed)

**State:**
- ✅ None required in 45 states
- ⚠️ Review required: AZ, IA, LA, MT, WA

**App Stores:**
- ✅ Apple: Age rating 17+ (unrestricted web access + competitions)
- ✅ Google: Age rating Teen (simulated gambling)

---

### Tax Obligations

**For prizes valued $600+:**
- Must issue IRS Form 1099-MISC to winner
- Report to IRS
- Winner responsible for tax payment

**For your structure:**
- Max single prize: 6 weeks free premium = $11.94 value
- User could theoretically win multiple times (competitive user could win $143.28/year if winning max every month)
- **Well below $600 threshold** ✓
- No tax reporting required unless user wins $600+ cumulative in calendar year

**Conservative approach:**
- Track cumulative prizes per user per calendar year
- If approaching $600, collect W-9 and prepare 1099-MISC
- Even winning 6 weeks every month for 12 months = $143.28/year (well under $600)
- Virtually impossible to hit $600 threshold with 6-week cap

**If implementing higher prizes in future:**
- Budget for 1099 filing ($5-10 per form)
- Collect W-9 from winners
- File by January 31st each year

---

## App Store Compliance

### Apple App Store

**Guidelines Reference:**
- 3.1.1 - In-App Purchase
- 3.1.3(b) - Multiplatform Services
- 4.7 - Gambling-like Features

**Requirements:**
- ✅ Premium subscription must use Apple IAP (30% fee)
- ✅ BR purchases must use Apple IAP (30% fee)
- ✅ Cannot redirect to external payment
- ✅ Cannot mention pricing outside of app
- ✅ Must allow family sharing for subscriptions (optional)

**Prohibited:**
- ❌ Cash prizes
- ❌ External payment links
- ❌ "Real money gambling" claims

**Your compliance status:**
- ✅ No cash prizes (only in-app credits)
- ✅ Skill-based (not random gambling)
- ✅ Age-gated (18+)
- ✅ Official rules available
- **Status: Compliant**

---

### Google Play Store

**Policies Reference:**
- Payments Policy
- Gambling Apps Policy
- User-Generated Content Policy

**Requirements:**
- ✅ In-app purchases for digital goods (30% fee)
- ✅ Skill gaming allowed (no license needed)
- ✅ Age rating disclosure
- ✅ Clear prize terms

**More lenient than Apple:**
- ✅ Real-money gaming allowed in some regions (with license)
- ✅ External payments allowed for physical goods
- ✅ Alternative payment methods (in some regions)

**Your compliance status:**
- ✅ Skill-based competition
- ✅ No real-money gambling
- ✅ Clear terms posted
- **Status: Compliant**

---

## Implementation Roadmap

### Phase 1: Free Tier Foundation (Months 1-3)

**Goal:** Build user base, prove product-market fit

**Features:**
- ✅ Simple scoring system (record-based underdogs)
- ✅ BR currency economy
- ✅ Daily bonuses and achievements
- ✅ Basic leaderboards
- ✅ All sports supported

**Legal:**
- ✅ Post terms of service
- ✅ Add age gate (18+)
- ✅ Basic privacy policy

**Success Metrics:**
- 1,000+ registered users
- 500+ MAU
- 100+ daily active pools
- 3+ pools per user average

**No monetization:** Focus on retention and engagement

---

### Phase 2: Premium Launch (Months 4-6)

**Goal:** Launch premium tier, test conversion

**Features:**
- ✅ $1.99/month premium subscription
- ✅ Real odds integration (The Odds API)
- ✅ Exclusive odds-based pools
- ✅ Edge intelligence features
- ✅ 7-day free trial

**Legal:**
- ✅ Update terms for premium tier
- ✅ Add subscription management
- ✅ Document API quota management

**Marketing:**
- ✅ In-app upgrade prompts
- ✅ Feature comparison chart
- ✅ "Try free for 7 days" campaign

**Success Metrics:**
- 2-5% conversion to premium
- <10% churn rate (monthly)
- 4.5+ star app store rating

**Revenue Goal:** Break-even (100-150 premium subscribers)

---

### Phase 3: Competitions Launch (Months 7-9)

**Goal:** Add premium competitions, drive premium growth

**Features:**
- ✅ Monthly Premium Challenge leaderboard
- ✅ Top 10 win prizes (1-6 weeks free, capped at 6 weeks max)
- ✅ Achievement-based premium trials (free users)
- ✅ Annual subscription option ($19.99/year)

**Legal:**
- ✅ Post official rules
- ✅ Get legal review ($3,000-5,000)
- ✅ File in required states (if needed)
- ✅ Add prize fulfillment system

**Marketing:**
- ✅ "Win Free Premium" messaging
- ✅ Monthly winner announcements
- ✅ Success stories / testimonials

**Success Metrics:**
- 5-10% premium conversion
- 20%+ engagement increase
- 500+ premium subscribers

**Revenue Goal:** $750-1,500/month profit

---

### Phase 4: Scale & Optimize (Months 10-12)

**Goal:** Grow user base, optimize conversion

**Features:**
- ✅ Team pools / private leagues
- ✅ Social sharing improvements
- ✅ Push notification optimization
- ✅ Referral rewards program

**Legal:**
- ✅ Ongoing compliance monitoring
- ✅ Update rules as needed
- ✅ Expand to restricted states (if viable)

**Marketing:**
- ✅ Influencer partnerships
- ✅ Sports community outreach
- ✅ Paid acquisition testing

**Success Metrics:**
- 10,000+ MAU
- 10%+ premium conversion
- 1,000+ premium subscribers
- $1,000+/month profit

---

## Technical Requirements

### Free Tier Implementation

**Scoring System:**
```dart
// simple_pick_scoring.dart enhancements
- Add record-based underdog detection
- Formula: underdogBonus = max(0, (opponentWins - teamWins) / 20)
- Use ESPN records/rankings (free data)
- Apply confidence multiplier (0.9x to 1.3x)
```

**BR Economy:**
```dart
// br_currency_service.dart (new)
- Track BR balance per user
- Daily bonus system
- Achievement rewards
- Referral tracking
- Purchase handling via IAP
```

**Pool Generation:**
```dart
// pool_auto_generator.dart updates
- Remove odds availability checks
- Generate simple pick pools for ALL games
- Add metadata: requiresOdds: false
- Enable confidence multiplier
```

---

### Premium Tier Implementation

**Subscription Management:**
```dart
// subscription_service.dart (new)
- Apple IAP integration (StoreKit 2)
- Google IAP integration (Billing Library)
- Subscription status checking
- Trial period management
- Restore purchases
- Cross-platform sync
```

**Odds Integration:**
```dart
// odds_api_service.dart (existing - optimize)
- Implement Firestore caching (2-6 hour TTL)
- Quota manager enforcement
- Multi-endpoint optimization
- Premium-only API calls
- Fallback to ESPN if quota exceeded
```

**Premium Features:**
```dart
// premium_features_service.dart (new)
- Feature flagging system
- Edge intelligence (AI picks)
- Live odds tracking
- Historical trends
- Line movement alerts
```

---

### Competition System

**Leaderboard:**
```dart
// leaderboard_service.dart (new)
- Monthly premium rankings
- Skill-based scoring
- Minimum qualification (10 pools/month)
- Top 3 winner selection
- Prize fulfillment automation
```

**Prize Management:**
```dart
// prize_service.dart (new)
- Prize credit issuance (1-6 weeks, capped at 6 weeks max)
- Subscription extension logic
- Auto-subscribe popup with pre-checked opt-out
- Winner notification
- Prize history tracking
- Audit logging
```

---

### Analytics & Monitoring

**Key Metrics to Track:**
```
User Acquisition:
- Daily/Monthly Active Users
- Retention rates (D1, D7, D30)
- Churn rate

Monetization:
- Free → Premium conversion rate
- Trial → Paid conversion rate
- Revenue per user (ARPU)
- Lifetime value (LTV)
- Churn by tier

Engagement:
- Pools entered per user
- Picks made per user
- Daily login rate
- Feature usage (odds vs simple)

Technical:
- API quota usage
- Cache hit rates
- App crashes
- Response times
```

**Tools:**
- Firebase Analytics
- RevenueCat (IAP analytics)
- Mixpanel or Amplitude
- Sentry (error tracking)

---

## Marketing Strategy

### Value Proposition

**Free Tier:**
"Prove Your Sports Knowledge - Compete for Free"

**Key Messages:**
- No credit card required
- Earn rewards just by playing
- Compete against friends
- All sports, all season
- Build your ranking

---

**Premium Tier:**
"Get the Sharpest Edge - Real Vegas Odds"

**Key Messages:**
- Real-time betting lines
- More accurate scoring
- Exclusive high-stakes pools
- AI-powered insights
- Less than a coffee per month

---

### Conversion Funnels

#### Free → Premium Trial

**Trigger Points:**
1. After 3 successful pool entries
2. When viewing exclusive premium pool
3. After losing close match to premium user
4. During major event (UFC PPV, playoffs)
5. When free user hits 5-game win streak

**Messaging:**
- "See what you're missing with real odds"
- "Try premium free for 7 days"
- "Upgrade to compete in [Event] pools"
- "Premium users score 23% higher on average"

---

#### Trial → Paid

**Day 1-2:** Welcome sequence
- Feature tour
- First premium pool entry
- Odds tutorial

**Day 3-4:** Engagement reminders
- "You've earned +50 points with odds!"
- Show performance comparison

**Day 5-6:** Pre-expiration nudge
- "2 days left in your trial"
- "Lock in $1.99/mo before trial ends"
- Show annual savings option

**Day 7:** Expiration handling
- "Your trial has ended"
- One-click re-subscribe
- Downgrade to free (graceful)

---

### Retention Tactics

**For Free Users:**
- Daily login streaks (BR bonuses)
- Weekly challenges
- Seasonal achievements
- Referral rewards (200 BR per friend)
- Social sharing rewards

**For Premium Users:**
- Monthly leaderboard competition
- Exclusive event pools
- Early access to new features
- Priority support
- Ad-free experience
- Winner spotlights

---

### User Acquisition Channels

**Organic:**
- App Store Optimization (ASO)
- Social media (Twitter, Reddit: r/sportsbook, r/fantasyfootball)
- Sports forums and communities
- Word of mouth / referrals

**Paid (when profitable):**
- Google Ads (search: "sports betting app", "fantasy sports")
- Meta Ads (interest targeting: sports fans, betting enthusiasts)
- TikTok Ads (short demo videos)
- Influencer partnerships (sports YouTubers)

**Content Marketing:**
- Blog: "How to pick NFL winners"
- YouTube: Strategy guides, winner interviews
- Podcast appearances
- Guest posts on sports sites

---

## Risk Mitigation

### Legal Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| State gambling challenge | Low | High | Get legal review, post clear rules, maintain free entry |
| App store rejection | Low | High | Follow guidelines exactly, emphasize skill-based |
| User age violation | Medium | Medium | Robust age gate, ID verification for prizes |
| Tax reporting error | Low | Low | Stay under $600/year per user, implement 1099 system for future |

**Insurance:** Consider E&O policy ($500-1,000/year) once revenue > $10K/month

---

### Technical Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| API quota exceeded | Medium | Medium | Implement caching, quota manager, premium-only gating |
| Subscription sync issues | Medium | Medium | Use RevenueCat or similar, test thoroughly |
| Prize fulfillment bug | Low | High | Manual review for winners, audit logging, test environment |
| Data breach | Low | Critical | Use Firebase security rules, encrypt PII, regular audits |

---

### Business Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Low conversion (<2%) | Medium | High | A/B test pricing, improve onboarding, add more premium value |
| High churn (>20%/mo) | Medium | High | Engagement features, better retention tactics, annual plans |
| Competitor launches | Medium | Medium | Focus on community, faster iteration, unique features |
| API price increase | Low | Medium | Have ESPN fallback, negotiate volume discount, pass costs to users |

---

## Success Metrics & KPIs

### Phase 1 (Free Tier) - Months 1-3

**Growth:**
- ✅ 1,000+ registered users
- ✅ 50%+ D1 retention
- ✅ 30%+ D7 retention

**Engagement:**
- ✅ 3+ pools per user per week
- ✅ 60%+ weekly active users
- ✅ 100+ daily active pools

**Quality:**
- ✅ 4.5+ star rating
- ✅ <1% crash rate
- ✅ <2 second load time

---

### Phase 2 (Premium Launch) - Months 4-6

**Monetization:**
- ✅ 2-5% free → premium conversion
- ✅ 50%+ trial → paid conversion
- ✅ 100-200 premium subscribers
- ✅ Break-even revenue

**Retention:**
- ✅ <10% monthly churn
- ✅ 70%+ trial completion rate
- ✅ 3+ months average LTV

---

### Phase 3 (Competitions) - Months 7-9

**Scale:**
- ✅ 5,000+ MAU
- ✅ 5-10% premium conversion
- ✅ 500+ premium subscribers
- ✅ $750-1,500/month profit

**Engagement:**
- ✅ 40%+ increase in premium pool participation
- ✅ 20%+ increase in overall engagement
- ✅ 10+ pools per premium user per month

---

### Phase 4 (Scale) - Months 10-12

**Growth:**
- ✅ 10,000+ MAU
- ✅ 10%+ premium conversion
- ✅ 1,000+ premium subscribers
- ✅ $1,000-2,000/month profit

**Sustainability:**
- ✅ Positive unit economics
- ✅ <$5 CAC (customer acquisition cost)
- ✅ >$20 LTV (lifetime value)
- ✅ LTV:CAC ratio > 3:1

---

## Budget Summary

### One-Time Costs

| Item | Cost | Timeline |
|------|------|----------|
| Legal review (attorney opinion) | $1,500-3,000 | Before Phase 3 |
| Official rules drafting | $1,000-2,000 | Before Phase 3 |
| Terms of service update | $500-1,000 | Before Phase 2 |
| Total | **$3,000-6,000** | One-time |

---

### Monthly Recurring Costs

| Item | Cost (at 500 premium users) | Cost (at 1,000 premium users) |
|------|------------------------------|-------------------------------|
| The Odds API | $75 | $150 |
| Firebase/Firestore | $50 | $75 |
| Server hosting | $50 | $75 |
| Analytics tools | $0-50 | $50-100 |
| Legal compliance | $83 | $83 |
| **Total Fixed** | **$258-308** | **$433-483** |

---

### Revenue Summary (5% Conversion)

| MAU | Premium Users | Gross Revenue | Net Revenue (after fees) | Costs | Profit |
|-----|---------------|---------------|--------------------------|-------|--------|
| 1,000 | 50 | $100 | $70 | $165 | **-$95** |
| 2,500 | 125 | $249 | $174 | $195 | **-$21** |
| 5,000 | 250 | $498 | $348 | $250 | **+$98** |
| 10,000 | 500 | $995 | $697 | $308 | **+$389** |
| 20,000 | 1,000 | $1,990 | $1,393 | $433 | **+$960** |

**Break-even point:** ~4,000 MAU with 5% conversion (200 premium users)

---

## Next Steps

### Immediate Actions (This Week)

1. ✅ Disable odds API calls in testing to stop quota burn
2. ✅ Finalize simple scoring implementation for all sports
3. ✅ Review and approve this freemium strategy
4. ✅ Create project timeline with milestones

### Phase 1 Prep (Next 2 Weeks)

1. ✅ Implement record-based underdog bonuses
2. ✅ Build BR currency system
3. ✅ Add daily bonus mechanics
4. ✅ Create achievement system
5. ✅ Update pool generation to remove odds requirements
6. ✅ Test free tier end-to-end

### Phase 2 Prep (Months 2-3)

1. ✅ Integrate Apple IAP (StoreKit)
2. ✅ Integrate Google IAP
3. ✅ Implement subscription management
4. ✅ Build premium feature flags
5. ✅ Optimize odds API with caching
6. ✅ Create upgrade prompts and flows
7. ✅ Design free trial experience

### Legal Prep (Before Phase 3)

1. ✅ Hire attorney for review ($1,500-3,000)
2. ✅ Draft official rules
3. ✅ Update terms of service
4. ✅ Update privacy policy
5. ✅ Implement age verification
6. ✅ Add geographic restrictions
7. ✅ Create prize fulfillment system

---

## Appendices

### A. Competitive Analysis

**Direct Competitors:**
- PrizePicks (DFS, $5+ entries, cash prizes, requires license)
- Underdog Fantasy (DFS, paid entries, cash prizes, licensed)
- Sleeper (100% free, no monetization, bragging rights only)

**Your Differentiators:**
- Lower barrier to entry (free tier)
- Affordable premium ($1.99 vs $5+ entries)
- No gambling license required
- Available in all 50 states (eventually)
- In-app currency system (no cash withdrawal risks)

---

### B. Feature Comparison Matrix

| Feature | Free Tier | Premium ($1.99/mo) |
|---------|-----------|-------------------|
| Simple scoring | ✅ | ✅ |
| Real Vegas odds | ❌ | ✅ |
| All sports | ✅ | ✅ |
| All pool types | ✅ | ✅ |
| BR currency earning | ✅ | ✅ Faster |
| Confidence multipliers | ✅ | ✅ |
| Basic leaderboards | ✅ | ✅ |
| Premium-only pools | ❌ | ✅ |
| Edge AI picks | ❌ | ✅ |
| Live odds alerts | ❌ | ✅ |
| Historical trends | ❌ | ✅ |
| Ad-free | ❌ | ✅ |
| Priority support | ❌ | ✅ |
| Monthly competitions | ❌ | ✅ |
| Annual savings option | ❌ | ✅ |

---

### C. Example Official Rules Outline

**Full template to be created in separate document**

**Sections required:**
1. Sponsor information
2. Eligibility (age, location)
3. How to enter (free and paid methods)
4. Entry period and deadlines
5. Prize descriptions and values
6. Winner selection criteria
7. Winner notification process
8. Odds of winning disclosure
9. Conditions and restrictions
10. Disputes and governing law
11. Privacy policy reference
12. Limitation of liability

---

### D. In-App Messaging Templates

**Free → Trial Conversion:**

**Prompt 1 (After 3 pools):**
> "🎯 You're getting good at this!
>
> Upgrade to **Odds Edge** and compete with real Vegas lines.
>
> **Try FREE for 7 days**
>
> [Start Free Trial] [Maybe Later]"

**Prompt 2 (Viewing premium pool):**
> "🔒 This is a premium pool with **real odds**
>
> Premium users score 23% higher with precise underdog bonuses.
>
> **$1.99/month • Try 7 days FREE**
>
> [Unlock Premium] [Stay Free]"

**Prompt 3 (Win streak):**
> "🔥 5-game win streak!
>
> Imagine your score with real-time Vegas odds.
>
> **Try Odds Edge free for 7 days**
>
> [Upgrade Now] [Not Now]"

---

**Trial → Paid Conversion:**

**Day 5 of 7 (Pre-expiration):**
> "⏰ Your premium trial ends in 2 days
>
> You've earned **+156 points** with real odds this week.
>
> Lock in **$1.99/month** to keep your edge.
>
> Save 16% with annual plan: **$19.99/year**
>
> [Continue Premium] [Switch to Annual] [Return to Free]"

---

### E. Support Resources

**Customer Support FAQs:**

**"What's the difference between Free and Premium?"**
> Free tier uses simple scoring based on team records. Premium uses real Vegas odds for more precise underdog bonuses and exclusive features. [See full comparison]

**"How do I earn BR for free?"**
> Daily login (50 BR), referrals (200 BR), watching ads (25 BR), achievements, and weekly streaks. You can compete without spending a cent!

**"Can I cancel my premium subscription anytime?"**
> Yes! Cancel anytime from your account settings. You'll keep premium through the end of your billing period.

**"How do I win free premium weeks?"**
> Be in the top 10 premium users each month based on skill rankings. Must make picks in 10+ pools to qualify. Win 1-6 weeks free (max 6 weeks). See official rules for details.

**"Is this gambling?"**
> No. Bragging Rights is a skill-based sports prediction game. You're competing based on your sports knowledge, not random chance. Plus, free entry is always available.

---

## Document Maintenance

**Review Schedule:**
- Monthly: Revenue metrics, conversion rates, user feedback
- Quarterly: Legal compliance, feature performance, competition analysis
- Annually: Full strategy review, pricing adjustments, goal setting

**Version History:**
- v1.0 (2025-01-06): Initial strategy document

**Document Owner:** Product/Business Lead

**Stakeholders:** Engineering, Legal, Marketing, Finance

---

## Conclusion

This freemium model balances:
- ✅ **User accessibility** (free tier is genuinely free)
- ✅ **Legal compliance** (skill-based, free entry, no gambling license)
- ✅ **Profitability** (92% margins on premium)
- ✅ **Scalability** (costs grow linearly with premium users)
- ✅ **Competitiveness** ($1.99 vs $5+ competitors)

**The path forward is clear:**
1. Launch free tier and build user base (Months 1-3)
2. Add premium tier and test conversion (Months 4-6)
3. Implement competitions and scale (Months 7-12)

**Success criteria:**
- 10,000+ MAU by month 12
- 5-10% premium conversion
- $1,000+/month profit
- 4.5+ star rating
- Legal compliance maintained

**Next milestone:** Complete Phase 1 implementation and reach 1,000+ registered users.

---

**Questions or feedback?** Contact [Product Lead] or open a GitHub issue in the project repository.
