# Firebase Backend Integration Plan - Bragging Rights

## Last Updated: 2025-08-17

## Executive Summary
This document outlines the complete Firebase backend integration strategy for the Bragging Rights sports betting app. The integration will be implemented in 4 phases over 4 weeks, focusing on authentication, data storage, real-time features, and cloud functions.

---

## 📋 Table of Contents
1. [Current State Analysis](#current-state-analysis)
2. [Firebase Services Architecture](#firebase-services-architecture)
3. [Database Schema Design](#database-schema-design)
4. [Implementation Phases](#implementation-phases)
5. [Security & Rules](#security--rules)
6. [Cost Analysis](#cost-analysis)
7. [Technical Requirements](#technical-requirements)
8. [Risk Mitigation](#risk-mitigation)

---

## Current State Analysis

### Existing Setup
- Flutter app initialized with basic UI/UX
- Firebase packages added to pubspec.yaml (currently commented out)
- No backend integration implemented yet
- Using mock/hardcoded data for development

### Required Firebase Packages
```yaml
dependencies:
  firebase_core: ^4.0.0
  firebase_auth: ^6.0.1
  cloud_firestore: ^6.0.0
  firebase_storage: ^13.0.0
  firebase_messaging: ^16.0.0
  firebase_analytics: ^11.0.0
  firebase_crashlytics: ^4.0.0
  cloud_functions: ^5.0.0
```

---

## Firebase Services Architecture

### 🔐 **Authentication Service**
- **Email/Password**: Primary authentication method
- **Google Sign-In**: Social login option
- **Apple Sign-In**: Required for iOS App Store
- **Anonymous Auth**: Trial users exploration
- **Phone Auth**: Account recovery & 2FA
- **Custom Claims**: Admin roles, premium status

### 📊 **Cloud Firestore Database**
- **Structure**: NoSQL document database
- **Real-time Sync**: Live updates for games/odds
- **Offline Support**: Cached data for poor connectivity
- **Scalability**: Automatic scaling for user growth

### 💾 **Cloud Storage**
- **User Avatars**: Profile pictures
- **Team Logos**: Sports team imagery
- **Achievement Badges**: Gamification assets
- **CDN Integration**: Fast global delivery

### 📱 **Cloud Messaging (FCM)**
- **Transactional**: Bet confirmations, results
- **Promotional**: Weekly BR allowance, bonuses
- **Social**: Friend invites, pool notifications
- **Live Updates**: Game starts, score changes

### ⚡ **Cloud Functions**
- **Bet Settlement**: Automated win/loss calculation
- **BR Economy**: Weekly allowances, bonuses
- **Data Sync**: Sports API integration
- **Security**: Fraud detection, rate limiting

### 📈 **Analytics & Monitoring**
- **User Behavior**: Track feature usage
- **Performance**: App speed metrics
- **Crashlytics**: Error tracking
- **A/B Testing**: Feature experiments

---

## Database Schema Design

### Core Collections Structure

```javascript
// 1. Users Collection
/users/{userId} {
  // Profile Information
  uid: string,
  email: string,
  displayName: string,
  photoURL: string,
  phoneNumber: string,
  
  // Sports Preferences
  favoriteSports: string[],
  favoriteTeams: string[],
  
  // Account Status
  createdAt: timestamp,
  lastLoginAt: timestamp,
  isPremium: boolean,
  isActive: boolean,
  
  // Subcollections
  /wallet {
    balance: number,
    lastAllowance: timestamp,
    lifetimeEarned: number,
    lifetimeWagered: number
  },
  
  /stats {
    totalBets: number,
    wins: number,
    losses: number,
    winRate: number,
    currentStreak: number,
    bestStreak: number
  }
}

// 2. Games Collection
/games/{gameId} {
  // Game Information
  sport: string,
  league: string,
  homeTeam: {
    name: string,
    logo: string,
    score: number
  },
  awayTeam: {
    name: string,
    logo: string,
    score: number
  },
  
  // Timing
  gameTime: timestamp,
  status: 'scheduled' | 'live' | 'final' | 'cancelled',
  quarter/period: string,
  timeRemaining: string,
  
  // Betting Lines
  odds: {
    moneyline: {
      home: number,
      away: number
    },
    spread: {
      home: number,
      away: number,
      line: number
    },
    total: {
      over: number,
      under: number,
      line: number
    }
  },
  
  // Results
  result: {
    winner: string,
    finalScore: string,
    coveredSpread: string
  }
}

// 3. Bets Collection
/bets/{betId} {
  // User & Game Reference
  userId: string,
  gameId: string,
  poolId: string,
  
  // Bet Details
  betType: 'moneyline' | 'spread' | 'total' | 'prop' | 'parlay',
  selection: string,
  odds: number,
  wagerAmount: number,
  potentialPayout: number,
  
  // Status
  status: 'pending' | 'won' | 'lost' | 'push' | 'cancelled',
  placedAt: timestamp,
  settledAt: timestamp,
  
  // Parlay Support
  isParlay: boolean,
  parlayLegs: []
}

// 4. Pools Collection
/pools/{poolId} {
  // Pool Configuration
  type: 'public' | 'private' | 'tournament',
  name: string,
  description: string,
  sport: string,
  gameId: string,
  
  // Financial
  buyIn: number,
  maxParticipants: number,
  totalPot: number,
  
  // Participants
  participants: [{
    userId: string,
    displayName: string,
    betId: string,
    rank: number
  }],
  
  // Timing
  createdAt: timestamp,
  closesAt: timestamp,
  status: 'open' | 'closed' | 'settled'
}

// 5. Transactions Collection
/transactions/{transactionId} {
  // User Reference
  userId: string,
  
  // Transaction Details
  type: 'deposit' | 'withdrawal' | 'wager' | 'payout' | 'allowance' | 'bonus',
  amount: number,
  description: string,
  
  // Balance Tracking
  balanceBefore: number,
  balanceAfter: number,
  
  // Metadata
  timestamp: timestamp,
  relatedId: string, // betId, poolId, etc.
  status: 'pending' | 'completed' | 'failed'
}

// 6. Leaderboards Collection
/leaderboards/{period} {
  // Period: daily, weekly, monthly, allTime
  period: string,
  startDate: timestamp,
  endDate: timestamp,
  
  // Rankings
  rankings: [{
    userId: string,
    displayName: string,
    photoURL: string,
    wins: number,
    profit: number,
    winRate: number,
    rank: number
  }],
  
  // Last Updated
  updatedAt: timestamp
}
```

---

## Implementation Phases

### 📅 **Phase 1: Foundation & Authentication (Week 1)**

#### Day 1-2: Firebase Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and initialize
firebase login
firebase init

# Configure Flutter
flutterfire configure
```

#### Day 3-4: Authentication Implementation
```dart
// lib/services/auth_service.dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Email/Password Sign Up
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await credential.user?.updateDisplayName(displayName);
      
      // Create user document
      await _createUserDocument(credential.user!);
      
      return credential;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }
  
  // Create initial user document
  Future<void> _createUserDocument(User user) async {
    await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'favoriteSports': [],
        'favoriteTeams': [],
      });
    
    // Initialize wallet
    await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('wallet')
      .doc('current')
      .set({
        'balance': 500, // Starting BR
        'lastAllowance': FieldValue.serverTimestamp(),
      });
  }
}
```

#### Day 5: Social Authentication
- Google Sign-In integration
- Apple Sign-In for iOS
- Link authentication methods

#### Deliverables:
- ✅ Firebase project configured
- ✅ Authentication flows working
- ✅ User documents created on signup
- ✅ Initial 500 BR allocated

---

### 📅 **Phase 2: Data Layer & Wallet System (Week 2)**

#### Day 1-2: Data Models
```dart
// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final List<String> favoriteSports;
  final List<String> favoriteTeams;
  final DateTime createdAt;
  
  // Wallet information
  final int brBalance;
  final DateTime lastAllowance;
  
  // Statistics
  final int totalBets;
  final int wins;
  final double winRate;
  
  // Firestore conversion
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: data['uid'],
      email: data['email'],
      displayName: data['displayName'],
      // ... map all fields
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    // ... all fields
  };
}
```

#### Day 3-4: Wallet Service
```dart
// lib/services/wallet_service.dart
class WalletService {
  final String userId;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Get current balance
  Stream<int> getBalance() {
    return _db
      .collection('users')
      .doc(userId)
      .collection('wallet')
      .doc('current')
      .snapshots()
      .map((doc) => doc.data()?['balance'] ?? 0);
  }
  
  // Place wager (atomic transaction)
  Future<bool> placeWager(int amount) async {
    return _db.runTransaction((transaction) async {
      final walletRef = _db
        .collection('users')
        .doc(userId)
        .collection('wallet')
        .doc('current');
      
      final walletDoc = await transaction.get(walletRef);
      final currentBalance = walletDoc.data()?['balance'] ?? 0;
      
      if (currentBalance < amount) {
        throw InsufficientFundsException();
      }
      
      transaction.update(walletRef, {
        'balance': FieldValue.increment(-amount),
      });
      
      return true;
    });
  }
  
  // Weekly allowance check
  Future<void> checkWeeklyAllowance() async {
    final walletDoc = await _db
      .collection('users')
      .doc(userId)
      .collection('wallet')
      .doc('current')
      .get();
    
    final lastAllowance = walletDoc.data()?['lastAllowance']?.toDate();
    final now = DateTime.now();
    
    if (lastAllowance == null || 
        now.difference(lastAllowance).inDays >= 7) {
      await addBR(25, 'Weekly Allowance');
    }
  }
}
```

#### Day 5: Transaction Logging
- Record all BR movements
- Transaction history UI
- Balance verification

#### Deliverables:
- ✅ User data models
- ✅ Wallet service with atomic transactions
- ✅ Transaction history
- ✅ Weekly allowance system

---

### 📅 **Phase 3: Games & Betting System (Week 3)**

#### Day 1-2: Game Management
```dart
// lib/services/game_service.dart
class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Get live games
  Stream<List<Game>> getLiveGames(String sport) {
    return _db
      .collection('games')
      .where('sport', isEqualTo: sport)
      .where('status', isEqualTo: 'live')
      .orderBy('gameTime')
      .snapshots()
      .map((snapshot) => 
        snapshot.docs.map((doc) => 
          Game.fromFirestore(doc)).toList()
      );
  }
  
  // Get upcoming games
  Stream<List<Game>> getUpcomingGames(String sport) {
    final now = DateTime.now();
    final tomorrow = now.add(Duration(days: 1));
    
    return _db
      .collection('games')
      .where('sport', isEqualTo: sport)
      .where('gameTime', isGreaterThan: now)
      .where('gameTime', isLessThan: tomorrow)
      .orderBy('gameTime')
      .limit(20)
      .snapshots()
      .map((snapshot) => 
        snapshot.docs.map((doc) => 
          Game.fromFirestore(doc)).toList()
      );
  }
}
```

#### Day 3-4: Betting Engine
```dart
// lib/services/betting_service.dart
class BettingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;
  
  // Place bet with validation
  Future<String> placeBet({
    required String gameId,
    required String poolId,
    required BetType betType,
    required String selection,
    required int wagerAmount,
    required double odds,
  }) async {
    // Start batch write
    final batch = _db.batch();
    
    try {
      // 1. Verify game hasn't started
      final gameDoc = await _db
        .collection('games')
        .doc(gameId)
        .get();
      
      if (gameDoc.data()?['status'] != 'scheduled') {
        throw BettingClosedException();
      }
      
      // 2. Create bet document
      final betRef = _db.collection('bets').doc();
      batch.set(betRef, {
        'betId': betRef.id,
        'userId': userId,
        'gameId': gameId,
        'poolId': poolId,
        'betType': betType.toString(),
        'selection': selection,
        'odds': odds,
        'wagerAmount': wagerAmount,
        'potentialPayout': calculatePayout(wagerAmount, odds),
        'status': 'pending',
        'placedAt': FieldValue.serverTimestamp(),
      });
      
      // 3. Update pool participants
      final poolRef = _db.collection('pools').doc(poolId);
      batch.update(poolRef, {
        'participants': FieldValue.arrayUnion([{
          'userId': userId,
          'betId': betRef.id,
        }]),
        'totalPot': FieldValue.increment(wagerAmount),
      });
      
      // 4. Deduct from wallet (separate transaction)
      final walletService = WalletService(userId);
      await walletService.placeWager(wagerAmount);
      
      // 5. Commit batch
      await batch.commit();
      
      return betRef.id;
    } catch (e) {
      throw BettingException(e.toString());
    }
  }
}
```

#### Day 5: Pool Management
- Create/join pools
- Private pool invitations
- Pool leaderboards

#### Deliverables:
- ✅ Game data streaming
- ✅ Bet placement with validation
- ✅ Pool participation
- ✅ Real-time odds updates

---

### 📅 **Phase 4: Cloud Functions & Settlement (Week 4)**

#### Day 1-2: Cloud Functions Setup
```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Triggered when game ends
exports.settleGameBets = functions.firestore
  .document('games/{gameId}')
  .onUpdate(async (change, context) => {
    const gameData = change.after.data();
    const previousData = change.before.data();
    
    // Check if game just finished
    if (previousData.status !== 'final' && 
        gameData.status === 'final') {
      
      const gameId = context.params.gameId;
      await settleBetsForGame(gameId, gameData);
    }
  });

