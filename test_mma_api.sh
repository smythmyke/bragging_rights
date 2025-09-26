#!/bin/bash

echo "🥊 Testing MMA Data from ESPN API"
echo "=================================="
echo ""

# UFC 311 event ID
EVENT_ID="401720563"
URL="https://site.api.espn.com/apis/site/v2/sports/mma/ufc/fightcenter/$EVENT_ID"

echo "📡 Fetching from: $URL"
echo ""

# Fetch and parse JSON
curl -s "$URL" | python -c "
import json
import sys

data = json.load(sys.stdin)
cards = data.get('cards', [])

print(f'📋 Found {len(cards)} fight cards\\n')

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

        print(f'Fight #{fight_count}:')
        print(f'  🥊 {fighter1_name} ({fighter1_record}) vs {fighter2_name} ({fighter2_record})')
        print(f'  ⚖️  Weight Class: {weight_class}')

        if fighter1_id:
            print(f'  🖼️  Fighter 1 Image: https://a.espncdn.com/i/headshots/mma/players/full/{fighter1_id}.png')
        else:
            print(f'  🖼️  Fighter 1 Image: N/A')

        if fighter2_id:
            print(f'  🖼️  Fighter 2 Image: https://a.espncdn.com/i/headshots/mma/players/full/{fighter2_id}.png')
        else:
            print(f'  🖼️  Fighter 2 Image: N/A')

        print(f'  📍 Card Position: {\"Main Card\" if is_main_card else \"Prelims\"}')
        print(f'  📊 Fight Order: {fight_order}')
        print()

print(f'✅ Total fights processed: {fight_count}')
"