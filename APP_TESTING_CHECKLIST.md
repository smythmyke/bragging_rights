# Bragging Rights App - Testing Checklist
## Test Date: 2025-08-26

### Test Environment
- [ ] Device: _______________
- [ ] Android Version: _______________
- [ ] Flutter Version: 3.24.5
- [ ] Test Type: Debug / Release

---

## 1. AUTHENTICATION & ONBOARDING

### 1.1 App Launch
- [ ] Splash screen displays correctly
- [ ] Animated sports icons appear (football, baseball, basketball, hockey)
- [ ] No crashes on initial load

### 1.2 Sign Up Flow
- [ ] Sign up button accessible from auth screen
- [ ] Can enter email and password
- [ ] Password validation works (min 6 characters)
- [ ] Account creation successful
- [ ] Starting balance of 500 BR received
- [ ] Redirected to sports selection screen

### 1.3 Sports Selection
- [ ] All 4 sports displayed (NBA, NFL, MLB, NHL)
- [ ] Can select/deselect sports
- [ ] Continue button works
- [ ] Selections saved to profile

### 1.4 Login Flow
- [ ] Login with existing credentials works
- [ ] Error messages display for invalid credentials
- [ ] "Forgot Password" link visible
- [ ] Password reset email sends successfully
- [ ] Auto-login on app restart works

### 1.5 Logout
- [ ] Profile screen accessible
- [ ] Logout button works
- [ ] Returns to auth screen after logout
- [ ] No cached data visible after logout

---

## 2. HOME SCREEN & NAVIGATION

### 2.1 Bottom Navigation
- [ ] 5 tabs visible (Home, Pools, Active Wagers, Stats, Profile)
- [ ] All tabs navigate correctly
- [ ] Selected tab highlighted
- [ ] No navigation crashes

### 2.2 Home Screen Content
- [ ] Welcome message displays username
- [ ] Current BR balance visible
- [ ] Quick action buttons work
- [ ] Featured pools section loads
- [ ] No loading errors

---

## 3. WALLET & TRANSACTIONS

### 3.1 BR Balance
- [ ] Current balance displays correctly
- [ ] Balance persists between sessions
- [ ] Balance updates after transactions

### 3.2 Transaction History
- [ ] Transaction history screen accessible
- [ ] Past transactions listed
- [ ] Transaction details accurate (amount, type, date)
- [ ] Sorting/filtering works (if implemented)

### 3.3 Weekly Allowance
- [ ] Weekly allowance info displayed
- [ ] Next allowance date shown
- [ ] 25 BR allowance amount correct

---

## 4. POOLS & BETTING

### 4.1 Pool Selection
- [ ] Available pools displayed
- [ ] Pool cards show correct info (name, buy-in, participants)
- [ ] Can tap to view pool details
- [ ] Join pool button visible

### 4.2 Joining Pools
- [ ] Buy-in amount deducted from balance
- [ ] Cannot join without sufficient BR
- [ ] Confirmation dialog appears
- [ ] Successfully added to pool
- [ ] Pool appears in "My Pools"

### 4.3 Pool Details Screen
- [ ] Pool information accurate
- [ ] Participants list shows
- [ ] Pool rules visible
- [ ] Current standings displayed
- [ ] Prize distribution shown

---

## 5. BETTING INTERFACE

### 5.1 Game Selection
- [ ] Games list loads from API
- [ ] Games show team logos (TheSportsDB)
- [ ] Upcoming games have times
- [ ] Live games show scores
- [ ] Can select game to bet on

### 5.2 Bet Types (Props Tab)
- [ ] Props tab accessible
- [ ] 25+ prop bets available
- [ ] Each prop shows description
- [ ] Odds displayed correctly
- [ ] Can select multiple props

### 5.3 Placing Bets
- [ ] Bet amount input works
- [ ] Potential payout calculated correctly
- [ ] Cannot bet more than balance
- [ ] Bet confirmation dialog appears
- [ ] Bet successfully placed
- [ ] Balance updated immediately

### 5.4 Edge Screen
- [ ] Edge percentage slider works
- [ ] BR amount updates with edge
- [ ] Explanation text visible
- [ ] Can place edge-adjusted bets

---

## 6. ACTIVE WAGERS

### 6.1 Active Bets Display
- [ ] All active bets listed
- [ ] Bet details accurate (teams, amount, odds)
- [ ] Game status shown (upcoming/live/completed)
- [ ] Can view individual bet details

