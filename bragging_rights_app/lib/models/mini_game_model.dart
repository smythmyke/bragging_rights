import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a mini-game available in the app
class MiniGameModel {
  final String id;
  final String name;
  final String title; // Display title (can be different from name/id)
  final String embedUrl;
  final String platform; // 'html5_free', 'gamedistribution', 'native'
  final int weekNumber;
  final bool active;
  final String icon;
  final String sportType;
  final String description;
  final int maxScore;
  final String? thumbnailUrl; // URL for game preview image
  final String? bannerUrl; // URL for banner/header image
  final int brCost; // BR cost to play (default 15)

  // NEW FIELDS FOR GAMES PAGE IMPROVEMENTS
  final bool featured; // Is this the featured game?
  final DateTime? featuredUntil; // When to unfeature
  final String longDescription; // 2-3 sentences for featured card
  final int playerCount; // Total plays this week
  final int averageDuration; // Minutes per game session
  final int topPrize; // BR amount for 1st place (deprecated - not used)
  final String category; // "Trivia", "Sports", "Arcade", "Puzzle", etc.

  // Runtime property - not stored in Firestore
  bool isFavorited; // Set at runtime based on user's favorites

  MiniGameModel({
    required this.id,
    required this.name,
    required this.title,
    required this.embedUrl,
    required this.platform,
    required this.weekNumber,
    required this.active,
    required this.icon,
    required this.sportType,
    required this.description,
    required this.maxScore,
    this.thumbnailUrl,
    this.bannerUrl,
    this.brCost = 15,
    this.featured = false,
    this.featuredUntil,
    this.longDescription = '',
    this.playerCount = 0,
    this.averageDuration = 5,
    this.topPrize = 500,
    this.category = 'General',
    this.isFavorited = false,
  });

  factory MiniGameModel.fromMap(Map<String, dynamic> map) {
    return MiniGameModel(
      id: map['id'] ?? '',
      name: map['name'] ?? map['title'] ?? '',
      title: map['title'] ?? map['name'] ?? '',
      embedUrl: map['embedUrl'] ?? '',
      platform: map['platform'] ?? 'html5_free',
      weekNumber: map['weekNumber'] ?? 1,
      active: map['active'] ?? true,
      icon: map['icon'] ?? 'gameController',
      sportType: map['sportType'] ?? 'general',
      description: map['description'] ?? '',
      maxScore: map['maxScore'] ?? 10000,
      thumbnailUrl: map['thumbnailUrl'],
      bannerUrl: map['bannerUrl'],
      brCost: map['brCost'] ?? 15,
      // New fields
      featured: map['featured'] ?? false,
      featuredUntil: map['featuredUntil'] != null
          ? (map['featuredUntil'] as Timestamp).toDate()
          : null,
      longDescription: map['longDescription'] ?? map['description'] ?? '',
      playerCount: map['playerCount'] ?? 0,
      averageDuration: map['averageDuration'] ?? 5,
      topPrize: map['topPrize'] ?? 500,
      category: map['category'] ?? _inferCategoryFromSportType(map['sportType'] ?? 'general'),
      isFavorited: false, // Will be set at runtime
    );
  }

  /// Helper method to infer category from sportType if category not provided
  static String _inferCategoryFromSportType(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'basketball':
      case 'football':
      case 'soccer':
      case 'baseball':
        return 'Sports';
      case 'trivia':
      case 'quiz':
        return 'Trivia';
      case 'puzzle':
        return 'Puzzle';
      case 'arcade':
        return 'Arcade';
      default:
        return 'General';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'embedUrl': embedUrl,
      'platform': platform,
      'weekNumber': weekNumber,
      'active': active,
      'icon': icon,
      'sportType': sportType,
      'description': description,
      'maxScore': maxScore,
      'thumbnailUrl': thumbnailUrl,
      'bannerUrl': bannerUrl,
      'brCost': brCost,
      // New fields
      'featured': featured,
      'featuredUntil': featuredUntil != null ? Timestamp.fromDate(featuredUntil!) : null,
      'longDescription': longDescription,
      'playerCount': playerCount,
      'averageDuration': averageDuration,
      'topPrize': topPrize,
      'category': category,
    };
  }
}

// Leaderboard classes removed - not using score tracking system
