#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Initialize achievements collection in Firestore with predefined achievements
"""
import json
import os
import sys
import io
from datetime import datetime

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

def init_firebase():
    """Initialize Firebase Admin SDK"""
    if not os.path.exists(SERVICE_ACCOUNT_PATH):
        print(f"ERROR: Service account key not found at: {SERVICE_ACCOUNT_PATH}")
        sys.exit(1)

    cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK initialized\n")

def get_achievements():
    """Define all achievements"""
    return [
        # Pool Achievements
        {
            "id": "first_pool",
            "name": "First Pool Entry",
            "description": "Join your first pool",
            "category": "pools",
            "tier": "bronze",
            "brReward": 50,
            "iconName": "pool_circle",
            "requirements": {
                "type": "pool_join_count",
                "count": 1
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "pool_regular",
            "name": "Pool Regular",
            "description": "Join 10 pools",
            "category": "pools",
            "tier": "silver",
            "brReward": 100,
            "iconName": "pool_star",
            "requirements": {
                "type": "pool_join_count",
                "count": 10
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "pool_veteran",
            "name": "Pool Veteran",
            "description": "Join 50 pools",
            "category": "pools",
            "tier": "gold",
            "brReward": 250,
            "iconName": "pool_gold",
            "requirements": {
                "type": "pool_join_count",
                "count": 50
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "pool_legend",
            "name": "Pool Legend",
            "description": "Join 100 pools",
            "category": "pools",
            "tier": "platinum",
            "brReward": 500,
            "iconName": "pool_crown",
            "requirements": {
                "type": "pool_join_count",
                "count": 100
            },
            "isActive": True,
            "isRepeatable": False,
        },

        # Picks Achievements
        {
            "id": "first_win",
            "name": "First Win",
            "description": "Win your first pool",
            "category": "picks",
            "tier": "bronze",
            "brReward": 100,
            "iconName": "trophy_bronze",
            "requirements": {
                "type": "pool_win_count",
                "count": 1
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "winning_streak_3",
            "name": "Hot Streak",
            "description": "Win 3 pools in a row",
            "category": "picks",
            "tier": "silver",
            "brReward": 200,
            "iconName": "fire",
            "requirements": {
                "type": "win_streak",
                "count": 3
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "winning_streak_5",
            "name": "On Fire",
            "description": "Win 5 pools in a row",
            "category": "picks",
            "tier": "gold",
            "brReward": 400,
            "iconName": "fire_gold",
            "requirements": {
                "type": "win_streak",
                "count": 5
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "perfect_week",
            "name": "Perfect Week",
            "description": "Win all pools in a week",
            "category": "picks",
            "tier": "gold",
            "brReward": 500,
            "iconName": "star_gold",
            "requirements": {
                "type": "perfect_week",
                "days": 7
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "underdog_king",
            "name": "Underdog King",
            "description": "Win 10 pools with underdog picks",
            "category": "picks",
            "tier": "silver",
            "brReward": 300,
            "iconName": "underdog_crown",
            "requirements": {
                "type": "underdog_win_count",
                "count": 10
            },
            "isActive": True,
            "isRepeatable": False,
        },

        # Streak Achievements
        {
            "id": "login_streak_3",
            "name": "Engaged Fan",
            "description": "Login 3 days in a row",
            "category": "streaks",
            "tier": "bronze",
            "brReward": 50,
            "iconName": "calendar_bronze",
            "requirements": {
                "type": "login_streak",
                "count": 3
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "login_streak_7",
            "name": "Weekly Warrior",
            "description": "Login 7 days in a row",
            "category": "streaks",
            "tier": "silver",
            "brReward": 150,
            "iconName": "calendar_silver",
            "requirements": {
                "type": "login_streak",
                "count": 7
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "login_streak_30",
            "name": "Monthly Master",
            "description": "Login 30 days in a row",
            "category": "streaks",
            "tier": "gold",
            "brReward": 500,
            "iconName": "calendar_gold",
            "requirements": {
                "type": "login_streak",
                "count": 30
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "login_streak_100",
            "name": "Century Club",
            "description": "Login 100 days in a row",
            "category": "streaks",
            "tier": "platinum",
            "brReward": 1000,
            "iconName": "calendar_platinum",
            "requirements": {
                "type": "login_streak",
                "count": 100
            },
            "isActive": True,
            "isRepeatable": False,
        },

        # Social Achievements
        {
            "id": "first_referral",
            "name": "Influencer",
            "description": "Refer your first friend",
            "category": "social",
            "tier": "bronze",
            "brReward": 200,
            "iconName": "person_add",
            "requirements": {
                "type": "referral_count",
                "count": 1
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "referral_master",
            "name": "Referral Master",
            "description": "Refer 5 friends",
            "category": "social",
            "tier": "silver",
            "brReward": 500,
            "iconName": "people",
            "requirements": {
                "type": "referral_count",
                "count": 5
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "pool_creator",
            "name": "Pool Creator",
            "description": "Create your first private pool",
            "category": "social",
            "tier": "bronze",
            "brReward": 100,
            "iconName": "create",
            "requirements": {
                "type": "pool_create_count",
                "count": 1
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "tournament_host",
            "name": "Tournament Host",
            "description": "Host a pool with 10+ players",
            "category": "social",
            "tier": "silver",
            "brReward": 300,
            "iconName": "group",
            "requirements": {
                "type": "large_pool_create",
                "minPlayers": 10
            },
            "isActive": True,
            "isRepeatable": False,
        },

        # Special Achievements
        {
            "id": "early_adopter",
            "name": "Early Adopter",
            "description": "Join during beta",
            "category": "special",
            "tier": "platinum",
            "brReward": 1000,
            "iconName": "rocket",
            "requirements": {
                "type": "early_signup",
                "beforeDate": "2025-03-01"
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "first_week",
            "name": "First Week",
            "description": "Complete 5 pools in first week",
            "category": "special",
            "tier": "silver",
            "brReward": 250,
            "iconName": "speed",
            "requirements": {
                "type": "first_week_pools",
                "count": 5,
                "days": 7
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "high_roller",
            "name": "High Roller",
            "description": "Join a pool with 100+ BR buy-in",
            "category": "special",
            "tier": "gold",
            "brReward": 200,
            "iconName": "diamond",
            "requirements": {
                "type": "high_stakes_join",
                "minBuyIn": 100
            },
            "isActive": True,
            "isRepeatable": False,
        },
        {
            "id": "comeback_kid",
            "name": "Comeback Kid",
            "description": "Win after being in last place",
            "category": "special",
            "tier": "silver",
            "brReward": 200,
            "iconName": "trending_up",
            "requirements": {
                "type": "comeback_win",
                "fromPosition": "last"
            },
            "isActive": True,
            "isRepeatable": False,
        },
    ]

def create_achievements():
    """Create achievements in Firestore"""
    db = firestore.client()
    achievements_ref = db.collection('achievements')

    achievements = get_achievements()

    print("=" * 80)
    print("INITIALIZING ACHIEVEMENTS COLLECTION")
    print("=" * 80)
    print()

    created_count = 0
    updated_count = 0

    for achievement in achievements:
        achievement_id = achievement['id']

        # Add timestamps
        achievement['createdAt'] = firestore.SERVER_TIMESTAMP
        achievement['updatedAt'] = firestore.SERVER_TIMESTAMP

        # Check if achievement already exists
        doc_ref = achievements_ref.document(achievement_id)
        doc = doc_ref.get()

        if doc.exists:
            # Update existing achievement
            doc_ref.update(achievement)
            print(f"📝 Updated: {achievement['name']} ({achievement['tier']})")
            updated_count += 1
        else:
            # Create new achievement
            doc_ref.set(achievement)
            print(f"✅ Created: {achievement['name']} ({achievement['tier']}) - {achievement['brReward']} BR")
            created_count += 1

    print()
    print("=" * 80)
    print(f"✅ ACHIEVEMENTS INITIALIZED")
    print("=" * 80)
    print(f"Created: {created_count}")
    print(f"Updated: {updated_count}")
    print(f"Total: {len(achievements)}")
    print()
    print("📊 Breakdown by Category:")

    categories = {}
    for achievement in achievements:
        cat = achievement['category']
        categories[cat] = categories.get(cat, 0) + 1

    for category, count in categories.items():
        print(f"  {category}: {count}")

    print()
    print("💎 Breakdown by Tier:")

    tiers = {}
    for achievement in achievements:
        tier = achievement['tier']
        tiers[tier] = tiers.get(tier, 0) + 1

    for tier, count in tiers.items():
        print(f"  {tier}: {count}")

    print()
    print("💰 Total BR Available:")
    total_br = sum(a['brReward'] for a in achievements)
    print(f"  {total_br} BR across all achievements")
    print()

def main():
    init_firebase()
    create_achievements()

if __name__ == '__main__':
    main()
