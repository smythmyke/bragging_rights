import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Weather Service using OpenWeatherMap API
/// Provides weather data for outdoor sports venues
/// Free tier: 1000 calls/day, 60 calls/minute
class WeatherService {
  // OpenWeatherMap API (free tier available)
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';
  static const String _apiKey = ''; // Get from https://openweathermap.org/api
  
  // Cache weather data to minimize API calls
  final Map<String, CachedWeather> _cache = {};
  
  // Stadium/Venue coordinates for major outdoor sports
  static const Map<String, VenueLocation> _venues = {
    // NFL Stadiums (outdoor)
    'Lambeau Field': VenueLocation(44.5013, -88.0622, 'Green Bay Packers'),
    'Highmark Stadium': VenueLocation(42.7738, -78.7870, 'Buffalo Bills'),
    'GEHA Field at Arrowhead': VenueLocation(39.0489, -94.4839, 'Kansas City Chiefs'),
    'Soldier Field': VenueLocation(41.8623, -87.6167, 'Chicago Bears'),
    'MetLife Stadium': VenueLocation(40.8135, -74.0745, 'NY Giants/Jets'),
    'Gillette Stadium': VenueLocation(42.0909, -71.2643, 'New England Patriots'),
    'Heinz Field': VenueLocation(40.4468, -80.0158, 'Pittsburgh Steelers'),
    'FirstEnergy Stadium': VenueLocation(41.5061, -81.6995, 'Cleveland Browns'),
    'M&T Bank Stadium': VenueLocation(39.2780, -76.6227, 'Baltimore Ravens'),
    'Nissan Stadium': VenueLocation(36.1665, -86.7713, 'Tennessee Titans'),
    'TIAA Bank Field': VenueLocation(30.3239, -81.6373, 'Jacksonville Jaguars'),
    'Hard Rock Stadium': VenueLocation(25.9580, -80.2389, 'Miami Dolphins'),
    'Raymond James Stadium': VenueLocation(27.9759, -82.5033, 'Tampa Bay Buccaneers'),
    'Bank of America Stadium': VenueLocation(35.2258, -80.8528, 'Carolina Panthers'),
    'Empower Field': VenueLocation(39.7439, -105.0202, 'Denver Broncos'),
    'Lumen Field': VenueLocation(47.5952, -122.3316, 'Seattle Seahawks'),
    'Levi\'s Stadium': VenueLocation(37.4033, -121.9694, 'San Francisco 49ers'),
    
    // MLB Stadiums (all outdoor except domed)
    'Fenway Park': VenueLocation(42.3467, -71.0972, 'Boston Red Sox'),
    'Yankee Stadium': VenueLocation(40.8296, -73.9262, 'New York Yankees'),
    'Citi Field': VenueLocation(40.7571, -73.8458, 'New York Mets'),
    'Wrigley Field': VenueLocation(41.9484, -87.6553, 'Chicago Cubs'),
    'Dodger Stadium': VenueLocation(34.0739, -118.2400, 'Los Angeles Dodgers'),
    'Oracle Park': VenueLocation(37.7786, -122.3893, 'San Francisco Giants'),
    'Petco Park': VenueLocation(32.7076, -117.1570, 'San Diego Padres'),
    'Coors Field': VenueLocation(39.7559, -104.9942, 'Colorado Rockies'),
    'Busch Stadium': VenueLocation(38.6226, -90.1928, 'St. Louis Cardinals'),
    'PNC Park': VenueLocation(40.4469, -80.0057, 'Pittsburgh Pirates'),
    'Camden Yards': VenueLocation(39.2838, -76.6218, 'Baltimore Orioles'),
    'Nationals Park': VenueLocation(38.8730, -77.0074, 'Washington Nationals'),
    'Citizens Bank Park': VenueLocation(39.9061, -75.1665, 'Philadelphia Phillies'),
    'Progressive Field': VenueLocation(41.4962, -81.6852, 'Cleveland Guardians'),
    'Comerica Park': VenueLocation(42.3390, -83.0485, 'Detroit Tigers'),
    'Target Field': VenueLocation(44.9817, -93.2776, 'Minnesota Twins'),
    'Kauffman Stadium': VenueLocation(39.0517, -94.4803, 'Kansas City Royals'),
    'Angel Stadium': VenueLocation(33.8003, -117.8827, 'Los Angeles Angels'),
    'Oakland Coliseum': VenueLocation(37.7516, -122.2006, 'Oakland Athletics'),
    'T-Mobile Park': VenueLocation(47.5914, -122.3325, 'Seattle Mariners'),
    
    // Tennis Venues (major tournaments)
    'Arthur Ashe Stadium': VenueLocation(40.7500, -73.8450, 'US Open'),
    'Indian Wells': VenueLocation(33.7239, -116.3055, 'BNP Paribas Open'),
    'Miami Open': VenueLocation(25.7089, -80.1618, 'Miami Open'),
    
    // Golf Courses (major)
    'Augusta National': VenueLocation(33.5020, -82.0227, 'The Masters'),
    'Pebble Beach': VenueLocation(36.5686, -121.9495, 'AT&T Pebble Beach'),
    'TPC Sawgrass': VenueLocation(30.1975, -81.3947, 'The Players Championship'),
  };
  
