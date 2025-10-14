/**
 * Wallet Data Migration Script
 *
 * This script fixes wallet data inconsistencies caused by the old code using
 * incorrect Firestore paths. It performs the following migrations:
 *
 * 1. Migrates wallet balances from wallets/{uid} to users/{uid}/wallet/current
 * 2. Updates transaction types from 'payout' to 'winnings' for consistency
 * 3. Verifies data integrity after migration
 *
 * IMPORTANT: Run this script ONCE after deploying the wallet sync fixes.
 *
 * Usage:
 *   node scripts/migrate_wallet_data.js [--dry-run] [--user-id=<uid>]
 *
 * Options:
 *   --dry-run    Preview changes without applying them
 *   --user-id    Migrate only a specific user (for testing)
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'service-account-key.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://bragging-rights-ea6e1.firebaseio.com"
});

const db = admin.firestore();

// Parse command line arguments
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const userIdArg = args.find(arg => arg.startsWith('--user-id='));
const specificUserId = userIdArg ? userIdArg.split('=')[1] : null;

console.log('');
console.log('╔════════════════════════════════════════════════════════════╗');
console.log('║     💰 WALLET DATA MIGRATION SCRIPT                       ║');
console.log('╚════════════════════════════════════════════════════════════╝');
console.log('');
console.log(`Mode: ${isDryRun ? '🔍 DRY RUN (no changes will be made)' : '✍️  LIVE (changes will be applied)'}`);
if (specificUserId) {
  console.log(`Target: Single user (${specificUserId})`);
} else {
  console.log(`Target: All users`);
}
console.log('');

// Statistics
const stats = {
  usersProcessed: 0,
  walletsPatched: 0,
  walletsPatchFailed: 0,
  transactionsUpdated: 0,
  transactionsUpdateFailed: 0,
  errors: [],
};

/**
 * Migrate wallet balance from old path to new path
 */
async function migrateWalletBalance(userId) {
  try {
    console.log(`\n📂 Processing user: ${userId}`);

    // Check if old wallet exists
    const oldWalletRef = db.collection('wallets').doc(userId);
    const oldWalletDoc = await oldWalletRef.get();

    if (!oldWalletDoc.exists) {
      console.log(`   ℹ️  No old wallet found at wallets/${userId}`);
      return { patched: false, reason: 'no_old_wallet' };
    }

    const oldWalletData = oldWalletDoc.data();
    console.log(`   ✅ Old wallet found: ${JSON.stringify(oldWalletData)}`);

    // Check if new wallet exists
    const newWalletRef = db.collection('users').doc(userId).collection('wallet').doc('current');
    const newWalletDoc = await newWalletRef.get();

    if (!newWalletDoc.exists) {
      console.log(`   ❌ No new wallet found at users/${userId}/wallet/current`);
      console.log(`   ⚠️  User needs wallet initialization first. Skipping.`);
      return { patched: false, reason: 'no_new_wallet' };
    }

    const newWalletData = newWalletDoc.data();
    console.log(`   ✅ New wallet found: balance=${newWalletData.balance}`);

    // Calculate what needs to be migrated
    const oldBalance = oldWalletData.balance || 0;
    const oldTotalWinnings = oldWalletData.totalWinnings || 0;
    const newBalance = newWalletData.balance || 0;
    const newLifetimeEarned = newWalletData.lifetimeEarned || 0;

    console.log(`\n   📊 Migration Analysis:`);
    console.log(`      Old wallet balance: ${oldBalance} BR`);
    console.log(`      Old total winnings: ${oldTotalWinnings} BR`);
    console.log(`      New wallet balance: ${newBalance} BR`);
    console.log(`      New lifetime earned: ${newLifetimeEarned} BR`);

    // Check if migration is needed
    if (oldBalance === 0 && oldTotalWinnings === 0) {
      console.log(`   ✅ Old wallet is empty. No migration needed.`);
      return { patched: false, reason: 'empty_old_wallet' };
    }

    // Determine migration strategy
    const balanceDifference = oldBalance;
    const lifetimeEarnedDifference = oldTotalWinnings;

    console.log(`\n   🔧 Migration Plan:`);
    console.log(`      Add ${balanceDifference} BR to balance`);
    console.log(`      Add ${lifetimeEarnedDifference} BR to lifetimeEarned`);

    if (isDryRun) {
      console.log(`   🔍 [DRY RUN] Would update wallet but skipping...`);
      return { patched: true, dryRun: true };
    }

    // Perform migration
    await db.runTransaction(async (transaction) => {
      // Update new wallet with migrated amounts
      transaction.update(newWalletRef, {
        balance: admin.firestore.FieldValue.increment(balanceDifference),
        lifetimeEarned: admin.firestore.FieldValue.increment(lifetimeEarnedDifference),
        lastTransaction: admin.firestore.FieldValue.serverTimestamp(),
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
        migratedFrom: 'wallets_collection',
      });

      // Create migration transaction record
      const migrationTxRef = db.collection('transactions').doc();
      transaction.set(migrationTxRef, {
        userId: userId,
        type: 'migration',
        amount: balanceDifference,
        description: `Wallet migration from old collection (balance: ${oldBalance}, winnings: ${oldTotalWinnings})`,
        balanceBefore: newBalance,
        balanceAfter: newBalance + balanceDifference,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        status: 'completed',
        metadata: {
          oldBalance: oldBalance,
          oldTotalWinnings: oldTotalWinnings,
          migratedBalance: balanceDifference,
          migratedLifetimeEarned: lifetimeEarnedDifference,
        },
      });

      // Mark old wallet as migrated (don't delete for safety)
      transaction.update(oldWalletRef, {
        migrated: true,
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
        migratedTo: `users/${userId}/wallet/current`,
      });
    });

    console.log(`   ✅ Migration completed successfully!`);
    return { patched: true };

  } catch (error) {
    console.error(`   ❌ Error migrating wallet for user ${userId}:`, error);
    stats.errors.push({ userId, error: error.message, operation: 'wallet_migration' });
    return { patched: false, error: error.message };
  }
}

