import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class FighterImageCacheService {
  static final FighterImageCacheService _instance = FighterImageCacheService._internal();
  factory FighterImageCacheService() => _instance;
  FighterImageCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for current session
  final Map<String, String> _memoryCache = {};

  // Cache duration (30 days)
  static const Duration CACHE_DURATION = Duration(days: 30);

  /// Get fighter image URL with smart caching
  /// First checks memory cache, then Firestore, then fetches from ESPN
  Future<String?> getFighterImageUrl(String fighterId) async {
    if (fighterId.isEmpty) return null;

    // Check if this is a placeholder ID (f1_XX or f2_XX)
    if (fighterId.startsWith('f1_') || fighterId.startsWith('f2_')) {
      // Return ESPN's default no photo image for placeholders
      debugPrint('⚠️ Placeholder fighter ID: $fighterId - using default image');
      return 'https://a.espncdn.com/combiner/i?img=/i/headshots/nophoto.png';
    }

    try {
      // 1. Check memory cache first (fastest)
      if (_memoryCache.containsKey(fighterId)) {
        debugPrint('🎯 Fighter $fighterId image found in memory cache');
        return _memoryCache[fighterId];
      }

      // 2. Check Firestore cache
      final cachedImage = await _getFromFirestore(fighterId);
      if (cachedImage != null) {
        debugPrint('💾 Fighter $fighterId image found in Firestore cache');
        _memoryCache[fighterId] = cachedImage;
        return cachedImage;
      }

      // 3. Fetch from ESPN and cache
      debugPrint('🌐 Fetching fighter $fighterId image from ESPN');
      final espnUrl = await _fetchAndCacheFromESPN(fighterId);
      if (espnUrl != null) {
        _memoryCache[fighterId] = espnUrl;
      }

      return espnUrl;
    } catch (e) {
      debugPrint('❌ Error getting fighter image for $fighterId: $e');
      // Return default ESPN URL as fallback
      return _getESPNImageUrl(fighterId);
    }
  }

  /// Check if image exists in Firestore cache
  Future<String?> _getFromFirestore(String fighterId) async {
    try {
      final doc = await _firestore
          .collection('fighter_images_cache')
          .doc(fighterId)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      final cachedAt = DateTime.parse(data['cachedAt']);

      // Check if cache is expired
      if (DateTime.now().difference(cachedAt) > CACHE_DURATION) {
        debugPrint('⏰ Cache expired for fighter $fighterId');
        // Delete expired cache
        await doc.reference.delete();
        return null;
      }

      // Check if this is a no-image entry
      if (data['noImage'] == true && data['url'] != null) {
        return data['url']; // Return placeholder URL
      }

      // Check if we have base64 data or just URL
      if (data['imageBase64'] != null) {
        return data['imageBase64']; // Return data URL
      } else if (data['url'] != null) {
        return data['url'];
      }

      return null;
    } catch (e) {
      debugPrint('Error reading from Firestore: $e');
      return null;
    }
  }

  /// Fetch image from ESPN and save to Firestore
  Future<String?> _fetchAndCacheFromESPN(String fighterId) async {
    try {
      final espnUrl = _getESPNImageUrl(fighterId);

      // First check if the image exists
      final checkResponse = await http.head(Uri.parse(espnUrl)).timeout(
        Duration(seconds: 5),
        onTimeout: () => http.Response('', 404),
      );

      if (checkResponse.statusCode != 200) {
        debugPrint('❌ No image found for fighter $fighterId at ESPN');
        // Cache the fact that no image exists and return placeholder
        await _cacheNoImage(fighterId);
        return 'https://a.espncdn.com/combiner/i?img=/i/headshots/nophoto.png';
      }

      // Fetch the actual image
      final response = await http.get(Uri.parse(espnUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        // Convert to base64 for storage
        final base64String = base64Encode(bytes);
        final dataUrl = 'data:image/png;base64,$base64String';

        // Store in Firestore
        await _saveToFirestore(fighterId, espnUrl, dataUrl, bytes.length);

        debugPrint('✅ Cached fighter $fighterId image (${bytes.length} bytes)');
        return dataUrl;
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching from ESPN: $e');
      // Return the URL anyway for CachedNetworkImage to try
      return _getESPNImageUrl(fighterId);
    }
  }

  /// Save image data to Firestore
  Future<void> _saveToFirestore(
    String fighterId,
    String originalUrl,
    String dataUrl,
    int fileSize,
  ) async {
    try {
      // For large images, we might want to store just the URL
      // and let CachedNetworkImage handle the actual caching
      final storeBase64 = fileSize < 500000; // Only store base64 if < 500KB

      await _firestore
          .collection('fighter_images_cache')
          .doc(fighterId)
          .set({
        'fighterId': fighterId,
        'url': originalUrl,
        'imageBase64': storeBase64 ? dataUrl : null,
        'fileSize': fileSize,
        'cachedAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(CACHE_DURATION).toIso8601String(),
        'verified': true,
      });
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
      // Don't throw - still return the URL even if caching fails
    }
  }

  /// Cache the fact that a fighter has no image
  Future<void> _cacheNoImage(String fighterId) async {
    try {
      await _firestore
          .collection('fighter_images_cache')
          .doc(fighterId)
          .set({
        'fighterId': fighterId,
        'url': 'https://a.espncdn.com/combiner/i?img=/i/headshots/nophoto.png',
        'noImage': true,
        'cachedAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error caching no-image status: $e');
    }
  }

  /// Generate ESPN CDN URL for fighter
  String _getESPNImageUrl(String fighterId) {
    return 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png';
  }

  /// Clear memory cache (call on low memory warning)
  void clearMemoryCache() {
    _memoryCache.clear();
    debugPrint('🧹 Cleared fighter image memory cache');
  }

  /// Clear expired Firestore cache entries
  Future<void> cleanupExpiredCache() async {
    try {
      final now = DateTime.now();
      final query = await _firestore
          .collection('fighter_images_cache')
          .where('expiresAt', isLessThan: now.toIso8601String())
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      debugPrint('🧹 Cleaned up ${query.docs.length} expired fighter images');
    } catch (e) {
      debugPrint('Error cleaning up cache: $e');
    }
  }

  /// Preload images for a specific event
  Future<void> preloadEventFighters(List<String> fighterIds) async {
    debugPrint('📥 Preloading ${fighterIds.length} fighter images');

    for (final fighterId in fighterIds) {
      try {
        await getFighterImageUrl(fighterId);
        // Add small delay to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        debugPrint('Error preloading fighter $fighterId: $e');
      }
    }

    debugPrint('✅ Finished preloading fighter images');
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final collection = await _firestore
          .collection('fighter_images_cache')
          .get();

      int totalCached = collection.docs.length;
      int withImages = 0;
      int noImages = 0;
      int expired = 0;

      final now = DateTime.now();

      for (final doc in collection.docs) {
        final data = doc.data();
        if (data['noImage'] == true) {
          noImages++;
        } else if (data['imageBase64'] != null || data['url'] != null) {
          withImages++;
        }

        final expiresAt = DateTime.parse(data['expiresAt']);
        if (expiresAt.isBefore(now)) {
          expired++;
        }
      }

      return {
        'totalCached': totalCached,
        'withImages': withImages,
        'noImages': noImages,
        'expired': expired,
        'memoryCached': _memoryCache.length,
      };
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }
}