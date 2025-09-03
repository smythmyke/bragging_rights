#!/usr/bin/env python3
"""ESPN API Explorer - Test various endpoints for granular game state data"""

import json
import time
import requests
from datetime import datetime

# Test with actual recent game IDs
test_games = {
    'nba': '401585135',  # Recent NBA game
    'nfl': '401547505',  # Recent NFL game
    'mlb': '401581100',  # Recent MLB game
    'nhl': '401559520',  # Recent NHL game
    'ufc': '401492652',  # Recent UFC event
}

def explore_endpoint(name, url):
    """Explore an ESPN API endpoint and extract game state data"""
    print(f"\n{'='*80}")
    print(f"Testing: {name}")
    print(f"URL: {url}")
    print('='*80)
    
    try:
        response = requests.get(url)
        response.raise_for_status()
        data = response.json()
        
        # Save raw response for analysis
        filename = f"espn_{name.replace(' ', '_').lower()}.json"
        with open(filename, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"[OK] Saved raw response to {filename}")
        
        # Extract key game state information
        extract_game_state(name, data)
        
    except requests.exceptions.RequestException as e:
        print(f"[ERROR] Error fetching {name}: {e}")
    except json.JSONDecodeError as e:
        print(f"[ERROR] Error parsing JSON for {name}: {e}")

def extract_game_state(name, data):
    """Extract and display game state information"""
    
    # For scoreboard endpoints
    if 'events' in data and data['events']:
        print("\n[SCOREBOARD DATA:]")
        for event in data['events'][:1]:  # Just first event
            if 'status' in event:
                status = event['status']
                print(f"  Status Type: {status.get('type', {}).get('name', 'N/A')}")
                print(f"  Period: {status.get('period', 'N/A')}")
                print(f"  Clock: {status.get('displayClock', 'N/A')}")
                print(f"  Detail: {status.get('type', {}).get('detail', 'N/A')}")
                
            if 'competitions' in event and event['competitions']:
                comp = event['competitions'][0]
                
                # Situation (football specific)
                if 'situation' in comp:
                    sit = comp['situation']
                    print(f"\n  [GAME SITUATION:]")
                    print(f"    Down: {sit.get('down', 'N/A')}")
                    print(f"    Distance: {sit.get('distance', 'N/A')}")
                    print(f"    Possession: {sit.get('possession', 'N/A')}")
                    print(f"    Last Play: {sit.get('lastPlay', {}).get('text', 'N/A')}")
                    
                # Game details
                if 'details' in comp:
                    print(f"\n  [DETAILS:] {comp['details']}")
    
    # For summary endpoints
    if 'header' in data:
        print("\n[SUMMARY DATA:]")
        header = data.get('header', {})
        if 'competitions' in header and header['competitions']:
            comp = header['competitions'][0]
            print(f"  Status: {comp.get('status', {}).get('type', {}).get('name', 'N/A')}")
            if 'playByPlaySource' in comp:
                print(f"  Play-by-play available: Yes")
    
    # For play-by-play
    if 'plays' in data:
        print(f"\n[PLAY-BY-PLAY DATA:] {len(data['plays'])} plays found")
        if data['plays']:
            latest_play = data['plays'][0]
            print(f"  Latest play ID: {latest_play.get('id', 'N/A')}")
            print(f"  Type: {latest_play.get('type', {}).get('text', 'N/A')}")
            print(f"  Text: {latest_play.get('text', 'N/A')}")
            print(f"  Period: {latest_play.get('period', {}).get('number', 'N/A')}")
            print(f"  Clock: {latest_play.get('clock', {}).get('displayValue', 'N/A')}")
    
    # For MMA/Boxing
    if 'rounds' in data:
        print(f"\n[ROUNDS DATA:] {len(data.get('rounds', []))} rounds")
        
    # For fights in MMA
    if 'fights' in data:
        print(f"\n[FIGHTS DATA:]")
        for fight in data['fights'][:1]:
            print(f"  Fight ID: {fight.get('id', 'N/A')}")
            if 'status' in fight:
                print(f"  Status: {fight['status'].get('type', {}).get('name', 'N/A')}")
                print(f"  Round: {fight['status'].get('period', 'N/A')}")
                print(f"  Time: {fight['status'].get('displayClock', 'N/A')}")
    
    # Print available top-level keys
    print(f"\n[Available fields:] {', '.join(data.keys())}")