// Settlement logic
async function settleBetsForGame(gameId, gameData) {
  const betsSnapshot = await admin.firestore()
    .collection('bets')
    .where('gameId', '==', gameId)
    .where('status', '==', 'pending')
    .get();
  
  const batch = admin.firestore().batch();
  
  betsSnapshot.docs.forEach(doc => {
    const bet = doc.data();
    const won = determineBetOutcome(bet, gameData);
    
    batch.update(doc.ref, {
      'status': won ? 'won' : 'lost',
      'settledAt': admin.firestore.FieldValue.serverTimestamp(),
    });
    
    if (won) {
      // Add winnings to user wallet
      const payout = bet.potentialPayout;
      addToWallet(bet.userId, payout, 'Bet Won');
    }
  });
  
  await batch.commit();
}
```

#### Day 3: Weekly Allowance Function
```javascript
// Scheduled function - runs every Monday at 9 AM
exports.weeklyAllowance = functions.pubsub
  .schedule('0 9 * * 1')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('isActive', '==', true)
      .get();
    
    const batch = admin.firestore().batch();
    
    usersSnapshot.docs.forEach(doc => {
      const walletRef = doc.ref
        .collection('wallet')
        .doc('current');
      
      batch.update(walletRef, {
        'balance': admin.firestore.FieldValue.increment(25),
        'lastAllowance': admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    
    await batch.commit();
    
    // Send push notifications
    await sendAllowanceNotifications();
  });
```

#### Day 4-5: Advanced Features
- Leaderboard calculations
- Fraud detection
- Rate limiting
- Data aggregation

#### Deliverables:
- ✅ Automated bet settlement
- ✅ Weekly allowance distribution
- ✅ Leaderboard updates
- ✅ Security functions

---

## Security & Rules

### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function hasEnoughBalance(amount) {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)/wallet/current).data.balance >= amount;
    }
    
    // Users can only access their own data
    match /users/{userId} {
      allow read: if isOwner(userId);
      allow create: if isOwner(userId);
      allow update: if isOwner(userId) && 
        !request.resource.data.diff(resource.data).affectedKeys()
          .hasAny(['uid', 'createdAt']);
      
      // Wallet is read-only for users
      match /wallet/{document} {
        allow read: if isOwner(userId);
        allow write: if false; // Only Cloud Functions
      }
      
      // Stats are read-only
      match /stats/{document} {
        allow read: if isOwner(userId);
        allow write: if false;
      }
    }
    
    // Games are read-only for all authenticated users
    match /games/{gameId} {
      allow read: if isAuthenticated();
      allow write: if false; // Admin only
    }
    
    // Bets - create only, no updates
    match /bets/{betId} {
      allow read: if isOwner(resource.data.userId);
      allow create: if isAuthenticated() && 
        request.auth.uid == request.resource.data.userId &&
        hasEnoughBalance(request.resource.data.wagerAmount);
      allow update, delete: if false;
    }
    
    // Pools - complex rules
    match /pools/{poolId} {
      allow read: if isAuthenticated();
      allow create: if isAuthenticated() &&
        request.resource.data.createdBy == request.auth.uid;
      allow update: if isAuthenticated() &&
        request.resource.data.diff(resource.data).affectedKeys()
          .hasOnly(['participants', 'totalPot']);
    }
    
    // Transactions - read only own
    match /transactions/{transactionId} {
      allow read: if isOwner(resource.data.userId);
      allow write: if false; // System only
    }
    
    // Leaderboards - public read
    match /leaderboards/{document} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

### Cloud Storage Rules
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User avatars
    match /avatars/{userId}/{fileName} {
      allow read: if true;
      allow write: if request.auth != null && 
        request.auth.uid == userId &&
        request.resource.size < 5 * 1024 * 1024 && // 5MB limit
        request.resource.contentType.matches('image/.*');
    }
    
    // Team logos - read only
    match /teams/{allPaths=**} {
      allow read: if true;
      allow write: if false;
    }
  }
}
```

---

## Cost Analysis

### Monthly Cost Projection (10,000 Active Users)

| Service | Usage | Cost |
|---------|-------|------|
| **Authentication** | 10,000 users | $0 (free tier) |
| **Firestore** | | |
| - Document reads | 30M reads | $18 |
| - Document writes | 5M writes | $9 |
| - Storage | 10 GB | $1.80 |
| **Cloud Functions** | | |
| - Invocations | 2M | $0.80 |
| - Compute time | 400K GB-seconds | $8 |
| **Cloud Storage** | | |
| - Storage | 50 GB | $1.30 |
| - Operations | 1M | $0.50 |
| **Cloud Messaging** | 500K messages | $0 (free) |
| **Hosting** | CDN bandwidth | $15 |
| **Total** | | **~$54.40/month** |

### Scaling Considerations
- Costs scale linearly with users
- Implement caching to reduce reads
- Use batch operations when possible
- Archive old data to reduce storage

---

## Technical Requirements

### Development Environment
```bash
# Required tools
- Flutter SDK 3.0+
- Node.js 18+ (for Functions)
- Firebase CLI
- Android Studio / Xcode
- VS Code with extensions

# Firebase project setup
firebase login
firebase init
# Select: Firestore, Functions, Storage, Hosting, Emulators

# Flutter Firebase setup
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging
flutter pub add cloud_functions

# Configure for platforms
flutterfire configure
```

### Testing Strategy
1. **Local Development**: Firebase Emulators
2. **Staging Environment**: Separate Firebase project
3. **Production**: Live Firebase project

```bash
# Start emulators for local development
firebase emulators:start

# Deploy to staging
firebase use staging
firebase deploy

# Deploy to production
firebase use production
firebase deploy --only firestore:rules
firebase deploy --only functions
```

---

## Risk Mitigation

### Technical Risks
| Risk | Mitigation |
|------|------------|
| Data loss | Daily automated backups |
| Service outage | Multi-region deployment |
| Scaling issues | Auto-scaling, caching layer |
| Security breach | Security rules, encryption |

### Business Risks
| Risk | Mitigation |
|------|------------|
| Regulatory compliance | Legal review, geo-blocking |
| Fraud/abuse | Rate limiting, verification |
| User trust | Transparent operations |
| Competition | Unique features, fast iteration |

### Monitoring & Alerts
- Firebase Performance Monitoring
- Crashlytics for error tracking
- Custom dashboards for key metrics
- PagerDuty integration for critical alerts

---

## Implementation Timeline

### Week 1: Foundation
- ✅ Firebase project setup
- ✅ Authentication implementation
- ✅ Basic user management
- ✅ Initial testing

### Week 2: Core Features
- ✅ Wallet system
- ✅ Transaction logging
- ✅ User profiles
- ✅ Data models

### Week 3: Betting System
- ✅ Game management
- ✅ Bet placement
- ✅ Pool system
- ✅ Real-time updates

### Week 4: Advanced Features
- ✅ Cloud Functions
- ✅ Settlement automation
- ✅ Leaderboards
- ✅ Push notifications

### Week 5: Polish & Launch
- 🔄 Testing & QA
- 🔄 Performance optimization
- 🔄 Security audit
- 🔄 Production deployment

---

## Success Metrics

### Technical KPIs
- API response time < 200ms
- App crash rate < 1%
- Successful transaction rate > 99.9%
- Uptime > 99.9%

### Business KPIs
- User registration completion > 80%
- Daily active users > 30%
- Bet placement conversion > 50%
- Weekly retention > 60%

---

## Next Steps

1. **Immediate Actions**:
   - Create Firebase project in console
   - Set up development environment
   - Implement Phase 1 authentication

2. **Team Assignments**:
   - Backend: Cloud Functions, Security Rules
   - Frontend: Firebase integration, UI updates
   - DevOps: CI/CD, monitoring setup

3. **Dependencies**:
   - Sports data API selection
   - Payment processor setup
   - Legal compliance review

---

## Appendix

### Useful Commands
```bash
# Firebase
firebase init
firebase deploy
firebase emulators:start
firebase functions:log

# Flutter
flutter pub get
flutter clean
flutter build apk
flutter build ios

# Testing
flutter test
firebase emulators:exec --only firestore "npm test"
```

### Resources
- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev)
- [Firebase Pricing Calculator](https://firebase.google.com/pricing)
- [Security Rules Guide](https://firebase.google.com/docs/rules)

---

## Contact & Support

For questions or issues regarding this implementation plan:
- Technical Lead: [Your Name]
- Project Manager: [PM Name]
- Firebase Support: support@firebase.google.com

---

*This document is a living guide and will be updated as the implementation progresses.*