# 💰 Wallet Data Migration Guide

## Overview

This guide explains how to migrate wallet data after fixing the wallet sync issues between the More tab and Bets tab.

### What Was Fixed?

The app had critical bugs where:
1. **SettlementService** was writing wallet balances to the wrong Firestore path (`wallets/{uid}` instead of `users/{uid}/wallet/current`)
2. **WalletService** was creating transactions with type `'payout'` but only looking for type `'winnings'`
3. **Wallet stats** showed only 30-day history while bet stats showed lifetime history

### What This Migration Does

The migration script fixes existing data by:
1. ✅ Migrating wallet balances from `wallets/{uid}` → `users/{uid}/wallet/current`
2. ✅ Updating transaction types from `'payout'` → `'winnings'`
3. ✅ Creating audit trail with migration transaction records
4. ✅ Marking old data as migrated (not deleted for safety)

---

## Prerequisites

Before running the migration:

1. **Deploy code fixes first:**
   - ✅ `settlement_service.dart` - Fixed Firestore paths
   - ✅ `wallet_service.dart` - Fixed transaction types and time filters
   - ✅ Rebuild and deploy the Flutter app

2. **Install Node.js dependencies:**
   ```bash
   cd scripts
   npm install firebase-admin
   ```

3. **Verify Firebase Admin SDK credentials:**
   - Ensure `bragging-rights-c2aa0-firebase-adminsdk-kl46s-8c50f833f5.json` exists in project root
   - If missing, download from Firebase Console → Project Settings → Service Accounts

4. **Backup your Firestore database:**
   - Go to Firebase Console → Firestore Database → Import/Export
   - Export to Cloud Storage bucket
   - **CRITICAL:** Don't skip this step!

---

## Migration Process

### Step 1: Test with Dry Run

First, run the migration in dry-run mode to preview changes:

```bash
node scripts/migrate_wallet_data.js --dry-run
```

**What to check:**
- Number of users to be processed
- Number of wallets to be patched
- Number of transactions to be updated
- Any errors or warnings

**Example output:**
```
╔════════════════════════════════════════════════════════════╗
║     💰 WALLET DATA MIGRATION SCRIPT                       ║
╚════════════════════════════════════════════════════════════╝

Mode: 🔍 DRY RUN (no changes will be made)
Target: All users

Found 45 users with old wallet data

📂 Processing user: abc123xyz...
   ✅ Old wallet found: {"balance": 250, "totalWinnings": 500}
   ✅ New wallet found: balance=100

   📊 Migration Analysis:
      Old wallet balance: 250 BR
      Old total winnings: 500 BR
      New wallet balance: 100 BR
      New lifetime earned: 300 BR

   🔧 Migration Plan:
      Add 250 BR to balance
      Add 500 BR to lifetimeEarned

   🔍 [DRY RUN] Would update wallet but skipping...

...

╔════════════════════════════════════════════════════════════╗
║     📊 MIGRATION SUMMARY                                   ║
╚════════════════════════════════════════════════════════════╝

Mode: DRY RUN
Users processed: 45
Wallets patched: 32
Wallet patch failures: 0
Transactions updated: 156
Transaction update failures: 0
Total errors: 0

🔍 This was a DRY RUN. No changes were made.
   Run without --dry-run to apply changes.
```

---

### Step 2: Test with Single User

Test the migration on a single user first:

```bash
# Replace USER_ID with an actual user ID from your database
node scripts/migrate_wallet_data.js --user-id=abc123xyz456
```

**After running:**
1. Open the app and log in as that user
2. Check the More tab wallet balance
3. Verify it matches expected amount
4. Check Bets tab stats
5. Verify transactions history shows migration record

---

### Step 3: Run Full Migration

Once you've verified the single user migration works:

```bash
node scripts/migrate_wallet_data.js
```

**This will:**
- Migrate ALL users with old wallet data
- Update ALL transactions with type 'payout'
- Create migration transaction records
- Mark old wallets as migrated

**Monitor the output for:**
- ✅ Success messages for each user
- ❌ Any errors (will be summarized at end)
- 📊 Final statistics

---

### Step 4: Verify Migration

After migration completes:

1. **Check Firebase Console:**
   - Go to Firestore Database
   - Browse `users/{uid}/wallet/current` docs
   - Verify `balance` and `lifetimeEarned` fields are correct
   - Check for `migratedAt` timestamp

