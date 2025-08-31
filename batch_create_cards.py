"""
Batch create all remaining Power Cards using batchUpdate API
"""

import os
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

PACKAGE_NAME = 'com.braggingrights.bragging_rights_app'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']

# All remaining power cards
REMAINING_CARDS = [
    # DEFENSIVE (remaining)
    {'sku': 'insurance_card', 'price': '1990000', 'title': 'Insurance Card', 
     'desc': 'Get 50% wager back if you lose - play safe!'},
    {'sku': 'mulligan_card', 'price': '1990000', 'title': 'Mulligan Card',
     'desc': 'Change pick before game starts!'},
    {'sku': 'time_freeze_card', 'price': '990000', 'title': 'Time Freeze Card',
     'desc': 'Extend deadline by 15 minutes!'},
    
    # OFFENSIVE (remaining)
    {'sku': 'sabotage_card', 'price': '3990000', 'title': 'Sabotage Card',
     'desc': 'Force opponent to opposite team!'},
    {'sku': 'curse_card', 'price': '2990000', 'title': 'Curse Card',
     'desc': 'Give opponent -10% odds!'},
    {'sku': 'copycat_card', 'price': '2990000', 'title': 'Copycat Card',
     'desc': 'Copy the leader\'s pick!'},
    {'sku': 'chaos_card', 'price': '2990000', 'title': 'Chaos Card',
     'desc': 'Randomize opponent\'s pick!'},
    {'sku': 'veto_card', 'price': '3990000', 'title': 'Veto Card',
     'desc': 'Cancel another power card!'},
    
    # UTILITY
    {'sku': 'double_down_card', 'price': '3990000', 'title': 'Double Down Card',
     'desc': 'Double winnings if you win!'},
    {'sku': 'crystal_ball_card', 'price': '2990000', 'title': 'Crystal Ball Card',
     'desc': 'See majority pick before you!'},
    {'sku': 'lucky_charm_card', 'price': '2990000', 'title': 'Lucky Charm Card',
     'desc': '+15% better odds on next pick!'},
    {'sku': 'split_card', 'price': '3990000', 'title': 'Split Card',
     'desc': 'Bet both teams for small win!'},
    {'sku': 'wildcard_card', 'price': '9990000', 'title': 'Wildcard',
     'desc': 'Acts as any other card! (Rare)'},
    {'sku': 'referee_card', 'price': '4990000', 'title': 'Referee Card',
     'desc': 'Override one controversial call!'},
    
    # SOCIAL
    {'sku': 'party_pooper_card', 'price': '3990000', 'title': 'Party Pooper Card',
     'desc': 'Cancel all power cards in game!'},
    {'sku': 'robin_hood_card', 'price': '2990000', 'title': 'Robin Hood Card',
     'desc': 'Take 10% from leader to last!'},
    {'sku': 'amnesty_card', 'price': '4990000', 'title': 'Amnesty Card',
     'desc': 'All eliminated return to pool!'},
    {'sku': 'blackout_card', 'price': '2990000', 'title': 'Blackout Card',
     'desc': 'Hide picks until game starts!'},
    {'sku': 'auction_card', 'price': '3990000', 'title': 'Auction Card',
     'desc': 'Highest bidder switches teams!'},
    
    # PACKS
    {'sku': 'power_pack', 'price': '4990000', 'title': 'Power Card Pack',
     'desc': '5 cards with 1 guaranteed rare!'},
    {'sku': 'ultimate_pack', 'price': '9990000', 'title': 'Ultimate Card Pack',
     'desc': '10 cards with 2 guaranteed epic!'},
    {'sku': 'defensive_bundle', 'price': '14990000', 'title': 'Defensive Bundle',
     'desc': 'All 6 defensive cards!'},
    {'sku': 'offensive_bundle', 'price': '19990000', 'title': 'Offensive Bundle',
     'desc': 'All 6 offensive cards!'},
    {'sku': 'master_collection', 'price': '49990000', 'title': 'Master Collection',
     'desc': 'ALL 22 power cards!'}
]

def main():
    # Authenticate
    creds = None
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
    
    if not creds:
        print("No valid credentials")
        return
    
    service = build('androidpublisher', 'v3', credentials=creds)
    
    print(f"Batch Creating {len(REMAINING_CARDS)} Power Cards\n")
    print("=" * 50)
    
    # Build requests for batch update
    requests = []
    for card in REMAINING_CARDS:
        requests.append({
            'inappproduct': {
                'packageName': PACKAGE_NAME,
                'sku': card['sku'],
                'status': 'active',
                'purchaseType': 'managedUser',
                'defaultPrice': {
                    'priceMicros': card['price'],
                    'currency': 'USD'
                },
                'listings': {
                    'en-US': {
                        'title': card['title'],
                        'description': card['desc']
                    }
                },
                'defaultLanguage': 'en-US'
            },
            'updateMask': 'status,defaultPrice,listings',
            'allowMissing': True
        })
    
    try:
        # Batch update all products at once
        body = {'requests': requests}
        
        result = service.inappproducts().batchUpdate(
            packageName=PACKAGE_NAME,
            body=body
        ).execute()
        
        # Process results
        products = result.get('inappproducts', [])
        print(f"Successfully processed {len(products)} products!\n")
        
        for product in products:
            sku = product.get('sku', 'Unknown')
            if 'defaultPrice' in product:
                price = int(product['defaultPrice']['priceMicros']) / 1000000
                print(f"+ {sku:<20} ${price:>6.2f}")
            else:
                print(f"+ {sku}")
        
    except Exception as e:
        print(f"Batch update failed, trying individual creates...\n")
        
        # Fallback to individual creates
        success = 0
        for card in REMAINING_CARDS:
            try:
                body = {
                    'packageName': PACKAGE_NAME,
                    'sku': card['sku'],
                    'status': 'active',
                    'purchaseType': 'managedUser',
                    'defaultPrice': {
                        'priceMicros': card['price'],
                        'currency': 'USD'
                    },
                    'listings': {
                        'en-US': {
                            'title': card['title'],
                            'description': card['desc']
                        }
                    },
                    'defaultLanguage': 'en-US'
                }
                
                service.inappproducts().insert(
                    packageName=PACKAGE_NAME,
                    body=body
                ).execute()
                
                print(f"+ {card['sku']:<20} ${int(card['price']) / 1000000:>6.2f}")
                success += 1
                
            except Exception as e2:
                if 'already exists' in str(e2):
                    print(f"= {card['sku']:<20} (exists)")
                else:
                    print(f"X {card['sku']:<20} (failed)")
        
        print(f"\nCreated {success} new products")
    
    print("=" * 50)
    print("Complete!")

if __name__ == '__main__':
    main()