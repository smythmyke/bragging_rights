import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service for managing team logos with intelligent caching
/// Uses The-Sports-DB API for complete team coverage
class TeamLogoService {
  static const String _apiBaseUrl = 'https://www.thesportsdb.com/api/v1/json/3';
  static const String _apiKey = '3'; // Free tier key, replace with your own
  
  // Cache duration in days
  static const int _cacheDurationDays = 30;
  
  // Singleton pattern
  static final TeamLogoService _instance = TeamLogoService._internal();
  factory TeamLogoService() => _instance;
  TeamLogoService._internal();

  final Map<String, Uint8List> _memoryCache = {};
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Get team logo with multi-level caching strategy
  /// Priority: Memory > Local File > Firebase > API
  Future<Uint8List?> getTeamLogo({
    required String sport,
    required String teamId,
    required String teamName,
  }) async {
    final cacheKey = '${sport}_$teamId';
    
    // 1. Check memory cache (fastest)
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 2. Check local file cache
    final localLogo = await _getLocalCachedLogo(cacheKey);
    if (localLogo != null) {
      _memoryCache[cacheKey] = localLogo;
      return localLogo;
    }

    // 3. Check Firebase Storage (CDN)
    final firebaseLogo = await _getFirebaseLogo(sport, teamId);
    if (firebaseLogo != null) {
      await _saveToLocalCache(cacheKey, firebaseLogo);
      _memoryCache[cacheKey] = firebaseLogo;
      return firebaseLogo;
    }

    // 4. Fetch from The-Sports-DB API
    final apiLogo = await _fetchFromApi(sport, teamName);
    if (apiLogo != null) {
      // Save to all cache levels
      await _saveToFirebase(sport, teamId, apiLogo);
      await _saveToLocalCache(cacheKey, apiLogo);
      _memoryCache[cacheKey] = apiLogo;
      return apiLogo;
    }

    // 5. Return placeholder if all fails
    return await _getPlaceholderLogo(sport);
  }

  /// Pre-cache popular teams for instant loading
  Future<void> preCachePopularTeams() async {
    final popularTeams = {
      'nba': [
        {'id': 'lakers', 'name': 'Los Angeles Lakers'},
        {'id': 'warriors', 'name': 'Golden State Warriors'},
        {'id': 'celtics', 'name': 'Boston Celtics'},
        {'id': 'heat', 'name': 'Miami Heat'},
        {'id': 'bulls', 'name': 'Chicago Bulls'},
      ],
      'nfl': [
        {'id': 'cowboys', 'name': 'Dallas Cowboys'},
        {'id': 'patriots', 'name': 'New England Patriots'},
        {'id': 'packers', 'name': 'Green Bay Packers'},
        {'id': 'chiefs', 'name': 'Kansas City Chiefs'},
        {'id': '49ers', 'name': 'San Francisco 49ers'},
      ],
      'mlb': [
        {'id': 'yankees', 'name': 'New York Yankees'},
        {'id': 'dodgers', 'name': 'Los Angeles Dodgers'},
        {'id': 'redsox', 'name': 'Boston Red Sox'},
        {'id': 'cubs', 'name': 'Chicago Cubs'},
        {'id': 'giants', 'name': 'San Francisco Giants'},
      ],
      'nhl': [
        {'id': 'rangers', 'name': 'New York Rangers'},
        {'id': 'bruins', 'name': 'Boston Bruins'},
        {'id': 'blackhawks', 'name': 'Chicago Blackhawks'},
        {'id': 'penguins', 'name': 'Pittsburgh Penguins'},
        {'id': 'redwings', 'name': 'Detroit Red Wings'},
      ],
    };

    for (final sport in popularTeams.keys) {
      for (final team in popularTeams[sport]!) {
        await getTeamLogo(
          sport: sport,
          teamId: team['id']!,
          teamName: team['name']!,
        );
      }
    }
  }

  /// Get local cached logo
  Future<Uint8List?> _getLocalCachedLogo(String cacheKey) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/team_logos/$cacheKey.png');
      
