import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../lib/firebase_options.dart';

/// Script to add Marble Run game to Firestore and upload images to Storage
/// Run with: dart run scripts/add_marble_run_game.dart

Future<void> main() async {
  print('🚀 Starting Marble Run game setup...\n');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('✅ Firebase initialized\n');

  final firestore = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;

  // Step 1: Upload images to Firebase Storage
  print('📤 Uploading images to Firebase Storage...');

  final imageFiles = {
    'thumbnail': File(r'C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\game_assets\marble_run\thumbnail.jpg'),
    'banner': File(r'C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\game_assets\marble_run\banner.jpg'),
    'gameplay': File(r'C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\game_assets\marble_run\gameplay.jpg'),
  };

  Map<String, String> imageUrls = {};

  for (var entry in imageFiles.entries) {
    final name = entry.key;
    final file = entry.value;

    if (!file.existsSync()) {
      print('  ⚠️  $name image not found: ${file.path}');
      continue;
    }

    try {
      final ref = storage.ref().child('game_images/marble_run/$name.jpg');
      print('  📁 Uploading $name.jpg...');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      imageUrls[name] = url;

      print('  ✅ $name uploaded: $url');
    } catch (e) {
      print('  ❌ Failed to upload $name: $e');
    }
  }

  print('\n📊 Uploaded ${imageUrls.length}/3 images\n');

  // Step 2: Add Marble Run game document to Firestore
  print('💾 Adding Marble Run game to Firestore...');

  final gameData = {
    'id': 'marble_run',
    'name': 'Marble Run - Ultimate Race!',
    'slug': 'marble-run',
    'category': 'arcade',
    'sportType': null,

    // Platform & Integration
    'platform': 'gamedistribution',
    'embedUrl': 'https://html5.gamedistribution.com/ae42ea5c4e0b4ff4b9eddf47fbd2cc5e/?gd_sdk_referrer_url=https://braggingrightsapp.com',
    'gdGameId': 'ae42ea5c4e0b4ff4b9eddf47fbd2cc5e',

    // Visual Assets
    'thumbnailUrl': imageUrls['thumbnail'] ?? '',
    'bannerUrl': imageUrls['banner'] ?? '',
    'gameplayUrl': imageUrls['gameplay'] ?? '',
    'icon': '🎱',

    // Game Info
    'description': 'Guide your marble through colorful mazes and challenging tracks! Race against time and collect points.',
    'instructions': 'Tap and swipe to control your marble. Collect points and reach the finish line!',
    'avgPlaytime': '5min',
    'difficulty': 'medium',

    // Pricing & Economy
    'brCost': 5,
    'revenueShare': 0.5, // 50% for GameDistribution

    // Status & Availability
    'active': true,
    'featured': true,
    'weekNumber': 1,
    'rotationOrder': 1,

    // Metadata
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'totalPlays': 0,
    'rating': 0.0,
    'ratingCount': 0,
  };

  try {
    await firestore.collection('mini-games').doc('marble_run').set(gameData);
    print('✅ Marble Run game added to Firestore!\n');
  } catch (e) {
    print('❌ Failed to add game to Firestore: $e\n');
    exit(1);
  }

  // Step 3: Verify game is in Firestore
  print('🔍 Verifying game was added...');
  final doc = await firestore.collection('mini-games').doc('marble_run').get();

  if (doc.exists) {
    print('✅ Game verified in Firestore');
    print('   Name: ${doc.data()?['name']}');
    print('   Active: ${doc.data()?['active']}');
    print('   Platform: ${doc.data()?['platform']}');
    print('   Thumbnail: ${doc.data()?['thumbnailUrl']?.isNotEmpty == true ? "✅" : "❌"}');
    print('   Banner: ${doc.data()?['bannerUrl']?.isNotEmpty == true ? "✅" : "❌"}');
  } else {
    print('❌ Game not found in Firestore!');
  }

  print('\n🎉 Setup complete! Open the Edge tab in your app to see Marble Run.\n');

  exit(0);
}
