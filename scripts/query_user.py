#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Query Firestore for user 'smythmyke' and display their data
"""
import json
import os
import sys
import io

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Add firebase-admin to path if needed
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("ERROR: firebase-admin not installed")
    print("Install with: pip install firebase-admin")
    sys.exit(1)

# Path to service account key
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
SERVICE_ACCOUNT_PATH = os.path.join(PROJECT_ROOT, 'service-account-key.json')

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"ERROR: Service account key not found at: {SERVICE_ACCOUNT_PATH}")
        sys.exit(1)

    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK initialized\n")

def find_user_by_username(username):
    """Find user by username field"""
    db = firestore.client()
    users_ref = db.collection('users')

    # Try exact match first
    query = users_ref.where('username', '==', username).limit(1)
    docs = query.stream()

    results = []
    for doc in docs:
        results.append({
            'id': doc.id,
            'data': doc.to_dict()
        })

    return results

def find_user_by_email(email):
    """Find user by email field"""
    db = firestore.client()
    users_ref = db.collection('users')

    query = users_ref.where('email', '==', email).limit(1)
    docs = query.stream()

    results = []
    for doc in docs:
        results.append({
            'id': doc.id,
            'data': doc.to_dict()
        })

    return results

def search_all_users_containing(search_term):
    """Get all users and filter locally (Firestore doesn't support LIKE queries)"""
    db = firestore.client()
    users_ref = db.collection('users')

    # Get all users (limit to reasonable number)
    docs = users_ref.limit(100).stream()

    results = []
    search_lower = search_term.lower()

    for doc in docs:
        data = doc.to_dict()
        username = data.get('username', '').lower()
        email = data.get('email', '').lower()

        if search_lower in username or search_lower in email:
            results.append({
                'id': doc.id,
                'data': data
            })

    return results

def display_user(user_data):
    """Display user data in readable format"""
    print("=" * 80)
    print(f"USER ID: {user_data['id']}")
    print("=" * 80)

    data = user_data['data']

    # Key fields
    print(f"\nUsername: {data.get('username', 'N/A')}")
    print(f"Email: {data.get('email', 'N/A')}")
    print(f"Display Name: {data.get('displayName', 'N/A')}")

    # Premium status
    print(f"\n--- Premium Status ---")
    print(f"isPremium: {data.get('isPremium', False)}")
    print(f"subscriptionType: {data.get('subscriptionType', 'None')}")

    # BR Currency
    print(f"\n--- BR Currency ---")
    print(f"brBalance: {data.get('brBalance', 0)}")
    print(f"totalBrEarned: {data.get('totalBrEarned', 0)}")
    print(f"totalBrSpent: {data.get('totalBrSpent', 0)}")

    # Streak
    print(f"\n--- Login Streak ---")
    print(f"loginStreak: {data.get('loginStreak', 0)}")
    print(f"longestLoginStreak: {data.get('longestLoginStreak', 0)}")
    print(f"lastLoginDate: {data.get('lastLoginDate', 'N/A')}")

    # Admin fields
    print(f"\n--- Admin Fields ---")
    print(f"isAdmin: {data.get('isAdmin', False)}")
    admin_override = data.get('adminOverride', {})
    if admin_override:
        print(f"adminOverride.enabled: {admin_override.get('enabled', False)}")
        print(f"adminOverride.forceFreeTier: {admin_override.get('forceFreeTier', False)}")
        print(f"adminOverride.forcePremiumTier: {admin_override.get('forcePremiumTier', False)}")
    else:
        print("adminOverride: Not set")

    # Full JSON
    print(f"\n--- Full JSON ---")
    print(json.dumps(data, indent=2, default=str))
    print("=" * 80)

def main():
    init_firebase()

    search_term = 'smythmyke'

    print(f"🔍 Searching for user: '{search_term}'\n")

    # Try username search
    print("Searching by username...")
    results = find_user_by_username(search_term)

    if not results:
        # Try email search
        print("No results. Searching by email...")
        results = find_user_by_email(search_term)

    if not results:
        # Try partial match search
        print("No results. Searching all users for partial match...")
        results = search_all_users_containing(search_term)

    if not results:
        print(f"\n❌ No users found matching '{search_term}'")
        print("\nTrying to list first 10 users to help you find the right one...")

        db = firestore.client()
        docs = db.collection('users').limit(10).stream()

        print("\n--- First 10 Users ---")
        for doc in docs:
            data = doc.to_dict()
            print(f"ID: {doc.id}")
            print(f"  Username: {data.get('username', 'N/A')}")
            print(f"  Email: {data.get('email', 'N/A')}")
            print()

        return

    print(f"\n✅ Found {len(results)} user(s):\n")

    for user in results:
        display_user(user)

if __name__ == '__main__':
    main()
