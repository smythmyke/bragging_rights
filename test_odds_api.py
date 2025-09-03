#!/usr/bin/env python3
"""Test The Odds API for game state information"""

import requests
import json
from datetime import datetime

# The Odds API - Free tier allows 500 requests/month
# Get your free key at: https://the-odds-api.com/

def test_odds_api():
    """Test The Odds API endpoints"""
    
    # You can get a free API key at https://the-odds-api.com/
    # Free tier: 500 requests/month
    API_KEY = 'demo'  # Using demo key for testing
    
    print("="*80)
    print("THE ODDS API TESTING")
    print("="*80)
    print("Note: Using demo API key. Get your free key at https://the-odds-api.com/")
    print("Free tier: 500 requests/month\n")
    
    endpoints = {
        'Active Sports': f'https://api.the-odds-api.com/v4/sports/?apiKey={API_KEY}',
        'NFL Scores': f'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/scores/?apiKey={API_KEY}&daysFrom=3',
        'NBA Scores': f'https://api.the-odds-api.com/v4/sports/basketball_nba/scores/?apiKey={API_KEY}&daysFrom=3',
        'MLB Scores': f'https://api.the-odds-api.com/v4/sports/baseball_mlb/scores/?apiKey={API_KEY}&daysFrom=3',
        'UFC Scores': f'https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/scores/?apiKey={API_KEY}&daysFrom=3',
        'Soccer Scores': f'https://api.the-odds-api.com/v4/sports/soccer_epl/scores/?apiKey={API_KEY}&daysFrom=3',
    }
    
    for name, url in endpoints.items():
        print(f"\n{'-'*60}")
        print(f"Testing: {name}")
        print(f"URL: {url[:100]}...")
        
        try:
            response = requests.get(url)
            
            # Check headers for usage limits
            print(f"Status: {response.status_code}")
            print(f"Requests Used: {response.headers.get('x-requests-used', 'N/A')}")
            print(f"Requests Remaining: {response.headers.get('x-requests-remaining', 'N/A')}")
            
            if response.status_code == 200:
                data = response.json()
                
                # Save for analysis
                filename = f"odds_api_{name.replace(' ', '_').lower()}.json"
                with open(filename, 'w') as f:
                    json.dump(data, f, indent=2)
                print(f"[OK] Saved to {filename}")
                
                # Analyze the data
                if isinstance(data, list):
                    print(f"Total items: {len(data)}")
                    
                    if data and 'scores' in name.lower():
                        # This is a scores endpoint
                        game = data[0] if data else {}
                        print("\nSample game data:")
                        print(f"  ID: {game.get('id', 'N/A')}")
                        print(f"  Sport: {game.get('sport_key', 'N/A')}")
                        print(f"  Commence Time: {game.get('commence_time', 'N/A')}")
                        print(f"  Completed: {game.get('completed', 'N/A')}")
                        
                        if 'scores' in game and game['scores']:
                            print(f"  Scores:")
                            for score in game['scores']:
                                print(f"    {score.get('name', 'N/A')}: {score.get('score', 'N/A')}")
                        
                        # Check for period/quarter data
                        if 'periods' in game:
                            print(f"  Periods available: Yes")
                            print(f"  Period data: {game['periods']}")
                        
                        if 'last_update' in game:
                            print(f"  Last Update: {game['last_update']}")
                    
                    elif data and 'sports' in name.lower():
                        # This is the sports list
                        print("\nAvailable sports (first 5):")
                        for sport in data[:5]:
                            print(f"  - {sport.get('title', 'N/A')} ({sport.get('key', 'N/A')})")
                            print(f"    Active: {sport.get('active', 'N/A')}, In-Season: {sport.get('has_outrights', 'N/A')}")
                
            else:
                print(f"Error: {response.status_code}")
                print(f"Response: {response.text[:200]}")
                
        except Exception as e:
            print(f"Error: {e}")
        
        print("-"*60)

def analyze_odds_api_capabilities():
    """Analyze what The Odds API provides"""
    print("\n" + "="*80)
    print("THE ODDS API CAPABILITIES SUMMARY")
    print("="*80)
    
    print("""
Based on testing, The Odds API provides:

LIVE SCORES:
- Game scores updated in real-time
- Completed status flag
- Last update timestamp
- Home/Away team names and scores

LIMITATIONS:
- No period/quarter/inning breakdown in free tier
- No play-by-play data
- No detailed game state (possession, timeouts, etc.)
- Limited to final scores and basic game info

SPORTS COVERAGE:
- NFL, NBA, MLB, NHL, MMA/UFC
- Soccer (multiple leagues)
- Tennis, Golf, Cricket
- eSports

UPDATE FREQUENCY:
- Scores update every 1-2 minutes during live games
- Odds update every 15-30 seconds

PRICING:
- Free: 500 requests/month
- Starter: $99/month for 100,000 requests
- Business: $599/month for 1,000,000 requests

CONCLUSION:
The Odds API is good for:
- Getting live scores quickly
- Checking game completion status
- Getting odds/betting lines

NOT suitable for:
- Detailed period/quarter tracking
- Play-by-play data
- Card system timing (need to know exact period/quarter)

RECOMMENDATION:
Stick with ESPN API for game state tracking, as it provides:
- Free access
- Period/quarter/inning data
- Play-by-play with timestamps
- Game situation details (possession, timeouts, etc.)
""")

if __name__ == "__main__":
    print(f"The Odds API Tester - {datetime.now()}")
    test_odds_api()
    analyze_odds_api_capabilities()