import 'package:flutter/material.dart';
import '../models/props_models.dart';
import '../screens/betting/bet_selection_screen.dart';

class PropsTabContent extends StatefulWidget {
  final PropsTabData propsData;
  final Function(String id, String title, String odds, BetType type) onBetSelected;
  final Set<String> selectedBetIds;
  final VoidCallback onRefresh;
  
  const PropsTabContent({
    super.key,
    required this.propsData,
    required this.onBetSelected,
    required this.selectedBetIds,
    required this.onRefresh,
  });

  @override
  State<PropsTabContent> createState() => _PropsTabContentState();
}

class _PropsTabContentState extends State<PropsTabContent> {
  String _searchQuery = '';
  bool _showHomeTeam = true;
  String? _selectedCategory;
  final Map<String, bool> _expandedPlayers = {};
  final Map<String, bool> _expandedCategories = {};
  
  // Football prop categories
  static const Map<String, List<String>> _propCategories = {
    'PASSING': [
      'player_pass_tds', 'player_pass_yds', 'player_pass_completions',
      'player_pass_attempts', 'player_interceptions'
    ],
    'RUSHING': [
      'player_rush_yds', 'player_rush_attempts', 'player_rush_tds',
      'player_longest_rush'
    ],
    'RECEIVING': [
      'player_reception_yds', 'player_receptions', 'player_reception_tds',
      'player_longest_reception'
    ],
    'SCORING': [
      'player_anytime_td', 'player_1st_td', 'player_last_td',
      'player_2_plus_tds', 'player_field_goals'
    ],
    'DEFENSIVE': [
      'player_tackles', 'player_sacks', 'player_interceptions_defensive'
    ],
  };
  
