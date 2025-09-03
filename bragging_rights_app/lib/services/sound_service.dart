import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../data/card_sound_mappings.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();
  final Map<String, String> _cloudSoundUrls = {};
  bool _soundEnabled = true;
  double _volume = 0.7;

  // Initialize service
  Future<void> initialize() async {
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(_volume);
    
    // Optionally upload sounds to Firebase Storage on first run
    // await _uploadSoundsToCloud();
  }

  // Play sound when selecting/viewing a card
  Future<void> playCardSelect(String cardId) async {
    if (!_soundEnabled) return;
    
    final sounds = CardSoundMappings.getSoundsForCard(cardId);
    if (sounds != null) {
      await _playSound(sounds.selectPath);
    }
  }

  // Play sound when purchasing a card
  Future<void> playCardPurchase(String cardId) async {
    if (!_soundEnabled) return;
    
    final sounds = CardSoundMappings.getSoundsForCard(cardId);
    if (sounds != null) {
      await _playSound(sounds.purchasePath);
    }
  }

  // Play sound when using/activating a card
  Future<void> playCardUse(String cardId) async {
    if (!_soundEnabled) return;
    
    final sounds = CardSoundMappings.getSoundsForCard(cardId);
    if (sounds != null) {
      await _playSound(sounds.usePath);
    }
  }

  // Play common sounds
  Future<void> playInsufficientFunds() async {
    if (!_soundEnabled) return;
    await _playSound(CardSoundMappings.commonSounds.insufficientPath);
  }

  Future<void> playNavigateToBuyBR() async {
    if (!_soundEnabled) return;
    await _playSound(CardSoundMappings.commonSounds.navigatePath);
  }

  Future<void> playCardActivated() async {
    if (!_soundEnabled) return;
    await _playSound(CardSoundMappings.commonSounds.activatedPath);
  }

  Future<void> playCardExpired() async {
    if (!_soundEnabled) return;
    await _playSound(CardSoundMappings.commonSounds.expiredPath);
  }

  Future<void> playStrategyLocked() async {
    if (!_soundEnabled) return;
    await _playSound(CardSoundMappings.commonSounds.lockedPath);
  }

  // Core sound playing method
  Future<void> _playSound(String path) async {
    try {
      // Check if we have a cloud URL for this sound
      final cloudUrl = _cloudSoundUrls[path];
      
      if (cloudUrl != null) {
        // Play from cloud
        await _player.play(UrlSource(cloudUrl));
      } else {
        // Play from local assets
        await _player.play(AssetSource(path.replaceFirst('assets/', '')));
      }
    } catch (e) {
      print('Error playing sound $path: $e');
    }
  }

  // Upload sounds to Firebase Storage (run once during app setup)
  Future<void> uploadSoundsToCloud() async {
    final storage = FirebaseStorage.instance;
    final soundFiles = [
      'cards-shuffling-87543.mp3',
      'applause-01-253125.mp3',
      'ding-47489.mp3',
      'cool-breeze.mp3',
      'applause-cheer.mp3',
      'iced-magic-1-378607.mp3',
      'time-freeze-extended.mp3',
      'lock-sound-effect-247455.mp3',
      'well-arent-you-smart.mp3',
      'modern-digital-doorbell-sound-325250.mp3',
      'gulp.mp3',
      'dice-142528.mp3',
      'casino-jackpot.mp3',
      'tech-inspiration.mp3',
      'gasp-6253.mp3',
      'time-freeze-tension-327055.mp3',
      'joker-laugh-2-98829.mp3',
      'laugh-high-pitch-154516.mp3',
      'magic-descend-3-259525.mp3',
      'magic-ascend-3-259526.mp3',
      'crowd-applause-113728.mp3',
      'sfx-magic.mp3',
      'magic-03-278824.mp3',
      'riffle-card-shuffle-104313.mp3',
    ];

    for (final fileName in soundFiles) {
      try {
        final ref = storage.ref().child('sounds/$fileName');
        
        // Check if already uploaded
        try {
          final url = await ref.getDownloadURL();
          _cloudSoundUrls['assets/sounds/$fileName'] = url;
          print('Sound already uploaded: $fileName');
          continue;
        } catch (e) {
          // File doesn't exist, proceed with upload
        }
        
        // Load file from assets
        final ByteData data = await rootBundle.load('assets/sounds/$fileName');
        final List<int> bytes = data.buffer.asUint8List();
        
        // Upload to Firebase Storage
        final uploadTask = await ref.putData(
          Uint8List.fromList(bytes),
          SettableMetadata(contentType: 'audio/mpeg'),
        );
        
        // Get download URL
        final url = await uploadTask.ref.getDownloadURL();
        _cloudSoundUrls['assets/sounds/$fileName'] = url;
        
        print('Uploaded sound: $fileName');
      } catch (e) {
        print('Error uploading $fileName: $e');
      }
    }
    
    // Save URLs to local storage or Firestore for future use
    await _saveSoundUrlsToFirestore();
  }

  // Save sound URLs to Firestore for caching
  Future<void> _saveSoundUrlsToFirestore() async {
    // Save to a Firestore document for app-wide access
    // This avoids re-fetching URLs on every app launch
    try {
      // await FirebaseFirestore.instance
      //     .collection('app_config')
      //     .doc('sound_urls')
      //     .set({'urls': _cloudSoundUrls});
    } catch (e) {
      print('Error saving sound URLs: $e');
    }
  }

  // Load cached sound URLs from Firestore
  Future<void> loadSoundUrls() async {
    try {
      // final doc = await FirebaseFirestore.instance
      //     .collection('app_config')
      //     .doc('sound_urls')
      //     .get();
      // 
      // if (doc.exists) {
      //   _cloudSoundUrls.clear();
      //   _cloudSoundUrls.addAll(Map<String, String>.from(doc.data()!['urls']));
      // }
    } catch (e) {
      print('Error loading sound URLs: $e');
    }
  }

  // Settings
  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _player.setVolume(_volume);
  }

  bool get soundEnabled => _soundEnabled;
  double get volume => _volume;

  // Dispose
  void dispose() {
    _player.dispose();
  }
}