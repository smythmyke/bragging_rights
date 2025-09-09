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
  final Map<String, bool> _expandedPlayers = {};
  final Map<String, bool> _expandedPositions = {};
  
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
        
        // Props List
        Expanded(
          child: _buildPropsList(),
        ),
      ],
    );
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
    
    // Group players
    final starPlayers = displayPlayers
        .where((p) => p.isStar)
        .toList()
      ..sort((a, b) => b.propCount.compareTo(a.propCount));
    
    final positionGroups = <String, List<PlayerProps>>{};
    for (final player in displayPlayers.where((p) => !p.isStar)) {
      if (!positionGroups.containsKey(player.position)) {
        positionGroups[player.position] = [];
      }
      positionGroups[player.position]!.add(player);
    }
    
    // Sort players within each position by prop count
    positionGroups.forEach((pos, players) {
      players.sort((a, b) => b.propCount.compareTo(a.propCount));
    });
    
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
        
        // Star Players Section
        if (starPlayers.isNotEmpty) ...[
          _buildSectionHeader('⭐ Star Players', true),
          const SizedBox(height: 8),
          ...starPlayers.map((player) => _buildPlayerCard(player)),
          const SizedBox(height: 16),
        ],
        
        // Position Groups
        ...positionGroups.entries.map((entry) {
          final position = entry.key;
          final players = entry.value.take(5).toList(); // Limit to 5 per position
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPositionHeader(position, players.length),
              if (_expandedPositions[position] ?? false) ...[
                const SizedBox(height: 8),
                ...players.map((player) => _buildPlayerCard(player)),
              ],
              const SizedBox(height: 16),
            ],
          );
        }),
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
  
  Widget _buildPositionHeader(String position, int count) {
    final isExpanded = _expandedPositions[position] ?? false;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedPositions[position] = !isExpanded;
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
              _getPositionDisplayName(position),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
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
  
  Widget _buildPlayerCard(PlayerProps player) {
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
          
          // Player Props
          if (isExpanded) ...[
            const Divider(height: 1),
            ...player.props.map((prop) => _buildPropItem(player, prop)),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPropItem(PlayerProps player, PropOption prop) {
    final propId = '${player.name}_${prop.marketKey}';
    
    if (prop.isOverUnder) {
      // Over/Under prop with two options
      return Column(
        children: [
          _buildPropOption(
            propId: '${propId}_over',
            title: '${prop.displayName} Over ${prop.formattedLine}',
            odds: prop.formatOdds(prop.overOdds),
            player: player,
          ),
          _buildPropOption(
            propId: '${propId}_under',
            title: '${prop.displayName} Under ${prop.formattedLine}',
            odds: prop.formatOdds(prop.underOdds),
            player: player,
          ),
        ],
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