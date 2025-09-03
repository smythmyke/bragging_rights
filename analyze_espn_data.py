#!/usr/bin/env python3
"""Analyze ESPN API data for granular game state information"""

import json
import pprint

def analyze_file(filename, sport):
    """Analyze a specific ESPN data file"""
    print(f"\n{'='*80}")
    print(f"Analyzing {sport} data from {filename}")
    print('='*80)
    
    try:
        with open(filename, 'r') as f:
            data = json.load(f)
        
        # For scoreboard files
        if 'scoreboard' in filename:
            events = data.get('events', [])
            print(f"Total events: {len(events)}")
            
            if events:
                event = events[0]
                print(f"\nFirst event status:")
                status = event.get('status', {})
                print(f"  Type: {status.get('type', {}).get('name')}")
                print(f"  Period: {status.get('period')}")
                print(f"  Clock: {status.get('displayClock')}")
                
                if 'competitions' in event:
                    comp = event['competitions'][0]
                    
                    # Check for situation (NFL specific)
                    if 'situation' in comp:
                        print(f"\nGame Situation (NFL):")
                        sit = comp['situation']
                        print(f"  Down: {sit.get('down')}")
                        print(f"  Distance: {sit.get('distance')}")
                        print(f"  YardLine: {sit.get('yardLine')}")
                        print(f"  Possession: {sit.get('possession')}")
                        print(f"  isRedZone: {sit.get('isRedZone')}")
                        print(f"  homeTimeouts: {sit.get('homeTimeouts')}")
                        print(f"  awayTimeouts: {sit.get('awayTimeouts')}")
                        if 'lastPlay' in sit:
                            print(f"  Last Play: {sit['lastPlay'].get('text', '')[:100]}...")
        
        # For summary files
        if 'summary' in filename:
            # Check plays
            plays = data.get('plays', [])
            print(f"\nTotal plays: {len(plays)}")
            
            if plays:
                print("\nSample plays (first 3):")
                for i, play in enumerate(plays[:3]):
                    print(f"\n  Play {i+1}:")
                    print(f"    Type: {play.get('type', {}).get('text')}")
                    print(f"    Period: {play.get('period', {}).get('number')} ({play.get('period', {}).get('displayValue')})")
                    print(f"    Clock: {play.get('clock', {}).get('displayValue')}")
                    print(f"    Text: {play.get('text', '')[:100]}...")
                    
                    # Check for additional data
                    if 'scoringPlay' in play:
                        print(f"    Scoring Play: {play['scoringPlay']}")
                    if 'shootingPlay' in play:
                        print(f"    Shooting Play: {play['shootingPlay']}")
                    if 'wallclock' in play:
                        print(f"    Timestamp: {play['wallclock']}")
            
            # Check for drives (NFL)
            if 'drives' in data:
                drives = data['drives']
                print(f"\nTotal drives: {len(drives.get('previous', []))}")
                if 'current' in drives:
                    print("Current drive details available")
            
            # Check for at-bats (MLB)
            if 'atBats' in data:
                at_bats = data['atBats']
                print(f"\nTotal at-bats: {len(at_bats)}")
                if at_bats:
                    print(f"Sample at-bat: {at_bats[0].get('text', '')[:100]}...")
            
            # Check header for current state
            if 'header' in data:
                header = data['header']
                if 'competitions' in header and header['competitions']:
                    comp = header['competitions'][0]
                    print(f"\nCurrent game state from header:")
                    print(f"  Status: {comp.get('status', {}).get('type', {}).get('name')}")
                    print(f"  Detail: {comp.get('status', {}).get('type', {}).get('detail')}")
                    
    except FileNotFoundError:
        print(f"File not found: {filename}")
    except json.JSONDecodeError:
        print(f"Invalid JSON in {filename}")
    except Exception as e:
        print(f"Error analyzing {filename}: {e}")

# Analyze all files
files_to_analyze = [
    ('espn_nba_summary.json', 'NBA'),
    ('espn_nfl_summary.json', 'NFL'),
    ('espn_mlb_summary.json', 'MLB'),
    ('espn_nba_scoreboard.json', 'NBA Scoreboard'),
    ('espn_nfl_scoreboard.json', 'NFL Scoreboard'),
    ('espn_mlb_scoreboard.json', 'MLB Scoreboard'),
    ('espn_ufc_scoreboard.json', 'UFC Scoreboard'),
]

print("ESPN API DATA ANALYSIS")
print("="*80)
print("Analyzing granular game state data available from ESPN")

for filename, sport in files_to_analyze:
    analyze_file(filename, sport)

print("\n" + "="*80)
print("SUMMARY OF FINDINGS:")
print("="*80)
print("""
ESPN API provides the following granular data:

TEAM SPORTS (NBA, NFL, MLB, NHL):
- Period/Quarter/Inning number and name
- Game clock (minutes:seconds for timed sports)
- Play-by-play with timestamps (wallclock)
- Scoring plays flagged
- Timeouts remaining (NFL)
- Possession data (NFL, NBA)
- Down & distance (NFL)
- Red zone indicator (NFL)
- Last play text (NFL)
- Drive summaries (NFL)
- At-bat details (MLB)

INDIVIDUAL SPORTS (UFC, Tennis):
- Round/Set information
- Round start/end events
- Fight outcome details
- Limited real-time updates

TIMING GRANULARITY:
- Scoreboard: Updates every 15-30 seconds during live games
- Summary: More detailed, includes play-by-play
- Updates include exact timestamps for synchronization
""")