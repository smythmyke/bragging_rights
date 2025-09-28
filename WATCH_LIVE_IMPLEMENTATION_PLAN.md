# Watch Live Feature & Sticky Button Implementation Plan

## Overview
This document outlines the implementation plan for two key features:
1. Making the "View All Sports" button sticky on the Games page
2. Adding a "Watch Live" section with streaming links

---

## Feature 1: Sticky "View All Sports" Button

### Current State
- Button is at the bottom of the games list
- Users must scroll to the bottom to access it
- Gets lost when viewing many games

### Proposed Changes
- Make button fixed/sticky at bottom of screen
- Remains visible while scrolling through games
- Maintains current styling but adds shadow for depth

### Implementation Details
**File:** `lib/screens/home/home_screen.dart` (Games tab section)

**Changes:**
1. Wrap games list in a Stack widget
2. Position button at bottom with `Positioned.bottom`
3. Add elevation/shadow for visibility
4. Ensure button doesn't overlap last game item (add padding to list)

---

## Feature 2: Watch Live Page

### Navigation Changes
**Location:** Bottom navigation bar on Games page
- Replace "Pools" button with "Watch Live"
- Icon: `Icons.live_tv` or `Icons.play_circle_outline`

### Page Structure

#### File Location
```
lib/
├── screens/
│   └── watch/
│       └── watch_live_screen.dart
└── models/
    └── streaming_service_model.dart
```

### Watch Live Screen Content

#### 1. Header Disclaimers
```
⚠️ IMPORTANT NOTICE:
• These are third-party streaming links not affiliated with Bragging Rights
• We do not host, promote, or endorse any content on these sites
• Users must verify the legality of streaming services in their jurisdiction
• Some content may be geo-restricted or require VPN access
• Use at your own risk and discretion
```

#### 2. Legal Disclaimer
```
LEGAL DISCLAIMER:
Bragging Rights provides these links for informational purposes only.
We make no representations about the content, legality, or safety of
these external sites. Users are responsible for complying with all
applicable laws in their region. We strongly recommend using official,
licensed streaming services where available.
```

#### 3. Acceptance Requirement
- Checkbox: "I understand and accept the terms and conditions"
- Links only visible after acceptance
- Preference saved locally to remember choice

#### 4. Content Sections

##### A. Official Streaming Services (Top Section)
**Recommended Legal Options:**
- ESPN+ (NFL, NHL, MLB, UFC)
- DAZN (Boxing, MMA)
- Peacock (Premier League, NFL)
- Amazon Prime Video (Thursday Night Football)
- Apple TV+ (MLS, MLB)
- NBA League Pass
- NHL.TV / ESPN+
- NFL Sunday Ticket / YouTube TV
- MLB.TV

##### B. Third-Party Streaming Links (After Disclaimer Acceptance)

**SportSurge**
- Mirror 1: https://v2.sportsurge.net/home5/
- Mirror 2: https://sportsurge.bz/
- Mirror 3: https://www.sportsurge.uno/

**CrackStreams**
- Mirror 1: https://crackstreams.cx/
- Mirror 2: https://crackstreams.ch/

**BuffStreams**
- Mirror: https://buffsports.io/

**LiveTV**
- Mirror 1: https://livetv860.me/enx/
- Mirror 2: https://livetv.sx/enx/

**DofuStream**
- Main Site: http://www.dofustream.com/

**StreamEast**
- Mirror: https://v2.streameast.sk/

#### 5. Additional Safety Information
- Recommendation to use ad-blockers
- Warning about pop-ups and redirects
- VPN usage guidelines
- Device security recommendations

### UI/UX Design

#### Layout Structure
```
WatchLiveScreen
├── AppBar (title: "Watch Live Sports")
├── ScrollView
│   ├── Warning Banner (red/orange gradient)
│   ├── Disclaimer Card
│   ├── Acceptance Checkbox
│   ├── Official Services Section
│   │   └── Grid of service cards
│   └── Third-Party Links Section (conditional)
│       ├── Safety Tips Card
│       └── List of streaming services
└── Bottom padding for navigation
```

#### Visual Design
- Warning banner: Red/orange gradient with white text
- Official services: Green accent cards
- Third-party links: Dark cards with warning icons
- Each service card shows:
  - Service name
  - Mirror number (if applicable)
  - External link icon
  - Tap to open in browser

### State Management
- Track disclaimer acceptance (SharedPreferences)
- Loading states for external links
- Error handling for failed launches

### External Package Requirements
- `url_launcher`: For opening links in browser
- `shared_preferences`: For storing acceptance state

### Safety Features
1. Links open in external browser (not WebView)
2. No direct embedding of streams
3. Clear separation between official and unofficial sources
4. Persistent warnings about risks

### Implementation Priority
1. Create basic Watch Live screen with disclaimers
2. Add official streaming services section
3. Implement acceptance checkbox logic
4. Add third-party links section
5. Polish UI and add animations
6. Implement sticky button on Games page

---

## Testing Checklist
- [ ] Sticky button remains visible while scrolling
- [ ] Sticky button doesn't cover game content
- [ ] Watch Live navigation works from Games page
- [ ] Disclaimer acceptance is required
- [ ] Acceptance state is remembered
- [ ] All links open in external browser
- [ ] UI is responsive on different screen sizes
- [ ] Warning messages are clearly visible

---

## Legal Considerations
- Consult legal counsel about streaming link aggregation
- Consider geographic restrictions
- Add terms of service update if needed
- Monitor for DMCA or legal notices
- Be prepared to remove links if requested

---

## Future Enhancements
- Add "Report Broken Link" feature
- Include game-specific streaming options
- Add favorite streaming services
- Push notifications for live games
- Integration with game details pages