      if (await file.exists()) {
        // Check if cache is still valid
        final prefs = await SharedPreferences.getInstance();
        final cachedTime = prefs.getInt('logo_cache_time_$cacheKey') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        if (now - cachedTime < (_cacheDurationDays * 24 * 60 * 60 * 1000)) {
          return await file.readAsBytes();
        }
        
        // Cache expired, delete it
        await file.delete();
      }
    } catch (e) {
      print('Error reading local cache: $e');
    }
    return null;
  }

  /// Save logo to local cache
  Future<void> _saveToLocalCache(String cacheKey, Uint8List data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logosDir = Directory('${directory.path}/team_logos');
      if (!await logosDir.exists()) {
        await logosDir.create(recursive: true);
      }
      
      final file = File('${logosDir.path}/$cacheKey.png');
      await file.writeAsBytes(data);
      
      // Save cache timestamp
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'logo_cache_time_$cacheKey',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error saving to local cache: $e');
    }
  }

  /// Get logo from Firebase Storage
  Future<Uint8List?> _getFirebaseLogo(String sport, String teamId) async {
    try {
      final ref = _storage.ref('team_logos/$sport/$teamId/logo.png');
      final data = await ref.getData();
      return data;
    } catch (e) {
      print('Logo not in Firebase: $e');
      return null;
    }
  }

  /// Save logo to Firebase Storage
  Future<void> _saveToFirebase(String sport, String teamId, Uint8List data) async {
    try {
      final ref = _storage.ref('team_logos/$sport/$teamId/logo.png');
      await ref.putData(
        data,
        SettableMetadata(
          contentType: 'image/png',
          customMetadata: {
            'sport': sport,
            'teamId': teamId,
            'source': 'thesportsdb',
            'cached': DateTime.now().toIso8601String(),
          },
        ),
      );
    } catch (e) {
      print('Error saving to Firebase: $e');
    }
  }

  /// Fetch logo from The-Sports-DB API
  Future<Uint8List?> _fetchFromApi(String sport, String teamName) async {
    try {
      // Map sport codes to league IDs for TheSportsDB
      // Using the most popular leagues for each sport
      final leagueMapping = {
        'nba': '4387', // NBA
        'nfl': '4391', // NFL  
        'mlb': '4424', // MLB
        'nhl': '4380', // NHL
      };

      // First try to get all teams from the league
      // This is more reliable than searching by name
      final leagueId = leagueMapping[sport];
      if (leagueId != null) {
        final teamsUrl = Uri.parse(
          '$_apiBaseUrl/lookup_all_teams.php?id=$leagueId',
        );
        
        final response = await http.get(teamsUrl);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final teams = data['teams'] as List?;
          
          if (teams != null && teams.isNotEmpty) {
            // Find team by name (case insensitive, partial match)
            final team = teams.firstWhere(
              (t) {
                final strTeam = (t['strTeam'] ?? '').toLowerCase();
                final searchName = teamName.toLowerCase();
                return strTeam.contains(searchName) || 
                       searchName.contains(strTeam) ||
                       strTeam.split(' ').any((word) => searchName.contains(word));
              },
              orElse: () => <String, dynamic>{},
            );
            
            if (team.isNotEmpty) {
              // Try different logo fields in order of preference
              final logoUrl = team['strTeamBadge'] ?? 
                             team['strLogo'] ??
                             team['strTeamLogo'];
              
              if (logoUrl != null && logoUrl.toString().isNotEmpty) {
                // Download the logo
                final logoResponse = await http.get(Uri.parse(logoUrl));
                if (logoResponse.statusCode == 200) {
                  return logoResponse.bodyBytes;
                }
              }
            }
          }
        }
      }

      // Fallback: Search by team name if league lookup fails
      final searchUrl = Uri.parse(
        '$_apiBaseUrl/searchteams.php?t=${Uri.encodeComponent(teamName)}',
      );
      
      final searchResponse = await http.get(searchUrl);
      if (searchResponse.statusCode == 200) {
        final data = json.decode(searchResponse.body);
        final teams = data['teams'] as List?;
        
        if (teams != null && teams.isNotEmpty) {
          // Get first result
          final team = teams.first;
          final logoUrl = team['strTeamBadge'] ?? 
                         team['strLogo'] ??
                         team['strTeamLogo'];
          
          if (logoUrl != null && logoUrl.toString().isNotEmpty) {
            final logoResponse = await http.get(Uri.parse(logoUrl));
            if (logoResponse.statusCode == 200) {
              return logoResponse.bodyBytes;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching from TheSportsDB API: $e');
    }
    return null;
  }

  /// Get placeholder logo for sport
  Future<Uint8List?> _getPlaceholderLogo(String sport) async {
    try {
      final assetPath = 'assets/team_logos/placeholders/${sport}_placeholder.png';
      final byteData = await rootBundle.load(assetPath);
      return byteData.buffer.asUint8List();
    } catch (e) {
      // Return generic placeholder if sport-specific not found
      try {
        final byteData = await rootBundle.load('assets/team_logos/placeholders/generic.png');
        return byteData.buffer.asUint8List();
      } catch (e) {
        return null;
      }
    }
  }

  /// Clear all caches (useful for updates)
  Future<void> clearCache() async {
    _memoryCache.clear();
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logosDir = Directory('${directory.path}/team_logos');
      if (await logosDir.exists()) {
        await logosDir.delete(recursive: true);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith('logo_cache_time_'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get cache size in MB
  Future<double> getCacheSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logosDir = Directory('${directory.path}/team_logos');
      
      if (!await logosDir.exists()) return 0.0;
      
      int totalSize = 0;
      await for (final file in logosDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize / (1024 * 1024); // Convert to MB
    } catch (e) {
      return 0.0;
    }
  }
}

/// Extension for easy widget integration
extension TeamLogoWidget on TeamLogoService {
  /// Get a Flutter Image widget for the team logo
  Future<Widget> getTeamLogoWidget({
    required String sport,
    required String teamId,
    required String teamName,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) async {
    final logoData = await getTeamLogo(
      sport: sport,
      teamId: teamId,
      teamName: teamName,
    );

    if (logoData != null) {
      return Image.memory(
        logoData,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return _getPlaceholderWidget(sport, width, height);
        },
      );
    }

    return _getPlaceholderWidget(sport, width, height);
  }

  Widget _getPlaceholderWidget(String sport, double? width, double? height) {
    return Container(
      width: width ?? 50,
      height: height ?? 50,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          _getSportIcon(sport),
          color: Colors.grey[600],
          size: (width ?? 50) * 0.5,
        ),
      ),
    );
  }

  IconData _getSportIcon(String sport) {
    switch (sport) {
      case 'nba':
        return Icons.sports_basketball;
      case 'nfl':
        return Icons.sports_football;
      case 'mlb':
        return Icons.sports_baseball;
      case 'nhl':
        return Icons.sports_hockey;
      default:
        return Icons.sports;
    }
  }
}