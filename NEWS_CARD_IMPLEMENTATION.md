# News Card Implementation - Tap to Open in Browser

**Date:** 2025-10-10
**Status:** ✅ Implemented, Ready for Testing

---

## Summary

Implemented tap-to-open functionality for Breaking News cards in Edge Intelligence. Users can now:
1. View article preview (title, description, source, timestamp) on the card
2. Tap any article to open the full article in their default browser
3. See sentiment indicators (negative/positive/neutral) with color coding

---

## Changes Made

### 1. **BreakingNewsCard Widget** (`lib/widgets/edge/cards/breaking_news_card.dart`)

**Added:**
- `url_launcher` import for opening URLs in browser
- `_buildArticleItem()` method to display individual news articles
- `_openArticle()` method to launch URLs in external browser
- Sentiment-based color coding (red for negative, green for positive)
- "Time ago" calculation (e.g., "2h ago", "1d ago")
- Visual indicators: source icon, open-in-new icon

**Removed:**
- Old `_buildHeadlineItem()` method that showed simple text headlines

**Article Display Format:**
```
┌─────────────────────────────────────┐
│ Article Title (max 2 lines)        │
│ Description text... (max 2 lines)  │
│ 📰 ESPN  •  ⏰ 2h ago  🔗          │
└─────────────────────────────────────┘
```

**Key Features:**
- **Title**: Max 2 lines, truncated with ellipsis
- **Description**: Max 2 lines, optional (hidden if empty)
- **Source**: Displayed with icon
- **Time**: Calculated from publishedAt timestamp
- **Sentiment**: Background color changes based on sentiment
  - Negative = Red tint + warning icon
  - Positive = Green tint + trending icon
  - Neutral = Default white tint + article icon
- **Interaction**: Tap anywhere on article to open in browser

---

### 2. **EdgeCardBuilder** (`lib/services/edge/edge_card_builder.dart`)

**Updated:**
- `_buildBreakingNewsCard()` to use `articles` array instead of `headlines`
- Metadata now includes full `articles` array with all article data:
  ```dart
  metadata: {
    'articles': articles,  // Full article data including URLs
    'articleCount': articleCount,
    'source': newsData.source,
    'sport': intelligence.sport,
    'sentiment': newsData.data['sentiment'],
    'keyTopics': newsData.data['keyTopics'],
    'injuryNews': newsData.data['injuryNews'],
  }
  ```

- Teaser text now uses first article title instead of generic text
- `_buildBreakingNewsContent()` updated to format article titles correctly

---

### 3. **Article Data Structure**

Each article in the `articles` array contains:
```dart
{
  'title': 'LeBron out 3-4 weeks, expected to miss opener',
  'description': 'Lakers star LeBron James will be sidelined...',
  'url': 'https://www.espn.com/nba/story/...',  // ← Used to open in browser
  'source': 'ESPN',
  'publishedAt': '2025-10-09T21:45:45Z',
  'analysis': {
    'relevance': 0.9,
    'sentiment': 'negative',
    'mentions': ['Lakers']
  }
}
```

---

## User Flow

1. **View Game Details**
   - User navigates to game details screen
   - Edge Intelligence cards load automatically
   - Breaking News card appears (if unlocked or purchased)

2. **See News Preview**
   - Top 3 most relevant articles displayed
   - Each shows: title, description, source, time
   - Color-coded by sentiment (red/green/neutral)

3. **Tap to Read Full Article**
   - User taps anywhere on an article card
   - `url_launcher` opens article URL in default browser
   - User reads full article on source website (ESPN, CBS Sports, etc.)
   - User returns to app via back button/app switcher

---

## Technical Details

### URL Launching
```dart
Future<void> _openArticle(String url) async {
  if (url.isEmpty) return;

  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (e) {
    debugPrint('Error opening article: $e');
  }
}
```

- **Mode**: `LaunchMode.externalApplication` opens in browser (not in-app webview)
- **Error Handling**: Silently fails if URL is invalid or can't be launched
- **Platform**: Works on iOS (Safari), Android (Chrome/default browser), Web