2. **Check in App:**
   - Log in as different users
   - More tab → Check wallet balance is correct
   - More tab → Check Won/Lost stats match Bets tab
   - Bets tab → Verify profit calculations are correct

3. **Check Transaction History:**
   - Navigate to Transactions screen in app
   - Look for "Wallet migration" transaction record
   - Verify amounts are correct

4. **Spot Check Users:**
   - Identify users who had pending bets during migration
   - Verify their balances are accurate
   - Check that settled bets still show correct payouts

---

## Migration Script Options

### Command Line Arguments

```bash
node scripts/migrate_wallet_data.js [OPTIONS]
```

**Available options:**

| Option | Description | Example |
|--------|-------------|---------|
| `--dry-run` | Preview changes without applying them | `--dry-run` |
| `--user-id=<uid>` | Migrate only specific user (for testing) | `--user-id=abc123` |

**Examples:**

```bash
# Dry run for all users
node scripts/migrate_wallet_data.js --dry-run

# Dry run for single user
node scripts/migrate_wallet_data.js --dry-run --user-id=abc123

# Live migration for single user (testing)
node scripts/migrate_wallet_data.js --user-id=abc123

# Live migration for all users (production)
node scripts/migrate_wallet_data.js
```

---

## What Gets Migrated?

### Wallet Balances

**Old Path:**
```
wallets/{userId}
├── balance: 250
├── totalWinnings: 500
└── totalLosses: 200
```

**New Path:**
```
users/{userId}/wallet/current
├── balance: 100 + 250 = 350  ← Incremented
├── lifetimeEarned: 300 + 500 = 800  ← Incremented
├── lifetimeWagered: 700  ← Unchanged
├── migratedAt: <timestamp>  ← Added
└── migratedFrom: "wallets_collection"  ← Added
```

**Old wallet marked as migrated:**
```
wallets/{userId}
├── balance: 250  ← Preserved (not deleted)
├── totalWinnings: 500
├── migrated: true  ← Added
├── migratedAt: <timestamp>  ← Added
└── migratedTo: "users/{userId}/wallet/current"  ← Added
```

### Transaction Types

**Before:**
```
transactions/{txId}
├── type: "payout"  ← Old type
├── amount: 150
└── description: "Winnings from Chiefs vs Bills"
```

**After:**
```
transactions/{txId}
├── type: "winnings"  ← Updated
├── originalType: "payout"  ← Preserved
├── amount: 150
├── description: "Winnings from Chiefs vs Bills"
├── updatedAt: <timestamp>  ← Added
└── updatedBy: "migration_script"  ← Added
```

### Migration Transaction Record

A new transaction is created for each migrated user:

```
transactions/{newTxId}
├── userId: "abc123"
├── type: "migration"
├── amount: 250
├── description: "Wallet migration from old collection..."
├── balanceBefore: 100
├── balanceAfter: 350
├── timestamp: <timestamp>
├── status: "completed"
└── metadata:
    ├── oldBalance: 250
    ├── oldTotalWinnings: 500
    ├── migratedBalance: 250
    └── migratedLifetimeEarned: 500
```

---

## Troubleshooting

### Issue: "No old wallet found"

**Meaning:** User has no data in `wallets/{uid}` collection

**Action:** ✅ This is normal - user wasn't affected by the bug. Skip.

---

### Issue: "No new wallet found"

**Meaning:** User doesn't have `users/{uid}/wallet/current` document

**Action:** ⚠️ User needs wallet initialization first:
1. User should log into the app
2. App will create wallet on first login
3. Then run migration for that user

---

### Issue: Migration shows negative balances

**Meaning:** User may have pending bets or recent transactions

**Action:**
1. Check user's active bets
2. Verify transaction history
3. Calculate expected balance manually
4. If incorrect, contact user and manually adjust

---

### Issue: Wallet stats still don't match between tabs

**Possible causes:**
1. App code wasn't redeployed before migration
2. Flutter app cache not cleared
3. User needs to force refresh app

**Solutions:**
1. Verify deployed app has all 4 code fixes
2. Have user log out and log back in
3. Clear app cache/data
4. Reinstall app if needed

---

### Issue: Transaction type update failed

**Error message:** "Batch write limit exceeded"

