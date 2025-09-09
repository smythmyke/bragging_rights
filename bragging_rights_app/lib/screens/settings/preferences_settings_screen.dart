import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_preferences_service.dart';
import '../../models/user_preferences.dart';

class PreferencesSettingsScreen extends StatefulWidget {
  const PreferencesSettingsScreen({super.key});

  @override
  State<PreferencesSettingsScreen> createState() => _PreferencesSettingsScreenState();
}

class _PreferencesSettingsScreenState extends State<PreferencesSettingsScreen> {
  final UserPreferencesService _prefsService = UserPreferencesService();
  UserPreferences? _preferences;
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Available sports
  final List<String> _availableSports = [
    'NFL', 'NBA', 'NHL', 'MLB', 'MMA', 'Boxing', 'Tennis', 'Soccer'
  ];
  
  // Selected sports
  Set<String> _selectedSports = {};
  
  // Settings
  bool _showLiveGamesFirst = true;
  bool _autoLoadOdds = false;
  int _maxGamesPerSport = 5;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    try {
      final prefs = await _prefsService.getUserPreferences();
      
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _selectedSports = prefs.favoriteSports.map((s) => s.toUpperCase()).toSet();
          _showLiveGamesFirst = prefs.showLiveGamesFirst;
          _autoLoadOdds = prefs.autoLoadOdds;
          _maxGamesPerSport = prefs.maxGamesPerSport;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _savePreferences() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final updatedPrefs = UserPreferences(
        userId: user.uid,
        favoriteSports: _selectedSports.map((s) => s.toLowerCase()).toList(),
        favoriteTeams: _preferences?.favoriteTeams ?? [],
        showLiveGamesFirst: _showLiveGamesFirst,
        autoLoadOdds: _autoLoadOdds,
        maxGamesPerSport: _maxGamesPerSport,
      );
      
      await _prefsService.saveUserPreferences(updatedPrefs);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferences saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[SETTINGS] Building PreferencesSettingsScreen');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Preferences'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Favorite Sports Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Favorite Sports',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select your favorite sports to see them first',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableSports.map((sport) {
                              final isSelected = _selectedSports.contains(sport);
                              return FilterChip(
                                label: Text(sport),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSports.add(sport);
                                    } else {
                                      // Keep at least one sport selected
                                      if (_selectedSports.length > 1) {
                                        _selectedSports.remove(sport);
                                      }
                                    }
                                  });
                                },
                                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                checkmarkColor: Theme.of(context).colorScheme.primary,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Display Settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Display Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Show Live Games First'),
                            subtitle: const Text('Prioritize live games at the top'),
                            value: _showLiveGamesFirst,
                            onChanged: (value) {
                              setState(() {
                                _showLiveGamesFirst = value;
                              });
                            },
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text('Games Per Sport'),
                            subtitle: Text('Show $_maxGamesPerSport games per sport initially'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: _maxGamesPerSport > 3 ? () {
                                    setState(() {
                                      _maxGamesPerSport--;
                                    });
                                  } : null,
                                ),
                                Text(
                                  '$_maxGamesPerSport',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: _maxGamesPerSport < 10 ? () {
                                    setState(() {
                                      _maxGamesPerSport++;
                                    });
                                  } : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Performance Settings
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Performance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Auto-Load Odds'),
                            subtitle: const Text('Automatically fetch odds for all games (uses more data)'),
                            value: _autoLoadOdds,
                            onChanged: (value) {
                              setState(() {
                                _autoLoadOdds = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info Card
                  Card(
                    color: Colors.blue.withOpacity(0.1),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'These preferences help optimize app performance and reduce data usage by loading only the sports and games you care about.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}