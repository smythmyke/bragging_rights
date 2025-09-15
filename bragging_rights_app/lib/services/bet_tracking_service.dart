import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_bet_status.dart';

/// Service to track and persist user bet statuses
class BetTrackingService {
  static final BetTrackingService _instance = BetTrackingService._internal();
  factory BetTrackingService() => _instance;
  BetTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache key prefix
  static const String _cacheKeyPrefix = 'user_bets_';

  // In-memory cache for quick access
  Map<String, UserBetStatus> _memoryCache = {};
  bool _isCacheLoaded = false;

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Save or update bet status
  Future<void> saveBetStatus(UserBetStatus status) async {
    if (_userId == null) {
      debugPrint('Cannot save bet status: User not logged in');
      return;
    }

    try {
      // Update memory cache
      _memoryCache[status.gameId] = status;

      // Save to SharedPreferences
      await _saveToLocalStorage();

      // Save to Firestore (fire and forget for performance)
      _saveToFirestore(status).catchError((e) {
        debugPrint('Error saving to Firestore: $e');
      });
    } catch (e) {
      debugPrint('Error saving bet status: $e');
    }
  }

  /// Get bet status for a specific game
  Future<UserBetStatus?> getBetStatus(String gameId) async {
    if (_userId == null) return null;

    // Check memory cache first
    if (_memoryCache.containsKey(gameId)) {
      return _memoryCache[gameId];
    }

    // Load from local storage if not in memory
    if (!_isCacheLoaded) {
      await loadAllBetStatuses();
    }

    return _memoryCache[gameId];
  }

  /// Get all bet statuses
  Future<Map<String, UserBetStatus>> getAllBetStatuses() async {
    if (_userId == null) return {};

    if (!_isCacheLoaded) {
      await loadAllBetStatuses();
    }

    return Map.from(_memoryCache);
  }

  /// Load all bet statuses from local storage and Firestore
  Future<void> loadAllBetStatuses() async {
    if (_userId == null) return;

    try {
      // Load from local storage first (fast)
      await _loadFromLocalStorage();
      _isCacheLoaded = true;

      // Then sync with Firestore in background
      _syncWithFirestore().catchError((e) {
        debugPrint('Error syncing with Firestore: $e');
      });
    } catch (e) {
      debugPrint('Error loading bet statuses: $e');
    }
  }

  /// Clear old bet statuses (older than 7 days)
  Future<void> clearOldBetStatuses() async {
    if (_userId == null) return;

    try {
      final keysToRemove = <String>[];

      _memoryCache.forEach((gameId, status) {
        if (!status.isRelevant) {
          keysToRemove.add(gameId);
        }
      });

      // Remove from memory cache
      for (final key in keysToRemove) {
        _memoryCache.remove(key);
      }

      // Update local storage
      await _saveToLocalStorage();

      // Clean up Firestore
      for (final gameId in keysToRemove) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('active_bets')
            .doc(gameId)
            .delete()
            .catchError((e) {
              debugPrint('Error deleting old bet from Firestore: $e');
            });
      }
    } catch (e) {
      debugPrint('Error clearing old bet statuses: $e');
    }
  }

  /// Remove specific bet status
  Future<void> removeBetStatus(String gameId) async {
    if (_userId == null) return;

    try {
      // Remove from memory cache
      _memoryCache.remove(gameId);

      // Update local storage
      await _saveToLocalStorage();

      // Remove from Firestore
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('active_bets')
          .doc(gameId)
          .delete()
          .catchError((e) {
            debugPrint('Error removing bet from Firestore: $e');
          });
    } catch (e) {
      debugPrint('Error removing bet status: $e');
    }
  }

  /// Check if a game has an active bet
  bool hasActiveBet(String gameId) {
    return _memoryCache.containsKey(gameId) &&
           (_memoryCache[gameId]?.isActive ?? false);
  }

  /// Clear all cached data (useful on logout)
  Future<void> clearCache() async {
    _memoryCache.clear();
    _isCacheLoaded = false;

    if (_userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_cacheKeyPrefix$_userId');
    }
  }

  // Private helper methods

  /// Save to local storage
  Future<void> _saveToLocalStorage() async {
    if (_userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$_userId';

      // Convert all bet statuses to JSON
      final Map<String, dynamic> jsonData = {};
      _memoryCache.forEach((gameId, status) {
        jsonData[gameId] = status.toJson();
      });

      // Save as JSON string
      await prefs.setString(cacheKey, jsonEncode(jsonData));
    } catch (e) {
      debugPrint('Error saving to local storage: $e');
    }
  }

  /// Load from local storage
  Future<void> _loadFromLocalStorage() async {
    if (_userId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_cacheKeyPrefix$_userId';
      final jsonString = prefs.getString(cacheKey);

      if (jsonString != null) {
        final Map<String, dynamic> jsonData = jsonDecode(jsonString);

        _memoryCache.clear();
        jsonData.forEach((gameId, statusJson) {
          if (statusJson is Map<String, dynamic>) {
            final status = UserBetStatus.fromJson(statusJson);
            if (status.isRelevant) {
              _memoryCache[gameId] = status;
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading from local storage: $e');
    }
  }

  /// Save to Firestore
  Future<void> _saveToFirestore(UserBetStatus status) async {
    if (_userId == null) return;

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('active_bets')
        .doc(status.gameId)
        .set(status.toMap());
  }

  /// Sync with Firestore
  Future<void> _syncWithFirestore() async {
    if (_userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('active_bets')
          .get();

      for (final doc in snapshot.docs) {
        final status = UserBetStatus.fromMap(doc.data(), doc.id);

        // Only update if Firestore version is newer
        if (status.isRelevant) {
          final localStatus = _memoryCache[doc.id];
          if (localStatus == null ||
              status.lastUpdated.isAfter(localStatus.lastUpdated)) {
            _memoryCache[doc.id] = status;
          }
        }
      }

      // Save updated cache to local storage
      await _saveToLocalStorage();
    } catch (e) {
      debugPrint('Error syncing with Firestore: $e');
    }
  }

  /// Create bet status from pool selection
  Future<void> createBetStatusFromPool({
    required String gameId,
    required String poolId,
    required double amount,
    required String sport,
    required DateTime gameDate,
  }) async {
    if (_userId == null) return;

    final existingStatus = await getBetStatus(gameId);

    if (existingStatus != null) {
      // Update existing status with new pool
      final updatedPoolIds = List<String>.from(existingStatus.poolIds);
      if (!updatedPoolIds.contains(poolId)) {
        updatedPoolIds.add(poolId);
      }

      final updatedStatus = existingStatus.copyWith(
        poolIds: updatedPoolIds,
        totalAmount: existingStatus.totalAmount + amount,
        lastUpdated: DateTime.now(),
      );

      await saveBetStatus(updatedStatus);
    } else {
      // Create new status
      final newStatus = UserBetStatus(
        gameId: gameId,
        userId: _userId!,
        betPlacedAt: DateTime.now(),
        poolIds: [poolId],
        totalAmount: amount,
        sport: sport,
        gameDate: gameDate,
      );

      await saveBetStatus(newStatus);
    }
  }
}