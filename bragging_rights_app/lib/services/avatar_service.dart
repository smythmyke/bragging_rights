import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/avatar_config.dart';

/// Service for managing user avatars using DiceBear API
class AvatarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Available avatar styles with metadata
  static const List<Map<String, dynamic>> availableStyles = [
    {
      'id': 'adventurer',
      'name': 'Adventurer',
      'description': 'Cartoon people with accessories',
      'rarity': 'common',
      'unlocked': true,
    },
    {
      'id': 'avataaars',
      'name': 'Avataaars',
      'description': 'Popular cartoon style',
      'rarity': 'common',
      'unlocked': true,
    },
    {
      'id': 'bottts',
      'name': 'Robots',
      'description': 'Cute robot avatars',
      'rarity': 'common',
      'unlocked': true,
    },
    {
      'id': 'big-smile',
      'name': 'Big Smile',
      'description': 'Always happy faces',
      'rarity': 'rare',
      'unlocked': false,
      'unlockCondition': 'Win 10 bets',
    },
    {
      'id': 'fun-emoji',
      'name': 'Fun Emoji',
      'description': 'Emoji-style faces',
      'rarity': 'rare',
      'unlocked': false,
      'unlockCondition': 'Reach Level 5',
    },
    {
      'id': 'lorelei',
      'name': 'Lorelei',
      'description': 'Elegant illustrations',
      'rarity': 'epic',
      'unlocked': false,
      'unlockCondition': 'Win 50 bets',
    },
    {
      'id': 'pixel-art',
      'name': 'Pixel Art',
      'description': 'Retro 8-bit style',
      'rarity': 'epic',
      'unlocked': false,
      'unlockCondition': 'Reach Level 10',
    },
    {
      'id': 'croodles',
      'name': 'Croodles',
      'description': 'Artistic doodles',
      'rarity': 'legendary',
      'unlocked': false,
      'unlockCondition': 'Win 100 bets',
    },
  ];

  /// Background color presets
  static const List<Map<String, String>> backgroundColors = [
    {'name': 'Transparent', 'value': 'transparent'},
    {'name': 'Light Blue', 'value': 'b6e3f4'},
    {'name': 'Light Purple', 'value': 'c0aede'},
    {'name': 'Light Pink', 'value': 'ffd5dc'},
    {'name': 'Light Orange', 'value': 'ffdfbf'},
    {'name': 'Light Green', 'value': 'd1f4dd'},
    {'name': 'Light Red', 'value': 'fecaca'},
    {'name': 'Peach', 'value': 'fed7aa'},
    {'name': 'Sky Blue', 'value': 'bfdbfe'},
    {'name': 'Lavender', 'value': 'e9d5ff'},
  ];

  /// Generate avatar URL from config
  static String generateAvatarUrl(AvatarConfig config) {
    return config.toUrl();
  }

  /// Generate simple avatar URL
  static String generateSimpleAvatarUrl({
    required String seed,
    String style = 'adventurer',
    String? backgroundColor,
  }) {
    final buffer = StringBuffer('https://api.dicebear.com/7.x/$style/svg?seed=$seed');
    if (backgroundColor != null && backgroundColor.isNotEmpty) {
      buffer.write('&backgroundColor=$backgroundColor');
    }
    return buffer.toString();
  }

  /// Get user's current avatar config
  Future<AvatarConfig?> getUserAvatarConfig() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['avatarConfig'] != null) {
        return AvatarConfig.fromMap(Map<String, dynamic>.from(data['avatarConfig']));
      }

      // Return default config if none exists
      return AvatarConfig(
        style: 'adventurer',
        seed: user.uid,
      );
    } catch (e) {
      print('❌ Error getting avatar config: $e');
      return null;
    }
  }

  /// Save avatar config
  Future<bool> saveAvatarConfig(AvatarConfig config) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'avatarConfig': config.toMap(),
        'photoURL': config.toUrl(),
        'avatarStyle': config.style,
        'avatarSeed': config.seed,
      });

      print('✅ Avatar config saved successfully');
      return true;
    } catch (e) {
      print('❌ Error saving avatar config: $e');
      return false;
    }
  }

  /// Save to favorites
  Future<bool> addToFavorites(AvatarConfig config) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final favoritesRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_avatars')
          .doc();

      await favoritesRef.set(config.copyWith(isFavorite: true).toMap());
      print('✅ Avatar added to favorites');
      return true;
    } catch (e) {
      print('❌ Error adding to favorites: $e');
      return false;
    }
  }

  /// Remove from favorites
  Future<bool> removeFromFavorites(String documentId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('favorite_avatars')
          .doc(documentId)
          .delete();
      return true;
    } catch (e) {
      print('❌ Error removing from favorites: $e');
      return false;
    }
  }

  /// Get favorite avatars
  Stream<List<AvatarConfig>> getFavoriteAvatars() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorite_avatars')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AvatarConfig.fromMap(doc.data()))
          .toList();
    });
  }

  /// Check if style is unlocked
  Future<bool> isStyleUnlocked(String styleId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    // Check if style is default unlocked
    final styleData = availableStyles.firstWhere(
      (s) => s['id'] == styleId,
      orElse: () => {'unlocked': false},
    );

    if (styleData['unlocked'] == true) return true;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;

      final unlockedStyles = List<String>.from(doc.data()?['unlockedStyles'] ?? []);
      return unlockedStyles.contains(styleId);
    } catch (e) {
      print('❌ Error checking unlock status: $e');
      return false;
    }
  }

  /// Get all unlocked styles for user
  Future<List<String>> getUnlockedStyles() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return [];

      final unlockedStyles = List<String>.from(doc.data()?['unlockedStyles'] ?? []);

      // Add default unlocked styles
      final defaultUnlocked = availableStyles
          .where((s) => s['unlocked'] == true)
          .map((s) => s['id'] as String)
          .toList();

      return [...defaultUnlocked, ...unlockedStyles];
    } catch (e) {
      print('❌ Error getting unlocked styles: $e');
      return [];
    }
  }

  /// Unlock style
  Future<bool> unlockStyle(String styleId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'unlockedStyles': FieldValue.arrayUnion([styleId]),
      });
      print('✅ Style unlocked: $styleId');
      return true;
    } catch (e) {
      print('❌ Error unlocking style: $e');
      return false;
    }
  }

  /// Check unlock conditions and auto-unlock styles
  Future<void> checkAndUnlockStyles(int totalWins, int userLevel) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final unlockedStyles = await getUnlockedStyles();

      // Check each locked style
      for (var style in availableStyles) {
        final styleId = style['id'] as String;
        if (unlockedStyles.contains(styleId)) continue;

        final condition = style['unlockCondition'] as String?;
        if (condition == null) continue;

        bool shouldUnlock = false;

        if (condition.contains('Win') && condition.contains('bets')) {
          final required = int.tryParse(condition.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (totalWins >= required) shouldUnlock = true;
        } else if (condition.contains('Level')) {
          final required = int.tryParse(condition.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (userLevel >= required) shouldUnlock = true;
        }

        if (shouldUnlock) {
          await unlockStyle(styleId);
        }
      }
    } catch (e) {
      print('❌ Error checking unlock conditions: $e');
    }
  }

  /// Generate random seed
  static String generateRandomSeed() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Get rarity color
  static String getRarityColor(String? rarity) {
    switch (rarity) {
      case 'common':
        return '#9CA3AF'; // Gray
      case 'rare':
        return '#3B82F6'; // Blue
      case 'epic':
        return '#A855F7'; // Purple
      case 'legendary':
        return '#F59E0B'; // Gold
      default:
        return '#9CA3AF';
    }
  }
}
