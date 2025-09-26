import json
import urllib.request

# UFC 311 event ID
event_id = "401720563"
url = f"https://site.api.espn.com/apis/site/v2/sports/mma/ufc/fightcenter/{event_id}"

print(f"Testing ESPN API for UFC event: {event_id}")
print("=" * 50)

try:
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())

    cards = data.get('cards', [])
    print(f"Found {len(cards)} fight cards\n")

    fight_count = 0

    for card in cards:
        competitions = card.get('competitions', [])

        for comp in competitions:
            fight_count += 1

            # Extract weight class
            weight_class = (comp.get('type', {}).get('text') or
                           comp.get('type', {}).get('abbreviation') or
                           comp.get('note') or
                           'TBD')

            # Extract fighters
            competitors = comp.get('competitors', [])
            if len(competitors) != 2:
                continue

            fighter1 = competitors[0].get('athlete', {})
            fighter2 = competitors[1].get('athlete', {})

            fighter1_name = fighter1.get('displayName', 'TBD')
            fighter2_name = fighter2.get('displayName', 'TBD')

            fighter1_id = str(fighter1.get('id', ''))
            fighter2_id = str(fighter2.get('id', ''))

            fighter1_record = competitors[0].get('record', '')
            fighter2_record = competitors[1].get('record', '')

            is_main_card = comp.get('orderDetails', {}).get('isMainCard', False)
            fight_order = comp.get('orderDetails', {}).get('order', 999)

            print(f"Fight #{fight_count}:")
            print(f"  {fighter1_name} ({fighter1_record}) vs {fighter2_name} ({fighter2_record})")
            print(f"  Weight Class: {weight_class}")

            if fighter1_id:
                print(f"  Fighter 1 Image: https://a.espncdn.com/i/headshots/mma/players/full/{fighter1_id}.png")

            if fighter2_id:
                print(f"  Fighter 2 Image: https://a.espncdn.com/i/headshots/mma/players/full/{fighter2_id}.png")

            print(f"  Card Position: {'Main Card' if is_main_card else 'Prelims'}")
            print(f"  Fight Order: {fight_order}")
            print()

    print(f"\nTotal fights processed: {fight_count}")

except Exception as e:
    print(f"Error: {e}")