// Script to add BR balance to user account
// Run with: node scripts/add_br_balance.js

const admin = require('firebase-admin');
const serviceAccount = require('../bragging-rights-firebase-key.json');

// Initialize admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://bragging-rights-ea6e1.firebaseio.com"
});

const db = admin.firestore();

async function addBRBalance(email, amount) {
  try {
    // Find user by email
    const userRecord = await admin.auth().getUserByEmail(email);
    console.log(`Found user: ${userRecord.uid} - ${userRecord.email}`);
    
    // Update wallet balance
    const walletRef = db.collection('wallets').doc(userRecord.uid);
    
    // Check if wallet exists
    const walletDoc = await walletRef.get();
    
    if (walletDoc.exists) {
      // Update existing wallet
      await walletRef.update({
        balance: amount,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`Updated wallet balance to ${amount} BR`);
    } else {
      // Create new wallet
      await walletRef.set({
        userId: userRecord.uid,
        balance: amount,
        transactions: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      });
      console.log(`Created wallet with ${amount} BR`);
    }
    
    // Add a transaction record
    await walletRef.collection('transactions').add({
      type: 'admin_credit',
      amount: amount,
      description: 'Admin testing credit',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      balance_after: amount
    });
    
    console.log('Transaction recorded');
    console.log(`Successfully added ${amount} BR to ${email}`);
    
  } catch (error) {
    console.error('Error:', error);
  } finally {
    process.exit();
  }
}

// Run the script
const email = 'smythmyke@gmail.com';
const amount = 99999;

addBRBalance(email, amount);