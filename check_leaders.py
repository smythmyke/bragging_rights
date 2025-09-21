import json

data = json.load(open('falcons_panthers_data.json', encoding='utf-8'))
leaders = data.get('leaders', [])

print('Game Leaders Data Structure:')
print('=' * 50)

for team in leaders:
    print(f"\n{team['team']['displayName']}:")
    for leader in team.get('leaders', []):
        display_name = leader['displayName']
        if leader.get('leaders'):
            athlete = leader['leaders'][0]
            display_value = athlete.get('displayValue', 'No data')
            name = athlete.get('athlete', {}).get('displayName', 'Unknown')
            print(f"  {display_name}: {name}")
            print(f"    Stats: {display_value}")
        else:
            print(f"  {display_name}: No data")