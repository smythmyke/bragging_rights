/**
 * In-App Purchase Cloud Functions for Bragging Rights App
 * Handles purchase verification and coin distribution
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Ensure Firebase is initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ============================================
// PURCHASE VERIFICATION
// ============================================

/**
 * Verify in-app purchase
 */
exports.verifyPurchase = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;
  const { productId, purchaseId, verificationData, platform } = data;

  if (!productId || !purchaseId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Product ID and Purchase ID are required'
    );
  }

  try {
    // Check if purchase was already processed
    const existingPurchase = await db.collection('purchases')
      .where('purchaseId', '==', purchaseId)
      .where('userId', '==', userId)
      .get();

    if (!existingPurchase.empty) {
      console.log(`Purchase ${purchaseId} already processed for user ${userId}`);
      return {
        valid: true,
        alreadyProcessed: true,
        message: 'Purchase already processed'
      };
    }

    // Verify with appropriate store
    let verificationResult;
    if (platform === 'ios') {
      verificationResult = await verifyApplePurchase(verificationData);
    } else {
      verificationResult = await verifyGooglePurchase(verificationData, productId);
    }

    if (!verificationResult.valid) {
      console.error(`Invalid purchase: ${purchaseId}`);
      return {
        valid: false,
        message: 'Purchase verification failed'
      };
    }

    // Record the purchase
    await recordPurchase(userId, productId, purchaseId, verificationResult);

    return {
      valid: true,
      alreadyProcessed: false,
      message: 'Purchase verified successfully'
    };

  } catch (error) {
    console.error('Purchase verification error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to verify purchase',
      error.message
    );
  }
});

/**
 * Verify Apple App Store purchase
 */
async function verifyApplePurchase(receiptData) {
  // In production, you would verify with Apple's servers
  // This is a simplified implementation
  
  // For testing/development
  if (!receiptData) {
    return { valid: false };
  }

  try {
    // TODO: Implement actual Apple receipt verification
    // https://developer.apple.com/documentation/appstorereceipts/verifyreceipt
    
    // Placeholder for development
    console.log('Apple purchase verification not yet implemented');
    return {
      valid: true,
      receipt: receiptData
    };
  } catch (error) {
    console.error('Apple verification error:', error);
    return { valid: false };
  }
}

/**
 * Verify Google Play purchase
 */
async function verifyGooglePurchase(purchaseToken, productId) {
  // In production, you would verify with Google Play API
  // This is a simplified implementation
  
  if (!purchaseToken) {
    return { valid: false };
  }

  try {
    // TODO: Implement actual Google Play verification
    // Use Google Play Developer API
    // https://developers.google.com/android-publisher/api-ref/purchases/products/get
    
    // Placeholder for development
    console.log('Google purchase verification not yet implemented');
    return {
      valid: true,
      token: purchaseToken,
      productId: productId
    };
  } catch (error) {
    console.error('Google verification error:', error);
    return { valid: false };
  }
}

/**
 * Record purchase in database
 */
async function recordPurchase(userId, productId, purchaseId, verificationResult) {
  const purchaseRef = db.collection('purchases').doc();
  
  await purchaseRef.set({
    userId: userId,
    productId: productId,
    purchaseId: purchaseId,
    verificationData: verificationResult,
    timestamp: FieldValue.serverTimestamp(),
    status: 'completed',
    processed: true
  });

  console.log(`Recorded purchase ${purchaseId} for user ${userId}`);
}

// ============================================
// PROMOTIONAL FUNCTIONS
// ============================================

/**
 * Grant promotional BR coins (Admin only)
 */
exports.grantPromotionalCoins = functions.https.onCall(async (data, context) => {
  // Verify admin status
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can grant promotional coins'
    );
  }

  const { userId, amount, reason } = data;

  if (!userId || !amount || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Valid userId and amount are required'
    );
  }

  try {
    const walletRef = db.collection('users').doc(userId)
      .collection('wallet').doc('current');
    
    const transactionRef = db.collection('transactions').doc();
    
    await db.runTransaction(async (transaction) => {
      const walletDoc = await transaction.get(walletRef);
      
      if (!walletDoc.exists) {
        throw new Error(`Wallet not found for user ${userId}`);
      }
      
      const currentBalance = walletDoc.data().balance || 0;
      const newBalance = currentBalance + amount;
      
      // Update wallet
      transaction.update(walletRef, {
        balance: newBalance,
        lastPromotion: FieldValue.serverTimestamp()
      });
      
      // Create transaction record
      transaction.set(transactionRef, {
        userId: userId,
        type: 'promotion',
        amount: amount,
        description: reason || 'Promotional BR coins',
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        timestamp: FieldValue.serverTimestamp(),
        grantedBy: context.auth.uid,
        status: 'completed'
      });
    });

    console.log(`Granted ${amount} promotional coins to user ${userId}`);

    return {
      success: true,
      message: `Successfully granted ${amount} BR coins`,
      newBalance: (await db.collection('users').doc(userId)
        .collection('wallet').doc('current').get()).data().balance
    };

  } catch (error) {
    console.error('Error granting promotional coins:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to grant promotional coins',
      error.message
    );
  }
});

