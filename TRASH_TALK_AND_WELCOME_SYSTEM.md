# Trash Talk & Welcome Back System - Design Specification

**Date**: 2025-10-09
**Status**: Planning Phase

---

## Table of Contents
1. [Welcome Back Overlay](#welcome-back-overlay)
2. [Trash Talk System](#trash-talk-system)
3. [Friends Leaderboard](#friends-leaderboard)
4. [Technical Implementation](#technical-implementation)

---

# Welcome Back Overlay

## Overview
One-time overlay shown on app launch that displays activity since last login. Always shows (not conditional). Manual dismiss only.

## Design

### Layout
```
┌─────────────────────────────────────────┐
│                                         │
│  Semi-transparent dark overlay (60%)    │
│                                         │
│    ┌─────────────────────────────┐     │
│    │  Welcome Back! 🏆           │     │
│    │  Last seen: 8 hours ago     │     │
│    ├─────────────────────────────┤     │
│    │  💰 Wallet Update           │     │
│    │  Was: 1,000 BR → Now: 1,450 BR    │
│    │  +450 BR (+45%)             │     │
│    ├─────────────────────────────┤     │
│    │  🎯 While You Were Away     │     │
│    │                             │     │
│    │  ✅ Lakers ML - Won +200 BR │     │
│    │  ✅ Celtics Spread - Won +150│     │
│    │  ❌ Warriors ML - Lost -100 │     │
│    │                             │     │
│    │  Net: +250 BR (2W-1L)       │     │
│    ├─────────────────────────────┤     │
│    │  📊 Performance Snapshot    │     │
│    │  Record: 15-8 (65%)         │     │
│    │  Streak: 🔥 3 wins          │     │
│    │  Profit: +1,450 BR          │     │
│    ├─────────────────────────────┤     │
│    │  🏆 Leaderboard Updates     │     │
│    │                             │     │
│    │  Global: #42 → #38 (↑4)    │     │
│    │  Friends: #3 → #2 (↑1)     │     │
│    │  You passed Mike! 💪        │     │
│    ├─────────────────────────────┤     │
│    │  ⏳ Active Bets             │     │
│    │  5 bets pending             │     │
│    │  [View Active Bets →]       │     │
│    ├─────────────────────────────┤     │
│    │       [Got It, Let's Go!]   │     │
│    └─────────────────────────────┘     │
│                                         │
└─────────────────────────────────────────┘
```

### Content Sections (in order)

#### 1. Header
- **Title**: "Welcome Back! 🏆"
- **Subtitle**: "Last seen: [time ago]" (e.g., "8 hours ago", "2 days ago")

#### 2. Wallet Update
- Previous balance → Current balance
- Net change with percentage
- Visual: +/- with color (green for profit, red for loss)
- Animation: Count up from old to new balance

#### 3. Settled Bets (if any since last login)
- **Title**: "🎯 While You Were Away"
- List of bets that settled (max 5 shown)
- Each bet shows:
  - ✅/❌ icon (won/lost)
  - Game name
  - Outcome with amount
- **Summary**: Net profit/loss and record (e.g., "2W-1L")

#### 4. Performance Snapshot
- **Title**: "📊 Performance Snapshot"
- Current W-L record with win rate
- Current streak (🔥 if winning, 💧 if losing)
- Total profit

#### 5. Leaderboard Updates
- **Title**: "🏆 Leaderboard Updates"
- Global rank change (e.g., "#42 → #38 (↑4)")
- Friends rank change (e.g., "#3 → #2 (↑1)")
- Callout if you passed a friend: "You passed Mike! 💪"

#### 6. Active Bets Preview
- **Title**: "⏳ Active Bets"
- Count of pending bets
- Button: "View Active Bets →" (navigates to Active Bets tab)

#### 7. Dismiss Button
- **Text**: "Got It, Let's Go!"
- **Action**: Closes overlay, shows Games screen
- Styled with primary color (cyan/neon green)

### Technical Tracking

**User Document Fields:**
```
users/{userId}/
  lastLoginAt: Timestamp (update on dismiss)
  lastSeenBalance: int (snapshot for comparison)
  lastSeenGlobalRank: int
  lastSeenFriendsRank: int
```

**On App Launch:**
1. Check `lastLoginAt` timestamp
2. Query bets settled since that timestamp
3. Calculate balance change
4. Fetch current ranks vs stored ranks
5. Display overlay with all data
6. On dismiss: Update `lastLoginAt` and snapshot fields

**Always Show:**
- Even if no activity (shows "No bets settled")
- Even if just logged in 5 minutes ago
- Dismissable only via "Got It" button

---

# Trash Talk System

## Overview
Manual trash talk messaging between friends. Costs 5 BR per recipient. Unlimited replies allowed for conversations.

---

## Sending Brags

### Trigger Points

**1. Won Bet Card (Past Bets Tab)**
```
┌─────────────────────────────────┐
│ Lakers vs Celtics               │
│ WON • +500 BR                   │
│ [View Details] [💬 Send Brag]   │
└─────────────────────────────────┘
```

**2. Performance Card**
- After passing friend in leaderboard
- "🎉 You passed Mike! [💬 Brag About It]"

**3. Leaderboard Screen**
- Tap friend → Context menu → "Send Brag"

**4. General Trash Talk**
- From Friends screen: "💬 Send Brag" button (top-right)
- No betting context required

---

### Send Brag Dialog

```
┌─────────────────────────────────┐
│ 💬 Send Brag to Friends         │
├─────────────────────────────────┤
│ Recipients: (max 5)             │
│ ☑️ Mike    ☑️ Sarah   ☐ Alex    │
│ ☑️ Jordan  ☐ Chris   ☐ Taylor   │
│                                 │
│ [Select All] [Deselect All]    │
├─────────────────────────────────┤
│ Message Type:                   │
│ ⚫ Text    ⚪ GIF               │
├─────────────────────────────────┤
│ Message:                        │
│ [________________________]      │
│ 0/50 characters                 │
│                                 │
│ [😀 Emoji Picker]               │
├─────────────────────────────────┤
│ Preview:                        │
│ 💰 Just won 500 BR on Lakers!   │
├─────────────────────────────────┤
│ Cost: 5 BR × 3 friends = 15 BR  │
│ Current Balance: 1,450 BR       │
├─────────────────────────────────┤
│     [Cancel]  [Send (15 BR)]    │
└─────────────────────────────────┘
```

### GIF Selection Mode

```
┌─────────────────────────────────┐
│ 💬 Send Brag to Friends         │
├─────────────────────────────────┤
│ Recipients: (3 selected)        │
│ ☑️ Mike  ☑️ Sarah  ☑️ Jordan    │
├─────────────────────────────────┤
│ Message Type:                   │
│ ⚪ Text    ⚫ GIF               │
├─────────────────────────────────┤
│ Search GIFs (Giphy):            │
│ [winning_______________] 🔍     │
│                                 │
│ ┌─────┐ ┌─────┐ ┌─────┐        │
│ │ GIF │ │ GIF │ │ GIF │        │
│ │  1  │ │  2  │ │  3  │        │
│ └─────┘ └─────┘ └─────┘        │
│ ┌─────┐ ┌─────┐ ┌─────┐        │
│ │ GIF │ │ GIF │ │ GIF │        │
│ │  4  │ │  5  │ │  6  │        │
│ └─────┘ └─────┘ └─────┘        │
├─────────────────────────────────┤
│ Selected: [GIF Preview]         │
├─────────────────────────────────┤
│ Cost: 5 BR × 3 friends = 15 BR  │
├─────────────────────────────────┤
│     [Cancel]  [Send (15 BR)]    │
└─────────────────────────────────┘
```

### Validation Rules

**Recipients:**
- Minimum: 1 friend
- Maximum: 5 friends per brag
- Can't select blocked users
- Can't select users who blocked you

**Message:**
- Text: 50 character limit
- Emojis count as 1-2 characters
- GIFs replace text entirely
- Must have either text OR GIF (not empty)

**Cost:**
- 5 BR per recipient
- Total = 5 × (number of recipients)
- Insufficient balance → Show error
- Transaction record created on send

---

## Receiving Brags

### In-App Notification (Bell Icon)

```
┌─────────────────────────────────┐
│ 🔔 Notifications (3 new)        │
├─────────────────────────────────┤
│ 💬 Mike sent you a brag         │
│ "Just crushed it! 💰"           │
│ 2 min ago                       │
│ [👍] [🔥] [😤] [😂] [💬 Reply]  │
├─────────────────────────────────┤
│ 💬 Sarah sent you a brag        │
│ [GIF: Celebration dance]        │
│ 1 hour ago                      │
│ [👍] [🔥] [😤] [😂] [💬 Reply]  │
├─────────────────────────────────┤
│ 💬 Jordan replied to you        │
│ "Watch your back! 😤"           │
│ 3 hours ago                     │
│ [👍] [🔥] [😤] [😂] [💬 Reply]  │
│                                 │
│ ↳ You: "Just won 500 BR! 💰"    │
│ ↳ Jordan: "Watch your back!"    │
│ ↳ You: "Already ahead! 🔥"      │
│   [💬 Continue Thread]          │
└─────────────────────────────────┘
```

**Features:**
- Shows last 7 days of brags
- Auto-deletes after 7 days
- Unread badge on bell icon
- Expandable threads (show full conversation)

### Push Notification

**Format:**
- **Title**: "💬 [Friend] sent you a brag!"
- **Body**: "[Message preview]" or "[GIF]"
- **Tap Action**: Open app → Notifications screen

**Settings:**
- Can be toggled off in More > Settings > Trash Talk

### Side Toast Popup (While In App)

```
┌─────────────────────────────────┐
│ 💬 Mike sent a brag!            │
│ "Just won 500 BR! 💰"           │
│ [View] [Dismiss]           [×]  │
└─────────────────────────────────┘
```

**Behavior:**
- Position: Top-right corner (below app bar)
- Duration: 5 seconds (auto-dismiss)
- Actions:
  - **View**: Opens notification center
  - **Dismiss**: Hides toast
  - **×**: Hides toast
- Shows while user is actively using app

---

## Reactions (Free)

**Quick Reactions (no cost):**
- 👍 Nice
- 🔥 Fire
- 😤 Whatever
- 😂 LOL

**How It Works:**
```
Mike's brag: "Just won 500 BR! 💰"
[👍 3] [🔥 5] [😤 1] [😂 2]
You reacted: 🔥
```

- Click icon to react
- Click again to change reaction
- Click same icon to remove reaction
- Shows count for each reaction
- Multiple friends can react
- Sender sees all reactions on their brag

---

## Replies (Conversations)

### Reply Dialog

```
┌─────────────────────────────────┐
│ Reply to Mike                   │
├─────────────────────────────────┤
│ Thread:                         │
│ ┌───────────────────────────┐   │
│ │ Mike: "Just won 500 BR!"  │   │
│ │ 2 min ago                 │   │
│ └───────────────────────────┘   │
│ ┌───────────────────────────┐   │
│ │ You: "Nice! Watch out!"   │   │
│ │ 1 min ago                 │   │
│ └───────────────────────────┘   │
│ ┌───────────────────────────┐   │
│ │ Mike is typing...         │   │
│ └───────────────────────────┘   │
├─────────────────────────────────┤
│ Your reply:                     │
│ [________________________]      │
│ 0/50 characters                 │
│                                 │
│ [😀 Emoji] [GIF]                │
├─────────────────────────────────┤
│ Cost: 5 BR                      │
│ Current Balance: 1,450 BR       │
├─────────────────────────────────┤
│     [Cancel]  [Send Reply]      │
└─────────────────────────────────┘
```

### Unlimited Replies

**Key Changes:**
- ❌ No "one reply limit"
- ✅ Unlimited back-and-forth conversation
- Each reply costs 5 BR (same as initial brag)
- Thread view shows full conversation history
- "X is typing..." indicator shows when friend is composing

**Threading:**
```
Notification view (expanded):

💬 Mike sent you a brag
"Just won 500 BR! 💰"
2 hours ago

Thread (5 messages):
  Mike: "Just won 500 BR! 💰"
  You: "Nice! But I'm still ahead 😎"
  Mike: "Not for long! 🔥"
  You: "We'll see about that!"
  Mike: "Already placed another bet 💪"

[💬 Reply (5 BR)]
```

### Typing Indicator

**Real-time Updates:**
- When friend starts typing: "Mike is typing..."
- Shows in notification list
- Shows in reply dialog
- Timeout: 10 seconds if no message sent
- Implemented via Firestore presence system

---

## Friend Management

### Remove Friend (Existing)

**Location:** Friends screen → Tap friend → "Remove Friend"

**Confirmation Dialog:**
```
┌─────────────────────────────────┐
│ Remove Friend?                  │
├─────────────────────────────────┤
│ Are you sure you want to        │
│ remove Mike from your friends?  │
│                                 │
│ • You'll be removed from each   │
│   other's friend lists          │
│ • Existing brags will remain    │
│ • You can re-add them later     │
├─────────────────────────────────┤
│     [Cancel]  [Remove Friend]   │
└─────────────────────────────────┘
```

**Effect:**
- Removes from both users' `friends` array
- Deletes `friendships` document
- Keeps existing brags/notifications (read-only)
- Clears from friends leaderboard
- Can re-add via friend request later

### Block User (New)

**Location:** Friends screen → Tap friend → "Block User"

**Confirmation Dialog:**
```
┌─────────────────────────────────┐
│ Block User?                     │
├─────────────────────────────────┤
│ Are you sure you want to        │
│ block Mike?                     │
│                                 │
│ • They can't send you brags     │
│ • You can't send them brags     │
│ • They won't appear in your     │
│   friends leaderboard           │
│ • All existing brags deleted    │
│ • They can't add you as friend  │
├─────────────────────────────────┤
│     [Cancel]  [Block User]      │
└─────────────────────────────────┘
```

**Effect:**
- Removes from friends list (like remove)
- Adds to `blockedUsers` array (both ways)
- Deletes all existing brags between you
- Prevents future friend requests
- User is not notified they were blocked

### Unblock User

**Location:** More > Settings > Blocked Users

```
┌─────────────────────────────────┐
│ Blocked Users                   │
├─────────────────────────────────┤
│ Mike                            │
│ [Unblock]                       │
├─────────────────────────────────┤
│ Sarah                           │
│ [Unblock]                       │
└─────────────────────────────────┘
```

**Effect:**
- Removes from `blockedUsers` array
- They can send you friend request again
- Does NOT automatically re-add as friend

---

## Settings (More Page)

### Trash Talk Settings

**Location:** More > Settings > Trash Talk

```
┌─────────────────────────────────┐
│ Trash Talk Settings             │
├─────────────────────────────────┤
│ ✅ Enable Trash Talk            │
│    Receive brags from friends   │
├─────────────────────────────────┤
│ ✅ Push Notifications           │
│    Get notified when friends    │
│    send brags                   │
├─────────────────────────────────┤
│ 🔕 Muted Friends                │
│    Select friends to mute       │
│    [Mike, Sarah] (2 muted)      │
│    [Manage →]                   │
├─────────────────────────────────┤
│ 🚫 Blocked Users                │
│    (1 blocked)                  │
│    [Manage →]                   │
└─────────────────────────────────┘
```

**Options:**

1. **Enable Trash Talk** (on/off)
   - Master switch for entire feature
   - If off: Can't send or receive brags
   - Existing brags remain visible

2. **Push Notifications** (on/off)
   - Controls push notifications only
   - In-app notifications still work
   - Toast popups still show

3. **Muted Friends**
   - Select individual friends to mute
   - You can still send them brags
   - You won't receive their brags
   - No notification to muted user

4. **Blocked Users**
   - View/manage blocked users list
   - Unblock option available

---

# Friends Leaderboard

## Overview
Two-tier leaderboard system: Global (all users) + Friends (your friend list only).

---

## Leaderboard Tabs

### Tab 1: Global Leaderboard (Existing)
- All users ranked by combo metric
- Shows top 100 + your position
- Unchanged from current implementation

### Tab 2: Friends Leaderboard (New)

```
┌─────────────────────────────────┐
│ 🏆 Friends Leaderboard          │
├─────────────────────────────────┤
│ 🥇 1. Mike                      │
│    💰 +2,500 BR • 🎯 18-7 (72%) │
│    🔥 5 wins • Last active: 1h  │
│    [View Bets] [💬 Send Brag]   │
├─────────────────────────────────┤
│ 🥈 2. You                       │
│    💰 +1,450 BR • 🎯 15-8 (65%) │
│    🔥 3 wins • Active now       │
├─────────────────────────────────┤
│ 🥉 3. Sarah                     │
│    💰 +1,200 BR • 🎯 12-6 (67%) │
│    💧 2 losses • Last active: 2h│
│    [View Bets] [💬 Send Brag]   │
├─────────────────────────────────┤
│ 4. Jordan                       │
│    💰 +800 BR • 🎯 10-5 (67%)   │
│    🔥 1 win • Last active: 5h   │
│    [View Bets] [💬 Send Brag]   │
└─────────────────────────────────┘
```

### Ranking Criteria (Combo Metric)

**Sort Order (Priority):**
1. **Primary**: Total Profit (descending)
2. **Tiebreaker 1**: Win Rate % (descending)
3. **Tiebreaker 2**: Current Streak (higher streak wins)

**Example Ranking:**
```
1. Mike:   +2,500 BR, 72%, 5 wins
2. You:    +1,450 BR, 65%, 3 wins
3. Sarah:  +1,200 BR, 67%, -2 losses  (lower profit than you)
4. Jordan: +800 BR, 67%, 1 win       (lower profit than Sarah)
```

### Display Information

**Each Friend Shows:**
- Rank position (1, 2, 3, etc.)
- Medals for top 3 (🥇🥈🥉)
- Username/Display name
- Total Profit (💰)
- W-L Record with win rate (🎯)
- Current Streak (🔥 wins, 💧 losses)
- Last Active timestamp
- Action buttons (View Bets, Send Brag)

**Your Row Highlighted:**
- Different background color
- "You" label instead of username
- No action buttons (can't brag to yourself)

---

## View Friend's Bets

### Active Bets (Public)

**Tap friend → "View Bets" → Shows:**

```
┌─────────────────────────────────┐
│ Mike's Active Bets (3)          │
├─────────────────────────────────┤
│ 🏀 Lakers vs Celtics            │
│ Lakers ML (+150)                │
│ Wager: 200 BR • Potential: 500  │
│ Game starts in 2 hours          │
├─────────────────────────────────┤
│ 🏈 Cowboys vs Eagles            │
│ Cowboys -3.5 (-110)             │
│ Wager: 150 BR • Potential: 286  │
│ LIVE - Q2 14:23                 │
├─────────────────────────────────┤
│ ⚾ Yankees vs Red Sox           │
│ Over 8.5 (-115)                 │
│ Wager: 100 BR • Potential: 187  │
│ Game starts tomorrow            │
└─────────────────────────────────┘
```

**Shows:**
- Game details
- Bet selection and odds
- Wager amount
- Potential payout
- Game status (scheduled, live, time until start)

**Does NOT Show:**
- Betslip before placement (only after placed)
- Private/hidden bets (if that feature exists)

### Settled Bets (Last 24 Hours)

```
┌─────────────────────────────────┐
│ Mike's Recent Activity          │
├─────────────────────────────────┤
│ ✅ Lakers ML - Won +300 BR      │
│    2 hours ago                  │
├─────────────────────────────────┤
│ ❌ Warriors Spread - Lost -150  │
│    5 hours ago                  │
├─────────────────────────────────┤
│ ✅ Celtics ML - Won +200 BR     │
│    1 day ago                    │
└─────────────────────────────────┘
```

**Shows:**
- Last 24 hours of settled bets
- Win/loss with profit/loss amount
- Time ago

---

## Friend Activity Stream (Existing - Enhanced)

**In Friends Tab or Home Screen:**

```
┌─────────────────────────────────┐
│ 📊 Friend Activity (Last 24h)   │
├─────────────────────────────────┤
│ 💚 Mike won 500 BR              │
│    Lakers ML                    │
│    2 min ago                    │
│    [💬 Send Brag]               │
├─────────────────────────────────┤
│ 💔 Sarah lost 150 BR            │
│    Warriors Spread              │
│    1 hour ago                   │
├─────────────────────────────────┤
│ 💚 Jordan won 300 BR            │
│    Celtics ML                   │
│    3 hours ago                  │
│    [💬 Send Brag]               │
└─────────────────────────────────┘
```

**Uses Existing:**
- `getFriendActivityStream()` from `friend_service.dart`
- Shows wins/losses from last 24 hours
- Limited to 3 most recent activities
- Updated in real-time

---

# Technical Implementation

## Firestore Structure

### Brags Collection

```
brags/
  {bragId}/
    senderId: "user123"
    recipientIds: ["user456", "user789", "user101"]

    messageType: "text" | "gif"
    message: "Just won 500 BR! 💰" (if text)
    gifUrl: "https://media.giphy.com/..." (if gif)

    betId: "bet123" (optional - null for general brags)
    cost: 15 (5 × 3 recipients)

    createdAt: Timestamp
    expiresAt: Timestamp (createdAt + 7 days)

    reactions: {
      user456: "👍",
      user789: "🔥",
      user101: "😤"
    }

    thread: [
      {
        senderId: "user456",
        message: "Watch your back!",
        gifUrl: null,
        sentAt: Timestamp,
        cost: 5
      },
      {
        senderId: "user123",
        message: "Already ahead! 🔥",
        gifUrl: null,
        sentAt: Timestamp,
        cost: 5
      }
    ]

    typingUsers: {
      user456: Timestamp (last typing activity)
    }
```

### User Document Updates

```
users/{userId}/
  lastLoginAt: Timestamp
  lastSeenBalance: int
  lastSeenGlobalRank: int
  lastSeenFriendsRank: int

  friends: ["user456", "user789", ...] (existing)
  blockedUsers: ["userABC", "userXYZ", ...]
  mutedFriends: ["user101", ...]

  trashTalkSettings: {
    enabled: true,
    pushNotifications: true
  }
```

### Notifications Collection

```
notifications/{userId}/
  brags/
    {bragId}/
      type: "brag" | "reply"
      fromUserId: "user123"
      fromUsername: "Mike"
      message: "Just won 500 BR!"
      gifUrl: null
      betId: "bet123"
      createdAt: Timestamp
      read: false
      reactions: {...}
      threadCount: 3
```

---

## Cloud Functions

### 1. sendBrag (onCall)

**Trigger:** User clicks "Send" in brag dialog

**Input:**
```javascript
{
  recipientIds: ["user456", "user789"],
  messageType: "text" | "gif",
  message: "Just won 500 BR!",
  gifUrl: "https://...",
  betId: "bet123" (optional)
}
```

**Logic:**
1. Validate user has sufficient balance (5 × recipients)
2. Check recipients are friends and not blocked/blocking
3. Deduct BR from sender's wallet (5 × recipients)
4. Create transaction record
5. Create brag document
6. Create notification for each recipient
7. Send push notifications (if enabled)
8. Return success/error

**Output:**
```javascript
{
  success: true,
  bragId: "brag123",
  cost: 15
}
```

### 2. replyToBrag (onCall)

**Trigger:** User clicks "Send Reply" in reply dialog

**Input:**
```javascript
{
  bragId: "brag123",
  messageType: "text" | "gif",
  message: "Watch your back!",
  gifUrl: null
}
```

**Logic:**
1. Validate user has 5 BR
2. Check brag exists and user is recipient
3. Deduct 5 BR from sender's wallet
4. Add reply to brag's thread array
5. Update notification for original sender
6. Send push notification
7. Return success/error

### 3. reactToBrag (onCall)

**Trigger:** User clicks reaction button

**Input:**
```javascript
{
  bragId: "brag123",
  reaction: "👍" | "🔥" | "😤" | "😂" | null
}
```

**Logic:**
1. Validate brag exists and user is recipient
2. Update reactions map (null = remove reaction)
3. Return success

### 4. cleanupExpiredBrags (scheduled)

**Trigger:** Daily at midnight EST

**Logic:**
1. Query brags where `expiresAt < now`
2. Delete brag documents
3. Delete associated notifications
4. Log cleanup count

### 5. updateTypingStatus (onCall)

**Trigger:** User types in reply dialog

**Input:**
```javascript
{
  bragId: "brag123"
}
```

**Logic:**
1. Update `typingUsers` map with current timestamp
2. Auto-expire after 10 seconds (client-side cleanup)

---

## Wallet Integration

### Transaction Records

**Sending Brag:**
```
transactions/{transactionId}/
  userId: "user123"
  type: "brag_sent"
  amount: -15
  description: "Sent brag to Mike, Sarah, Jordan"
  bragId: "brag123"
  timestamp: Timestamp
```

**Reply:**
```
transactions/{transactionId}/
  userId: "user456"
  type: "brag_reply"
  amount: -5
  description: "Reply to Mike's brag"
  bragId: "brag123"
  timestamp: Timestamp
```

**Balance Check:**
- Before sending: Check `walletBalance >= cost`
- If insufficient: Show error "Insufficient BR balance"

---

## API Integration

### Giphy API

**Endpoint:** `https://api.giphy.com/v1/gifs/search`

**Request:**
```
GET https://api.giphy.com/v1/gifs/search?api_key={key}&q=winning&limit=20
```

**Response:**
```javascript
{
  data: [
    {
      id: "abc123",
      images: {
        fixed_height: {
          url: "https://media.giphy.com/media/abc123/200.gif"
        }
      }
    }
  ]
}
```

**Implementation:**
- Flutter package: `giphy_get` or custom HTTP client
- Cache recent searches
- Limit results to 20 per search
- Store selected GIF URL in Firestore

---

## UI Components

### WelcomeBackOverlay Widget

**Location:** `lib/widgets/welcome_back_overlay.dart`

**Properties:**
```dart
class WelcomeBackOverlay extends StatelessWidget {
  final DateTime lastLoginAt;
  final int oldBalance;
  final int newBalance;
  final List<BetModel> settledBets;
  final int oldGlobalRank;
  final int newGlobalRank;
  final int oldFriendsRank;
  final int newFriendsRank;
  final List<String> friendsPassed;
  final int activeBetsCount;
  final VoidCallback onDismiss;
}
```

**Show Logic:**
- Triggered in `main.dart` after auth check
- Only on successful login
- Always shows (not conditional)

### BragDialog Widget

**Location:** `lib/widgets/trash_talk/brag_dialog.dart`

**Properties:**
```dart
class BragDialog extends StatefulWidget {
  final List<FriendData> friends;
  final String? betId; // optional context
  final BetModel? bet; // optional context
}
```

### NotificationCenter Widget

**Location:** `lib/screens/notifications/notification_center.dart`

**Features:**
- List of brags/replies
- Expandable threads
- Reaction buttons
- Reply button
- Mark as read
- Auto-delete after 7 days

---

## Testing Checklist

### Welcome Back Overlay
- [ ] Shows on every app launch
- [ ] Displays correct "last seen" time
- [ ] Shows balance change with animation
- [ ] Lists settled bets (wins/losses)
- [ ] Shows rank changes (global & friends)
- [ ] Highlights friends passed
- [ ] "Got It" button dismisses and updates lastLoginAt
- [ ] No settled bets shows "No activity"

### Send Brag
- [ ] Can select 1-5 friends
- [ ] Can't select more than 5
- [ ] Text input has 50 char limit
- [ ] Emoji picker works
- [ ] GIF search works (Giphy)
- [ ] Cost calculates correctly (5 × recipients)
- [ ] Insufficient balance shows error
- [ ] Success deducts BR and creates transaction
- [ ] Recipients receive notification

### Receive Brag
- [ ] In-app notification appears
- [ ] Push notification sent (if enabled)
- [ ] Toast popup shows while in app
- [ ] Can react (free)
- [ ] Can reply (costs 5 BR)
- [ ] Reactions update in real-time
- [ ] Thread shows full conversation

### Replies & Conversations
- [ ] Unlimited replies allowed
- [ ] Each reply costs 5 BR
- [ ] Thread view shows history
- [ ] "X is typing..." appears
- [ ] Typing indicator expires after 10 sec
- [ ] Can send text or GIF in reply

### Friend Management
- [ ] Remove friend works (existing)
- [ ] Block user removes + blocks
- [ ] Blocked user can't send brags
- [ ] Can't send brags to blocked user
- [ ] Unblock restores ability to friend

### Settings
- [ ] Enable/disable trash talk works
- [ ] Push notification toggle works
- [ ] Mute friend prevents receiving brags
- [ ] Muted friend can still receive from you

### Friends Leaderboard
- [ ] Shows only friends (not all users)
- [ ] Sorts by profit → win rate → streak
- [ ] Shows correct stats for each friend
- [ ] "View Bets" shows friend's active bets
- [ ] "Send Brag" opens brag dialog
- [ ] Your row is highlighted

### Cleanup
- [ ] Brags auto-delete after 7 days
- [ ] Notifications auto-delete after 7 days
- [ ] Expired brags don't appear in list

---

## Future Enhancements

1. **Group Brags**
   - Send to friend groups (e.g., "College Squad")
   - Separate leaderboards per group

2. **Brag Templates**
   - Pre-written messages for common scenarios
   - "Easy money!" "Who's the best?" etc.

3. **Brag Leaderboard**
   - Who sends the most brags
   - Who gets the most reactions

4. **Video Brags**
   - Record short video message (5 sec)
   - Cost: 10 BR

5. **Brag Achievements**
   - "Trash Talker" badge for 100 brags sent
   - "Popular" badge for 500 reactions received

6. **Friend Challenges**
   - Bet on same game, loser pays winner
   - Head-to-head tracking

---

**End of Specification**
