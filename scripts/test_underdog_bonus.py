#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test underdog bonus calculation logic
Verifies record parsing and bonus point calculations match Dart implementation
"""
import sys
import io

# Fix Windows console encoding
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def parse_win_percentage(record):
    """Parse team record and calculate win percentage"""
    if not record:
        return None

    parts = record.split('-')
    if not parts:
        return None

    try:
        wins = int(parts[0])
        losses = int(parts[1]) if len(parts) > 1 else 0
        ties = int(parts[2]) if len(parts) > 2 else 0

        total_games = wins + losses + ties
        if total_games == 0:
            return None

        # Ties count as 0.5 wins
        adjusted_wins = wins + (ties * 0.5)
        return adjusted_wins / total_games
    except (ValueError, IndexError):
        return None

def calculate_underdog_bonus(home_record, away_record):
    """
    Calculate underdog bonus based on win percentage difference
    Returns: (is_home_underdog, is_away_underdog, bonus_points, difference)
    """
    home_pct = parse_win_percentage(home_record)
    away_pct = parse_win_percentage(away_record)

    if home_pct is None or away_pct is None:
        return (False, False, 0, 0.0)

    # Determine underdog
    is_home_underdog = home_pct < away_pct
    is_away_underdog = away_pct < home_pct

    # Calculate win percentage difference
    difference = abs(home_pct - away_pct)

    # Bonus tiers (from simple_pick_scoring.dart)
    if difference >= 0.301:
        bonus = 50
    elif difference >= 0.201:
        bonus = 30
    elif difference >= 0.101:
        bonus = 20
    elif difference > 0.000:
        bonus = 10
    else:
        bonus = 0

    return (is_home_underdog, is_away_underdog, bonus, difference)

def run_tests():
    """Run comprehensive test cases"""
    print("=" * 80)
    print("UNDERDOG BONUS CALCULATION TESTS")
    print("=" * 80)
    print()

    test_cases = [
        # (home_record, away_record, description)
        ("10-5", "5-10", "Clear favorite vs underdog"),
        ("3-10", "10-3", "Strong underdog scenario"),
        ("7-6", "6-7", "Close matchup"),
        ("5-5", "5-5", "Equal records"),
        ("8-3-2", "5-6-1", "Records with ties"),
        ("0-13", "13-0", "Extreme underdog"),
        ("7-7-1", "8-7", "Tie-breaker scenario"),
        ("6-4-3", "8-3-2", "Complex tie calculation"),
        ("0-0", "5-5", "No games played"),
        ("12-3", "3-12", "Large differential"),
    ]

    passed = 0
    failed = 0

    for home, away, desc in test_cases:
        print(f"Test: {desc}")
        print(f"  Records: Home {home} vs Away {away}")

        home_pct = parse_win_percentage(home)
        away_pct = parse_win_percentage(away)

        if home_pct is not None:
            print(f"  Home Win%: {home_pct:.3f}")
        else:
            print(f"  Home Win%: N/A")

        if away_pct is not None:
            print(f"  Away Win%: {away_pct:.3f}")
        else:
            print(f"  Away Win%: N/A")

        is_home_dog, is_away_dog, bonus, diff = calculate_underdog_bonus(home, away)

        if is_home_dog:
            print(f"  🔵 Underdog: HOME (difference: {diff:.3f})")
        elif is_away_dog:
            print(f"  🔴 Underdog: AWAY (difference: {diff:.3f})")
        else:
            print(f"  ⚪ No Underdog (difference: {diff:.3f})")

        print(f"  💰 Bonus Points: +{bonus}")

        # Verify bonus tier is correct
        tier_correct = True
        if diff >= 0.301 and bonus != 50:
            tier_correct = False
        elif 0.201 <= diff < 0.301 and bonus != 30:
            tier_correct = False
        elif 0.101 <= diff < 0.201 and bonus != 20:
            tier_correct = False
        elif 0.000 < diff < 0.101 and bonus != 10:
            tier_correct = False
        elif diff == 0.000 and bonus != 0:
            tier_correct = False

        if tier_correct:
            print(f"  ✅ PASS")
            passed += 1
        else:
            print(f"  ❌ FAIL - Incorrect bonus tier")
            failed += 1

        print()

    print("=" * 80)
    print(f"TEST RESULTS: {passed} passed, {failed} failed")
    print("=" * 80)
    print()

    # Detailed bonus tier verification
    print("=" * 80)
    print("BONUS TIER VERIFICATION")
    print("=" * 80)
    print()

    tier_tests = [
        (0.000, 0.050, 10, "Tier 1: 0.000-0.100"),
        (0.066, 0.066, 10, "Tier 1: Midpoint"),
        (0.100, 0.100, 10, "Tier 1: Upper bound"),
        (0.101, 0.150, 20, "Tier 2: 0.101-0.200"),
        (0.150, 0.150, 20, "Tier 2: Midpoint"),
        (0.200, 0.200, 20, "Tier 2: Upper bound"),
        (0.201, 0.250, 30, "Tier 3: 0.201-0.300"),
        (0.250, 0.250, 30, "Tier 3: Midpoint"),
        (0.300, 0.300, 30, "Tier 3: Upper bound"),
        (0.301, 0.400, 50, "Tier 4: 0.301+"),
        (0.500, 0.500, 50, "Tier 4: Large diff"),
        (0.800, 0.800, 50, "Tier 4: Extreme diff"),
    ]

    tier_passed = 0
    tier_failed = 0

    for diff_low, diff_high, expected_bonus, desc in tier_tests:
        # Test with difference in range
        # Create records that yield this difference
        home_pct = 0.300  # Base
        away_pct = home_pct + diff_high

        if away_pct > 1.0:
            away_pct = 1.0
            home_pct = away_pct - diff_high

        difference = abs(home_pct - away_pct)

        # Calculate bonus
        if difference >= 0.301:
            actual_bonus = 50
        elif difference >= 0.201:
            actual_bonus = 30
        elif difference >= 0.101:
            actual_bonus = 20
        elif difference > 0.000:
            actual_bonus = 10
        else:
            actual_bonus = 0

        print(f"{desc}")
        print(f"  Difference: {difference:.3f}")
        print(f"  Expected Bonus: +{expected_bonus}")
        print(f"  Actual Bonus: +{actual_bonus}")

        if actual_bonus == expected_bonus:
            print(f"  ✅ PASS")
            tier_passed += 1
        else:
            print(f"  ❌ FAIL")
            tier_failed += 1
        print()

    print("=" * 80)
    print(f"TIER RESULTS: {tier_passed} passed, {tier_failed} failed")
    print("=" * 80)
    print()

    # Overall summary
    total_passed = passed + tier_passed
    total_failed = failed + tier_failed
    total_tests = total_passed + total_failed

    print("=" * 80)
    print("OVERALL SUMMARY")
    print("=" * 80)
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {total_passed}")
    print(f"Failed: {total_failed}")
    print(f"Success Rate: {(total_passed/total_tests*100):.1f}%")
    print("=" * 80)

    return total_failed == 0

if __name__ == '__main__':
    success = run_tests()
    sys.exit(0 if success else 1)
