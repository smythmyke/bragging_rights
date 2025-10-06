#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Set up admin override system for user smythmyke
"""
import json
import os
import sys
import io

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

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

USER_ID = 'JLl6AoOXHHUhIIW4t7xWDyqWsPm2'  # smythmyke@gmail.com

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"ERROR: Service account key not found at: {SERVICE_ACCOUNT_PATH}")
        sys.exit(1)

    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK initialized\n")

def setup_admin_override(user_id):
    """Add admin override fields to user"""
    db = firestore.client()
    user_ref = db.collection('users').document(user_id)

    # Get current user data
    user_doc = user_ref.get()
    if not user_doc.exists:
        print(f"❌ User {user_id} not found!")
        return False

    current_data = user_doc.to_dict()
    email = current_data.get('email', 'N/A')

    print(f"🔧 Setting up admin override for: {email}")
    print(f"   User ID: {user_id}\n")

    # Admin override fields
    admin_fields = {
        'isAdmin': True,
        'adminOverride': {
            'enabled': False,  # Start disabled, user can toggle in app
            'forceFreeTier': False,
            'forcePremiumTier': False,
        },
        # Initialize freemium fields if missing
        'brBalance': current_data.get('brBalance', 1000),  # Give 1000 BR to start
        'totalBrEarned': current_data.get('totalBrEarned', 1000),
        'totalBrSpent': current_data.get('totalBrSpent', 0),
        'loginStreak': current_data.get('loginStreak', 0),
        'longestLoginStreak': current_data.get('longestLoginStreak', 0),
        'lastLoginDate': current_data.get('lastLoginDate', None),
        'lastDailyBonus': current_data.get('lastDailyBonus', None),
        'referralCode': current_data.get('referralCode', None),
        'referredBy': current_data.get('referredBy', None),
        'adsWatchedToday': current_data.get('adsWatchedToday', 0),
        'lastAdWatchDate': current_data.get('lastAdWatchDate', None),
    }

    # Update user
    user_ref.update(admin_fields)

    print("✅ Admin override system added successfully!\n")
    print("--- Updated Fields ---")
    print(f"isAdmin: True")
    print(f"adminOverride.enabled: False (toggle in app to activate)")
    print(f"adminOverride.forceFreeTier: False")
    print(f"adminOverride.forcePremiumTier: False")
    print(f"brBalance: {admin_fields['brBalance']} (starting balance)")
    print(f"\n--- How to Use ---")
    print("1. In the app, go to Settings → Admin Controls")
    print("2. Toggle 'Enable Admin Override'")
    print("3. Choose tier:")
    print("   - Force Free Tier: See app as free user (no odds)")
    print("   - Force Premium Tier: See app as premium user (with odds)")
    print("   - Both OFF: Use actual isPremium status")

    return True

def main():
    init_firebase()

    print("=" * 80)
    print("ADMIN OVERRIDE SETUP")
    print("=" * 80)
    print()

    success = setup_admin_override(USER_ID)

    if success:
        print("\n" + "=" * 80)
        print("✅ SETUP COMPLETE")
        print("=" * 80)
    else:
        print("\n" + "=" * 80)
        print("❌ SETUP FAILED")
        print("=" * 80)

if __name__ == '__main__':
    main()
