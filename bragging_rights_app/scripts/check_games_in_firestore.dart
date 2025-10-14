import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../lib/firebase_options.dart';

/// Script to check what games are currently in Firestore
/// Run with: dart run scripts/check_games_in_firestore.dart

Future<void> main() async {
  print('🔍 Checking Firestore for mini-games...\n');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized\n');

  final firestore = FirebaseFirestore.instance;

  // Check mini-games collection
  print('📂 Checking /mini-games/ collection...');

  try {
    final snapshot = await firestore.collection('mini-games').get();

    if (snapshot.docs.isEmpty) {
      print('❌ No games found in Firestore');
      print('   The /mini-games/ collection is empty or doesn\'t exist.');
      print('\n💡 To add games:');
      print('   1. Run: dart run scripts/add_marble_run_game.dart');
      print('   2. Or manually add games in Firebase Console');
      print('   3. Or add Sports Trivia if not already added\n');
    } else {
      print('✅ Found ${snapshot.docs.length} game(s):\n');

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('─────────────────────────────────────────');
        print('Game ID: ${doc.id}');
        print('Name: ${data['name'] ?? 'N/A'}');
        print('Active: ${data['active'] ?? false}');
        print('Platform: ${data['platform'] ?? 'N/A'}');
        print('Featured: ${data['featured'] ?? false}');
        print('BR Cost: ${data['brCost'] ?? 'N/A'}');
        print('Icon: ${data['icon'] ?? 'N/A'}');
        print('Thumbnail: ${data['thumbnailUrl']?.isNotEmpty == true ? "✅ Set" : "❌ Missing"}');
        print('Banner: ${data['bannerUrl']?.isNotEmpty == true ? "✅ Set" : "❌ Missing"}');
        print('Embed URL: ${data['embedUrl']?.isNotEmpty == true ? "✅ Set" : "❌ Missing"}');
        print('Created: ${data['createdAt']?.toString() ?? 'N/A'}');
        print('');
      }
      print('─────────────────────────────────────────\n');
    }
  } catch (e) {
    print('❌ Error reading Firestore: $e\n');
    exit(1);
  }

  // Check active games specifically
  print('🔍 Checking active games (active=true)...');

  try {
    final activeSnapshot = await firestore
        .collection('mini-games')
        .where('active', isEqualTo: true)
        .get();

    if (activeSnapshot.docs.isEmpty) {
      print('❌ No active games found');
      print('   Make sure games have "active: true" field set\n');
    } else {
      print('✅ Found ${activeSnapshot.docs.length} active game(s):');
      for (var doc in activeSnapshot.docs) {
        print('   - ${doc.data()['name']} (${doc.id})');
      }
      print('');
    }
  } catch (e) {
    print('❌ Error checking active games: $e\n');
  }

  // Check leaderboards collection
  print('🏆 Checking /leaderboards/ collection...');

  try {
    final leaderboardsSnapshot = await firestore.collection('leaderboards').get();

    if (leaderboardsSnapshot.docs.isEmpty) {
      print('ℹ️  No leaderboards yet (normal for new setup)');
    } else {
      print('✅ Found ${leaderboardsSnapshot.docs.length} leaderboard(s)');
      for (var doc in leaderboardsSnapshot.docs) {
        print('   - ${doc.id}');
      }
    }
    print('');
  } catch (e) {
    print('❌ Error checking leaderboards: $e\n');
  }

  print('✅ Check complete!\n');

  exit(0);
}