  @override
  void initState() {
    super.initState();
    // Auto-expand star players
    for (final starName in widget.propsData.starPlayers) {
      _expandedPlayers[starName] = true;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and Team Toggle
        _buildHeaderControls(),
        
        // Category Filter
        _buildCategoryFilter(),
        
        // Props List
        Expanded(
          child: _buildPropsList(),
        ),
      ],
    );
  }
  
  Widget _buildCategoryFilter() {
    final availableCategories = _getAvailableCategories();
    
    if (availableCategories.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('All', null),
          const SizedBox(width: 8),
          ...availableCategories.map((category) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildFilterChip(category, category),
          )),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedCategory = selected ? value : null;
        });
      },
      selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      checkmarkColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  List<String> _getAvailableCategories() {
    final categories = <String>{};
    final players = widget.propsData.getTeamPlayers(_showHomeTeam);
    
    for (final player in players) {
      for (final prop in player.props) {
        final category = _getPropCategory(prop.marketKey);
        if (category != null && category != 'OTHER') {
          categories.add(category);
        }
      }
    }
    
    // Sort categories in desired order
    final orderedCategories = <String>[];
    for (final cat in ['PASSING', 'RUSHING', 'RECEIVING', 'SCORING', 'DEFENSIVE']) {
      if (categories.contains(cat)) {
        orderedCategories.add(cat);
      }
    }
    
    return orderedCategories;
  }
  
  String? _getPropCategory(String marketKey) {
    for (final entry in _propCategories.entries) {
      if (entry.value.contains(marketKey)) {
        return entry.key;
      }
    }
    return 'OTHER';
  }
  
  Widget _buildHeaderControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search player name...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          const SizedBox(height: 12),
          
          // Team Toggle
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHomeTeam = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _showHomeTeam ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.propsData.homeTeam,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _showHomeTeam ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHomeTeam = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_showHomeTeam ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.propsData.awayTeam,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: !_showHomeTeam ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPropsList() {
    List<PlayerProps> displayPlayers;
    
    if (_searchQuery.isNotEmpty) {
      // Search mode
      displayPlayers = widget.propsData.searchPlayers(_searchQuery);
      
      if (displayPlayers.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No players found for "$_searchQuery"',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }
    } else {
      // Team view mode
      displayPlayers = widget.propsData.getTeamPlayers(_showHomeTeam);
    }
    
    // Filter by category if selected
    if (_selectedCategory != null) {
      displayPlayers = displayPlayers.where((player) {
        return player.props.any((prop) => 
          _getPropCategory(prop.marketKey) == _selectedCategory
        );
      }).toList();
    }
    
    if (displayPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No player props available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onRefresh,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    
    // Group players by category based on their props
    final categoryGroups = <String, List<PlayerProps>>{};
    final starPlayers = <PlayerProps>[];
    
    for (final player in displayPlayers) {
      if (player.isStar) {
        starPlayers.add(player);
      }
      
      // Group by prop categories
      final playerCategories = <String>{};
      for (final prop in player.props) {
        final category = _getPropCategory(prop.marketKey) ?? 'OTHER';
        if (_selectedCategory == null || category == _selectedCategory) {
          playerCategories.add(category);
        }
      }
      
      for (final category in playerCategories) {
        if (!categoryGroups.containsKey(category)) {
          categoryGroups[category] = [];
        }
        if (!categoryGroups[category]!.contains(player)) {
          categoryGroups[category]!.add(player);
        }
      }
    }
    
    // Sort players within each category by prop count
    categoryGroups.forEach((cat, players) {
      players.sort((a, b) {
        if (a.isStar && !b.isStar) return -1;
        if (!a.isStar && b.isStar) return 1;
        return b.propCount.compareTo(a.propCount);
      });
    });
    
    starPlayers.sort((a, b) => b.propCount.compareTo(a.propCount));
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Refresh indicator
        if (!widget.propsData.isCacheValid)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Props data may be stale',
                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                  ),
                ),
                TextButton(
                  onPressed: widget.onRefresh,
                  child: const Text('Refresh'),
                ),
              ],
            ),
          ),
        
        // Star Players Section (only if no category filter)
        if (starPlayers.isNotEmpty && _selectedCategory == null) ...[
          _buildSectionHeader('⭐ Star Players', true),
          const SizedBox(height: 8),
          ...starPlayers.map((player) => _buildPlayerCard(player)),
          const SizedBox(height: 16),
        ],
        
        // Category Groups
        ..._buildCategoryGroups(categoryGroups),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, bool alwaysExpanded) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  List<Widget> _buildCategoryGroups(Map<String, List<PlayerProps>> categoryGroups) {
    final widgets = <Widget>[];
    
    // Order categories properly with OTHER last
    final orderedCategories = <String>[];
    for (final cat in ['PASSING', 'RUSHING', 'RECEIVING', 'SCORING', 'DEFENSIVE']) {
      if (categoryGroups.containsKey(cat)) {
        orderedCategories.add(cat);
      }
    }
    if (categoryGroups.containsKey('OTHER')) {
      orderedCategories.add('OTHER');
    }
    
    for (final category in orderedCategories) {
      final players = categoryGroups[category]!;
      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryHeader(category, players.length),
            if (_expandedCategories[category] ?? true) ...[
              const SizedBox(height: 8),
              ...players.map((player) => _buildPlayerCard(player, category)),
            ],
            const SizedBox(height: 16),
          ],
        ),
      );
    }
    
    return widgets;
  }
  
  Widget _buildCategoryHeader(String category, int count) {
    final isExpanded = _expandedCategories[category] ?? true;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedCategories[category] = !isExpanded;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              category,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerCard(PlayerProps player, [String? filterCategory]) {
    final isExpanded = _expandedPlayers[player.name] ?? player.isStar;
    final isHighlighted = _searchQuery.isNotEmpty && 
        player.name.toLowerCase().contains(_searchQuery.toLowerCase());
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.yellow.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted 
              ? Colors.yellow 
              : player.isStar 
                  ? Colors.amber.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
          width: player.isStar ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Player Header
          ListTile(
            onTap: () {
              setState(() {
                _expandedPlayers[player.name] = !isExpanded;
              });
            },
            leading: CircleAvatar(
              backgroundColor: player.isStar 
                  ? Colors.amber 
                  : Theme.of(context).primaryColor.withOpacity(0.2),
              child: Text(
                player.position,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: player.isStar ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
            ),
            title: Row(
              children: [
                if (player.isStar)
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    player.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${player.props.length} props available',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
          ),
          
          // Player Props (filtered by category if provided)
          if (isExpanded) ...[
            const Divider(height: 1),
            ...(filterCategory != null 
              ? player.props.where((prop) => 
                  _getPropCategory(prop.marketKey) == filterCategory)
              : player.props
            ).map((prop) => _buildPropItem(player, prop)),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPropItem(PlayerProps player, PropOption prop) {
    final propId = '${player.name}_${prop.marketKey}';
    
    if (prop.isOverUnder) {
      // Over/Under prop - display both on same row
      final overBetId = '${propId}_over';
      final underBetId = '${propId}_under';
      final isOverSelected = widget.selectedBetIds.contains(overBetId);
      final isUnderSelected = widget.selectedBetIds.contains(underBetId);
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prop title with line
            Text(
              '${prop.displayName} ${prop.formattedLine}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // Over and Under buttons in a row
            Row(
              children: [
                // Over button
                Expanded(
                  child: _buildCompactBetButton(
                    label: 'Over',
                    odds: prop.formatOdds(prop.overOdds),
                    isSelected: isOverSelected,
                    onTap: () {
                      widget.onBetSelected(
                        overBetId,
                        '${player.name} ${prop.displayName} Over ${prop.formattedLine}',
                        prop.formatOdds(prop.overOdds),
                        BetType.prop,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Under button
                Expanded(
                  child: _buildCompactBetButton(
                    label: 'Under',
                    odds: prop.formatOdds(prop.underOdds),
                    isSelected: isUnderSelected,
                    onTap: () {
                      widget.onBetSelected(
                        underBetId,
                        '${player.name} ${prop.displayName} Under ${prop.formattedLine}',
                        prop.formatOdds(prop.underOdds),
                        BetType.prop,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Straight prop (like Anytime TD)
      return _buildPropOption(
        propId: propId,
        title: prop.displayName,
        odds: prop.formatOdds(prop.straightOdds),
        player: player,
      );
    }
  }
  
  Widget _buildCompactBetButton({
    required String label,
    required String odds,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor.withOpacity(0.2)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.black87,
              ),
            ),
            Text(
              odds.isEmpty ? '--' : odds,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected 
                    ? Theme.of(context).primaryColor 
                    : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPropOption({
    required String propId,
    required String title,
    required String odds,
    required PlayerProps player,
  }) {
    final isSelected = widget.selectedBetIds.contains(propId);
    
    return ListTile(
      onTap: () {
        widget.onBetSelected(
          propId,
          '${player.name} $title',
          odds,
          BetType.prop,
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          odds,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
  
  String _getPositionDisplayName(String position) {
    final Map<String, String> displayNames = {
      'QB': 'Quarterbacks',
      'RB': 'Running Backs',
      'WR': 'Wide Receivers',
      'TE': 'Tight Ends',
      'WR/TE': 'Receivers',
      'K': 'Kickers',
      'DEF': 'Defense',
      'Player': 'Players',
      'P': 'Pitchers',
      'Batter': 'Batters',
    };
    
    return displayNames[position] ?? position;
  }
}