**Action:** Script automatically handles this by batching in groups of 500. If it still fails:
1. Check Firestore quota limits
2. Run migration during off-peak hours
3. Contact Firebase support if quota exceeded

---

## Rollback (Emergency)

If migration causes issues, you can restore from backup:

### Option 1: Firestore Import (Recommended)

1. Go to Firebase Console → Firestore Database → Import/Export
2. Click "Import data"
3. Select the backup created before migration
4. Import to your database
5. Redeploy the OLD code (before fixes)

### Option 2: Manual Rollback (Per User)

Run this command to rollback a single user:

```javascript
// Run in Firebase Console → Firestore → Run query
const userId = 'USER_ID_HERE';
const oldWalletRef = db.collection('wallets').doc(userId);
const newWalletRef = db.collection('users').doc(userId).collection('wallet').doc('current');

// Get migration metadata
const newWallet = await newWalletRef.get();
const migrationData = newWallet.data();

// Reverse migration
await newWalletRef.update({
  balance: admin.firestore.FieldValue.increment(-migrationData.migratedBalance),
  lifetimeEarned: admin.firestore.FieldValue.increment(-migrationData.migratedLifetimeEarned),
  migratedAt: admin.firestore.FieldValue.delete(),
  migratedFrom: admin.firestore.FieldValue.delete(),
});

// Unmark old wallet
await oldWalletRef.update({
  migrated: false,
  migratedAt: admin.firestore.FieldValue.delete(),
  migratedTo: admin.firestore.FieldValue.delete(),
});
```

---

## Post-Migration Cleanup (Optional)

After verifying migration was successful for 1-2 weeks:

### Delete Old Wallet Collection

```javascript
// WARNING: This permanently deletes data!
// Only run after 100% sure migration was successful

const walletsCollection = db.collection('wallets');
const snapshot = await walletsCollection.where('migrated', '==', true).get();

const batch = db.batch();
snapshot.docs.forEach(doc => {
  batch.delete(doc.ref);
});

await batch.commit();
console.log(`Deleted ${snapshot.size} old wallet documents`);
```

---

## Support

If you encounter issues during migration:

1. **Check script output** - Detailed error messages are provided
2. **Review Firestore logs** - Check Firebase Console for any database errors
3. **Verify code deployment** - Ensure all 4 code fixes are deployed
4. **Test with single user** - Always test with `--user-id` flag first
5. **Document issues** - Save error logs for debugging

---

## Summary Checklist

Before running migration:
- [ ] Deploy all 4 code fixes to production
- [ ] Backup Firestore database
- [ ] Install Node.js and firebase-admin
- [ ] Verify service account credentials
- [ ] Run dry-run mode first
- [ ] Test with single user
- [ ] Verify single user in app

After running migration:
- [ ] Check Firebase Console for migrated data
- [ ] Test multiple user accounts in app
- [ ] Verify More tab wallet stats match Bets tab
- [ ] Check transaction history shows migration records
- [ ] Monitor app for 24-48 hours
- [ ] Consider cleanup after 1-2 weeks

---

## Technical Details

### Script Logic

1. **Wallet Migration:**
   - Queries `wallets/{uid}` collection
   - For each user, checks if new wallet exists
   - Calculates balance difference
   - Uses Firestore transaction for atomic update
   - Creates migration transaction record
   - Marks old wallet as migrated

2. **Transaction Update:**
   - Queries transactions with type 'payout'
   - Batch updates in groups of 500
   - Changes type to 'winnings'
   - Preserves original type in 'originalType' field
   - Adds audit fields (updatedAt, updatedBy)

3. **Safety Features:**
   - Dry-run mode prevents accidental changes
   - Single-user testing reduces risk
   - Old data preserved (not deleted)
   - Migration markers added for tracking
   - Detailed logging for debugging
   - Firestore transactions ensure atomicity

---

## Migration Timeline (Recommended)

1. **Day 1:** Deploy code fixes, run dry-run
2. **Day 2:** Test single user migration
3. **Day 3:** Run full migration during off-peak hours
4. **Day 4-7:** Monitor app, verify user reports
5. **Week 2+:** Consider cleanup if stable

---

## Questions?

For migration support, contact:
- Developer: [Your contact info]
- Firebase Support: https://firebase.google.com/support

---

Last Updated: 2025-01-13
Script Version: 1.0.0
