import urllib.request
import json
from datetime import datetime

# Test ESPN API for fight results
url = "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard"

print("Checking ESPN API for fight result data structure")
print("=" * 60)

try:
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())

    events = data.get('events', [])

    # Find a completed event (if any)
    for event in events:
        event_name = event.get('name', 'Unknown')
        event_date = event.get('date', '')

        # Check first competition for status
        competitions = event.get('competitions', [])
        if competitions:
            first_comp = competitions[0]
            status = first_comp.get('status', {})
            status_type = status.get('type', {})

            print(f"\nEvent: {event_name}")
            print(f"Date: {event_date}")
            print(f"Status: {status_type.get('description', 'Unknown')}")
            print(f"Completed: {status_type.get('completed', False)}")
            print(f"State: {status_type.get('state', 'Unknown')}")

            # Check for winner information
            competitors = first_comp.get('competitors', [])
            if competitors and len(competitors) == 2:
                fighter1 = competitors[0]
                fighter2 = competitors[1]

                print(f"\nFight: {fighter1['athlete']['displayName']} vs {fighter2['athlete']['displayName']}")
                print(f"Fighter 1 winner: {fighter1.get('winner', False)}")
                print(f"Fighter 2 winner: {fighter2.get('winner', False)}")

                # Check for result details
                if 'result' in first_comp:
                    print(f"Result: {json.dumps(first_comp['result'], indent=2)}")

                # Check for situation (method, round, time)
                if 'situation' in first_comp:
                    situation = first_comp['situation']
                    print(f"\nSituation data:")
                    print(f"  Period (Round): {situation.get('period', 'N/A')}")
                    print(f"  Time: {situation.get('displayClock', 'N/A')}")

                # Check for notes (often contains method)
                if 'note' in first_comp:
                    print(f"Note: {first_comp['note']}")

            # Only show first 3 events for brevity
            if events.index(event) >= 2:
                break

    print("\n\nKEY FINDINGS FOR SETTLEMENT:")
    print("-" * 40)
    print("1. status.type.completed - Boolean indicating if fight is finished")
    print("2. competitors[].winner - Boolean indicating which fighter won")
    print("3. status.type.state - 'post' for completed, 'pre' for upcoming")
    print("4. situation.period - Round number when fight ended")
    print("5. note field - May contain method of victory")
    print("\nNeed to poll API periodically to check for updates")

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()