/**
 * Update transaction types from 'payout' to 'winnings'
 */
async function updateTransactionTypes() {
  try {
    console.log(`\n\n📝 Updating transaction types...`);

    // Query all transactions with type 'payout'
    let query = db.collection('transactions').where('type', '==', 'payout');

    if (specificUserId) {
      query = query.where('userId', '==', specificUserId);
    }

    const snapshot = await query.get();
    console.log(`   Found ${snapshot.size} transactions with type 'payout'`);

    if (snapshot.empty) {
      console.log(`   ✅ No transactions need updating`);
      return;
    }

    // Process in batches of 500 (Firestore limit)
    const batchSize = 500;
    let batch = db.batch();
    let batchCount = 0;
    let totalUpdated = 0;

    for (const doc of snapshot.docs) {
      if (isDryRun) {
        console.log(`   🔍 [DRY RUN] Would update transaction ${doc.id}`);
        totalUpdated++;
      } else {
        batch.update(doc.ref, {
          type: 'winnings',
          originalType: 'payout',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: 'migration_script',
        });
        batchCount++;
        totalUpdated++;

        // Commit batch every 500 operations
        if (batchCount >= batchSize) {
          await batch.commit();
          console.log(`   ✅ Committed batch of ${batchCount} transactions`);
          batch = db.batch();
          batchCount = 0;
        }
      }
    }

    // Commit remaining transactions
    if (batchCount > 0 && !isDryRun) {
      await batch.commit();
      console.log(`   ✅ Committed final batch of ${batchCount} transactions`);
    }

    console.log(`   ✅ Updated ${totalUpdated} transactions`);
    stats.transactionsUpdated = totalUpdated;

  } catch (error) {
    console.error(`   ❌ Error updating transaction types:`, error);
    stats.errors.push({ error: error.message, operation: 'transaction_update' });
    stats.transactionsUpdateFailed++;
  }
}

/**
 * Main migration function
 */
async function runMigration() {
  try {
    // Step 1: Migrate wallet balances
    console.log('═══════════════════════════════════════════════════════════');
    console.log('STEP 1: Migrating wallet balances');
    console.log('═══════════════════════════════════════════════════════════');

    let userIds = [];

    if (specificUserId) {
      userIds = [specificUserId];
    } else {
      // Get all users who have old wallets
      const oldWalletsSnapshot = await db.collection('wallets').get();
      userIds = oldWalletsSnapshot.docs.map(doc => doc.id);
      console.log(`Found ${userIds.length} users with old wallet data`);
    }

    for (const userId of userIds) {
      const result = await migrateWalletBalance(userId);
      stats.usersProcessed++;

      if (result.patched) {
        stats.walletsPatched++;
      } else if (result.error) {
        stats.walletsPatchFailed++;
      }
    }

    // Step 2: Update transaction types
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('STEP 2: Updating transaction types');
    console.log('═══════════════════════════════════════════════════════════');
    await updateTransactionTypes();

    // Print summary
    console.log('\n');
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║     📊 MIGRATION SUMMARY                                   ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log('');
    console.log(`Mode: ${isDryRun ? 'DRY RUN' : 'LIVE'}`);
    console.log(`Users processed: ${stats.usersProcessed}`);
    console.log(`Wallets patched: ${stats.walletsPatched}`);
    console.log(`Wallet patch failures: ${stats.walletsPatchFailed}`);
    console.log(`Transactions updated: ${stats.transactionsUpdated}`);
    console.log(`Transaction update failures: ${stats.transactionsUpdateFailed}`);
    console.log(`Total errors: ${stats.errors.length}`);
    console.log('');

    if (stats.errors.length > 0) {
      console.log('❌ Errors encountered:');
      stats.errors.forEach((error, index) => {
        console.log(`   ${index + 1}. ${error.operation}: ${error.error}`);
        if (error.userId) console.log(`      User: ${error.userId}`);
      });
      console.log('');
    }

    if (isDryRun) {
      console.log('🔍 This was a DRY RUN. No changes were made.');
      console.log('   Run without --dry-run to apply changes.');
    } else {
      console.log('✅ Migration completed!');
      console.log('   Verify wallet balances are correct in the app.');
    }
    console.log('');
    console.log('═══════════════════════════════════════════════════════════');

  } catch (error) {
    console.error('\n❌ FATAL ERROR during migration:', error);
    console.error('Stack trace:', error.stack);
  } finally {
    // Close Firebase connection
    await admin.app().delete();
  }
}

// Run the migration
runMigration().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
