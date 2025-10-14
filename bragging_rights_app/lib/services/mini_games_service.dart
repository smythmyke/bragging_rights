import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mini_game_model.dart';
import 'wallet_service.dart';

/// Service for managing mini-games and playtime tracking
class MiniGamesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final WalletService _walletService = WalletService();

  /// Get all active mini-games for the current week
  Stream<List<MiniGameModel>> getActiveGames() async* {
    final user = _auth.currentUser;

    await for (final snapshot in _firestore
        .collection('mini-games')
        .where('active', isEqualTo: true)
        .snapshots()) {

      final games = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return MiniGameModel.fromMap(data);
      }).toList();

      // Load favorites if user is logged in
      if (user != null) {
        final favorites = await _getUserFavorites(user.uid);
        for (var game in games) {
          game.isFavorited = favorites.contains(game.id);
        }
      }

      yield games;
    }
  }

  /// Get a specific game by ID
  Future<MiniGameModel?> getGame(String gameId) async {
    final doc = await _firestore.collection('mini-games').doc(gameId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    data['id'] = doc.id;
    return MiniGameModel.fromMap(data);
  }


  /// Deduct BR for playing a game
  Future<bool> deductEntryFee(String gameId, int brCost) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ [MiniGamesService] deductEntryFee: No user logged in');
      return false;
    }

    print('');
    print('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    print('┃ [MiniGamesService] Deducting Entry Fee        ┃');
    print('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    print('🎮 Game ID: $gameId');
    print('💰 BR Cost: $brCost');

    try {
      // Use WalletService to deduct BR (same as betting system)
      final success = await _walletService.placeWager(
        amount: brCost,
        betId: 'mini_game_$gameId',
        description: 'Mini-Game Entry Fee: $gameId',
      );

      if (success) {
        print('✅ Entry fee deducted successfully');
      } else {
        print('❌ Failed to deduct entry fee');
      }

      return success;
    } catch (e) {
      print('❌ Error deducting entry fee: $e');
      return false;
    }
  }

  /// Track game play events (started/ended) for analytics
  Future<void> trackGamePlay(String gameId, String event, {Duration? duration}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final timestamp = DateTime.now();

      // If game is starting, increment the playerCount in the game document
      if (event == 'started') {
        await _firestore.collection('mini-games').doc(gameId).update({
          'playerCount': FieldValue.increment(1),
        });
        print('📊 [ANALYTICS] Incremented playerCount for $gameId');
      }

      // Create a session document in game-analytics collection
      final sessionRef = _firestore
          .collection('game-analytics')
          .doc(gameId)
          .collection('sessions')
          .doc();

      final sessionData = {
        'userId': user.uid,
        'event': event, // 'started' or 'ended'
        'timestamp': Timestamp.fromDate(timestamp),
      };

      if (duration != null) {
        sessionData['durationSeconds'] = duration.inSeconds;
        sessionData['durationMinutes'] = duration.inMinutes;
      }

      await sessionRef.set(sessionData);

      print('📊 [ANALYTICS] Tracked $event event for $gameId${duration != null ? ' (${duration.inMinutes}m ${duration.inSeconds % 60}s)' : ''}');
    } catch (e) {
      print('❌ Error tracking game play: $e');
    }
  }

  /// Get user's favorite game IDs
  Future<Set<String>> _getUserFavorites(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();

      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      print('❌ Error getting favorites: $e');
      return {};
    }
  }

  /// Toggle favorite status for a game
  Future<bool> toggleFavorite(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final favoriteRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(gameId);

      final doc = await favoriteRef.get();

      if (doc.exists) {
        // Remove from favorites
        await favoriteRef.delete();
        print('💔 Removed $gameId from favorites');
        return false;
      } else {
        // Add to favorites
        await favoriteRef.set({
          'gameId': gameId,
          'addedAt': FieldValue.serverTimestamp(),
        });
        print('❤️ Added $gameId to favorites');
        return true;
      }
    } catch (e) {
      print('❌ Error toggling favorite: $e');
      return false;
    }
  }

  /// Check if a game is favorited
  Future<bool> isFavorited(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(gameId)
          .get();

      return doc.exists;
    } catch (e) {
      print('❌ Error checking favorite status: $e');
      return false;
    }
  }

  /// Get user's current BR balance using WalletService
  Future<int> getUserBRBalance() async {
    print('');
    print('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    print('┃ [MiniGamesService] getUserBRBalance() called   ┃');
    print('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');

    final user = _auth.currentUser;
    print('👤 Current user: ${user?.uid}');
    print('📧 User email: ${user?.email}');

    if (user == null) {
      print('❌ No user logged in - returning 0');
      print('');
      return 0;
    }

    try {
      print('📡 Using WalletService to get balance...');
      print('   Path: /users/${user.uid}/wallet/current');

      // Use WalletService (same as betting, challenges, pools)
      final balance = await _walletService.getCurrentBalance();

      print('✅ Balance retrieved from wallet: $balance BR');
      print('');

      return balance;
    } catch (e, stackTrace) {
      print('❌ ERROR getting BR balance:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      print('');
      return 0;
    }
  }

}
