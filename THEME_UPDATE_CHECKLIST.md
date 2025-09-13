# Neon Cyber Theme Update Checklist

## Color Mapping Reference
- `Colors.green` → `AppTheme.neonGreen`
- `Colors.greenAccent` → `AppTheme.neonGreen`
- `Colors.blue` → `AppTheme.primaryCyan`
- `Colors.red` → `AppTheme.errorPink`
- `Colors.amber`/`Colors.orange` → `AppTheme.warningAmber`
- `Colors.grey` → `AppTheme.surfaceBlue`
- `Colors.black` → `AppTheme.deepBlue`
- `Colors.white` → Keep for text, add opacity where needed

## ✅ Completed Updates - Phase 1
- [x] `app_theme.dart` - Theme configuration created
- [x] `main.dart` - Theme applied to MaterialApp
- [x] `neon_button.dart` - New component created
- [x] `neon_game_card.dart` - New component created
- [x] `theme_demo_screen.dart` - Demo screen created

## ✅ Completed Updates - Main Screens
- [x] `home_screen.dart` - All colors updated
- [x] `login_screen.dart` - All colors updated
- [x] `active_bets_screen.dart` - All colors updated
- [x] `game_detail_screen.dart` - All colors updated
- [x] `bet_selection_screen.dart` - All colors updated
- [x] `pool_selection_screen.dart` - All colors updated
- [x] `leaderboard_screen.dart` - All colors updated
- [x] `sports_selection_screen.dart` - All colors updated
- [x] `invite_friends_screen.dart` - All colors updated
- [x] `my_pools_screen.dart` - All colors updated
- [x] `fight_card_screen.dart` - All colors updated

## ✅ Completed Updates - Widgets
- [x] `bet_slip_widget.dart` - All colors updated
- [x] `power_card_widget.dart` - All colors updated
- [x] `intel_card_widget.dart` - All colors updated
- [x] `edge_card_widget.dart` - All colors updated
- [x] `game_card_enhanced.dart` - All colors updated

## 🔄 In Progress - Priority Screens
- [ ] `active_bets_screen.dart` - User's active bets
- [ ] `game_detail_screen.dart` - Game information
- [ ] `bet_selection_screen.dart` - Main betting interface
- [ ] `pool_selection_screen.dart` - Pool selection UI
- [ ] `leaderboard_screen.dart` - Rankings display

## 📱 Secondary Screens
- [ ] `sports_selection_screen.dart` - Onboarding
- [ ] `invite_friends_screen.dart` - Social features
- [ ] `my_pools_screen.dart` - User's pools
- [ ] `fight_card_screen.dart` - Fight betting
- [ ] `fight_pick_detail_screen.dart` - Fight details
- [ ] `h2h_picks_screen.dart` - Head to head picks
- [ ] `head_to_head_screen.dart` - H2H main
- [ ] `enhanced_pool_screen.dart` - Enhanced pools
- [ ] `pool_selection_screen_v2.dart` - Pool selection v2
- [ ] `strategy_room_screen.dart` - Strategy room

## 🎮 Premium/Edge Screens
- [ ] `edge_screen.dart` - Edge main
- [ ] `edge_screen_v2.dart` - Edge v2
- [ ] `edge_detail_screen.dart` - Edge details
- [ ] `edge_detail_screen_v2.dart` - Edge details v2

## 🎯 Game Screens
- [ ] `all_games_screen.dart` - All games list
- [ ] `optimized_games_screen.dart` - Optimized games
- [ ] `fight_card_grid_screen.dart` - Fight card grid

## ⚙️ Settings/Utility Screens
- [ ] `preferences_settings_screen.dart` - Settings
- [ ] `transaction_history_screen.dart` - Transactions
- [ ] `active_wagers_screen.dart` - Wagers
- [ ] `card_inventory_screen.dart` - Card inventory
- [ ] `card_detail_screen.dart` - Card details
- [ ] `intel_detail_screen.dart` - Intel details
- [ ] `lottie_splash_screen.dart` - Splash screen

## 🧩 Widget Components
- [ ] `power_card_widget.dart` - Power cards
- [ ] `intel_card_widget.dart` - Intel cards
- [ ] `edge_card_widget.dart` - Edge cards
- [ ] `edge_card_collection.dart` - Edge collection
- [ ] `edge_card_types.dart` - Edge types
- [ ] `game_card_enhanced.dart` - Game cards
- [ ] `expandable_bet_card.dart` - Bet cards
- [ ] `baseball_props_widget.dart` - Baseball props
- [ ] `props_tab_content.dart` - Props tabs
- [ ] `props_player_detail.dart` - Player details
- [ ] `props_player_selection.dart` - Player selection
- [ ] `team_logo.dart` - Team logos
- [ ] `bragging_rights_logo.dart` - App logo
- [ ] `loading_video_overlay.dart` - Loading overlay
- [ ] `info_edge_carousel.dart` - Edge carousel
- [ ] `standings_info_card.dart` - Standings card
- [ ] `pool_creation_limit_indicator.dart` - Pool limits

## 📊 Progress
- **Total Files**: 52
- **Completed**: 8 (15%)
- **Remaining**: 44 (85%)

## Update Process for Each File
1. Add import: `import '../../theme/app_theme.dart';`
2. Replace hardcoded colors with AppTheme colors
3. Test that the screen/widget still renders correctly
4. Mark as complete in this checklist

## Notes
- Priority given to user-facing screens that are most frequently accessed
- Widget updates should maintain backward compatibility
- Keep Colors.white for text but consider adding opacity
- Use AppTheme helper methods for gradients and glows where appropriate