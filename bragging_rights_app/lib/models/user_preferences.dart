import 'package:cloud_firestore/cloud_firestore.dart';

/// User preferences for optimizing API calls and personalizing experience
class UserPreferences {
  final String userId;
  final List<String> favoriteSports;
  final List<String> favoriteTeams;
  final bool showLiveGamesFirst;
  final bool autoLoadOdds;
  final int maxGamesPerSport;
  final DateTime lastUpdated;
  
  // Default sports for new users
  static const List<String> defaultSports = ['nfl', 'nba'];
  static const int defaultMaxGames = 5;

  UserPreferences({
    required this.userId,
    required this.favoriteSports,
    required this.favoriteTeams,
    this.showLiveGamesFirst = true,
    this.autoLoadOdds = false,
    this.maxGamesPerSport = defaultMaxGames,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  /// Create from Firestore document
  factory UserPreferences.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    
    if (data == null) {
      // Return defaults for new user
      return UserPreferences(
        userId: doc.id,
        favoriteSports: defaultSports,
        favoriteTeams: [],
      );
    }

    return UserPreferences(
      userId: doc.id,
      favoriteSports: List<String>.from(data['favoriteSports'] ?? defaultSports),
      favoriteTeams: List<String>.from(data['favoriteTeams'] ?? []),
      showLiveGamesFirst: data['showLiveGamesFirst'] ?? true,
      autoLoadOdds: data['autoLoadOdds'] ?? false,
      maxGamesPerSport: data['maxGamesPerSport'] ?? defaultMaxGames,
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'favoriteSports': favoriteSports,
      'favoriteTeams': favoriteTeams,
      'showLiveGamesFirst': showLiveGamesFirst,
      'autoLoadOdds': autoLoadOdds,
      'maxGamesPerSport': maxGamesPerSport,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  /// Create default preferences for new user
  factory UserPreferences.defaultForUser(String userId) {
    return UserPreferences(
      userId: userId,
      favoriteSports: defaultSports,
      favoriteTeams: [],
    );
  }

  /// Check if user has set preferences
  bool get hasCustomPreferences => 
      favoriteSports != defaultSports || favoriteTeams.isNotEmpty;

  /// Get sports to load (with fallback to defaults)
  List<String> get sportsToLoad => 
      favoriteSports.isNotEmpty ? favoriteSports : defaultSports;

  /// Copy with modifications
  UserPreferences copyWith({
    List<String>? favoriteSports,
    List<String>? favoriteTeams,
    bool? showLiveGamesFirst,
    bool? autoLoadOdds,
    int? maxGamesPerSport,
  }) {
    return UserPreferences(
      userId: userId,
      favoriteSports: favoriteSports ?? this.favoriteSports,
      favoriteTeams: favoriteTeams ?? this.favoriteTeams,
      showLiveGamesFirst: showLiveGamesFirst ?? this.showLiveGamesFirst,
      autoLoadOdds: autoLoadOdds ?? this.autoLoadOdds,
      maxGamesPerSport: maxGamesPerSport ?? this.maxGamesPerSport,
    );
  }
}