#!/bin/bash

echo "⚾ Testing MLB Edge APIs Integration"
echo "===================================="

# Get today's date
TODAY=$(date +%Y%m%d)

echo ""
echo "1. ESPN MLB Scoreboard Test:"
echo "---------------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard"

# Test ESPN MLB Scoreboard
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard?dates=$TODAY" | \
  python -m json.tool | head -100

echo ""
echo "2. ESPN MLB Teams Test:"
echo "----------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/teams"

# Test ESPN MLB Teams (just a few)
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/teams?limit=3" | \
  python -m json.tool | head -50

echo ""
echo "3. ESPN MLB News Test:"
echo "---------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/news"

# Test ESPN MLB News
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/news?limit=3" | \
  python -m json.tool | head -50

echo ""
echo "✅ MLB API tests complete!"
echo ""
echo "Note: MLB season runs April-October. Off-season data may be limited."
echo "Key MLB factors: Starting pitchers, weather/wind, ballpark factors"