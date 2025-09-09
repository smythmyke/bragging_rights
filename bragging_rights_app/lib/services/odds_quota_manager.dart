import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Odds API Quota Manager
/// Manages the monthly request limit across all sports
/// Initially 500 free requests, upgradeable to 20K ($30) or 100K ($59)
/// Implements smart allocation and fallback strategies
class OddsQuotaManager {
  static const int MONTHLY_LIMIT = 20000; // Starting with 20K tier ($30/month)
  static const String QUOTA_KEY = 'odds_api_quota';
  static const String LAST_RESET_KEY = 'odds_api_last_reset';
  
  // Sport-specific monthly allocations (total = 18,000, keeping 2,000 as buffer)
  static const Map<String, int> SPORT_ALLOCATIONS = {
    'nba': 4000,     // High volume, Oct-Apr season
    'nfl': 3000,     // High volume, Sep-Jan season
    'mlb': 3500,     // Long season, Apr-Oct
    'nhl': 3000,     // Oct-Apr season
    'tennis': 1500,  // Year-round, major tournaments
    'mma': 1000,     // Monthly events
    'boxing': 500,   // Fewer events
    'soccer': 1000,  // Year-round leagues
    'golf': 500,     // Weekly tournaments
    'ncaab': 0,      // Reserved for March Madness
    'ncaaf': 0,      // Reserved for season
  };
  
  // Priority levels for sports (higher = more important)
  static const Map<String, int> SPORT_PRIORITY = {
    'nba': 10,
    'nfl': 10,
    'mlb': 8,
    'nhl': 8,
    'tennis': 6,
    'soccer': 6,
    'mma': 5,
    'boxing': 4,
    'golf': 3,
    'ncaab': 7,
    'ncaaf': 7,
  };
  
  // Current month's usage tracking
  Map<String, int> _sportUsage = {};
  int _totalUsed = 0;
  DateTime _lastReset = DateTime.now();
  SharedPreferences? _prefs;
  
  // Singleton instance
  static final OddsQuotaManager _instance = OddsQuotaManager._internal();
  factory OddsQuotaManager() => _instance;
  OddsQuotaManager._internal();
  
