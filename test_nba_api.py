#!/usr/bin/env python3
"""Test script for NBA ESPN API matching service"""

import json
import urllib.request
from datetime import datetime, timedelta

def fetch_nba_games(date_str):
    """Fetch NBA games for a specific date"""
    url = f"https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates={date_str}"
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read())

def normalize_team_name(team):
    """Normalize team name for matching (similar to Flutter app logic)"""
    normalized = team.lower().strip()

    # NBA team name variations
    if 'thunder' in normalized and 'oklahoma' not in normalized:
        return 'oklahoma city thunder'
    if 'rockets' in normalized and 'houston' not in normalized:
        return 'houston rockets'

    # Remove special characters and extra spaces
    normalized = ''.join(c if c.isalnum() or c.isspace() else '' for c in normalized)
    normalized = ' '.join(normalized.split())

    return normalized

def test_matching(target_home, target_away, date_str):
    """Test matching logic for a specific game"""
    print(f"\nTesting date: {date_str}")
    print(f"Looking for: {target_away} @ {target_home}")
    print("-" * 60)

    data = fetch_nba_games(date_str)
    events = data.get('events', [])

    if not events:
        print(f"No games found for {date_str}")
        return False

    print(f"Found {len(events)} games on this date")

    for event in events:
        competitions = event.get('competitions', [{}])[0]
        competitors = competitions.get('competitors', [])

        if len(competitors) >= 2:
            home_team = next((c for c in competitors if c.get('homeAway') == 'home'), {})
            away_team = next((c for c in competitors if c.get('homeAway') == 'away'), {})

            home_name = home_team.get('team', {}).get('displayName', '')
            away_name = away_team.get('team', {}).get('displayName', '')

            # Normalize for comparison
            norm_home = normalize_team_name(home_name)
            norm_away = normalize_team_name(away_name)
            norm_target_home = normalize_team_name(target_home)
            norm_target_away = normalize_team_name(target_away)

            print(f"\n  Game: {away_name} @ {home_name}")
            print(f"  ESPN ID: {event.get('id')}")
            print(f"  Normalized: {norm_away} @ {norm_home}")

            # Check both normal and reversed order
            if (norm_home == norm_target_home and norm_away == norm_target_away) or \
               (norm_home == norm_target_away and norm_away == norm_target_home):
                print(f"  >>> MATCH FOUND! ESPN ID: {event.get('id')}")
                print(f"  Game time: {event.get('date')}")
                return True

    print("\n>>> No matching game found")
    return False

def main():
    print("=" * 60)
    print("NBA ESPN API Matching Service Test")
    print("=" * 60)

    # Test cases
    test_cases = [
        ("Houston Rockets", "Oklahoma City Thunder", "20260115"),
        ("Oklahoma City Thunder", "Houston Rockets", "20260115"),
        ("Los Angeles Lakers", "Houston Rockets", "20251225"),
        ("New York Knicks", "Cleveland Cavaliers", "20251225"),
    ]

    for away, home, date in test_cases:
        test_matching(home, away, date)

    # Test with today's date for completeness
    today = datetime.now().strftime("%Y%m%d")
    print(f"\n\nChecking today's games ({today}):")
    test_matching("Any Team", "Any Team", today)

if __name__ == "__main__":
    main()