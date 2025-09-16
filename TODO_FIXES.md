# TODO/FIXME Items - Bragging Rights App

## Summary
Total items: 51 TODOs/FIXMEs found across the codebase
Priority breakdown:
- 🔴 Critical: 11 items (blocks MVP)
- 🟡 Important: 21 items (missing features)
- 🟢 Nice to Have: 19 items (enhancements)

---

## 🔴 CRITICAL - Blocks MVP Launch

### 1. Wallet/Payment System (5 items)
**These prevent users from receiving winnings or getting refunds**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `multi_competition_monitor.dart` | 435 | Add winnings to wallet after pool settlement | Winners don't receive BR |
| `multi_competition_monitor.dart` | 492 | Call wallet service to refund BR on cancellation | No refunds on cancelled pools |
| `game_state_controller.dart` | 304 | Call wallet service to refund BR | No refunds on cancelled games |
| `game_state_controller.dart` | 275 | Implement pool settlement logic based on game result | Pools never settle |
| `edge_screen_v2.dart` | 622 | Implement actual in-app purchase (currently test BR) | No revenue generation |

### 2. Push Notifications (1 item)
**Critical for user engagement and retention**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `game_state_controller.dart` | 387 | Implement actual push notification system | No user notifications |

### 3. Pool Creation & Management (5 items)
**Users cannot create or manage custom pools**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `pool_selection_screen_v2.dart` | 908 | Implement actual pool creation logic | Can't create pools |
| `pool_selection_screen_v2.dart` | 1113 | Navigate to create private pool screen | No private pools |
| `pool_selection_screen.dart` | 1407 | Navigate to create pool screen | No pool creation |
| `my_pools_screen.dart` | 427 | Implement actual sharing for pools | Can't invite friends |
| `home_screen.dart` | 2364 | Navigate to create pool | No pool creation from home |

---

## 🟡 IMPORTANT - Missing Features

### 4. Combat Sports Scoring (2 items)
**MMA/Boxing scoring incomplete**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `multi_competition_monitor.dart` | 342 | Get actual scores from judges | No judge scores shown |
| `enhanced_espn_service.dart` | 265 | Implement multi-fight tracking | Only tracks main event |

### 5. Tennis Match State (6 items)
**Tennis scoring calculations missing**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `multi_competition_monitor.dart` | 358 | Calculate set point from game score | No set point indicator |
| `multi_competition_monitor.dart` | 359 | Calculate match point from set score | No match point indicator |
| `multi_competition_monitor.dart` | 360 | Determine tiebreak from game score | No tiebreak indicator |
| `enhanced_espn_service.dart` | 352 | Calculate set point status | Missing game state |
| `enhanced_espn_service.dart` | 353 | Calculate match point status | Missing game state |
| `enhanced_espn_service.dart` | 354 | Determine tiebreak status | Missing game state |
| `event_splitter_service.dart` | 492 | Determine if set is complete | Incorrect set status |
| `enhanced_espn_service.dart` | 338 | Parse player2 games from ESPN | Wrong score display |

### 6. Core User Actions (11 items)
**Basic navigation and actions not implemented**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `home_screen.dart` | 794 | Show notifications | No notification view |
| `home_screen.dart` | 1675 | Navigate to pool details | Can't view pool info |
| `home_screen.dart` | 2600 | Navigate to pool details | Can't view pool info |
| `home_screen.dart` | 2657 | Join pool functionality | Can't join pools |
| `home_screen.dart` | 2680 | Filter pools by sport | No filtering |
| `home_screen.dart` | 2708 | Quick join pool | No quick join |
| `home_screen.dart` | 3625 | Open terms of service | No legal docs |
| `home_screen.dart` | 3633 | Open privacy policy | No privacy policy |
| `home_screen.dart` | 3641 | Open app store | No app rating |
| `home_screen.dart` | 3654 | Sign out functionality | Can't sign out properly |
| `home_screen.dart` | 4359 | Purchase intel | Can't buy edge intel |
| `optimized_games_screen.dart` | 640 | Show notifications | No notification view |
| `fight_card_screen.dart` | 212 | Implement filtering | No fight filtering |

### 7. Card System (1 item)

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `card_inventory_screen.dart` | 390 | Implement actual card usage | Cards can't be used |

---

## 🟢 NICE TO HAVE - Enhancements

### 8. API Management (2 items)
**Usage tracking for rate limits**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `api_config_manager.dart` | 222 | Implement daily usage tracking | No usage monitoring |
| `api_config_manager.dart` | 227 | Implement monthly usage tracking | No usage monitoring |

### 9. Edge/Intelligence Features (4 items)
**Advanced analytics features**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `edge_intelligence_service.dart` | 1838 | Implement weather API for outdoor games | No weather data |
| `edge_test_service.dart` | 210 | Filter to find matching event | Inefficient search |
| `espn_nba_service.dart` | 276 | Parse standings for playoff implications | No playoff context |
| `nba_multi_source_service.dart` | 322 | Implement cache storage | No caching |

### 10. Game ID Generation (2 items)
**ID format documentation**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `event_matcher.dart` | 210 | NBA format: 0022300XXX (season + game) | Documentation only |
| `event_matcher.dart` | 238 | NHL format: YYYY020XXX (season + game) | Documentation only |

### 11. UI/Navigation (2 items)
**Missing screens**

| File | Line | Description | Impact |
|------|------|-------------|--------|
| `edge_screen.dart` | 1109 | Implement EdgeDetailScreen | Using dialog instead |
| `game_details_screen.dart` | 62 | Fetch game from Firestore/API | Fallback needed |

---

## Implementation Plan

### Week 1 Priority - Core Money Flow
1. **Wallet Integration** (5 TODOs)
   - Connect wallet service to pool settlement
   - Implement refund logic
   - Add winnings distribution
   - Test with real transactions

2. **Pool Settlement Logic** (1 TODO)
   - Implement game result processing
   - Calculate winners
   - Distribute winnings

3. **In-App Purchases** (1 TODO)
   - Replace test BR addition with real IAP
   - Configure store products
   - Test purchase flow

### Week 2 Priority - User Engagement
4. **Push Notifications** (1 TODO)
   - Firebase Cloud Messaging setup
   - Notification triggers
   - User preferences

5. **Pool Creation** (5 TODOs)
   - Create pool UI screens
   - Private pool functionality
   - Pool sharing/invites

### Week 3 Priority - Core Features
6. **User Actions** (11 TODOs)
   - Sign out flow
   - Navigation fixes
   - Legal document links
   - Pool interactions

7. **Sports-Specific** (8 TODOs)
   - Combat sports scoring
   - Tennis match states
   - Card usage

### Post-MVP
- API usage tracking
- Weather integration
- Advanced edge features
- Performance optimizations

---

## Quick Reference

**Files with most TODOs:**
1. `home_screen.dart` - 12 TODOs
2. `multi_competition_monitor.dart` - 5 TODOs
3. `enhanced_espn_service.dart` - 5 TODOs
4. `game_state_controller.dart` - 3 TODOs
5. `pool_selection_screen_v2.dart` - 2 TODOs

**Most critical files to fix:**
1. `multi_competition_monitor.dart` - Wallet integration
2. `game_state_controller.dart` - Settlement & notifications
3. `pool_selection_screen_v2.dart` - Pool creation
4. `edge_screen_v2.dart` - In-app purchases

---

*Last Updated: Current Session*
*Total TODOs: 51*
*Estimated Time to Fix Critical: 1-2 weeks*
*Estimated Time to Fix All: 4-6 weeks*