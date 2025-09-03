import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevTools {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Set BR balance for testing purposes
  /// Call this from anywhere in the app during development
  static Future<void> setTestBalance({int amount = 99999}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('No user logged in');
        return;
      }

      // Update wallet balance in the correct location
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('wallet')
          .doc('current')
          .set({
        'balance': amount,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastAllowance': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Successfully set balance to $amount BR for ${user.email}');

      // Add transaction record
      await _firestore.collection('transactions').add({
        'userId': user.uid,
        'type': 'dev_credit',
        'amount': amount,
        'description': 'Development testing credit',
        'timestamp': FieldValue.serverTimestamp(),
        'balance_after': amount,
      });

      print('✅ Transaction recorded');
    } catch (e) {
      print('❌ Error setting balance: $e');
    }
  }

  /// Create the required Firestore index
  static String getIndexCreationUrl() {
    return 'https://console.firebase.google.com/v1/r/project/bragging-rights-ea6e1/firestore/indexes?create_composite=ClNwcm9qZWN0cy9icmFnZ2luZy1yaWdodHMtZWE2ZTEvZGF0YWJhc2VzLyhkZWZhdWx0KS9jb2xsZWN0aW9uR3JvdXBzL3Bvb2xzL2luZGV4ZXMvXxABGgoKBnN0YXR1cxABGgkKBWJ1eUluEAEaDAoIX19uYW1lX18QAQ';
  }

  /// Initialize test data
  static Future<void> initializeTestData() async {
    // Set test balance
    await setTestBalance();

    // Add some test cards
    final user = _auth.currentUser;
    if (user != null) {
      final inventory = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('card_inventory')
          .doc('current');

      await inventory.set({
        'cardQuantities': {
          'double_down': 3,
          'insurance': 2,
          'mulligan': 5,
          'hedge': 1,
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Added test cards to inventory');
    }
  }
}