def test_all_sports():
    """Test various sports endpoints"""
    
    # 1. Test Scoreboards (current games)
    scoreboards = {
        'NBA Scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard',
        'NFL Scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard',
        'MLB Scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard',
        'NHL Scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard',
        'UFC Scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard',
        'Tennis Scoreboard': 'https://site.api.espn.com/apis/site/v2/sports/tennis/scoreboard',
    }
    
    print("=" * 80)
    print("TESTING SCOREBOARD ENDPOINTS")
    print("=" * 80)
    
    for name, url in scoreboards.items():
        explore_endpoint(name, url)
        time.sleep(1)  # Rate limiting
    
    # 2. Test Game Summaries (specific games)
    summaries = {
        'NBA Summary': f"https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event={test_games['nba']}",
        'NFL Summary': f"https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event={test_games['nfl']}",
        'MLB Summary': f"https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event={test_games['mlb']}",
        'UFC Summary': f"https://site.api.espn.com/apis/site/v2/sports/mma/ufc/summary?event={test_games['ufc']}",
    }
    
    print("\n" + "=" * 80)
    print("TESTING SUMMARY ENDPOINTS")
    print("=" * 80)
    
    for name, url in summaries.items():
        explore_endpoint(name, url)
        time.sleep(1)
    
    # 3. Test Play-by-Play (most detailed)
    playbyplay = {
        'NBA Play-by-Play': f"https://site.api.espn.com/apis/site/v2/sports/basketball/nba/playbyplay?gameId={test_games['nba']}",
        'NFL Play-by-Play': f"https://site.api.espn.com/apis/site/v2/sports/football/nfl/playbyplay?gameId={test_games['nfl']}",
        'MLB Play-by-Play': f"https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/playbyplay?gameId={test_games['mlb']}",
    }
    
    print("\n" + "=" * 80)
    print("TESTING PLAY-BY-PLAY ENDPOINTS")
    print("=" * 80)
    
    for name, url in playbyplay.items():
        explore_endpoint(name, url)
        time.sleep(1)

def test_odds_api():
    """Test The Odds API for game state data"""
    print("\n" + "=" * 80)
    print("TESTING THE ODDS API")
    print("=" * 80)
    
    # Note: You'll need to get a free API key from https://the-odds-api.com/
    API_KEY = 'YOUR_API_KEY_HERE'  # Replace with actual key
    
    endpoints = {
        'Live Sports': f'https://api.the-odds-api.com/v4/sports/?apiKey={API_KEY}',
        'NFL Scores': f'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/scores/?apiKey={API_KEY}&daysFrom=1',
        'NBA Scores': f'https://api.the-odds-api.com/v4/sports/basketball_nba/scores/?apiKey={API_KEY}&daysFrom=1',
    }
    
    if API_KEY == 'YOUR_API_KEY_HERE':
        print("[WARNING] Please add your Odds API key to test this endpoint")
        print("   Get a free key at: https://the-odds-api.com/")
        return
    
    for name, url in endpoints.items():
        explore_endpoint(name, url)
        time.sleep(1)

if __name__ == "__main__":
    print(f"ESPN API Explorer - {datetime.now()}")
    print("Testing various endpoints for granular game state data")
    
    # Run tests
    test_all_sports()
    
    # Uncomment to test Odds API (requires API key)
    # test_odds_api()
    
    print("\n[COMPLETE] Testing complete! Check the generated JSON files for full data.")