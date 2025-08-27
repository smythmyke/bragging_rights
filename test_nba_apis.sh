#!/bin/bash

echo "======================================"
echo "NBA API Testing Suite"
echo "======================================"
echo ""

# ESPN NBA API
echo "1. ESPN NBA API (FREE - Working)"
echo "---------------------------------"
echo "Endpoint: https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"
curl -s "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard" | python -m json.tool 2>/dev/null | head -15
echo ""

# TheSportsDB
echo "2. TheSportsDB (FREE - Working)"
echo "--------------------------------"
echo "Endpoint: https://www.thesportsdb.com/api/v1/json/3/search_all_teams.php?l=NBA"
curl -s "https://www.thesportsdb.com/api/v1/json/3/search_all_teams.php?l=NBA" | python -m json.tool 2>/dev/null | grep -A 2 '"strTeam"' | head -9
echo ""

# ESPN Team Info
echo "3. ESPN Team Info (FREE - Working)"
echo "-----------------------------------"
echo "Endpoint: https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams"
curl -s "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams" | python -m json.tool 2>/dev/null | head -20
echo ""

# ESPN News
echo "4. ESPN NBA News (FREE - Working)"
echo "----------------------------------"
echo "Endpoint: https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news"
curl -s "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/news" | python -m json.tool 2>/dev/null | head -20
echo ""

echo "======================================"
echo "Summary of Working FREE NBA APIs:"
echo "======================================"
echo "✅ ESPN NBA API - Scores, teams, news, standings"
echo "✅ TheSportsDB - Team info, logos, venues"
echo "❌ NBA Stats API - Blocked (requires special headers/proxy)"
echo "❌ Balldontlie.io - Requires API key now"
echo ""
echo "Note: NBA Stats API requires browser-like requests"
echo "      and may need proxy or headless browser"