  // Singleton instance
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();
  
  /// Get weather for a specific venue
  Future<WeatherData?> getVenueWeather(String venueName) async {
    // Check cache first
    final cached = _getCachedWeather(venueName);
    if (cached != null) {
      debugPrint('✅ Using cached weather for $venueName');
      return cached;
    }
    
    // Get venue location
    final venue = _venues[venueName];
    if (venue == null) {
      debugPrint('❌ Unknown venue: $venueName');
      return null;
    }
    
    return await getWeatherByCoordinates(
      venue.latitude,
      venue.longitude,
      venueName,
    );
  }
  
  /// Get weather by coordinates
  Future<WeatherData?> getWeatherByCoordinates(
    double lat,
    double lon,
    String locationName,
  ) async {
    if (_apiKey.isEmpty) {
      debugPrint('⚠️ OpenWeatherMap API key not set');
      return _getMockWeather(locationName);
    }
    
    try {
      final url = '$_baseUrl/weather?'
          'lat=$lat&lon=$lon'
          '&appid=$_apiKey'
          '&units=imperial'; // Use imperial for US sports
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final weather = WeatherData.fromJson(data, locationName);
        
        // Cache the result
        _cacheWeather(locationName, weather);
        
        return weather;
      } else {
        debugPrint('❌ Weather API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
      return _getMockWeather(locationName);
    }
  }
  
  /// Get weather impact on game
  Map<String, dynamic> getWeatherImpact(WeatherData weather, String sport) {
    final impact = <String, dynamic>{
      'severity': 'low',
      'factors': [],
      'insights': [],
    };
    
    // Temperature impact
    if (weather.temperature < 32) {
      impact['factors'].add('freezing');
      impact['severity'] = 'high';
      if (sport == 'nfl') {
        impact['insights'].add('Cold weather favors running game');
        impact['insights'].add('Potential for fumbles increases');
      }
    } else if (weather.temperature > 90) {
      impact['factors'].add('heat');
      impact['severity'] = 'medium';
      impact['insights'].add('Player fatigue will be a factor');
    }
    
    // Wind impact
    if (weather.windSpeed > 20) {
      impact['factors'].add('high_wind');
      impact['severity'] = 'high';
      if (sport == 'nfl') {
        impact['insights'].add('Passing game will be affected');
        impact['insights'].add('Field goals difficult beyond 40 yards');
      } else if (sport == 'mlb') {
        impact['insights'].add('Fly balls affected significantly');
        impact['insights'].add('Wind direction: ${weather.windDirection}°');
      }
    } else if (weather.windSpeed > 10) {
      impact['factors'].add('moderate_wind');
      impact['severity'] = 'medium';
    }
    
    // Precipitation impact
    if (weather.condition.toLowerCase().contains('rain')) {
      impact['factors'].add('rain');
      impact['severity'] = 'high';
      if (sport == 'nfl') {
        impact['insights'].add('Ball security crucial');
        impact['insights'].add('Under bet more likely');
      } else if (sport == 'mlb') {
        impact['insights'].add('Possible rain delay');
      }
    } else if (weather.condition.toLowerCase().contains('snow')) {
      impact['factors'].add('snow');
      impact['severity'] = 'very_high';
      impact['insights'].add('Severe weather conditions');
      impact['insights'].add('Low-scoring game likely');
    }
    
    // Humidity impact (for baseball)
    if (sport == 'mlb' && weather.humidity > 70) {
      impact['factors'].add('high_humidity');
      impact['insights'].add('Ball travels less in humid air');
    }
    
    return impact;
  }
  
  /// Check if weather is suitable for outdoor sports
  bool isPlayable(WeatherData weather) {
    // Lightning is automatic postponement
    if (weather.condition.toLowerCase().contains('thunder')) {
      return false;
    }
    
    // Heavy snow or ice
    if (weather.condition.toLowerCase().contains('blizzard') ||
        weather.condition.toLowerCase().contains('ice')) {
      return false;
    }
    
    // Extreme temperatures
    if (weather.temperature < -10 || weather.temperature > 110) {
      return false;
    }
    
    // Extreme wind
    if (weather.windSpeed > 50) {
      return false;
    }
    
    return true;
  }
  
  // Cache management
  WeatherData? _getCachedWeather(String location) {
    final cached = _cache[location];
    if (cached == null) return null;
    
    // Weather data is valid for 30 minutes
    if (DateTime.now().difference(cached.timestamp).inMinutes > 30) {
      _cache.remove(location);
      return null;
    }
    
    return cached.data;
  }
  
  void _cacheWeather(String location, WeatherData weather) {
    _cache[location] = CachedWeather(weather, DateTime.now());
  }
  
  /// Get mock weather data when API is unavailable
  WeatherData _getMockWeather(String location) {
    // Return reasonable defaults for testing
    return WeatherData(
      location: location,
      temperature: 72,
      feelsLike: 70,
      condition: 'Clear',
      description: 'Clear sky',
      humidity: 50,
      windSpeed: 8,
      windDirection: 180,
      pressure: 1013,
      visibility: 10,
      cloudiness: 20,
      timestamp: DateTime.now(),
    );
  }
  
  /// Get all outdoor venues
  List<String> getOutdoorVenues() => _venues.keys.toList();
  
  /// Check if venue is outdoor
  bool isOutdoorVenue(String venueName) => _venues.containsKey(venueName);
}

/// Weather data model
class WeatherData {
  final String location;
  final double temperature;
  final double feelsLike;
  final String condition;
  final String description;
  final int humidity;
  final double windSpeed;
  final int windDirection;
  final double pressure;
  final double visibility;
  final int cloudiness;
  final DateTime timestamp;
  
