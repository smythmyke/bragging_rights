"""
Create In-App Products using OAuth 2.0 (Your Google Account)
This works immediately without waiting 24 hours
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

# Products to create
PRODUCTS = [
    {
        'sku': 'br_coins_250',
        'status': 'active',
        'purchaseType': 'managedProduct',
        'defaultPrice': {
            'priceMicros': '5000000',
            'currency': 'USD'
        },
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
        'purchaseType': 'managedProduct',
        'defaultPrice': {
            'priceMicros': '10000000',
            'currency': 'USD'
        },
        'listings': {
            'en-US': {
                'title': '500 BR Coins + 50 Bonus',
                'description': 'Best value! Get 550 BR Coins total (500 + 50 bonus)'
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
            # You need to create OAuth 2.0 credentials in Google Cloud Console first
            # Download the credentials.json file
            if not os.path.exists('credentials.json'):
                print("ERROR: Missing credentials.json file!")
                print("\nTo create OAuth credentials:")
                print("1. Go to https://console.cloud.google.com")
                print("2. Select your project")
                print("3. Go to APIs & Services -> Credentials")
                print("4. Create Credentials -> OAuth client ID")
                print("5. Application type: Desktop app")
                print("6. Download JSON -> Save as 'credentials.json' in this folder")
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
    
    print(f"\nCreating products for: {PACKAGE_NAME}\n")
    
    for product in PRODUCTS:
        try:
            # Create the product
            result = service.inappproducts().insert(
                packageName=PACKAGE_NAME,
                body=product
            ).execute()
            
            print(f"SUCCESS: Created {product['sku']}")
            print(f"   Title: {product['listings']['en-US']['title']}")
            print(f"   Price: ${int(product['defaultPrice']['priceMicros']) / 1000000:.2f}")
            print()
            
        except Exception as e:
            error_msg = str(e)
            if 'already exists' in error_msg:
                print(f"WARNING: {product['sku']} already exists")
                
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
                    
                    print(f"   Updated successfully!")
                    
                except Exception as update_error:
                    print(f"   Could not update: {update_error}")
                    
            else:
                print(f"ERROR: Could not create {product['sku']}: {error_msg}")
        print()

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
            for product in products:
                print(f"  - {product.get('sku', 'Unknown SKU')}")
                if 'listings' in product:
                    for lang, listing in product['listings'].items():
                        print(f"    {lang}: {listing.get('title', 'No title')}")
                print()
        else:
            print(f"\nNo products found for {PACKAGE_NAME}")
            
    except Exception as e:
        print(f"ERROR: Could not list products: {e}")

if __name__ == '__main__':
    print("=" * 60)
    print("Google Play In-App Products Manager")
    print("=" * 60)
    
    print("\nOptions:")
    print("1. Create/Update products")
    print("2. List existing products")
    
    choice = input("\nEnter choice (1 or 2): ").strip()
    
    if choice == '1':
        create_products()
    elif choice == '2':
        list_products()
    else:
        print("Invalid choice!")