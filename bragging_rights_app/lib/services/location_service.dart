import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum RegionalLevel {
  neighborhood,
  city,
  state,
  national,
}

class RegionInfo {
  final String country;
  final String countryCode;
  final String state;
  final String stateCode;
  final String city;
  final String? neighborhood;
  final String? zipCode;
  final double? latitude;
  final double? longitude;
  final RegionalLevel defaultLevel;

  RegionInfo({
    required this.country,
    required this.countryCode,
    required this.state,
    required this.stateCode,
    required this.city,
    this.neighborhood,
    this.zipCode,
    this.latitude,
    this.longitude,
    required this.defaultLevel,
  });

  factory RegionInfo.fromJson(Map<String, dynamic> json) {
    return RegionInfo(
      country: json['country'] ?? 'United States',
      countryCode: json['countryCode'] ?? 'US',
      state: json['regionName'] ?? json['region'] ?? 'Unknown',
      stateCode: json['region'] ?? '',
      city: json['city'] ?? 'Unknown',
      neighborhood: json['neighborhood'],
      zipCode: json['zip'],
      latitude: json['lat']?.toDouble(),
      longitude: json['lon']?.toDouble(),
      defaultLevel: RegionalLevel.city,
    );
  }

  factory RegionInfo.defaultRegion() {
    return RegionInfo(
      country: 'United States',
      countryCode: 'US',
      state: 'National',
      stateCode: 'US',
      city: 'National',
      defaultLevel: RegionalLevel.national,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'countryCode': countryCode,
      'state': state,
      'stateCode': stateCode,
      'city': city,
      'neighborhood': neighborhood,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'defaultLevel': defaultLevel.toString().split('.').last,
    };
  }
}

class LocationService {
  static const String _ipApiUrl = 'http://ip-api.com/json';
  static const String _ipApiBackupUrl = 'https://ipapi.co/json';
  
  static LocationService? _instance;
  RegionInfo? _cachedRegion;
  DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  LocationService._internal();

  factory LocationService() {
    _instance ??= LocationService._internal();
    return _instance!;
  }

  // Main method to detect user's region
  Future<RegionInfo> detectRegion() async {
    // Check cache first
    if (_cachedRegion != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheDuration) {
        print('Using cached region: ${_cachedRegion!.city}, ${_cachedRegion!.state}');
        return _cachedRegion!;
      }
    }

    try {
      // Method 1: Try IP-based geolocation
      final region = await _detectByIP();
      if (region != null) {
        _cacheRegion(region);
        return region;
      }
    } catch (e) {
      print('IP detection failed: $e');
    }

    try {
      // Method 2: Fallback to device locale
      final region = await _detectByLocale();
      if (region != null) {
        _cacheRegion(region);
        return region;
      }
    } catch (e) {
      print('Locale detection failed: $e');
    }

    // Method 3: Default to national level
    print('All detection methods failed, using default national region');
    final defaultRegion = RegionInfo.defaultRegion();
    _cacheRegion(defaultRegion);
    return defaultRegion;
  }

  // IP-based geolocation
  Future<RegionInfo?> _detectByIP() async {
    try {
      // Try primary API
      final response = await http.get(
        Uri.parse(_ipApiUrl),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          print('IP location detected: ${data['city']}, ${data['regionName']}, ${data['country']}');
          return RegionInfo.fromJson(data);
        }
      }
    } catch (e) {
      print('Primary IP API failed, trying backup: $e');
      
      // Try backup API
      try {
        final response = await http.get(
          Uri.parse(_ipApiBackupUrl),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('Backup IP location detected: ${data['city']}, ${data['region']}, ${data['country_name']}');
          
          // Adapt backup API response format
          return RegionInfo(
            country: data['country_name'] ?? 'United States',
            countryCode: data['country'] ?? 'US',
            state: data['region'] ?? 'Unknown',
            stateCode: data['region_code'] ?? '',
            city: data['city'] ?? 'Unknown',
            zipCode: data['postal'],
            latitude: data['latitude']?.toDouble(),
            longitude: data['longitude']?.toDouble(),
            defaultLevel: RegionalLevel.city,
          );
        }
      } catch (backupError) {
        print('Backup IP API also failed: $backupError');
      }
    }
    
    return null;
  }

  // Fallback to device locale
  Future<RegionInfo?> _detectByLocale() async {
    try {
      final locale = Platform.localeName; // e.g., "en_US"
      print('Device locale: $locale');
      
      if (locale.contains('_')) {
        final parts = locale.split('_');
        final countryCode = parts.length > 1 ? parts[1].substring(0, 2) : 'US';
        
        // Map common country codes to regions
        final countryName = _getCountryName(countryCode);
        
        return RegionInfo(
          country: countryName,
          countryCode: countryCode,
          state: 'National',
          stateCode: countryCode,
          city: 'National',
          defaultLevel: RegionalLevel.national,
        );
      }
    } catch (e) {
      print('Locale detection error: $e');
    }
    
    return null;
  }

  // Get pools for user's region at different levels
  Map<RegionalLevel, String> getRegionalPoolFilters(RegionInfo region) {
    return {
      RegionalLevel.neighborhood: '${region.city}-${region.zipCode ?? "local"}',
      RegionalLevel.city: region.city,
      RegionalLevel.state: region.state,
      RegionalLevel.national: region.country,
    };
  }

  // Determine which regional level to show by default
  RegionalLevel getDefaultRegionalLevel(RegionInfo region) {
    // If we have good location data, start with city level
    if (region.city != 'Unknown' && region.city != 'National') {
      return RegionalLevel.city;
    }
    // Otherwise default to national
    return RegionalLevel.national;
  }

  // Cache the region info
  void _cacheRegion(RegionInfo region) {
    _cachedRegion = region;
    _cacheTime = DateTime.now();
  }

  // Clear cache (useful for testing or manual refresh)
  void clearCache() {
    _cachedRegion = null;
    _cacheTime = null;
  }

  // Helper method to get country name from code
  String _getCountryName(String code) {
    final countryMap = {
      'US': 'United States',
      'CA': 'Canada',
      'GB': 'United Kingdom',
      'AU': 'Australia',
      'NZ': 'New Zealand',
      'IN': 'India',
      'MX': 'Mexico',
      'BR': 'Brazil',
      'FR': 'France',
      'DE': 'Germany',
      'ES': 'Spain',
      'IT': 'Italy',
      'JP': 'Japan',
      'CN': 'China',
      'KR': 'South Korea',
    };
    
    return countryMap[code.toUpperCase()] ?? 'International';
  }

  // Get a formatted string for display
  String getRegionalDisplayString(RegionInfo region, RegionalLevel level) {
    switch (level) {
      case RegionalLevel.neighborhood:
        return '${region.neighborhood ?? region.city} Neighborhood';
      case RegionalLevel.city:
        return '${region.city} Metro';
      case RegionalLevel.state:
        return region.state;
      case RegionalLevel.national:
        return region.country;
    }
  }
}