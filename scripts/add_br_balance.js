// Script to add BR balance to user account
// Run with: node scripts/add_br_balance.js

const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

// Initialize admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'bragging-rights-ea6e1.firebasestorage.app'
});

const db = admin.firestore();

async function addBRBalance(email, amount) {
  try {
    // Find user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`Found user: ${userRecord.uid} - ${userRecord.email}`);

    // Update user's braggingRights field
    const userRef = db.collection('users').doc(userRecord.uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      console.log('❌ User document does not exist');
      return;
    }

    const currentBR = userDoc.data()?.braggingRights || 0;
    console.log(`Current BR balance: ${currentBR}`);

    // Set the braggingRights field
    await userRef.update({
      braggingRights: amount
    });

    console.log(`✅ Updated user BR balance to ${amount}`);
    console.log(`   Previous: ${currentBR} BR`);
    console.log(`   New: ${amount} BR`);

    // Also update wallet for consistency
    const walletRef = db.collection('wallets').doc(userRecord.uid);
    const walletDoc = await walletRef.get();

    if (walletDoc.exists) {
      await walletRef.update({
        balance: amount,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`✅ Updated wallet balance to ${amount} BR`);

      // Add transaction record
      await walletRef.collection('transactions').add({
        type: 'admin_credit',
        amount: amount,
        description: 'Admin testing credit for mini-games',
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        balance_after: amount
      });
      console.log('✅ Transaction recorded');
    }

    console.log(`\n🎮 Successfully added ${amount} BR to ${email}`);

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    process.exit();
  }
}

// Run the script
const email = 'smythmyke@gmail.com';
const amount = 500; // Give 500 BR for testing mini-games

addBRBalance(email, amount);