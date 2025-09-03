import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Run this with: dart run scripts/set_br_balance.dart

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  
  const email = 'smythmyke@gmail.com';
  const password = 'YOUR_PASSWORD'; // You'll need to update this
  const newBalance = 99999;
  
  try {
    // Sign in
    final credential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    
    print('Signed in as ${credential.user?.uid}');
    
    // Update wallet balance
    await firestore.collection('wallets').doc(credential.user!.uid).set({
      'userId': credential.user!.uid,
      'balance': newBalance,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    print('Successfully set balance to $newBalance BR');
    
    // Add transaction record
    await firestore
        .collection('wallets')
        .doc(credential.user!.uid)
        .collection('transactions')
        .add({
      'type': 'admin_credit',
      'amount': newBalance,
      'description': 'Testing credit',
      'timestamp': FieldValue.serverTimestamp(),
      'balance_after': newBalance,
    });
    
    print('Transaction recorded');
    
  } catch (e) {
    print('Error: $e');
  }
  
  // Sign out
  await auth.signOut();
}