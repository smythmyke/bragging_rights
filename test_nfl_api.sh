#!/bin/bash

echo "🏈 Testing NFL Edge APIs Integration"
echo "===================================="

# Test ESPN NFL API
echo ""
echo "1. ESPN NFL API Test:"
echo "--------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"

# Test ESPN NFL Scoreboard
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard" | \
  python -m json.tool | head -100

echo ""
echo "2. ESPN NFL Teams Test:"
echo "-----------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams"

# Test ESPN NFL Teams
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams?limit=5" | \
  python -m json.tool | head -50

echo ""
echo "3. ESPN NFL News Test:"
echo "---------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/football/nfl/news"

# Test ESPN NFL News
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/football/nfl/news?limit=3" | \
  python -m json.tool | head -50

echo ""
echo "✅ NFL API tests complete!"
echo ""
echo "Note: NFL season runs Sept-Feb. Off-season data may be limited."