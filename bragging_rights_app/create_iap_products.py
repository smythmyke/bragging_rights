"""
Google Play Developer API - Create In-App Products
Prerequisites:
1. Enable Google Play Developer API in Google Cloud Console
2. Create a service account and download JSON key
3. Grant permissions to service account in Play Console
4. Install: pip install google-auth google-auth-oauthlib google-auth-httplib2 google-api-python-client
"""

import json
from googleapiclient.discovery import build
from google.oauth2 import service_account

# Configuration
PACKAGE_NAME = 'com.braggingrights.bragging_rights_app'  # Your app's package name
SERVICE_ACCOUNT_FILE = 'path/to/your/service-account-key.json'  # Download from Google Cloud Console

# In-app products to create
PRODUCTS = [
    {
        'sku': 'br_coins_250',
        'status': 'active',
        'purchaseType': 'consumable',
        'defaultPrice': {
            'priceMicros': '5000000',
            'currency': 'USD'
        },
        'listings': {
            'en-US': {
                'title': '250 BR Coins',
                'description': 'Get 250 BR Coins to place wagers and join pools'
            }
        }
    },
    {
        'sku': 'br_coins_500',
        'status': 'active', 
        'purchaseType': 'consumable',
        'defaultPrice': {
            'priceMicros': '10000000',
            'currency': 'USD'
        },
        'listings': {
            'en-US': {
                'title': '500 BR Coins + 50 Bonus',
                'description': 'Best value! Get 550 BR Coins total (500 + 50 bonus)'
            }
        }
    }
]

def create_iap_products():
    """Create in-app products using Google Play Developer API"""
    
    # Authenticate
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/androidpublisher']
    )
    
    # Build the service
    service = build('androidpublisher', 'v3', credentials=credentials)
    
    # Create each product
    for product in PRODUCTS:
        try:
            # Create the in-app product
            result = service.inappproducts().insert(
                packageName=PACKAGE_NAME,
                body=product
            ).execute()
            
            print(f"✅ Created product: {product['sku']}")
            print(f"   Title: {product['listings']['en-US']['title']}")
            print(f"   Price: ${int(product['defaultPrice']['priceMicros']) / 1000000:.2f}")
            
        except Exception as e:
            print(f"❌ Error creating {product['sku']}: {str(e)}")

if __name__ == '__main__':
    print("Creating in-app products for Bragging Rights...")
    print(f"Package: {PACKAGE_NAME}\n")
    
    # Check if service account file is configured
    if SERVICE_ACCOUNT_FILE == 'path/to/your/service-account-key.json':
        print("⚠️  Please update SERVICE_ACCOUNT_FILE with your service account key path")
        print("\nTo set up service account:")
        print("1. Go to Google Cloud Console: https://console.cloud.google.com")
        print("2. Create/select project linked to your Play Console")
        print("3. Enable Google Play Android Developer API")
        print("4. Create service account & download JSON key")
        print("5. In Play Console: Users & Permissions → Invite User")
        print("6. Add service account email with 'Manage products' permission")
    else:
        create_iap_products()