### Time Calculation
```dart
String timeAgo = 'Recently';
if (publishedAt.isNotEmpty) {
  try {
    final pubDate = DateTime.parse(publishedAt);
    final diff = DateTime.now().difference(pubDate);
    if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }
  } catch (e) {
    // Keep default timeAgo
  }
}
```

### Sentiment Color Coding
```dart
Color sentimentColor = Colors.white.withOpacity(0.1);  // neutral
IconData sentimentIcon = Icons.article;

if (sentiment == 'negative') {
  sentimentColor = Colors.red.withOpacity(0.1);
  sentimentIcon = Icons.warning_amber;
} else if (sentiment == 'positive') {
  sentimentColor = Colors.green.withOpacity(0.1);
  sentimentIcon = Icons.trending_up;
}
```

---

## Dependencies

- ✅ **url_launcher: ^6.3.1** - Already installed in pubspec.yaml
- No additional packages needed

---

## Testing Checklist

### Manual Testing Required:

- [ ] **Navigate to a game with news data**
  - Suggested: Lakers, Warriors, or other high-profile team
  - Ensure Edge Intelligence cards are unlocked or have BR to purchase

- [ ] **Verify Breaking News card displays**
  - Check that articles show title, description, source, time
  - Verify sentiment colors (red/green/neutral backgrounds)
  - Confirm "X articles found" count is correct

- [ ] **Test tap-to-open functionality**
  - Tap an article card
  - Verify default browser opens
  - Confirm article URL loads correctly
  - Return to app and verify state is maintained

- [ ] **Test error handling**
  - Test with missing/invalid URLs (should fail silently)
  - Test with no description (should only show title)
  - Test with very long titles (should truncate at 2 lines)

- [ ] **Test on multiple platforms**
  - iOS: Opens in Safari
  - Android: Opens in Chrome/default browser
  - Check that app doesn't crash if user has no browser

---

## Known Limitations

1. **No In-App Browser**
   - Articles open in external browser (not in-app webview)
   - User must use back button/app switcher to return
   - This is intentional for simplicity (Option 1 from requirements)

2. **Article Length**
   - API returns 2,000-12,000+ character articles
   - Only showing title + description on card (perfect length)
   - Full content available on source website

3. **No Offline Mode**
   - Requires internet connection to open articles
   - URL launching fails silently if no connection

4. **No Paywall Detection**
   - Some sources (The Athletic, etc.) may have paywalls
   - User will see paywall in browser, not handled by app

---

## Future Enhancements (Not Implemented)

1. **In-App WebView**
   - Option to open articles in in-app browser
   - Add "Open in Browser" vs "Read in App" choice

2. **Article Bookmarking**
   - Save articles to read later
   - Store in Firestore per user

3. **Share Functionality**
   - Share article link via SMS, social media
   - Add share icon to article cards

4. **Player Name Mapping**
   - Map star players to teams (LeBron James → Lakers)
   - Catch articles that mention players but not team names

5. **Enhanced Keywords**
   - Add missing keywords: "miss", "ruled out", "day-to-day"
   - Adjust relevance threshold from > 0.5 to >= 0.5
   - See `news_scoring_analysis.md` for full recommendations

---

## Related Files

- `edge_news_card_mockup.html` - Original mockup with faux data
- `edge_news_card_real_data.html` - Mockup with real API data showing lengths
- `news_scoring_analysis.md` - Analysis of scoring effectiveness with real data
- `news_relevance_analysis.html` - Visualization of how relevance is determined

---

## Next Steps

1. ✅ Implementation complete
2. ⏳ **Test with real game data** (user's next task)
3. ⏳ Deploy to production
4. ⏳ Monitor for errors in Crashlytics
5. ⏳ Gather user feedback on news relevance
6. ⏳ Consider implementing recommended improvements from `news_scoring_analysis.md`

---

## Questions?

- Check `news_scoring_analysis.md` for details on how articles are scored and filtered
- Check `edge_news_card_real_data.html` to see article lengths and display format
- Review Edge Intelligence system docs for card unlock/purchase flow
