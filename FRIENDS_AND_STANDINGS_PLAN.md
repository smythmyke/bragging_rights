# Friends & Standings Feature Plan

## Overview
Implement a social layer that tracks friend relationships, displays competitive standings, and shows brief info cards on app launch to increase engagement and competition.

## 1. Friends System Architecture

### 1.1 Contact Integration
- **Permission Flow**
  - Request contacts permission on first "Invite Friends" tap
  - Explain value: "Find friends already on Bragging Rights and invite others"
  - Store permission status in SharedPreferences
  
- **Contact Syncing**
  - Hash phone numbers for privacy (SHA-256)
  - Match hashed numbers against registered users
  - Show contacts in 3 categories:
    1. Already on app (can add as friend)
    2. Invited (pending)
    3. Not invited (can send invite)

### 1.2 Friend Relationships Database Structure
```
firestore/
├── users/
│   └── {userId}/
│       ├── friends: [array of friend userIds]
│       ├── pendingInvites: [array of phone numbers]
│       └── friendRequests: [array of requesting userIds]
│
├── friendships/
│   └── {friendship_id}/  // Combined userId1_userId2
│       ├── users: [userId1, userId2]
│       ├── createdAt: timestamp
│       ├── headToHead: {
│       │   userId1Wins: number,
│       │   userId2Wins: number,
│       │   totalBets: number
│       │ }
│       └── sharedPools: [array of poolIds]
│
└── invites/
    └── {phoneNumberHash}/
        ├── invitedBy: [array of userIds]
        └── invitedAt: timestamp
```

### 1.3 Invite Flow
1. User taps "Invite Friends" in settings
2. Show contacts list with search/filter
3. For non-users: Open native SMS app with pre-filled message
   - Message: "Join me on Bragging Rights! [app_link]?code=[user_invite_code]"
   - User sends from their own SMS app
4. For existing users: Send in-app friend request (requires confirmation)
5. Track invite status locally and show pending invites

## 2. Standings Info Card

### 2.1 Display Logic
- **When**: On app cold start (not resume from background)
- **Duration**: 5 seconds auto-dismiss or tap to close
- **Frequency**: Max once per 12 hours unless manually refreshed
- **Position**: Overlay on home screen after load

### 2.2 Data Components

#### Friends Activity Section
- Show top 3 most recent friend activities
- Activity types:
  - Recent wins with payout
  - Active streaks
  - Big bets placed
  - Milestone achievements
- Sort by recency (last 24 hours)
- Include user's position if not in top 3

#### Global Rankings Section
- **State Ranking**: Based on geo-location or profile setting
- **National Ranking**: Overall US ranking
- **Metrics**: 
  - Primary: Total profit/loss
  - Secondary: Win percentage
  - Tertiary: Total bets won

### 2.3 Performance Optimization
- Pre-fetch during splash screen
- Real-time ranking calculations using Firestore listeners
- Background refresh when app is idle
- Lightweight queries with proper indexing for speed

## 3. Implementation Phases

### Phase 1: Contact Integration & Friend System
- [ ] Implement contacts permission flow
- [ ] Create friend relationship models
- [ ] Build invite/add friend UI in settings
- [ ] Set up Firestore friend collections
- [ ] Implement phone number hashing

### Phase 2: Friend Tracking
- [ ] Track head-to-head records
- [ ] Monitor shared pool participation
- [ ] Create friend activity feed
- [ ] Build friendship stats aggregation

### Phase 3: Standings Card
- [ ] Design info card UI component
- [ ] Implement data fetching service
- [ ] Add caching layer
- [ ] Create animation/transition effects
- [ ] Add user preferences for display

### Phase 4: Enhanced Features
- [ ] Friend group competitions
- [ ] Weekly friend leaderboards
- [ ] Achievement badges
- [ ] Friend betting insights

## 4. Privacy & Security Considerations

### 4.1 Contact Data
- Never store raw phone numbers
- Use one-way hashing for matching
- Opt-in model: Users must enable "Be discoverable by phone number" in settings
- Clear privacy policy on data usage

### 4.2 User Controls
- Toggle friend visibility
- Block/unblock users
- Delete friendship history
- Export personal data (GDPR compliance)

## 5. Notification Strategy

### 5.1 Friend Notifications
- Friend request received (requires confirmation)
- Friend won big bet (optional)
- Friend beat your score
- Weekly friend standings summary

### 5.2 SMS Invite Strategy (Device-Based)
- Use native device SMS (no cost to app)
- Pre-fill SMS with invite message and app link
- User sends from their own phone number (builds trust)
- Track invites sent via in-app analytics
- Can't auto-send reminders (user must manually resend)
- Flutter packages: url_launcher or flutter_sms

## 6. Analytics to Track

- Friend invite conversion rate
- Average friends per user
- Friend retention vs solo retention
- Head-to-head bet frequency
- Info card engagement rate
- Time spent viewing standings

## 7. Future Enhancements

- **Friend Pools**: Create private pools for friend groups
- **Challenges**: Send direct bet challenges to friends
- **Chat**: Simple messaging between friends
- **Social Sharing**: Share wins to social media
- **Friend Insights**: "You beat Mike 73% of the time in NBA bets"

## 8. Technical Considerations

### 8.1 Scalability
- Index friendship collections properly
- Paginate friend lists over 50
- Use Cloud Functions for heavy aggregations
- Consider Redis for real-time leaderboards

### 8.2 Edge Cases
- User changes phone number
- Circular friend requests (both users must confirm)
- Deleted accounts cleanup
- Maximum friends limit: 100 per user
- Rate limiting for invites (max 20 per day)

## 9. UI/UX Guidelines

- Keep info card clean and scannable
- Use consistent ranking indicators (#, arrows)
- Animate transitions smoothly
- Provide clear CTA for viewing full standings
- Make friend management intuitive

## 10. Success Metrics

- **Adoption**: 60% of users add at least 1 friend
- **Engagement**: 40% increase in daily active users
- **Retention**: 25% better 30-day retention for users with friends
- **Virality**: Each user invites average of 3 friends