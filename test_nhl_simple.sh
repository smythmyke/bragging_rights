#!/bin/bash

echo "🏒 Testing NHL Edge APIs Integration"
echo "===================================="

# Get today's date
TODAY=$(date +%Y-%m-%d)

echo ""
echo "1. NHL Official API Test:"
echo "------------------------"
echo "   Fetching: https://api-web.nhle.com/v1/schedule/$TODAY"

# Test NHL Official API
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://api-web.nhle.com/v1/schedule/$TODAY" | \
  python -m json.tool | head -50

echo ""
echo "2. ESPN NHL API Test:"
echo "--------------------"
echo "   Fetching: https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard"

# Test ESPN NHL API
curl -s -H "User-Agent: BraggingRights/1.0" \
  "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard" | \
  python -m json.tool | head -50

echo ""
echo "✅ NHL API tests complete!"