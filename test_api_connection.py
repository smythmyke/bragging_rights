"""
Test API connection and list any existing products
"""

import os
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

PACKAGE_NAME = 'com.braggingrights.bragging_rights_app'
SCOPES = ['https://www.googleapis.com/auth/androidpublisher']

def test_connection():
    """Test connection and list products"""
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
    
    # Try to list products
    try:
        print(f"Testing connection for package: {PACKAGE_NAME}")
        result = service.inappproducts().list(
            packageName=PACKAGE_NAME
        ).execute()
        
        products = result.get('inappproduct', [])
        print(f"Success! Found {len(products)} products")
        
        if products:
            for p in products:
                print(f"  - {p.get('sku', 'Unknown')}")
    except Exception as e:
        print(f"Error: {e}")
        
        # Try without package name to see what happens
        print("\nTrying to get app details...")
        try:
            # Get app details
            edit_request = service.edits().insert(
                packageName=PACKAGE_NAME,
                body={}
            ).execute()
            
            edit_id = edit_request['id']
            print(f"Successfully created edit: {edit_id}")
            
            # Delete the edit
            service.edits().delete(
                packageName=PACKAGE_NAME,
                editId=edit_id
            ).execute()
            
        except Exception as e2:
            print(f"Edit error: {e2}")

if __name__ == '__main__':
    test_connection()