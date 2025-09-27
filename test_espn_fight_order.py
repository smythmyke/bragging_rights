import urllib.request
import json

# Get UFC event
url = "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard"

print("Checking ESPN Fight Order")
print("=" * 60)

try:
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())

    events = data.get('events', [])
    if not events:
        print("No events found")
        exit()

    event = events[0]
    event_id = event.get('id')
    event_name = event.get('name', '')

    print(f"Event: {event_name}")
    print(f"Event ID: {event_id}")
    print("")

    # Get competitions
    competitions = event.get('competitions', [])

    print(f"Total fights: {len(competitions)}")
    print("")
    print("ESPN Order (as returned by API):")
    print("-" * 40)

    for i, comp in enumerate(competitions):
        competitors = comp.get('competitors', [])
        if len(competitors) == 2:
            fighter1 = competitors[0].get('athlete', {}).get('displayName', 'TBD')
            fighter2 = competitors[1].get('athlete', {}).get('displayName', 'TBD')

            # Check order details
            order_details = comp.get('orderDetails', {})
            order = order_details.get('order', i)
            is_main_card = order_details.get('isMainCard', False)

            # Check if it's main/co-main
            is_main = i == len(competitions) - 1
            is_co_main = i == len(competitions) - 2

            card_position = "MAIN CARD" if is_main_card else "PRELIMS"
            if is_main:
                card_position = "MAIN EVENT"
            elif is_co_main and is_main_card:
                card_position = "CO-MAIN EVENT"

            print(f"Fight {i+1:2d}: {fighter1:20s} vs {fighter2:20s} | Order: {order:2d} | {card_position}")

    print("")
    print("IMPORTANT NOTES:")
    print("1. ESPN returns fights with the MAIN EVENT LAST (highest index)")
    print("2. The 'order' field in orderDetails might indicate display order")
    print("3. Main card fights have isMainCard=true in orderDetails")
    print("4. We should display MAIN EVENT FIRST, then CO-MAIN, then others")

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()