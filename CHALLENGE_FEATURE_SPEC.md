# Sports Picks Challenge/Share Feature Specification

## Version 1.2.0
**Last Updated:** September 2025
**Status:** In Development

---

## Table of Contents
1. [Overview](#overview)
2. [Multi-Sport Implementation](#multi-sport-implementation)
3. [Existing System Integration](#existing-system-integration)
4. [User Stories](#user-stories)
5. [Technical Architecture](#technical-architecture)
6. [UI/UX Design](#uiux-design)
7. [Firebase Dynamic Links Setup](#firebase-dynamic-links-setup)
8. [Database Schema](#database-schema)
9. [Friend Selection & Management](#friend-selection--management)
10. [Notification System](#notification-system)
11. [API Endpoints](#api-endpoints)
12. [Implementation Phases](#implementation-phases)
13. [Testing Requirements](#testing-requirements)

---

## Overview

### Feature Description
The Challenge/Share feature allows users to challenge friends to compete in sports predictions across all supported sports (MMA, Boxing, NFL, NBA, NHL, MLB, Soccer). Users can share their picks via SMS or WhatsApp, with recipients receiving a deep link that either opens the app (if installed) or directs them to download it.

### Multi-Sport Support
This feature is designed to work universally across all sports in the Bragging Rights app. The implementation uses sport-agnostic data structures and UI components that adapt to the specific sport context (fight cards for combat sports, game schedules for team sports).

### Core Features
- Challenge existing friends from in-app friends list
- Share picks challenge via SMS/WhatsApp to any contact
- Firebase Dynamic Links for smart app routing
- Real-time notifications for challenge events
- Head-to-head pick comparison
- Challenge history and statistics per friend
- Group challenges for multiple friends
- **Multi-sport support** for all sports in the app

### Success Metrics
- Challenge acceptance rate > 40%
- User acquisition through challenges > 20%
- Challenge completion rate > 60%
- User retention increase > 15%
- Friend-to-friend challenge rate > 30%

---

## Multi-Sport Implementation

### Sport-Agnostic Design Principles

The Challenge feature is built with a sport-agnostic architecture to ensure it works seamlessly across all sports:

#### 1. **Unified Data Model**
```dart
class Challenge {
  final String sportType;        // 'mma', 'boxing', 'nfl', 'nba', etc.
  final String eventId;          // Universal event identifier
  final String eventName;        // "UFC 295", "Lakers vs Celtics", etc.
  final Map<String, PickState> picks;  // Generic pick structure
}
```

#### 2. **Sport-Specific Adapters**
Each sport implements a common interface for challenge-specific operations:
```dart
abstract class ChallengeAdapter {
  String getEventDisplayName();
  Widget buildPicksPreview();
  int calculateScore();
  String getShareMessage();
}

// Implementations:
- MMAFightChallengeAdapter
- BoxingFightChallengeAdapter
- NFLGameChallengeAdapter
- NBAGameChallengeAdapter
- etc.
```

#### 3. **Universal UI Components**
All challenge UI components accept sport context:
- `ChallengeButton` works on any picks screen
- `FriendSelectionSheet` adapts to sport terminology
- `ChallengeShareSheet` generates sport-appropriate messages
- `ChallengeResultsScreen` displays results based on sport scoring

#### 4. **Sport Detection**
The system automatically detects the sport from context:
```dart
// In fight_card_grid_screen.dart (MMA/Boxing):
sportType: 'mma'  // or 'boxing'

// In game_picks_screen.dart (Team sports):
sportType: 'nfl'  // 'nba', 'nhl', 'mlb', 'soccer'
```

### Implementation Strategy
1. **Phase 1**: Build for combat sports (MMA/Boxing) as they share similar structure
2. **Phase 2**: Extend to team sports with sport-specific adapters
3. **Phase 3**: Unified challenge hub showing all sport challenges

---

## Existing System Integration

### Current Friends System
The app already has a comprehensive friends management system that we will leverage:

#### **Existing Components:**

1. **FriendService** (`lib/services/friend_service.dart`)
   - Manages friends list in Firestore `users` collection
   - Friend relationships stored in `friends` array field
   - Friend request system via `friendRequests` field
   - `friendships` collection for head-to-head statistics
   - Friend activity tracking and rankings

2. **InviteFriendsScreen** (`lib/screens/friends/invite_friends_screen.dart`)
   - Contact permission handling
   - Phone number hashing for privacy (SHA-256)
   - SMS invite system with invite codes
   - Friend request sending functionality
   - Shows which contacts are already on the app

3. **Database Structure**
   ```javascript
   users/{userId} {
     friends: [userId1, userId2, ...],        // Array of friend user IDs
     friendRequests: [userId1, userId2, ...], // Pending friend requests
     phoneHash: string,                       // Hashed phone for contact matching
     username: string,
     displayName: string,
     totalProfit: number,
     winRate: number,
     currentStreak: number,
     lastActive: timestamp
   }

   friendships/{friendshipId} {
     users: [userId1, userId2],
     createdAt: timestamp,
     headToHead: {
       userId1Wins: number,
       userId2Wins: number,
       totalBets: number
     },
     sharedPools: []
   }
   ```

### Integration Strategy
- Leverage existing friends list for quick challenge selection
- Use existing friend request system for post-challenge friend additions
- Extend `friendships` collection to include challenge statistics
- Utilize existing phone number hashing for privacy-compliant contact matching

---

## User Stories

### Challenger Flow
1. **As a user**, I want to challenge my friends after making my picks
2. **As a user**, I want to share challenges via my preferred messaging app
3. **As a user**, I want to see when my challenge is accepted
4. **As a user**, I want to track my record against specific friends

### Recipient Flow
1. **As a recipient**, I want to easily accept a challenge
2. **As a new user**, I want to seamlessly download the app from a challenge link
3. **As a recipient**, I want to see the challenger's picks after I complete mine
4. **As a recipient**, I want notifications about challenge status

---

## Technical Architecture

### Technology Stack
```yaml
Frontend:
  - Flutter 3.x
  - Provider/Riverpod for state management
  - share_plus: ^7.2.0
  - firebase_dynamic_links: ^5.4.0
  - firebase_messaging: ^14.7.0
  - url_launcher: ^6.2.0

Backend:
  - Firebase Firestore
  - Firebase Cloud Functions
  - Firebase Cloud Messaging (FCM)
  - Firebase Dynamic Links

Analytics:
  - Firebase Analytics
  - Custom event tracking
```

### System Architecture
```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Flutter   │────▶│   Firebase   │────▶│   Friend's  │
│     App     │     │   Services   │     │    Device   │
└─────────────┘     └──────────────┘     └─────────────┘
       │                    │                     │
       │                    │                     │
       ▼                    ▼                     ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Challenge  │     │   Dynamic    │     │   App/Play  │
│   Create    │     │    Links     │     │    Store    │
└─────────────┘     └──────────────┘     └─────────────┘
```

---

## UI/UX Design

### Three-Button Layout Implementation

#### Current State (fight_card_grid_screen.dart)
```dart
// Lines 564-639: Current two-button layout
[ADVANCED BETS] [SAVE PICKS]
```

#### New Design
```dart
// Updated three-button layout
[ADVANCED 📊] [CHALLENGE 🤝] [SAVE PICKS ✓]

// Button states:
- ADVANCED: Enabled when any picks made
- CHALLENGE: Enabled after picks saved
- SAVE PICKS: Enabled when picks made, disabled during save
```

### Screen Flows

#### 1. Challenge Creation Flow with Friend Selection
```
Make Picks → Save Picks → Challenge Button → Friend Selection Sheet
                              │
                    ┌─────────┴──────────┐
                    ▼                    ▼
            Select Friends        Create Open Challenge
                    │                    │
                    ▼                    ▼
            Send to Selected      Share via SMS/WhatsApp
                    │                    │
                    ▼                    ▼
        In-app Notifications      Generate Dynamic Link
                    │                    │
                    ▼                    ▼
        Challenge Created         Format Share Message
```

#### 2. Challenge Acceptance Flow
```
Receive Link → Click Link → App Installed?
                                │
                    ┌───────────┴───────────┐
                    ▼                       ▼
                App Opens              Play Store
                    │                       │
                    ▼                       ▼
            Challenge Screen          Install App
                    │                       │
                    ▼                       ▼
              Accept Challenge         Open App
                    │                       │
                    ▼                       ▼
               Make Picks            Challenge Screen
```

### UI Components

#### Challenge Button Widget
```dart
class ChallengeButton extends StatelessWidget {
  final bool isEnabled;
  final VoidCallback onPressed;
  final int challengeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isEnabled
          ? BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.warningAmber, AppTheme.secondaryAmber],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: AppTheme.neonGlow(
                color: AppTheme.warningAmber,
                intensity: 0.4,
              ),
            )
          : null,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(Icons.group, size: 18),
        label: Text('CHALLENGE'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
```

#### Friend Selection Sheet
```dart
class FriendSelectionSheet extends StatefulWidget {
  final String eventId;
  final String eventName;
  final Map<String, FightPickState> picks;

  @override
  State<FriendSelectionSheet> createState() => _FriendSelectionSheetState();
}

class _FriendSelectionSheetState extends State<FriendSelectionSheet> {
  final FriendService _friendService = FriendService();
  final Set<String> _selectedFriends = {};
  List<FriendData> _friends = [];
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with tabs
          Row(
            children: [
              Expanded(
                child: Text('Challenge Friends',
                  style: AppTheme.neonText(fontSize: 20)),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          // Tab selector
          Container(
            margin: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                _TabButton(
                  label: 'Friends',
                  isActive: true,
                  count: _friends.length,
                ),
                SizedBox(width: 8),
                _TabButton(
                  label: 'Recent',
                  isActive: false,
                  onTap: () => _showRecentOpponents(),
                ),
                SizedBox(width: 8),
                _TabButton(
                  label: 'Pool Members',
                  isActive: false,
                  onTap: () => _showPoolMembers(),
                ),
              ],
            ),
          ),

          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search friends...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: _filterFriends,
          ),

          // Friends list
          Expanded(
            child: ListView.builder(
              itemCount: _friends.length,
              itemBuilder: (context, index) {
                final friend = _friends[index];
                return FriendTile(
                  friend: friend,
                  isSelected: _selectedFriends.contains(friend.id),
                  onTap: () => _toggleFriend(friend.id),
                  showStats: true, // Show challenge W/L record
                );
              },
            ),
          ),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createOpenChallenge,
                  icon: Icon(Icons.public),
                  label: Text('Open Challenge'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _selectedFriends.isNotEmpty
                    ? () => _sendChallenges()
                    : null,
                  icon: Icon(Icons.send),
                  label: Text('Send (${_selectedFriends.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryCyan,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

#### Share Options Sheet (for Open Challenge)
```dart
class ChallengeShareSheet extends StatelessWidget {
  final String challengeId;
  final String shareLink;
  final String eventName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Share Challenge',
            style: AppTheme.neonText(fontSize: 20)),
          SizedBox(height: 8),
          Text('Anyone with this link can accept your challenge',
            style: TextStyle(color: Colors.white60, fontSize: 12)),
          SizedBox(height: 20),

          // Quick share options
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareOption(
                icon: Icons.message,
                label: 'SMS',
                color: AppTheme.primaryCyan,
                onTap: () => _shareViaSMS(),
              ),
              _ShareOption(
                icon: FontAwesomeIcons.whatsapp,
                label: 'WhatsApp',
                color: Colors.green,
                onTap: () => _shareViaWhatsApp(),
              ),
              _ShareOption(
                icon: Icons.copy,
                label: 'Copy Link',
                color: AppTheme.warningAmber,
                onTap: () => _copyLink(),
              ),
              _ShareOption(
                icon: Icons.share,
                label: 'More',
                color: AppTheme.secondaryCyan,
                onTap: () => _shareViaSystem(),
              ),
            ],
          ),

          SizedBox(height: 20),

          // Link preview
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 20, color: AppTheme.primaryCyan),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shareLink,
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Firebase Dynamic Links Setup

### Configuration Steps

#### 1. Firebase Console Setup
```yaml
Project Settings:
  - Enable Dynamic Links
  - Add domain: braggingrights.page.link
  - Configure iOS Bundle ID: com.braggingrights.app
  - Configure Android Package: com.braggingrights.app

iOS Configuration:
  - Add Associated Domains capability
  - Add domain: applinks:braggingrights.page.link
  - Update Info.plist with URL schemes

Android Configuration:
  - Add intent filters in AndroidManifest.xml
  - Configure SHA-256 certificate fingerprints
```

#### 2. Dynamic Link Generation
```dart
class DynamicLinkService {
  final FirebaseDynamicLinks _dynamicLinks = FirebaseDynamicLinks.instance;

  Future<String> createChallengeLink({
    required String challengeId,
    required String challengerName,
    required String eventName,
  }) async {
    final DynamicLinkParameters parameters = DynamicLinkParameters(
      uriPrefix: 'https://braggingrights.page.link',
      link: Uri.parse('https://braggingrights.app/challenge'
          '?id=$challengeId'
          '&challenger=${Uri.encodeComponent(challengerName)}'
          '&event=${Uri.encodeComponent(eventName)}'),
      androidParameters: AndroidParameters(
        packageName: 'com.braggingrights.app',
        minimumVersion: 1,
        fallbackUrl: Uri.parse('https://play.google.com/store/apps/details?id=com.braggingrights.app'),
      ),
      iosParameters: IOSParameters(
        bundleId: 'com.braggingrights.app',
        minimumVersion: '1.0.0',
        fallbackUrl: Uri.parse('https://apps.apple.com/app/braggingrights/id123456789'),
        appStoreId: '123456789',
      ),
      socialMetaTagParameters: SocialMetaTagParameters(
        title: 'MMA Challenge from $challengerName',
        description: 'Can you beat my picks for $eventName?',
        imageUrl: Uri.parse('https://braggingrights.app/images/challenge-preview.png'),
      ),
      navigationInfoParameters: NavigationInfoParameters(
        forcedRedirectEnabled: true,
      ),
    );

    final ShortDynamicLink shortLink =
        await _dynamicLinks.buildShortLink(parameters);

    return shortLink.shortUrl.toString();
  }

  // Handle incoming links
  Future<void> initDynamicLinks() async {
    // Handle link when app is already open
    _dynamicLinks.onLink.listen((dynamicLinkData) {
      _handleDeepLink(dynamicLinkData.link);
    }).onError((error) {
      print('Dynamic Link Error: $error');
    });

    // Handle link when app is opened from terminated state
    final PendingDynamicLinkData? initialLink =
        await _dynamicLinks.getInitialLink();

    if (initialLink != null) {
      _handleDeepLink(initialLink.link);
    }
  }

  void _handleDeepLink(Uri deepLink) {
    final challengeId = deepLink.queryParameters['id'];
    if (challengeId != null) {
      // Navigate to challenge acceptance screen
      NavigatorService.navigateTo(
        '/challenge/accept',
        arguments: {'challengeId': challengeId},
      );
    }
  }
}
```

---

## Database Schema

### Firestore Collections

#### Enhanced users Collection (Existing + New Fields)
```javascript
users/{userId} {
  // Existing fields
  username: string,
  displayName: string,
  phoneHash: string,                  // SHA-256 hashed phone number
  friends: [userId1, userId2, ...],   // Array of friend user IDs
  friendRequests: [userId1, ...],     // Pending friend requests
  totalProfit: number,
  winRate: number,
  currentStreak: number,
  lastActive: timestamp,

  // New challenge-related fields
  recentChallenges: [{
    challengeId: string,
    friendId: string,
    friendName: string,
    sportType: string,               // 'mma', 'boxing', 'nfl', etc.
    eventName: string,
    status: string,                  // 'sent', 'received', 'completed'
    createdAt: timestamp,
    result: string?                  // 'won', 'lost', 'tied'
  }],

  challengeStats: {
    sent: number,                    // Total challenges sent
    received: number,                // Total challenges received
    won: number,                     // Challenges won
    lost: number,                    // Challenges lost
    tied: number,                    // Challenges tied
    winRate: number,                 // Win percentage
    favoriteOpponent: string?,       // Most challenged friend ID
    bySport: {                       // Per-sport statistics
      {sportType}: {
        won: number,
        lost: number,
        tied: number,
      }
    }
  },

  challengePreferences: {
    allowOpenChallenges: boolean,    // Accept challenges from non-friends
    notificationsEnabled: boolean,
    autoAcceptFromFriends: boolean,
  }
}
```

#### Enhanced friendships Collection (Existing + New Fields)
```javascript
friendships/{friendshipId} {
  // Existing fields
  users: [userId1, userId2],
  createdAt: timestamp,
  headToHead: {
    userId1Wins: number,
    userId2Wins: number,
    totalBets: number
  },
  sharedPools: [],

  // New challenge-related fields
  challengeHistory: {
    totalChallenges: number,
    userId1Wins: number,
    userId2Wins: number,
    ties: number,
    lastChallenge: timestamp,
    currentStreak: {
      userId: string,                // Who's on a streak
      count: number                   // Streak count
    },
    recentChallenges: [{
      challengeId: string,
      eventName: string,
      winnerId: string,
      completedAt: timestamp
    }]
  }
}
```

#### challenges Collection
```javascript
challenges/{challengeId} {
  // Core Information
  challengerId: string,              // User ID of challenger
  challengerName: string,             // Display name
  challengerAvatar: string,           // Profile image URL

  // Sport & Event Details
  sportType: enum ['mma', 'boxing', 'nfl', 'nba', 'nhl', 'mlb', 'soccer'],
  eventId: string,                   // Universal event ID
  eventName: string,                 // "UFC 295", "Lakers vs Celtics", etc.
  eventDate: timestamp,              // Event date/time
  poolId: string?,                   // Optional pool ID

  // Challenge Type
  type: enum ['friend', 'group', 'open', 'pool'],
  targetFriends: [userId1, userId2], // For friend/group challenges
  isPublic: boolean,                 // For open challenges

  // Challenge Data
  picks: {                           // Encrypted until accepted
    {fightId}: {
      winnerId: string,
      winnerName: string,
      method: string,
      round: number?,
      confidence: number,
      pickedAt: timestamp
    }
  },

  // Status
  status: enum ['pending', 'accepted', 'completed', 'expired'],
  createdAt: timestamp,
  expiresAt: timestamp,              // 24 hours before event

  // Participants
  participants: [{
    userId: string,
    userName: string,
    userAvatar: string,
    isFriend: boolean,               // Was friend when accepted
    acceptedAt: timestamp,
    completedAt: timestamp?,
    score: number?,                  // Final score
    place: number?,                  // 1st, 2nd, 3rd etc
  }],

  // Results
  results: {
    winnerId: string?,
    winnerName: string?,
    scores: Map<userId, number>,
    completedAt: timestamp,
  },

  // Metadata
  shareLink: string,                 // Firebase Dynamic Link
  shareCount: number,                // Times shared
  viewCount: number,                 // Times viewed
  acceptanceRate: number,            // % who accepted
}
```

#### challenge_notifications Collection
```javascript
challenge_notifications/{notificationId} {
  userId: string,                    // Recipient user ID
  challengeId: string,
  type: enum ['challenge_received', 'challenge_accepted',
              'picks_completed', 'event_starting', 'results_ready'],
  title: string,
  body: string,
  data: Map<String, dynamic>,
  read: boolean,
  createdAt: timestamp,
  scheduledFor: timestamp?,          // For scheduled notifications
  sent: boolean,
  sentAt: timestamp?,
}
```

#### user_challenge_stats Collection
```javascript
user_challenge_stats/{userId} {
  totalChallenges: number,
  challengesWon: number,
  challengesLost: number,
  challengesTied: number,
  winRate: number,

  friendRecords: {
    {friendUserId}: {
      wins: number,
      losses: number,
      ties: number,
      lastChallenge: timestamp,
    }
  },

  achievements: [{
    type: string,                    // 'first_challenge', 'win_streak_5', etc
    unlockedAt: timestamp,
  }],

  updatedAt: timestamp,
}
```

---

## Friend Selection & Management

### Friend Selection Flow

#### Challenge Types
1. **Friend Challenge** - Direct challenge to selected friends
2. **Group Challenge** - Challenge multiple friends simultaneously
3. **Open Challenge** - Public link anyone can accept
4. **Pool Challenge** - Challenge all members of a pool

#### Friend Selection Interface
```dart
class ChallengeFlowManager {
  Future<void> initiateChallenge({
    required String eventId,
    required Map<String, FightPickState> picks,
  }) async {
    // Step 1: Save picks if not already saved
    await _savePicksIfNeeded(picks);

    // Step 2: Show friend selection sheet
    final selectedFriends = await showModalBottomSheet<List<String>>(
      context: context,
      builder: (_) => FriendSelectionSheet(
        eventId: eventId,
        eventName: event.eventName,
        picks: picks,
      ),
    );

    if (selectedFriends != null && selectedFriends.isNotEmpty) {
      // Step 3: Create friend/group challenge
      await _createFriendChallenge(selectedFriends);
    } else {
      // Step 3 Alternative: Show open challenge options
      await _showOpenChallengeOptions();
    }
  }
}
```

#### Friend List Categories
```dart
class FriendCategories {
  // Primary categories shown in tabs
  static const categories = {
    'friends': 'My Friends',        // All friends
    'recent': 'Recent Opponents',   // Last 10 challenged
    'pool': 'Pool Members',          // Members of current pool
    'suggested': 'Suggested',        // Algorithm-based suggestions
  };

  // Friend suggestion algorithm
  Future<List<FriendData>> getSuggestedFriends(String userId) async {
    // Prioritize by:
    // 1. Friends never challenged
    // 2. Friends with similar win rate
    // 3. Friends active in last 7 days
    // 4. Friends in same geographic region
    // 5. Mutual friends with high activity
  }

  // Recent opponents with rematch option
  Future<List<RecentOpponent>> getRecentOpponents(String userId) async {
    return firestore
      .collection('challenges')
      .where('participants', 'array-contains', userId)
      .orderBy('completedAt', descending: true)
      .limit(10)
      .get()
      .then((snapshot) => snapshot.docs
        .map((doc) => RecentOpponent.fromChallenge(doc.data()))
        .toList());
  }
}
```

#### Friend Stats Display
```dart
class FriendTile extends StatelessWidget {
  final FriendData friend;
  final ChallengeStats? challengeStats;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(friend.avatarUrl),
          ),
          if (friend.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(friend.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (challengeStats != null)
            Text('${challengeStats.wins}W - ${challengeStats.losses}L',
              style: TextStyle(color: AppTheme.primaryCyan, fontSize: 12)),
          Text('Win Rate: ${friend.winRate.toStringAsFixed(1)}%',
            style: TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (challengeStats?.currentStreak > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warningAmber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('🔥 ${challengeStats!.currentStreak}',
                style: TextStyle(color: AppTheme.warningAmber, fontSize: 12)),
            ),
          SizedBox(width: 8),
          Checkbox(
            value: isSelected,
            onChanged: (_) => onTap(),
            activeColor: AppTheme.primaryCyan,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
```

### Challenge Management Features

#### Quick Actions
```dart
class QuickChallengeActions {
  // Rematch last opponent
  Future<void> rematchLastOpponent() async {
    final lastChallenge = await getLastCompletedChallenge();
    if (lastChallenge != null) {
      final opponentId = lastChallenge.getOpponentId(currentUserId);
      await createChallenge(
        targetFriends: [opponentId],
        message: 'Rematch from ${lastChallenge.eventName}!',
      );
    }
  }

  // Challenge pool members
  Future<void> challengePoolMembers(String poolId) async {
    final members = await getPoolMembers(poolId);
    await createGroupChallenge(
      targetFriends: members.map((m) => m.userId).toList(),
      poolId: poolId,
    );
  }

  // Challenge by win rate range
  Future<void> challengeSimilarSkillLevel() async {
    final myWinRate = await getUserWinRate(currentUserId);
    final friends = await getFriendsInWinRateRange(
      myWinRate - 10,
      myWinRate + 10,
    );
    // Show filtered friend list
  }
}
```

#### Friend Request After Challenge
```dart
class PostChallengeActions {
  // Automatically suggest friend request after challenge
  Future<void> suggestFriendRequest(String opponentId) async {
    if (!await areFriends(currentUserId, opponentId)) {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Add as Friend?'),
          content: Text('Would you like to add your opponent as a friend for future challenges?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add Friend'),
            ),
          ],
        ),
      );

      if (shouldAdd == true) {
        await sendFriendRequest(opponentId);
      }
    }
  }
}
```

---

## Notification System

### Firebase Cloud Messaging (FCM) Setup

#### 1. Notification Types
```dart
enum NotificationType {
  challengeReceived,    // Someone challenged you
  challengeAccepted,    // Your challenge was accepted
  picksCompleted,       // Opponent completed their picks
  eventStarting,        // Event starting in 1 hour
  resultsReady,        // Challenge results available
}
```

#### 2. Cloud Function Triggers
```javascript
// functions/src/notifications.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Trigger: New challenge created
exports.onChallengeCreated = functions.firestore
  .document('challenges/{challengeId}')
  .onCreate(async (snap, context) => {
    const challenge = snap.data();
    const { challengeId } = context.params;

    // Send notification to app users (friends of challenger)
    await sendChallengeNotification({
      challengeId,
      challengerName: challenge.challengerName,
      eventName: challenge.eventName,
    });
  });

// Trigger: Challenge accepted
exports.onChallengeAccepted = functions.firestore
  .document('challenges/{challengeId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status === 'pending' && after.status === 'accepted') {
      // Notify challenger
      await admin.messaging().send({
        token: await getUserFCMToken(after.challengerId),
        notification: {
          title: 'Challenge Accepted! 🥊',
          body: `${after.participants[0].userName} accepted your ${after.eventName} challenge`,
        },
        data: {
          type: 'challenge_accepted',
          challengeId: context.params.challengeId,
        },
      });
    }
  });

// Trigger: Picks completed
exports.onPicksCompleted = functions.firestore
  .document('pools/{poolId}/picks/{userId}')
  .onWrite(async (change, context) => {
    const { poolId, userId } = context.params;

    // Check if user has pending challenges
    const challenges = await admin.firestore()
      .collection('challenges')
      .where('participants', 'array-contains', { userId })
      .where('status', '==', 'accepted')
      .get();

    for (const doc of challenges.docs) {
      const challenge = doc.data();
      // Notify challenger that opponent completed picks
      await notifyChallengerOfCompletion(doc.id, userId);
    }
  });

// Scheduled: Event starting reminder
exports.eventStartingReminder = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    const oneHourLater = new Date(now.toMillis() + 60 * 60 * 1000);

    // Find events starting in 1 hour
    const challenges = await admin.firestore()
      .collection('challenges')
      .where('eventDate', '>=', now)
      .where('eventDate', '<=', oneHourLater)
      .where('status', '==', 'accepted')
      .get();

    for (const doc of challenges.docs) {
      await sendEventStartingNotification(doc.id, doc.data());
    }
  });
```

#### 3. Client-Side Notification Handling
```dart
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get FCM token
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveTokenToDatabase(token);
      }

      // Handle token refresh
      _fcm.onTokenRefresh.listen(_saveTokenToDatabase);

      // Configure message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Show local notification
    await _showLocalNotification(
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: message.data,
    );
  }

  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    // Navigate based on notification type
    final type = message.data['type'];
    final challengeId = message.data['challengeId'];

    switch (type) {
      case 'challenge_accepted':
      case 'picks_completed':
        NavigatorService.navigateTo(
          '/challenge/details',
          arguments: {'challengeId': challengeId},
        );
        break;
      case 'results_ready':
        NavigatorService.navigateTo(
          '/challenge/results',
          arguments: {'challengeId': challengeId},
        );
        break;
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'challenges',
        'Challenge Notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@drawable/ic_notification',
        color: Color(0xFF00D4FF),
      );

    const IOSNotificationDetails iosDetails = IOSNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await FlutterLocalNotificationsPlugin().show(
      Random().nextInt(1000),
      title,
      body,
      details,
      payload: jsonEncode(data),
    );
  }
}
```

---

## API Endpoints

### Challenge Service Implementation
```dart
class ChallengeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DynamicLinkService _dynamicLinks = DynamicLinkService();
  final NotificationService _notifications = NotificationService();

  // Create new challenge
  Future<Challenge> createChallenge({
    required String eventId,
    required String eventName,
    required Map<String, FightPickState> picks,
    String? poolId,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final challengeId = _firestore.collection('challenges').doc().id;

      // Encrypt picks
      final encryptedPicks = await _encryptPicks(picks);

      // Create challenge document
      final challenge = Challenge(
        id: challengeId,
        challengerId: user.uid,
        challengerName: user.displayName ?? 'Anonymous',
        challengerAvatar: user.photoURL,
        eventId: eventId,
        eventName: eventName,
        eventDate: await _getEventDate(eventId),
        poolId: poolId,
        picks: encryptedPicks,
        status: ChallengeStatus.pending,
        createdAt: Timestamp.now(),
        expiresAt: Timestamp.fromDate(
          DateTime.now().add(Duration(hours: 24)),
        ),
        participants: [],
        shareCount: 0,
        viewCount: 0,
      );

      // Save to Firestore
      await _firestore
        .collection('challenges')
        .doc(challengeId)
        .set(challenge.toMap());

      // Generate dynamic link
      final shareLink = await _dynamicLinks.createChallengeLink(
        challengeId: challengeId,
        challengerName: challenge.challengerName,
        eventName: eventName,
      );

      challenge.shareLink = shareLink;

      // Update with share link
      await _firestore
        .collection('challenges')
        .doc(challengeId)
        .update({'shareLink': shareLink});

      return challenge;
    } catch (e) {
      throw Exception('Failed to create challenge: $e');
    }
  }

  // Accept challenge
  Future<void> acceptChallenge(String challengeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser!;

      await _firestore.runTransaction((transaction) async {
        final challengeDoc = await transaction.get(
          _firestore.collection('challenges').doc(challengeId),
        );

        if (!challengeDoc.exists) {
          throw Exception('Challenge not found');
        }

        final challenge = Challenge.fromMap(challengeDoc.data()!);

        // Check if already accepted
        if (challenge.participants.any((p) => p.userId == user.uid)) {
          throw Exception('Already accepted this challenge');
        }

        // Add participant
        final participant = ChallengeParticipant(
          userId: user.uid,
          userName: user.displayName ?? 'Anonymous',
          userAvatar: user.photoURL,
          acceptedAt: Timestamp.now(),
        );

        transaction.update(
          _firestore.collection('challenges').doc(challengeId),
          {
            'status': 'accepted',
            'participants': FieldValue.arrayUnion([participant.toMap()]),
          },
        );
      });

      // Send notification to challenger
      await _notifications.sendChallengeAcceptedNotification(challengeId);

    } catch (e) {
      throw Exception('Failed to accept challenge: $e');
    }
  }

  // Get challenge details
  Future<Challenge> getChallenge(String challengeId) async {
    try {
      final doc = await _firestore
        .collection('challenges')
        .doc(challengeId)
        .get();

      if (!doc.exists) {
        throw Exception('Challenge not found');
      }

      // Increment view count
      await _firestore
        .collection('challenges')
        .doc(challengeId)
        .update({'viewCount': FieldValue.increment(1)});

      return Challenge.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get challenge: $e');
    }
  }

  // Get user's challenges
  Stream<List<Challenge>> getUserChallenges(String userId) {
    return _firestore
      .collection('challenges')
      .where('challengerId', '==', userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Challenge.fromMap(doc.data()))
        .toList());
  }

  // Get challenges where user is participant
  Stream<List<Challenge>> getAcceptedChallenges(String userId) {
    return _firestore
      .collection('challenges')
      .where('participants.userId', 'array-contains', userId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Challenge.fromMap(doc.data()))
        .toList());
  }

  // Share challenge
  Future<void> shareChallenge({
    required String challengeId,
    required ShareMethod method,
  }) async {
    try {
      final challenge = await getChallenge(challengeId);

      final message = '''
🥊 MMA CHALLENGE! 🥊

${challenge.challengerName} has challenged you!

Event: ${challenge.eventName}
Date: ${DateFormat('MMM d, h:mm a').format(challenge.eventDate.toDate())}

Think you know MMA better? Accept the challenge and prove it!

${challenge.shareLink}

Don't have the app? Download Bragging Rights:
Android: https://play.google.com/store/apps/details?id=com.braggingrights.app
iOS: https://apps.apple.com/app/braggingrights/id123456789
''';

      switch (method) {
        case ShareMethod.sms:
          final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
          await launchUrl(uri);
          break;

        case ShareMethod.whatsapp:
          final uri = Uri.parse(
            'whatsapp://send?text=${Uri.encodeComponent(message)}',
          );
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri);
          } else {
            // Fallback to web WhatsApp
            final webUri = Uri.parse(
              'https://wa.me/?text=${Uri.encodeComponent(message)}',
            );
            await launchUrl(webUri);
          }
          break;

        case ShareMethod.system:
          await Share.share(
            message,
            subject: 'Bragging Rights Challenge - ${challenge.eventName}',
          );
          break;
      }

      // Update share count
      await _firestore
        .collection('challenges')
        .doc(challengeId)
        .update({'shareCount': FieldValue.increment(1)});

    } catch (e) {
      throw Exception('Failed to share challenge: $e');
    }
  }
}
```

---

## Implementation Phases

### Phase 1: Core Functionality ✅ COMPLETED (September 2025)
- [x] Update UI with three-button layout (CHALLENGE button added to fight card screen)
- [x] Implement challenge creation flow
  - [x] Created Challenge model classes (Challenge, ChallengeParticipant, ChallengeResults, ChallengeStats)
  - [x] Implemented ChallengeService with Firestore integration
  - [x] Added sport-agnostic architecture supporting all sports
  - [x] Created FriendSelectionSheet widget for selecting friends
  - [x] Created ChallengeShareSheet widget for sharing
- [x] Create share functionality (SMS/WhatsApp)
  - [x] SMS sharing via url_launcher
  - [x] WhatsApp sharing with web fallback
  - [x] Copy link to clipboard
  - [x] System share dialog
  - [x] Share count tracking
- [x] Integrated with fight card grid screen (MMA/Boxing)
- [x] Added sport type detection and multi-sport support
- [x] Added per-sport challenge statistics tracking
- [x] Deployed Firestore security rules for challenges, notifications, and friendships
- [ ] Set up Firebase Dynamic Links (DEFERRED - using placeholder links for now)
- [ ] Build challenge acceptance screen (PENDING)

**Implementation Notes:**
- Sport-agnostic design allows easy extension to NFL, NBA, NHL, MLB, Soccer
- Challenge button enabled after picks are saved
- Friend selection shows win rates, streaks, and online status
- Both friend challenges and open challenges supported
- Dependencies added: share_plus ^10.1.2

### Phase 2: Notifications (DEFERRED)
Push notifications will be implemented in a future phase. Current implementation includes:
- [x] Firestore notification document structure
- [x] Notification tracking in ChallengeService
- [ ] FCM push notification setup (DEFERRED)
- [ ] Cloud Functions for notification triggers (DEFERRED)
- [ ] Local notification handling (DEFERRED)

### Phase 3: Enhanced Features (PENDING)
- [ ] Add challenge history view
- [ ] Implement head-to-head statistics
- [ ] Create results comparison screen
- [ ] Build challenge acceptance screen for recipients
- [ ] Add achievements system
- [ ] Build leaderboard
- [ ] Extend to other sports (NFL, NBA, NHL, MLB, Soccer)

### Phase 4: Polish & Testing (PENDING)
- [ ] UI/UX refinements
- [ ] Performance optimization
- [ ] Error handling improvements
- [ ] Analytics integration
- [ ] Beta testing

---

## Testing Requirements

### Unit Tests
```dart
// test/services/challenge_service_test.dart
void main() {
  group('ChallengeService', () {
    test('creates challenge with valid data', () async {
      final service = ChallengeService();
      final challenge = await service.createChallenge(
        eventId: 'ufc_295',
        eventName: 'UFC 295',
        picks: mockPicks,
      );

      expect(challenge.id, isNotEmpty);
      expect(challenge.shareLink, contains('braggingrights.page.link'));
    });

    test('accepts challenge successfully', () async {
      final service = ChallengeService();
      await service.acceptChallenge('test_challenge_id');

      final challenge = await service.getChallenge('test_challenge_id');
      expect(challenge.status, ChallengeStatus.accepted);
      expect(challenge.participants.length, greaterThan(0));
    });
  });
}
```

### Integration Tests
```dart
// test/integration/challenge_flow_test.dart
void main() {
  testWidgets('Complete challenge flow', (tester) async {
    // 1. Create picks
    await tester.pumpWidget(TestApp());
    await tester.tap(find.byType(FighterCard).first);
    await tester.tap(find.text('SAVE PICKS'));
    await tester.pumpAndSettle();

    // 2. Create challenge
    await tester.tap(find.text('CHALLENGE'));
    await tester.pumpAndSettle();

    // 3. Share via SMS
    await tester.tap(find.text('SMS'));
    verify(mockUrlLauncher.launch(any)).called(1);

    // 4. Verify challenge created
    final challenges = await challengeService.getUserChallenges('test_user');
    expect(challenges.length, 1);
  });
}
```

### E2E Testing Scenarios
1. **New User Flow**
   - Receive challenge link
   - Click link → Redirect to Play Store
   - Install app → Open app
   - Navigate to challenge
   - Create account
   - Accept challenge

2. **Existing User Flow**
   - Receive challenge link
   - Click link → App opens
   - View challenge details
   - Accept challenge
   - Make picks
   - View comparison

3. **Notification Flow**
   - Create challenge
   - Friend accepts → Receive notification
   - Friend completes picks → Receive notification
   - Event starts → Receive reminder
   - Results available → Receive notification

---

## Security Considerations

### Data Protection
- Encrypt picks until both users complete
- Use Firebase Security Rules for access control
- Validate all user inputs
- Rate limit challenge creation (max 10/hour)

### Firebase Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Challenges
    match /challenges/{challengeId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null
        && request.auth.uid == resource.data.challengerId
        && resource.data.createdAt == request.time;
      allow update: if request.auth != null
        && (request.auth.uid == resource.data.challengerId
          || request.auth.uid in resource.data.participants[].userId);
    }

    // Challenge notifications
    match /challenge_notifications/{notificationId} {
      allow read: if request.auth != null
        && request.auth.uid == resource.data.userId;
      allow write: if false; // Only server can write
    }
  }
}
```

---

## Analytics & Metrics

### Key Events to Track
```dart
// Analytics events
Analytics.logEvent('challenge_created', {
  'event_id': eventId,
  'pool_id': poolId,
  'picks_count': picks.length,
});

Analytics.logEvent('challenge_shared', {
  'challenge_id': challengeId,
  'method': shareMethod,
});

Analytics.logEvent('challenge_accepted', {
  'challenge_id': challengeId,
  'time_to_accept': timeToAccept,
});

Analytics.logEvent('challenge_completed', {
  'challenge_id': challengeId,
  'winner': winnerId,
  'score_difference': scoreDiff,
});
```

### Success Metrics Dashboard
- Daily active challenges
- Challenge acceptance rate
- User acquisition through challenges
- Average time to accept challenge
- Challenge completion rate
- Viral coefficient (K-factor)

---

## Appendix

### Dependencies to Add
```yaml
# pubspec.yaml
dependencies:
  firebase_dynamic_links: ^5.4.0
  share_plus: ^7.2.0
  url_launcher: ^6.2.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^16.0.0

dev_dependencies:
  mockito: ^5.4.0
  integration_test:
    sdk: flutter
```

### Environment Variables
```env
# .env
DYNAMIC_LINKS_DOMAIN=braggingrights.page.link
ANDROID_PACKAGE_NAME=com.braggingrights.app
IOS_BUNDLE_ID=com.braggingrights.app
IOS_APP_STORE_ID=123456789
PLAY_STORE_URL=https://play.google.com/store/apps/details?id=com.braggingrights.app
APP_STORE_URL=https://apps.apple.com/app/braggingrights/id123456789
```

### Migration Notes
- Ensure all existing users have FCM tokens
- Backfill user statistics for existing data
- Test Dynamic Links on both platforms before release
- Prepare customer support for challenge-related queries

---

## Support & Documentation

### User Documentation
- In-app tutorial for first-time challenge creation
- FAQ section for common issues
- Video walkthrough of challenge flow

### Developer Documentation
- API reference for challenge endpoints
- Cloud Function deployment guide
- Troubleshooting guide for Dynamic Links

### Contact
- Technical Lead: [tech@braggingrights.app]
- Product Owner: [product@braggingrights.app]
- Support: [support@braggingrights.app]

---

## Implementation Summary (September 2025)

### ✅ What's Been Completed

**Core Architecture:**
- Sport-agnostic challenge system supporting all sports (MMA, Boxing, NFL, NBA, NHL, MLB, Soccer)
- Complete data models for challenges, participants, results, and statistics
- Firestore integration with proper security considerations
- Per-sport challenge statistics tracking

**Backend Services:**
- `ChallengeService` with full CRUD operations
- Challenge creation for friend, group, and open challenges
- Challenge acceptance flow
- User statistics tracking (overall and per-sport)
- Share count tracking
- View count tracking

**UI Components:**
- `FriendSelectionSheet` - Select friends with search, stats display, online indicators
- `ChallengeShareSheet` - Share via SMS, WhatsApp, system share, or copy link
- Challenge button integration in fight card screen
- Sport-specific icons and messaging

**Features:**
- Friend challenges (1-on-1)
- Group challenges (multiple friends)
- Open challenges (shareable link)
- Multiple share methods (SMS, WhatsApp, Copy, More)
- Friend stats display (win rate, streaks)
- Sport type auto-detection
- Challenge expiration handling

**Files Created:**
```
lib/models/challenge.dart
lib/services/challenge_service.dart
lib/widgets/challenge/friend_selection_sheet.dart
lib/widgets/challenge/challenge_share_sheet.dart
```

**Files Modified:**
```
lib/screens/betting/fight_card_grid_screen.dart (integrated challenge flow)
pubspec.yaml (added share_plus dependency)
firestore.rules (added challenge collection security rules)
CHALLENGE_FEATURE_SPEC.md (updated with multi-sport architecture)
```

### 🚧 What's Pending

**High Priority:**
- Challenge acceptance screen for recipients
- Challenge results/comparison view
- Challenge history screen
- Firebase Dynamic Links setup (currently using placeholder links)

**Medium Priority:**
- Head-to-head statistics view
- Challenge leaderboards
- Extend to other sports screens (NFL, NBA, NHL, MLB, Soccer)
- In-app challenge notifications (Firestore-based)

**Low Priority (Deferred):**
- Push notifications via FCM
- Cloud Functions for automated notifications
- Achievements system
- Advanced analytics integration

### 📝 Next Steps

1. **Test Phase 1 Implementation:**
   - Test friend challenge creation and sharing
   - Test open challenge creation and sharing
   - Verify Firestore data structure
   - Test on both MMA and Boxing events

2. **Implement Challenge Acceptance:**
   - Create challenge acceptance screen
   - Handle deep links (placeholder or Dynamic Links)
   - Display challenger's picks after recipient completes theirs
   - Update challenge status and participants

3. **Build Results View:**
   - Compare picks between users
   - Calculate scores based on fight results
   - Display winner/loser
   - Update user statistics

4. **Extend to Other Sports:**
   - Apply same pattern to NFL, NBA, NHL, MLB, Soccer screens
   - Test sport-specific adapters
   - Verify multi-sport statistics tracking

### 🎯 Success Criteria

- [x] Users can challenge friends from within the app
- [x] Users can share challenge links via SMS/WhatsApp
- [x] Challenge data is stored in Firestore with proper structure
- [x] Multi-sport architecture is in place
- [ ] Recipients can accept challenges
- [ ] Users can view challenge results
- [ ] Statistics are tracked correctly per sport

### 📚 Technical Debt

- Firebase Dynamic Links need proper setup (currently using placeholder URLs)
- Push notifications deferred to future phase
- Cloud Functions for automated processes not yet implemented
- Need comprehensive error handling and edge case testing

### 🔧 Deployment Notes

**Firestore Security Rules:** ✅ DEPLOYED
New security rules have been deployed for the challenge feature (September 29, 2025).

**Rules Deployed:**
- `/challenges/{challengeId}` - Read: authenticated, Create: challenge owner, Update: owner or when accepting challenge, Delete: owner only if no participants
- `/challenge_notifications/{notificationId}` - Read/Update/Delete: notification recipient only, Create: authenticated
- `/friendships/{friendshipId}` - Full CRUD for authenticated users

To redeploy in the future:
```bash
# From project root
firebase deploy --only firestore:rules
```

**Query Indexes Required:**
Firestore will automatically prompt to create composite indexes when queries are first run. Expected indexes:
- `challenges` collection: `challengerId` + `createdAt` (desc)
- `challenges` collection: `eventId` + `createdAt` (desc)
- `challenges` collection: `participants` (array-contains) + `createdAt` (desc)

These indexes will be created automatically when the app first queries them and can be confirmed at:
https://console.firebase.google.com/project/bragging-rights-ea6e1/firestore/indexes