  WeatherData({
    required this.location,
    required this.temperature,
    required this.feelsLike,
    required this.condition,
    required this.description,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.pressure,
    required this.visibility,
    required this.cloudiness,
    required this.timestamp,
  });
  
  factory WeatherData.fromJson(Map<String, dynamic> json, String location) {
    return WeatherData(
      location: location,
      temperature: json['main']['temp'].toDouble(),
      feelsLike: json['main']['feels_like'].toDouble(),
      condition: json['weather'][0]['main'],
      description: json['weather'][0]['description'],
      humidity: json['main']['humidity'],
      windSpeed: json['wind']['speed'].toDouble(),
      windDirection: json['wind']['deg'] ?? 0,
      pressure: json['main']['pressure'].toDouble(),
      visibility: (json['visibility'] ?? 10000) / 1000, // Convert to km
      cloudiness: json['clouds']['all'] ?? 0,
      timestamp: DateTime.now(),
    );
  }
  
  /// Get formatted weather summary
  String get summary {
    return '$condition, ${temperature.round()}°F (feels like ${feelsLike.round()}°F), '
           'Wind: ${windSpeed.round()} mph, Humidity: $humidity%';
  }
  
  /// Get wind direction as compass direction
  String get windCompass {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((windDirection + 22.5) / 45).floor() % 8;
    return directions[index];
  }
  
  Map<String, dynamic> toMap() {
    return {
      'location': location,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'condition': condition,
      'description': description,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'windDirection': windDirection,
      'windCompass': windCompass,
      'pressure': pressure,
      'visibility': visibility,
      'cloudiness': cloudiness,
      'timestamp': timestamp.toIso8601String(),
      'summary': summary,
    };
  }
}

/// Venue location data
class VenueLocation {
  final double latitude;
  final double longitude;
  final String team;
  
  const VenueLocation(this.latitude, this.longitude, this.team);
}

/// Cached weather data
class CachedWeather {
  final WeatherData data;
  final DateTime timestamp;
  
  CachedWeather(this.data, this.timestamp);
}