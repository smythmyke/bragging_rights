"""
Create ALL Bragging Rights In-App Products (BR Coins + Power Cards)
"""

import os
import json
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# Configuration
PACKAGE_NAME = 'com.braggingrights.bragging_rights_app'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']

# All products to create
PRODUCTS = [
    # BR COINS
    {
        'sku': 'br_coins_250',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '5000000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': '250 BR Coins',
                'description': 'Get 250 BR Coins to place wagers and join pools'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'br_coins_500',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '10000000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': '500 BR Coins + 50 Bonus',
                'description': 'Best value! Get 550 BR Coins total (500 + 50 bonus)'
            }
        },
        'defaultLanguage': 'en-US'
    },
    
    # DEFENSIVE CARDS
    {
        'sku': 'extra_life_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Extra Life Card',
                'description': 'Get back into an eliminated pool - your second chance at glory!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'eraser_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Eraser Card',
                'description': 'Turn one loss into a win - rewrite history in your favor!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'shield_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '1990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Shield Card',
                'description': 'Block one attack card from another player - defend your position!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'insurance_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '1990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Insurance Card',
                'description': 'Get 50% of your wager back if you lose - play it safe!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'mulligan_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '1990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Mulligan Card',
                'description': 'Change your pick before game starts - second thoughts allowed!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'time_freeze_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Time Freeze Card',
                'description': 'Extend deadline to make a pick by 15 minutes - never miss out!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    
    # OFFENSIVE CARDS
    {
        'sku': 'steal_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '4990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Steal Card',
                'description': 'Swap your loss with another player\'s win - ultimate revenge!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'sabotage_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Sabotage Card',
                'description': 'Force opponent to pick opposite team - chaos unleashed!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'curse_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Curse Card',
                'description': 'Give opponent -10% odds on their next pick - bad luck incoming!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'copycat_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Copycat Card',
                'description': 'Copy the pick of the current leader - follow the winner!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'chaos_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Chaos Card',
                'description': 'Randomize one opponent\'s pick - let fate decide!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'veto_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Veto Card',
                'description': 'Cancel another player\'s power card - not on my watch!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    
    # UTILITY CARDS
    {
        'sku': 'double_down_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Double Down Card',
                'description': 'Double your winnings if you win - high risk, high reward!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'crystal_ball_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Crystal Ball Card',
                'description': 'See what majority picked before you pick - wisdom of the crowd!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'lucky_charm_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Lucky Charm Card',
                'description': '+15% better odds on your next pick - fortune favors you!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'split_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Split Card',
                'description': 'Bet on both teams for guaranteed small win - hedge your bets!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'wildcard_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '9990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Wildcard',
                'description': 'Counts as any other card - ultimate flexibility! (Rare)'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'referee_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '4990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Referee Card',
                'description': 'Override one controversial call in your favor - be the ref!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    
    # SOCIAL CARDS
    {
        'sku': 'party_pooper_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Party Pooper Card',
                'description': 'Cancel all power cards in current game - level playing field!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'robin_hood_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Robin Hood Card',
                'description': 'Take 10% from leader, give to last place - share the wealth!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'amnesty_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '4990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Amnesty Card',
                'description': 'All eliminated players return to pool - everyone\'s back in!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'blackout_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Blackout Card',
                'description': 'Hide all picks until game starts - play in the dark!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'auction_card',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Auction Card',
                'description': 'Force highest bidder to switch teams - money talks!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    
    # CARD PACKS
    {
        'sku': 'starter_pack',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Starter Card Pack',
                'description': '3 random common cards - begin your collection!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'power_pack',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '4990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Power Card Pack',
                'description': '5 random cards with 1 guaranteed rare - boost your deck!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'ultimate_pack',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '9990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Ultimate Card Pack',
                'description': '10 random cards with 2 guaranteed epic - dominate the game!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'defensive_bundle',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '14990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Defensive Bundle',
                'description': 'Get all 6 defensive cards - ultimate protection!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'offensive_bundle',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '19990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Offensive Bundle',
                'description': 'Get all 6 offensive cards - maximum attack power!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'master_collection',
        'status': 'active',
        'purchaseType': 'managedUser',
        'defaultPrice': {'priceMicros': '49990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Master Collection',
                'description': 'Get ALL 22 power cards - complete domination!'
            }
        },
        'defaultLanguage': 'en-US'
    }
]

def authenticate():
    """Authenticate using OAuth 2.0"""
    creds = None
    
    # Token file stores the user's access and refresh tokens
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    
    # If there are no (valid) credentials available, let the user log in
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists('credentials.json'):
                print("ERROR: Missing credentials.json file!")
                return None
                
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
            
        # Save the credentials for the next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())
    
    return creds

def create_products():
    """Create in-app products"""
    creds = authenticate()
    if not creds:
        return
    
    # Build the service
    service = build('androidpublisher', 'v3', credentials=creds)
    
    print(f"\nCreating {len(PRODUCTS)} products for: {PACKAGE_NAME}\n")
    print("=" * 60)
    
    success_count = 0
    error_count = 0
    
    for product in PRODUCTS:
        try:
            # Create the product
            result = service.inappproducts().insert(
                packageName=PACKAGE_NAME,
                body=product
            ).execute()
            
            print(f"SUCCESS: Created {product['sku']}")
            print(f"         {product['listings']['en-US']['title']}")
            print(f"         Price: ${int(product['defaultPrice']['priceMicros']) / 1000000:.2f}")
            success_count += 1
            
        except Exception as e:
            error_msg = str(e)
            if 'already exists' in error_msg:
                print(f"EXISTS:  {product['sku']} already exists")
                
                # Try to update it instead
                try:
                    update_body = {
                        'status': product['status'],
                        'defaultPrice': product['defaultPrice'],
                        'listings': product['listings']
                    }
                    
                    result = service.inappproducts().update(
                        packageName=PACKAGE_NAME,
                        sku=product['sku'],
                        body=update_body
                    ).execute()
                    
                    print(f"         Updated successfully!")
                    success_count += 1
                    
                except Exception as update_error:
                    print(f"         Could not update: {update_error}")
                    error_count += 1
                    
            else:
                print(f"ERROR:   Could not create {product['sku']}")
                print(f"         {error_msg}")
                error_count += 1
        print()
    
    print("=" * 60)
    print(f"COMPLETE: {success_count} products created/updated successfully")
    if error_count > 0:
        print(f"          {error_count} products failed")
    print("=" * 60)

def list_products():
    """List existing products"""
    creds = authenticate()
    if not creds:
        return
    
    service = build('androidpublisher', 'v3', credentials=creds)
    
    try:
        result = service.inappproducts().list(
            packageName=PACKAGE_NAME
        ).execute()
        
        products = result.get('inappproduct', [])
        
        if products:
            print(f"\nExisting products for {PACKAGE_NAME}:\n")
            print("=" * 60)
            for product in products:
                sku = product.get('sku', 'Unknown SKU')
                status = product.get('status', 'Unknown')
                if 'listings' in product and 'en-US' in product['listings']:
                    title = product['listings']['en-US'].get('title', 'No title')
                    print(f"  {sku:<25} {status:<10} {title}")
                else:
                    print(f"  {sku:<25} {status}")
            print("=" * 60)
            print(f"Total: {len(products)} products")
        else:
            print(f"\nNo products found for {PACKAGE_NAME}")
            
    except Exception as e:
        print(f"ERROR: Could not list products: {e}")

if __name__ == '__main__':
    print("=" * 60)
    print("Bragging Rights - Bulk Product Creator")
    print("=" * 60)
    
    print("\nOptions:")
    print("1. Create/Update all products")
    print("2. List existing products")
    
    choice = input("\nEnter choice (1 or 2): ").strip()
    
    if choice == '1':
        create_products()
    elif choice == '2':
        list_products()
    else:
        print("Invalid choice!")