### 6.2 Bet Tracking
- [ ] Live games update scores
- [ ] Bet status updates (pending/won/lost)
- [ ] Winning bets highlighted
- [ ] Losing bets marked appropriately

---

## 7. API INTEGRATIONS

### 7.1 The Odds API
- [ ] Live odds load for games
- [ ] Odds update periodically
- [ ] Multiple betting markets available
- [ ] API errors handled gracefully

### 7.2 Team Logos (TheSportsDB)
- [ ] NBA team logos display
- [ ] NFL team logos display
- [ ] MLB team logos display
- [ ] NHL team logos display
- [ ] Fallback for missing logos

### 7.3 Live Scores (ESPN)
- [ ] Live scores update during games
- [ ] Final scores shown for completed games
- [ ] Game status accurate
- [ ] Schedule data loads

---

## 8. SOCIAL FEATURES

### 8.1 Leaderboards
- [ ] Daily leaderboard accessible
- [ ] Weekly leaderboard accessible
- [ ] Monthly leaderboard accessible
- [ ] All-time leaderboard accessible
- [ ] User's rank displayed
- [ ]rankings update after wins

### 8.2 User Stats
- [ ] Total wins displayed
- [ ] Win rate percentage correct
- [ ] Profit/loss tracked
- [ ] Win streak shown
- [ ] Best win highlighted

---

## 9. IN-APP PURCHASES

### 9.1 BR Store
- [ ] Store/shop accessible
- [ ] 6 coin packages displayed ($0.99-$99.99)
- [ ] Package descriptions clear
- [ ] Bonus amounts shown

### 9.2 Purchase Flow
- [ ] Can select package
- [ ] Payment dialog appears
- [ ] Test purchase works (sandbox mode)
- [ ] BR added to balance after purchase
- [ ] Purchase history recorded

### 9.3 Restore Purchases
- [ ] Restore purchases button visible
- [ ] Previous purchases restored
- [ ] No duplicate charges

---

## 10. NOTIFICATIONS

### 10.1 Permission Request
- [ ] Notification permission requested on first launch
- [ ] Can accept/decline permissions
- [ ] Settings respected

### 10.2 Notification Types
- [ ] Bet result notifications received
- [ ] Weekly allowance notification
- [ ] Game reminder (30 min before)
- [ ] Win celebration notification
- [ ] Pool invitation notification

---

## 11. ERROR HANDLING

### 11.1 Network Errors
- [ ] Offline mode message appears
- [ ] Graceful degradation without internet
- [ ] Retry mechanisms work
- [ ] No app crashes

### 11.2 Invalid Actions
- [ ] Cannot bet more than balance
- [ ] Cannot join full pools
- [ ] Validation messages clear
- [ ] No data corruption

---

## 12. PERFORMANCE

### 12.1 Load Times
- [ ] App launches in < 3 seconds
- [ ] Screens load in < 2 seconds
- [ ] Smooth scrolling (60 FPS)
- [ ] No janky animations

### 12.2 Memory Usage
- [ ] No memory leaks detected
- [ ] App doesn't crash after extended use
- [ ] Background/foreground transitions smooth

---

## 13. CELEBRATION & FEEDBACK

### 13.1 Win Celebrations
- [ ] Celebration screen appears for wins
- [ ] Confetti animation plays
- [ ] Win amount displayed
- [ ] Share button works (if implemented)

### 13.2 User Feedback
- [ ] Loading indicators appear during operations
- [ ] Success messages for completed actions
- [ ] Error messages helpful and clear
- [ ] Haptic feedback on actions (if implemented)

---

## 14. SECURITY

### 14.1 Data Protection
- [ ] Cannot modify balance directly
- [ ] Bet validation enforced
- [ ] No sensitive data in logs
- [ ] Secure authentication tokens

### 14.2 Session Management
- [ ] Auto-logout after inactivity (if implemented)
- [ ] Session persists appropriately
- [ ] No unauthorized access to features

---

## CRITICAL ISSUES FOUND
1. _________________________________
2. _________________________________
3. _________________________________

## MINOR ISSUES FOUND
1. _________________________________
2. _________________________________
3. _________________________________

## SUGGESTIONS FOR IMPROVEMENT
1. _________________________________
2. _________________________________
3. _________________________________

---

## OVERALL TEST RESULT
- [ ] **PASSED** - Ready for production
- [ ] **PASSED WITH ISSUES** - Minor fixes needed
- [ ] **FAILED** - Critical issues need resolution

### Tester Signature: _________________
### Date Completed: _________________