/**
 * Apply referral bonus
 */
exports.applyReferralBonus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const userId = context.auth.uid;
  const { referralCode } = data;

  if (!referralCode) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Referral code is required'
    );
  }

  try {
    // Find referrer
    const referrerSnapshot = await db.collection('users')
      .where('referralCode', '==', referralCode)
      .limit(1)
      .get();

    if (referrerSnapshot.empty) {
      throw new functions.https.HttpsError(
        'not-found',
        'Invalid referral code'
      );
    }

    const referrerId = referrerSnapshot.docs[0].id;

    if (referrerId === userId) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Cannot use your own referral code'
      );
    }

    // Check if user already used a referral
    const userDoc = await db.collection('users').doc(userId).get();
    const userData = userDoc.data();

    if (userData.referredBy) {
      throw new functions.https.HttpsError(
        'already-exists',
        'Referral bonus already claimed'
      );
    }

    // Apply bonuses
    const newUserBonus = 50; // BR coins for new user
    const referrerBonus = 100; // BR coins for referrer

    // Update new user
    await grantBonus(userId, newUserBonus, `Referral bonus from ${referralCode}`);
    
    // Update referrer
    await grantBonus(referrerId, referrerBonus, `Referral bonus for inviting user`);

    // Mark referral as used
    await db.collection('users').doc(userId).update({
      referredBy: referrerId,
      referralUsedAt: FieldValue.serverTimestamp()
    });

    // Update referrer's referral count
    await db.collection('users').doc(referrerId).update({
      referralCount: FieldValue.increment(1),
      totalReferralBonus: FieldValue.increment(referrerBonus)
    });

    console.log(`Referral bonus applied: ${userId} referred by ${referrerId}`);

    return {
      success: true,
      message: `Welcome bonus of ${newUserBonus} BR coins added!`,
      bonusAmount: newUserBonus
    };

  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    console.error('Error applying referral bonus:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to apply referral bonus'
    );
  }
});

/**
 * Grant bonus helper function
 */
async function grantBonus(userId, amount, description) {
  const walletRef = db.collection('users').doc(userId)
    .collection('wallet').doc('current');
  
  const transactionRef = db.collection('transactions').doc();
  
  await db.runTransaction(async (transaction) => {
    const walletDoc = await transaction.get(walletRef);
    
    if (!walletDoc.exists) {
      throw new Error(`Wallet not found for user ${userId}`);
    }
    
    const currentBalance = walletDoc.data().balance || 0;
    const newBalance = currentBalance + amount;
    
    // Update wallet
    transaction.update(walletRef, {
      balance: newBalance,
      lastBonus: FieldValue.serverTimestamp()
    });
    
    // Create transaction record
    transaction.set(transactionRef, {
      userId: userId,
      type: 'bonus',
      amount: amount,
      description: description,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      timestamp: FieldValue.serverTimestamp(),
      status: 'completed'
    });
  });
}

// ============================================
// SUBSCRIPTION MANAGEMENT
// ============================================

/**
 * Check and update premium subscription status
 */
exports.checkPremiumStatus = functions.pubsub
  .schedule('0 0 * * *') // Daily at midnight
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Checking premium subscription statuses...');
    
    try {
      const now = new Date();
      
      // Get all users with expired premium subscriptions
      const expiredSnapshot = await db.collection('users')
        .where('isPremium', '==', true)
        .where('premiumExpiresAt', '<=', now)
        .get();
      
      if (expiredSnapshot.empty) {
        console.log('No expired premium subscriptions found');
        return null;
      }
      
      const batch = db.batch();
      let count = 0;
      
      for (const doc of expiredSnapshot.docs) {
        batch.update(doc.ref, {
          isPremium: false,
          premiumExpiredAt: FieldValue.serverTimestamp()
        });
        count++;
      }
      
      await batch.commit();
      console.log(`Updated ${count} expired premium subscriptions`);
      
      // Log the operation
      await db.collection('system_logs').add({
        type: 'premium_check',
        timestamp: FieldValue.serverTimestamp(),
        expiredCount: count
      });
      
    } catch (error) {
      console.error('Error checking premium status:', error);
    }
    
    return null;
  });

console.log('Purchase Cloud Functions initialized');