  /// Initialize the quota manager
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadQuotaData();
    _checkMonthlyReset();
  }
  
  /// Load saved quota data
  Future<void> _loadQuotaData() async {
    if (_prefs == null) return;
    
    // Load usage data
    final quotaJson = _prefs!.getString(QUOTA_KEY);
    if (quotaJson != null) {
      final data = json.decode(quotaJson);
      _sportUsage = Map<String, int>.from(data['sportUsage'] ?? {});
      _totalUsed = data['totalUsed'] ?? 0;
    }
    
    // Load last reset date
    final lastResetMs = _prefs!.getInt(LAST_RESET_KEY);
    if (lastResetMs != null) {
      _lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
    }
  }
  
  /// Save quota data
  Future<void> _saveQuotaData() async {
    if (_prefs == null) return;
    
    final data = {
      'sportUsage': _sportUsage,
      'totalUsed': _totalUsed,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _prefs!.setString(QUOTA_KEY, json.encode(data));
    await _prefs!.setInt(LAST_RESET_KEY, _lastReset.millisecondsSinceEpoch);
  }
  
  /// Check if month has changed and reset quotas
  void _checkMonthlyReset() {
    final now = DateTime.now();
    if (now.month != _lastReset.month || now.year != _lastReset.year) {
      debugPrint('📅 New month detected - resetting Odds API quotas');
      _resetQuotas();
    }
  }
  
  /// Reset all quotas for new month
  void _resetQuotas() {
    _sportUsage.clear();
    _totalUsed = 0;
    _lastReset = DateTime.now();
    _saveQuotaData();
  }
  
  /// Check if a sport can make an API request
  bool canMakeRequest(String sport, {int count = 1}) {
    _checkMonthlyReset();
    
    final sportLower = sport.toLowerCase();
    final allocation = SPORT_ALLOCATIONS[sportLower] ?? 10;
    final used = _sportUsage[sportLower] ?? 0;
    
    // Check sport-specific limit
    if (used + count > allocation) {
      // Check if we can borrow from buffer
      final bufferRemaining = MONTHLY_LIMIT - _totalUsed;
      if (bufferRemaining >= count) {
        debugPrint('⚠️ $sport exceeded allocation ($used/$allocation), using buffer');
        return true;
      }
      
      debugPrint('❌ $sport quota exceeded ($used/$allocation)');
      return false;
    }
    
    // Check total limit
    if (_totalUsed + count > MONTHLY_LIMIT) {
      debugPrint('❌ Total Odds API quota exceeded ($_totalUsed/$MONTHLY_LIMIT)');
      return false;
    }
    
    return true;
  }
  
  /// Record API usage
  Future<void> recordUsage(String sport, {int count = 1}) async {
    final sportLower = sport.toLowerCase();
    _sportUsage[sportLower] = (_sportUsage[sportLower] ?? 0) + count;
    _totalUsed += count;
    
    debugPrint('📊 Odds API usage: $sport +$count (${_sportUsage[sportLower]}/${SPORT_ALLOCATIONS[sportLower] ?? 10})');
    debugPrint('📊 Total usage: $_totalUsed/$MONTHLY_LIMIT');
    
    await _saveQuotaData();
  }
  
  /// Get remaining quota
  int getRemainingQuota() {
    return MONTHLY_LIMIT - _totalUsed;
  }
  
  /// Get usage statistics
  Map<String, dynamic> getUsageStats() {
    final stats = <String, dynamic>{
      'totalUsed': _totalUsed,
      'totalLimit': MONTHLY_LIMIT,
      'remainingTotal': MONTHLY_LIMIT - _totalUsed,
      'percentUsed': (_totalUsed / MONTHLY_LIMIT * 100).toStringAsFixed(1),
      'lastReset': _lastReset.toIso8601String(),
      'daysUntilReset': _getDaysUntilReset(),
      'sports': {},
    };
    
    // Add per-sport stats
    SPORT_ALLOCATIONS.forEach((sport, allocation) {
      final used = _sportUsage[sport] ?? 0;
      stats['sports'][sport] = {
        'used': used,
        'allocation': allocation,
        'remaining': allocation - used,
        'percentUsed': allocation > 0 ? (used / allocation * 100).toStringAsFixed(1) : '0.0',
      };
    });
    
    return stats;
  }
  
  /// Get days until quota reset
  int _getDaysUntilReset() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return nextMonth.difference(now).inDays;
  }
  
  /// Get recommended cache duration based on usage
  Duration getRecommendedCacheDuration(String sport) {
    final sportLower = sport.toLowerCase();
    final allocation = SPORT_ALLOCATIONS[sportLower] ?? 10;
    final used = _sportUsage[sportLower] ?? 0;
    final percentUsed = allocation > 0 ? used / allocation : 0.0;
    
    // Longer cache as we approach limits
    if (percentUsed > 0.8) {
      return const Duration(hours: 24); // Cache for 24 hours
    } else if (percentUsed > 0.6) {
      return const Duration(hours: 12); // Cache for 12 hours
    } else if (percentUsed > 0.4) {
      return const Duration(hours: 6);  // Cache for 6 hours
    } else {
      return const Duration(hours: 2);  // Default 2 hour cache
    }
  }
  
  /// Check if should use cached data instead of API
  bool shouldUseCache(String sport) {
    final sportLower = sport.toLowerCase();
    final allocation = SPORT_ALLOCATIONS[sportLower] ?? 10;
    final used = _sportUsage[sportLower] ?? 0;
    
    // Force cache if approaching limit
    if (used >= allocation * 0.9) {
      debugPrint('⚠️ $sport approaching limit - forcing cache usage');
      return true;
    }
    
    // Force cache if total usage is high
    if (_totalUsed >= MONTHLY_LIMIT * 0.9) {
      debugPrint('⚠️ Total API limit approaching - forcing cache usage');
      return true;
    }
    
    return false;
  }
  
  /// Get priority score for a sport (used for allocation decisions)
  int getPriority(String sport) {
    return SPORT_PRIORITY[sport.toLowerCase()] ?? 1;
  }
  
  /// Reallocate unused quota from low-activity sports
  void reallocateUnusedQuota() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    final percentMonthElapsed = daysElapsed / daysInMonth;
    
    // Only reallocate after 50% of month has passed
    if (percentMonthElapsed < 0.5) return;
    
    final unusedQuota = <String, int>{};
    int totalUnused = 0;
    
    // Find sports with unused quota
    SPORT_ALLOCATIONS.forEach((sport, allocation) {
      final used = _sportUsage[sport] ?? 0;
      final expectedUsage = (allocation * percentMonthElapsed).round();
      
      if (used < expectedUsage * 0.5) {
        // Sport is using less than 50% of expected
        final unused = expectedUsage - used;
        unusedQuota[sport] = unused;
        totalUnused += unused;
      }
    });
    
    if (totalUnused > 0) {
      debugPrint('♻️ Reallocating $totalUnused unused API calls');
      // This unused quota becomes available in the buffer
    }
  }
  
  /// Get fallback recommendation when quota exceeded
  String getFallbackRecommendation(String sport) {
    return '''
    ⚠️ Odds API quota exceeded for $sport
    
    Fallback options:
    1. Use cached odds if available (< 24 hours old)
    2. Use ESPN odds from game data (free)
    3. Show games without odds
    4. Wait until next month (${_getDaysUntilReset()} days)
    
    Current usage: ${_sportUsage[sport.toLowerCase()] ?? 0}/${SPORT_ALLOCATIONS[sport.toLowerCase()] ?? 10}
    Total usage: $_totalUsed/$MONTHLY_LIMIT
    ''';
  }
}

/// Extension for OddsApiService integration
extension OddsQuotaIntegration on OddsQuotaManager {
  /// Wrap API call with quota checking
  Future<T?> executeWithQuota<T>({
    required String sport,
    required Future<T?> Function() apiCall,
    T? Function()? getCached,
  }) async {
    // Check if should use cache
    if (shouldUseCache(sport)) {
      if (getCached != null) {
        final cached = getCached();
        if (cached != null) {
          debugPrint('✅ Using cached data for $sport (quota preservation)');
          return cached;
        }
      }
    }
    
    // Check if can make request
    if (!canMakeRequest(sport)) {
      debugPrint(getFallbackRecommendation(sport));
      if (getCached != null) {
        return getCached();
      }
      return null;
    }
    
    // Make API call
    try {
      final result = await apiCall();
      if (result != null) {
        await recordUsage(sport);
      }
      return result;
    } catch (e) {
      debugPrint('Error in quota-managed API call: $e');
      return null;
    }
  }
}