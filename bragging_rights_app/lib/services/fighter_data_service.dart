import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'edge/sports/espn_mma_service.dart';

/// Service for managing fighter profiles and data
class FighterDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EspnMmaService _espnService = EspnMmaService();
  
  // Cache duration constants
  static const Duration _profileCacheDuration = Duration(days: 30);
  static const Duration _imageCacheDuration = Duration(days: 90);
  
  // Memory cache for current session
  final Map<String, FighterData> _memoryCache = {};
  
  /// Get fighter data with intelligent caching
  Future<FighterData?> getFighterData({
    required String fighterId,
    required String fighterName,
    String? espnId,
    bool forceRefresh = false,
  }) async {
    try {
      // Check memory cache first
      if (!forceRefresh && _memoryCache.containsKey(fighterId)) {
        return _memoryCache[fighterId];
      }
      
      // Check Firestore cache
      final cachedData = await _getFromFirestore(fighterId);
      if (cachedData != null && !forceRefresh) {
        if (_isCacheValid(cachedData.lastUpdated)) {
          _memoryCache[fighterId] = cachedData;
          return cachedData;
        }
      }
      
      // Fetch fresh data from ESPN if we have an ESPN ID
      if (espnId != null) {
        final freshData = await _fetchFromEspn(espnId, fighterId, fighterName);
        if (freshData != null) {
          await _saveToFirestore(freshData);
          _memoryCache[fighterId] = freshData;
          return freshData;
        }
      }
      
      // Return cached data even if stale (better than nothing)
      return cachedData;
      
    } catch (e) {
      debugPrint('Error getting fighter data: $e');
      return null;
    }
  }
  
  /// Batch fetch multiple fighters (efficient for fight cards)
  Future<Map<String, FighterData>> batchGetFighters(
    List<FighterRequest> requests,
  ) async {
    final results = <String, FighterData>{};
    
    // First, try to get all from cache
    final needsFetch = <FighterRequest>[];
    
    for (final request in requests) {
      final cached = await _getFromFirestore(request.fighterId);
      if (cached != null && _isCacheValid(cached.lastUpdated)) {
        results[request.fighterId] = cached;
        _memoryCache[request.fighterId] = cached;
      } else {
        needsFetch.add(request);
      }
    }
    
    // Batch fetch missing/stale fighters
    if (needsFetch.isNotEmpty) {
      debugPrint('Fetching ${needsFetch.length} fighter profiles from ESPN...');
      
      // Fetch in parallel with Future.wait
      final futures = needsFetch.map((request) => 
        _fetchFromEspn(request.espnId, request.fighterId, request.fighterName)
      );
      
      final freshData = await Future.wait(futures);
      
      // Save and cache results
      for (int i = 0; i < needsFetch.length; i++) {
        final data = freshData[i];
        if (data != null) {
          await _saveToFirestore(data);
          results[needsFetch[i].fighterId] = data;
          _memoryCache[needsFetch[i].fighterId] = data;
        }
      }
    }
    
    return results;
  }
  
  /// Get fighter from Firestore
  Future<FighterData?> _getFromFirestore(String fighterId) async {
    try {
      final doc = await _firestore
          .collection('fighters')
          .doc(fighterId)
          .get();
      
      if (doc.exists) {
        return FighterData.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error reading fighter from Firestore: $e');
    }
    return null;
  }
  
  /// Save fighter to Firestore
  Future<void> _saveToFirestore(FighterData data) async {
    try {
      await _firestore
          .collection('fighters')
          .doc(data.id)
          .set(data.toFirestore());
    } catch (e) {
      debugPrint('Error saving fighter to Firestore: $e');
    }
  }
  
  /// Fetch fresh data from ESPN
  Future<FighterData?> _fetchFromEspn(
    String espnId,
    String fighterId,
    String fighterName,
  ) async {
    try {
      final profile = await _espnService.getFighterProfile(espnId);
      
      if (profile != null) {
        return FighterData(
          id: fighterId,
          espnId: espnId,
          name: fighterName,
          nickname: profile.nickname,
          record: profile.record,
          weightClass: profile.weightClass,
          reach: profile.reach,
          stance: profile.stance,
          age: profile.age,
          camp: profile.camp,
          wins: profile.stats['wins'] ?? 0,
          losses: profile.stats['losses'] ?? 0,
          draws: profile.stats['draws'] ?? 0,
          kos: profile.stats['kos'] ?? 0,
          submissions: profile.stats['submissions'] ?? 0,
          decisions: profile.stats['decisions'] ?? 0,
          headshotUrl: _extractHeadshotUrl(espnId),
          flagUrl: null, // ESPN doesn't provide this consistently
          lastUpdated: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('Error fetching fighter from ESPN: $e');
    }
    
    // Return basic data if ESPN fails
    return FighterData.basic(
      id: fighterId,
      espnId: espnId,
      name: fighterName,
      lastUpdated: DateTime.now(),
    );
  }
  
  /// Generate ESPN headshot URL
  String? _extractHeadshotUrl(String espnId) {
    // ESPN headshot URL pattern
    // Example: https://a.espncdn.com/i/headshots/mma/players/full/{espnId}.png
    return 'https://a.espncdn.com/i/headshots/mma/players/full/$espnId.png';
  }
  
  /// Check if cache is still valid
  bool _isCacheValid(DateTime lastUpdated) {
    final age = DateTime.now().difference(lastUpdated);
    return age < _profileCacheDuration;
  }
  
  /// Clear memory cache (call on app background/terminate)
  void clearMemoryCache() {
    _memoryCache.clear();
  }
}

/// Fighter data model
class FighterData {
  final String id;
  final String espnId;
  final String name;
  final String? nickname;
  final String? record;
  final String? weightClass;
  final double? reach;
  final String? stance;
  final int? age;
  final String? camp;
  final int wins;
  final int losses;
  final int draws;
  final int kos;
  final int submissions;
  final int decisions;
  final String? headshotUrl;
  final String? flagUrl;
  final DateTime lastUpdated;
  
  FighterData({
    required this.id,
    required this.espnId,
    required this.name,
    this.nickname,
    this.record,
    this.weightClass,
    this.reach,
    this.stance,
    this.age,
    this.camp,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.kos = 0,
    this.submissions = 0,
    this.decisions = 0,
    this.headshotUrl,
    this.flagUrl,
    required this.lastUpdated,
  });
  
  /// Create basic fighter data when ESPN fails
  factory FighterData.basic({
    required String id,
    required String espnId,
    required String name,
    required DateTime lastUpdated,
  }) {
    return FighterData(
      id: id,
      espnId: espnId,
      name: name,
      lastUpdated: lastUpdated,
    );
  }
  
  /// Create from Firestore document
  factory FighterData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FighterData(
      id: doc.id,
      espnId: data['espnId'] ?? '',
      name: data['name'] ?? '',
      nickname: data['nickname'],
      record: data['record'],
      weightClass: data['weightClass'],
      reach: data['reach']?.toDouble(),
      stance: data['stance'],
      age: data['age'],
      camp: data['camp'],
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      draws: data['draws'] ?? 0,
      kos: data['kos'] ?? 0,
      submissions: data['submissions'] ?? 0,
      decisions: data['decisions'] ?? 0,
      headshotUrl: data['headshotUrl'],
      flagUrl: data['flagUrl'],
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }
  
  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'espnId': espnId,
      'name': name,
      'nickname': nickname,
      'record': record,
      'weightClass': weightClass,
      'reach': reach,
      'stance': stance,
      'age': age,
      'camp': camp,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'kos': kos,
      'submissions': submissions,
      'decisions': decisions,
      'headshotUrl': headshotUrl,
      'flagUrl': flagUrl,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }
  
  /// Get formatted record string
  String get formattedRecord => record ?? '$wins-$losses-$draws';
  
  /// Get finish rate percentage
  double get finishRate {
    if (wins == 0) return 0;
    return ((kos + submissions) / wins) * 100;
  }
}

/// Request model for batch fetching
class FighterRequest {
  final String fighterId;
  final String fighterName;
  final String espnId;
  
  FighterRequest({
    required this.fighterId,
    required this.fighterName,
    required this.espnId,
  });
}