"""
Add Power Cards products (skipping existing ones)
"""

import os
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

PACKAGE_NAME = 'com.braggingrights.bragging_rights_app'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']

# Power cards only (since you already have BR coins)
POWER_CARDS = [
    # DEFENSIVE CARDS
    {
        'sku': 'extra_life_card',
        'status': 'active',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Extra Life Card',
                'description': 'Get back into an eliminated pool - second chance!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'eraser_card',
        'status': 'active',
        'defaultPrice': {'priceMicros': '3990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Eraser Card',
                'description': 'Turn one loss into a win - rewrite history!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    {
        'sku': 'shield_card', 
        'status': 'active',
        'defaultPrice': {'priceMicros': '1990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Shield Card',
                'description': 'Block attack cards - defend your position!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    # OFFENSIVE CARDS
    {
        'sku': 'steal_card',
        'status': 'active',
        'defaultPrice': {'priceMicros': '4990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Steal Card', 
                'description': 'Swap your loss with another win - revenge!'
            }
        },
        'defaultLanguage': 'en-US'
    },
    # CARD PACKS
    {
        'sku': 'starter_pack',
        'status': 'active',
        'defaultPrice': {'priceMicros': '2990000', 'currency': 'USD'},
        'listings': {
            'en-US': {
                'title': 'Starter Card Pack',
                'description': '3 random cards - begin your collection!'
            }
        },
        'defaultLanguage': 'en-US'
    }
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
    
    print(f"Adding Power Cards for {PACKAGE_NAME}\n")
    print("=" * 50)
    
    for card in POWER_CARDS:
        try:
            # Create the product with packageName
            body = {
                'packageName': PACKAGE_NAME,
                'sku': card['sku'],
                'status': card['status'],
                'purchaseType': 'managedUser',
                'defaultPrice': card['defaultPrice'],
                'listings': card['listings'],
                'defaultLanguage': card['defaultLanguage']
            }
            
            result = service.inappproducts().insert(
                packageName=PACKAGE_NAME,
                body=body
            ).execute()
            
            print(f"SUCCESS: {card['sku']}")
            print(f"  {card['listings']['en-US']['title']}")
            print(f"  ${int(card['defaultPrice']['priceMicros']) / 1000000:.2f}\n")
            
        except Exception as e:
            if 'already exists' in str(e):
                print(f"EXISTS: {card['sku']}\n")
            else:
                print(f"ERROR: {card['sku']}")
                print(f"  {str(e)[:100]}\n")
    
    print("=" * 50)
    print("Complete!")

if __name__ == '__main__':
    main()