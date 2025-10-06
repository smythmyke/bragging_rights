#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Update admin tier override for testing free vs premium experiences
Usage: python update_admin_tier.py [free|premium|actual]
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

def set_tier(tier_mode):
    """Update admin override for tier testing"""
    db = firestore.client()
    user_ref = db.collection('users').document(USER_ID)

    # Get current user data
    user_doc = user_ref.get()
    if not user_doc.exists:
        print(f"❌ User {USER_ID} not found!")
        return False

    current_data = user_doc.to_dict()
    email = current_data.get('email', 'N/A')

    print(f"👤 User: {email}")
    print(f"📧 Setting tier mode: {tier_mode.upper()}\n")

    # Determine override values based on mode
    if tier_mode == 'free':
        override = {
            'enabled': True,
            'forceFreeTier': True,
            'forcePremiumTier': False,
        }
        message = "🆓 FREE TIER - Simple picks only, no odds"
    elif tier_mode == 'premium':
        override = {
            'enabled': True,
            'forceFreeTier': False,
            'forcePremiumTier': True,
        }
        message = "💎 PREMIUM TIER - With odds and premium pools"
    elif tier_mode == 'actual':
        override = {
            'enabled': False,
            'forceFreeTier': False,
            'forcePremiumTier': False,
        }
        actual_status = current_data.get('isPremium', False)
        message = f"⚙️ ACTUAL STATUS - Using isPremium={actual_status}"
    else:
        print(f"❌ Invalid tier mode: {tier_mode}")
        print("Valid options: free, premium, actual")
        return False

    # Update Firestore
    user_ref.update({
        'adminOverride': override
    })

    print("✅ Tier updated successfully!\n")
    print("=" * 60)
    print(message)
    print("=" * 60)
    print()
    print("📱 Next Steps:")
    print("1. Restart the Bragging Rights app")
    print("2. App will now show the selected tier experience")
    print()
    print("🔄 To change tier, run:")
    print("   python scripts/update_admin_tier.py free")
    print("   python scripts/update_admin_tier.py premium")
    print("   python scripts/update_admin_tier.py actual")

    return True

def get_current_status():
    """Display current admin override status"""
    db = firestore.client()
    user_ref = db.collection('users').document(USER_ID)

    user_doc = user_ref.get()
    if not user_doc.exists:
        print(f"❌ User {USER_ID} not found!")
        return

    data = user_doc.to_dict()
    email = data.get('email', 'N/A')
    override = data.get('adminOverride', {})
    actual_premium = data.get('isPremium', False)

    print("=" * 60)
    print("CURRENT TIER STATUS")
    print("=" * 60)
    print(f"User: {email}")
    print()
    print("Admin Override:")
    print(f"  Enabled: {override.get('enabled', False)}")
    print(f"  Force Free Tier: {override.get('forceFreeTier', False)}")
    print(f"  Force Premium Tier: {override.get('forcePremiumTier', False)}")
    print()
    print(f"Actual Status:")
    print(f"  isPremium: {actual_premium}")
    print()

    # Determine effective tier
    if override.get('enabled', False):
        if override.get('forceFreeTier', False):
            effective = "🆓 FREE TIER (Forced)"
        elif override.get('forcePremiumTier', False):
            effective = "💎 PREMIUM TIER (Forced)"
        else:
            effective = "⚙️ ACTUAL STATUS (Override enabled but no tier forced)"
    else:
        effective = f"⚙️ ACTUAL STATUS ({'Premium' if actual_premium else 'Free'})"

    print(f"Effective Tier: {effective}")
    print("=" * 60)

def main():
    init_firebase()

    if len(sys.argv) < 2:
        # No arguments - show current status
        get_current_status()
        print()
        print("Usage: python update_admin_tier.py [free|premium|actual|status]")
        return

    mode = sys.argv[1].lower()

    if mode == 'status':
        get_current_status()
    elif mode in ['free', 'premium', 'actual']:
        set_tier(mode)
    else:
        print(f"❌ Invalid mode: {mode}")
        print("Valid options: free, premium, actual, status")
        sys.exit(1)

if __name__ == '__main__':
    main()
