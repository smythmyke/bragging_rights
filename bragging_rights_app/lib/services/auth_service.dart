import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
// Google Sign-In causing JLink issues in release mode
// import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String displayName,
    List<String>? favoriteSports,
  }) async {
    try {
      print('AuthService: Starting sign up process');
      print('AuthService: Email: $email');
      print('AuthService: Display name: $displayName');
      
      // Create user with email and password
      print('AuthService: Creating user with Firebase Auth...');
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('AuthService: User created successfully with UID: ${credential.user?.uid}');

      // Update display name
      print('AuthService: Updating display name...');
      await credential.user?.updateDisplayName(displayName);
      print('AuthService: Display name updated');

      // Create user document in Firestore
      print('AuthService: Creating user document in Firestore...');
      await _createUserDocument(
        user: credential.user!,
        displayName: displayName,
        favoriteSports: favoriteSports ?? [],
      );
      print('AuthService: User document created successfully');

      return credential;
    } on FirebaseAuthException catch (e) {
      print('AuthService: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('AuthService: Unexpected error during sign up: $e');
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('AuthService: Starting sign in process');
      print('AuthService: Email: $email');
      
      print('AuthService: Attempting Firebase sign in...');
      UserCredential? credential;
      try {
        credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('AuthService: Sign in successful - UID: ${credential.user?.uid}');
      } catch (authError) {
        print('AuthService: Error during signInWithEmailAndPassword: $authError');
        print('AuthService: Error type: ${authError.runtimeType}');
        if (authError is FirebaseAuthException) {
          throw authError;
        } else {
          throw Exception('Authentication error: $authError');
        }
      }

      // Check if user document exists, create if not
      print('AuthService: Ensuring user document exists...');
      await _ensureUserDocument(credential.user!);
      print('AuthService: User document check complete');

      return credential;
    } on FirebaseAuthException catch (e) {
      print('AuthService: FirebaseAuthException during sign in - Code: ${e.code}, Message: ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('AuthService: Unexpected error during sign in: $e');
      print('AuthService: Error type: ${e.runtimeType}');
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Sign in with Google (temporarily disabled due to JLink build issues)
  Future<UserCredential?> signInWithGoogle() async {
    // Temporarily disabled - Google Sign-In causing JLink issues in release mode
    throw Exception('Google Sign-In temporarily unavailable. Please use email/password login.');
    
    // Original implementation commented out:
    // try {
    //   final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    //   if (googleUser == null) return null;
    //   final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    //   final credential = GoogleAuthProvider.credential(
    //     accessToken: googleAuth.accessToken,
    //     idToken: googleAuth.idToken,
    //   );
    //   final userCredential = await _auth.signInWithCredential(credential);
    //   await _ensureUserDocument(
    //     userCredential.user!,
    //     displayName: googleUser.displayName,
    //     photoUrl: googleUser.photoUrl,
    //   );
    //   return userCredential;
    // } on FirebaseAuthException catch (e) {
    //   throw _handleAuthException(e);
    // } catch (e) {
    //   throw Exception('Google sign-in failed: $e');
    // }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Google Sign-In disabled due to build issues
      // if (await _googleSignIn.isSignedIn()) {
      //   await _googleSignIn.signOut();
      // }
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument({
    required User user,
    required String displayName,
    required List<String> favoriteSports,
  }) async {
    print('_createUserDocument: Starting for UID: ${user.uid}');
    final userDoc = _firestore.collection('users').doc(user.uid);

    // Check if document already exists
    print('_createUserDocument: Checking if document exists...');
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      print('_createUserDocument: Document does not exist, creating new document...');
      // Create user document
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'favoriteSports': favoriteSports,
        'favoriteTeams': [],
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isPremium': false,
        'isActive': true,
      });
      print('_createUserDocument: User document created');

      // Create wallet subcollection with initial 500 BR
      print('_createUserDocument: Creating wallet with 500 BR...');
      await userDoc.collection('wallet').doc('current').set({
        'balance': 500,
        'lifetimeEarned': 500,
        'lifetimeWagered': 0,
        'lastAllowance': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('_createUserDocument: Wallet created');

      // Create stats subcollection
      print('_createUserDocument: Creating stats...');
      await userDoc.collection('stats').doc('current').set({
        'totalBets': 0,
        'wins': 0,
        'losses': 0,
        'pushes': 0,
        'winRate': 0.0,
        'currentStreak': 0,
        'bestStreak': 0,
        'totalPools': 0,
        'poolsWon': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('_createUserDocument: Stats created');

      // Log initial transaction for 500 BR
      print('_createUserDocument: Creating initial transaction...');
      await _firestore.collection('transactions').add({
        'userId': user.uid,
        'type': 'initial_bonus',
        'amount': 500,
        'description': 'Welcome bonus - 500 BR',
        'balanceBefore': 0,
        'balanceAfter': 500,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'completed',
      });
      print('_createUserDocument: Initial transaction created');
    } else {
      print('_createUserDocument: Document already exists, skipping creation');
    }
  }

  // Ensure user document exists (for existing users)
  Future<void> _ensureUserDocument(User user, {String? displayName, String? photoUrl}) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await _createUserDocument(
        user: user,
        displayName: displayName ?? user.displayName ?? 'User',
        favoriteSports: [],
      );
      
      // Update photo URL if provided (for Google Sign-In)
      if (photoUrl != null) {
        await userDoc.update({'photoURL': photoUrl});
      }
    } else {
      // Update last login and photo URL if changed
      final updates = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      
      if (photoUrl != null) {
        updates['photoURL'] = photoUrl;
      }
      
      await userDoc.update(updates);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
    List<String>? favoriteSports,
    List<String>? favoriteTeams,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    // Update Firebase Auth profile
    if (displayName != null) {
      await user.updateDisplayName(displayName);
    }
    if (photoURL != null) {
      await user.updatePhotoURL(photoURL);
    }

    // Update Firestore document
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (photoURL != null) updates['photoURL'] = photoURL;
    if (favoriteSports != null) updates['favoriteSports'] = favoriteSports;
    if (favoriteTeams != null) updates['favoriteTeams'] = favoriteTeams;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(user.uid).update(updates);
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = currentUser;
    if (user == null) return null;

    final docSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    return docSnapshot.data();
  }

  // Get user wallet balance
  Stream<int> getUserBalance() {
    final user = currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('wallet')
        .doc('current')
        .snapshots()
        .map((doc) => (doc.data()?['balance'] ?? 0) as int);
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    print('_handleAuthException: Error code: ${e.code}');
    print('_handleAuthException: Error message: ${e.message}');
    print('_handleAuthException: Stack trace: ${e.stackTrace}');
    
    switch (e.code) {
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      // Delete user data from Firestore
      final batch = _firestore.batch();
      
      // Delete user document
      batch.delete(_firestore.collection('users').doc(user.uid));
      
      // Delete user's bets
      final betsQuery = await _firestore
          .collection('bets')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      for (var doc in betsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's transactions
      final transactionsQuery = await _firestore
          .collection('transactions')
          .where('userId', isEqualTo: user.uid)
          .get();
      
      for (var doc in transactionsQuery.docs) {
        batch.delete(doc.reference);
      }
      
      // Commit batch delete
      await batch.commit();
      
      // Delete Firebase Auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please sign in again to delete your account.');
      }
      throw _handleAuthException(e);
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}