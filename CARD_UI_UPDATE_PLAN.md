# Card UI Update Implementation Plan

## Overview
Simplify card display in Edge tab and create dedicated card detail pages with full information.

## Phase 1: Update PowerCardWidget
### Tasks:
1. Remove "OWNED" text label and container
2. Remove card description text
3. Keep only card name
4. Remove rarity text labels
5. Maintain golden glow for owned cards
6. Keep price display for purchasable cards
7. Add grayed-out effect for locked cards

### Visual States:
- **Owned**: Golden glow border, no price, no "OWNED" text
- **Available**: Normal display with price badge
- **Locked**: Grayed out/dimmed, price shown but muted

## Phase 2: Create Card Detail Page
### File: `lib/screens/card_detail_screen.dart`

### Components:
1. **AppBar with Balance Display**
   - Show current BR balance
   - Back navigation button
   - Card name as title

2. **Card Display Section**
   - Large card image (full screen width)
   - Animated entrance effect
   - Rarity indicator (visual only)
   - Owned quantity badge if applicable

3. **Card Information Section**
   - Card name (large, bold)
   - Card type (Offensive/Defensive/Special)
   - Rarity tier (Common/Rare/Legendary)
   - Power description
   - When to use
   - How to use

4. **Action Section**
   - If not owned: "GET" button with price
   - If owned: "USE" button (grayed if not applicable)
   - If insufficient funds: "INSUFFICIENT FUNDS" disabled button

## Phase 3: Navigation Integration
### Update home_screen.dart:
1. Add navigation from PowerCardWidget tap to CardDetailScreen
2. Pass card data and user inventory status
3. Handle purchase callbacks

## Phase 4: Edge Intel Products
### Add new Intel product definitions:
1. Create Intel product model
2. Add Live Game Intel and Pre-Game Analysis
3. Implement similar card-style display
4. Create detail pages for Intel products

## Implementation Order:
1. ✅ Create AI prompts for Edge Intel cards
2. Update PowerCardWidget to remove text
3. Create CardDetailScreen with navbar
4. Update navigation in home_screen Edge tab
5. Test card display and navigation
6. Add Intel products to the system

## File Structure:
```
lib/
  screens/
    card_detail_screen.dart (NEW)
  widgets/
    power_card_widget.dart (UPDATE)
  screens/
    home/
      home_screen.dart (UPDATE)
```

## Success Criteria:
- [ ] Cards display cleanly without text overflow
- [ ] Only card name visible on grid
- [ ] Golden glow indicates ownership
- [ ] Tap navigates to detail page
- [ ] Detail page shows full card info
- [ ] Balance visible on detail page
- [ ] Purchase flow works from detail page
- [ ] Intel products have card representations