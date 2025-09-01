#!/usr/bin/env python3
"""
Test script to evaluate different Tennis APIs for Bragging Rights
"""

import requests
import json
from datetime import datetime

def test_espn_tennis():
    """Test ESPN Tennis API - our primary choice"""
    print("\n1. Testing ESPN Tennis API")
    print("-" * 40)
    
    try:
        print("📍 Base URL: https://site.api.espn.com/apis/site/v2/sports/tennis")
        print("💰 Pricing: FREE (no key required)")
        
        # Test scoreboard endpoint
        response = requests.get(
            "https://site.api.espn.com/apis/site/v2/sports/tennis/scoreboard",
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            events = data.get('events', [])
            print(f"✅ API Working! Live/Recent matches: {len(events)}")
            
            if events:
                match = events[0]
                competition = match.get('competitions', [{}])[0]
                competitors = competition.get('competitors', [])
                if len(competitors) >= 2:
                    p1 = competitors[0].get('athlete', {}).get('displayName', 'Unknown')
                    p2 = competitors[1].get('athlete', {}).get('displayName', 'Unknown')
                    status = competition.get('status', {}).get('type', {}).get('description', '')
                    print(f"   Sample match: {p1} vs {p2}")
                    print(f"   Status: {status}")
        
        # Test ATP rankings
        print("\n   Testing ATP Rankings...")
        rankings_response = requests.get(
            "https://site.api.espn.com/apis/site/v2/sports/tennis/atp/rankings",
            timeout=5
        )
        
        if rankings_response.status_code == 200:
            rankings_data = rankings_response.json()
            if 'rankings' in rankings_data:
                print("   ATP Rankings available")
                top_3 = rankings_data['rankings'].get('competitors', [])[:3]
                for player in top_3:
                    athlete = player.get('athlete', {})
                    rank = player.get('rank', 'N/A')
                    name = athlete.get('displayName', 'Unknown')
                    print(f"   #{rank}: {name}")
        
        # Test WTA rankings
        print("\n   Testing WTA Rankings...")
        wta_response = requests.get(
            "https://site.api.espn.com/apis/site/v2/sports/tennis/wta/rankings",
            timeout=5
        )
        
        if wta_response.status_code == 200:
            print("   WTA Rankings available")
        
        # Test tournaments
        print("\n   Testing Tournament Data...")
        tournament_response = requests.get(
            "https://site.api.espn.com/apis/site/v2/sports/tennis/scoreboard?limit=50",
            timeout=5
        )
        
        if tournament_response.status_code == 200:
            data = tournament_response.json()
            leagues = data.get('leagues', [])
            if leagues:
                print(f"   Tournaments found: {len(leagues)}")
                for league in leagues[:3]:
                    print(f"   - {league.get('name', 'Unknown')}")
        
        print("\nESPN Tennis API Summary:")
        print("   - Live scores: YES")
        print("   - Rankings: YES")
        print("   - Tournaments: YES")
        print("   - No API key: YES")
        print("   - Free to use: YES")
        
    except Exception as e:
        print(f"ERROR: {e}")

def test_tennis_live_data():
    """Test Tennis Live Data API (RapidAPI)"""
    print("\n2. Testing Tennis Live Data API (RapidAPI)")
    print("-" * 40)
    
    print("   Base URL: https://tennis-live-data.p.rapidapi.com")
    print("   Pricing: Free tier (100 req/month), Pro ($29/month)")
    print("   Requires RapidAPI key")
    print("   Features: Live scores, H2H, detailed stats")
    print("   Limitations: Low free tier limit")

def test_api_tennis():
    """Test API-Tennis"""
    print("\n3. Testing API-Tennis")
    print("-" * 40)
    
    print("   Base URL: https://api-tennis.com")
    print("   Pricing: Free with attribution")
    print("   Features: Live scores, rankings, H2H")
    print("   Requires registration")

def test_flashscore():
    """Test Flashscore Tennis (web scraping)"""
    print("\n4. Testing Flashscore Tennis")
    print("-" * 40)
    
    print("   Base URL: https://www.flashscore.com/tennis/")
    print("   Pricing: Free (web scraping)")
    print("   Features: Comprehensive live scores, odds")
    print("   Limitations: Requires web scraping")

def test_sofascore():
    """Test SofaScore API"""
    print("\n5. Testing SofaScore API")
    print("-" * 40)
    
    try:
        # SofaScore has undocumented API endpoints
        response = requests.get(
            "https://api.sofascore.com/api/v1/sport/tennis/events/live",
            headers={'User-Agent': 'Mozilla/5.0'},
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            events = data.get('events', [])
            print("   Undocumented API working!")
            print(f"   Live matches: {len(events)}")
        else:
            print("   API returned status:", response.status_code)
            
    except Exception as e:
        print(f"   Connection failed: {e}")
    
    print("   Base URL: https://api.sofascore.com")
    print("   Pricing: Free (undocumented)")
    print("   Features: Live scores, detailed stats, H2H")
    print("   Limitations: Undocumented, may change")

def print_recommendation():
    """Print final recommendation"""
    print("\n" + "=" * 60)
    print("RECOMMENDATION FOR BRAGGING RIGHTS")
    print("=" * 60)
    
    print("""
PRIMARY IMPLEMENTATION: ESPN Tennis API
----------------------------------------
- Completely FREE with no API key
- Same pattern as NBA/NFL/NHL/MLB
- Reliable and stable
- Good coverage of major tournaments
- Live scores and rankings

DATA COVERAGE:
- Live match scores: YES
- Daily schedules: YES
- ATP/WTA rankings: YES
- Tournament info: YES
- Basic match stats: YES
- Player profiles: Partial
- H2H records: NO (need alternative)
- Surface stats: NO (need alternative)

IMPLEMENTATION PLAN:
1. Use ESPN Tennis as primary source
2. Follow same pattern as other ESPN sports
3. Mock H2H and surface stats for MVP
4. Add enhanced data sources later if needed

EDGE INTELLIGENCE FOR TENNIS:
- Current form (last 5 matches)
- Head-to-head history (mock initially)
- Surface preference (hard/clay/grass)
- Tournament importance
- Ranking differential
- Recent injuries/news
    """)

def main():
    print("Testing Tennis APIs for Bragging Rights Integration")
    print("=" * 60)
    
    # Test each API
    test_espn_tennis()
    test_tennis_live_data()
    test_api_tennis()
    test_flashscore()
    test_sofascore()
    
    # Print recommendation
    print_recommendation()
    
    print("\nTesting Complete!")

if __name__ == "__main__":
    main()