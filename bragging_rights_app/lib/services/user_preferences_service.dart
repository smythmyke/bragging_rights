import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_preferences.dart';

/// Service for managing user preferences
class UserPreferencesService {
  static final UserPreferencesService _instance = UserPreferencesService._internal();
  factory UserPreferencesService() => _instance;
  UserPreferencesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  UserPreferences? _cachedPreferences;
  
  /// Get current user's preferences
  Future<UserPreferences> getUserPreferences() async {
    // Return cached if available and recent
    if (_cachedPreferences != null &&
        DateTime.now().difference(_cachedPreferences!.lastUpdated).inMinutes < 30) {
      return _cachedPreferences!;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final doc = await _firestore
          .collection('userPreferences')
          .doc(userId)
          .get();

      if (doc.exists) {
        _cachedPreferences = UserPreferences.fromFirestore(doc);
      } else {
        // Create default preferences for new user
        _cachedPreferences = UserPreferences.defaultForUser(userId);
        await saveUserPreferences(_cachedPreferences!);
      }

      return _cachedPreferences!;
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
      // Return defaults on error
      return UserPreferences.defaultForUser(userId);
    }
  }

  /// Save user preferences
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _firestore
          .collection('userPreferences')
          .doc(userId)
          .set(preferences.toFirestore());
      
      _cachedPreferences = preferences;
      debugPrint('✅ User preferences saved');
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
      throw e;
    }
  }

  /// Update favorite sports
  Future<void> updateFavoriteSports(List<String> sports) async {
    final current = await getUserPreferences();
    final updated = current.copyWith(favoriteSports: sports);
    await saveUserPreferences(updated);
  }

  /// Update favorite teams
  Future<void> updateFavoriteTeams(List<String> teams) async {
    final current = await getUserPreferences();
    final updated = current.copyWith(favoriteTeams: teams);
    await saveUserPreferences(updated);
  }

  /// Toggle a sport as favorite
  Future<void> toggleFavoriteSport(String sport) async {
    final current = await getUserPreferences();
    final sports = List<String>.from(current.favoriteSports);
    
    if (sports.contains(sport)) {
      sports.remove(sport);
    } else {
      sports.add(sport);
    }
    
    final updated = current.copyWith(favoriteSports: sports);
    await saveUserPreferences(updated);
  }

  /// Clear cache
  void clearCache() {
    _cachedPreferences = null;
  }

  /// Check if user prefers a sport
  Future<bool> prefersSport(String sport) async {
    final prefs = await getUserPreferences();
    return prefs.favoriteSports.contains(sport.toLowerCase());
  }

  /// Get sports in priority order
  Future<List<String>> getSportsInPriorityOrder() async {
    final prefs = await getUserPreferences();
    
    // User's favorite sports first
    final prioritized = List<String>.from(prefs.favoriteSports);
    
    // Add popular sports not in favorites
    const popularSports = ['nfl', 'nba', 'mlb', 'nhl'];
    for (final sport in popularSports) {
      if (!prioritized.contains(sport)) {
        prioritized.add(sport);
      }
    }
    
    return prioritized;
  }

  /// Calculate game priority score
  int calculateGamePriority({
    required String homeTeam,
    required String awayTeam,
    required String status,
    required DateTime gameTime,
    bool hasActivePools = false,
  }) {
    int score = 0;
    
    // Live games get highest priority
    if (status == 'live') score += 1000;
    
    // Games starting soon
    final hoursUntilGame = gameTime.difference(DateTime.now()).inHours;
    if (hoursUntilGame <= 3 && hoursUntilGame >= 0) score += 500;
    
    // User's favorite teams
    if (_cachedPreferences != null) {
      final favoriteTeams = _cachedPreferences!.favoriteTeams;
      if (favoriteTeams.contains(homeTeam) || favoriteTeams.contains(awayTeam)) {
        score += 800;
      }
    }
    
    // Games with active pools
    if (hasActivePools) score += 300;
    
    // Prime time games (8 PM or later)
    if (gameTime.hour >= 20) score += 100;
    
    // Weekend games
    if (gameTime.weekday == DateTime.saturday || 
        gameTime.weekday == DateTime.sunday) {
      score += 50;
    }
    
    return score;
  }
}