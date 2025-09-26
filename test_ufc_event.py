import json
import urllib.request

# UFC Fight Night event
event_id = "600055226"
url = f"https://site.api.espn.com/apis/site/v2/sports/mma/ufc/fightcenter/{event_id}"

print(f"Testing UFC Fight Night: Ulberg vs. Reyes (ID: {event_id})")
print("=" * 60)

try:
    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read())

    cards = data.get('cards', [])
    print(f"Found {len(cards)} fight cards\n")

    fight_count = 0
    fights_with_weight_class = 0
    fights_with_images = 0

    for card in cards:
        competitions = card.get('competitions', [])

        for comp in competitions:
            fight_count += 1

            # Debug: Print the entire type field
            type_info = comp.get('type', {})
            print(f"\nFight #{fight_count} - Type field: {type_info}")

            # Extract weight class
            weight_class = (type_info.get('text') or
                           type_info.get('abbreviation') or
                           comp.get('note') or
                           'TBD')

            if weight_class != 'TBD':
                fights_with_weight_class += 1

            # Extract fighters
            competitors = comp.get('competitors', [])
            if len(competitors) != 2:
                print(f"  WARNING: Expected 2 competitors, got {len(competitors)}")
                continue

            fighter1 = competitors[0].get('athlete', {})
            fighter2 = competitors[1].get('athlete', {})

            fighter1_name = fighter1.get('displayName', 'TBD')
            fighter2_name = fighter2.get('displayName', 'TBD')

            fighter1_id = str(fighter1.get('id', ''))
            fighter2_id = str(fighter2.get('id', ''))

            if fighter1_id and fighter2_id:
                fights_with_images += 1

            fighter1_record = competitors[0].get('record', '')
            fighter2_record = competitors[1].get('record', '')

            print(f"\nFight #{fight_count}:")
            print(f"  Matchup: {fighter1_name} vs {fighter2_name}")
            print(f"  Records: {fighter1_record} vs {fighter2_record}")
            print(f"  Weight Class: \"{weight_class}\"")
            print(f"  Fighter IDs: {fighter1_id} vs {fighter2_id}")

            if fighter1_id:
                print(f"  Fighter 1 Image URL: https://a.espncdn.com/i/headshots/mma/players/full/{fighter1_id}.png")
            else:
                print(f"  Fighter 1 Image URL: N/A (no ID)")

            if fighter2_id:
                print(f"  Fighter 2 Image URL: https://a.espncdn.com/i/headshots/mma/players/full/{fighter2_id}.png")
            else:
                print(f"  Fighter 2 Image URL: N/A (no ID)")

    print("\n" + "=" * 60)
    print(f"Summary:")
    print(f"  Total fights: {fight_count}")
    print(f"  Fights with weight class: {fights_with_weight_class}")
    print(f"  Fights with both fighter images: {fights_with_images}")

except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()