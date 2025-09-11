import 'package:flutter/material.dart';
import '../models/props_models.dart';
import 'props_player_detail.dart';

/// Player selection grid screen for props betting
class PropsPlayerSelection extends StatefulWidget {
  final PropsTabData propsData;
  final Function(String id, String title, String odds, dynamic type) onBetSelected;
  final Set<String> selectedBetIds;
  final VoidCallback onRefresh;
  
  const PropsPlayerSelection({
    super.key,
    required this.propsData,
    required this.onBetSelected,
    required this.selectedBetIds,
    required this.onRefresh,
  });

  @override
  State<PropsPlayerSelection> createState() => _PropsPlayerSelectionState();
}

class _PropsPlayerSelectionState extends State<PropsPlayerSelection> {
  bool _showHomeTeam = true;
  final Map<String, bool> _expandedPositions = {};
  
  // Position order for baseball
  static const List<String> _positionOrder = [
    'P', 'SP', 'RP', 'CP', // Pitchers
    'C', // Catcher
    '1B', '2B', '3B', 'SS', // Infielders
    'LF', 'CF', 'RF', 'OF', // Outfielders
    'DH', // Designated Hitter
    'Batter', 'Player', // Generic
  ];
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Team Toggle
        _buildTeamToggle(),
        
        // Player Grid
        Expanded(
          child: _buildPlayerGrid(),
        ),
      ],
    );
  }
  
  Widget _buildTeamToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Container(
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _showHomeTeam = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPlayerGrid() {
    // Get players for selected team
    final teamPlayers = widget.propsData.getTeamPlayers(_showHomeTeam);
    
    if (teamPlayers.isEmpty) {
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
    
    // Group players by position
    final playersByPosition = _groupPlayersByPosition(teamPlayers);
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Refresh indicator if cache is stale
        if (!widget.propsData.isCacheValid)
          _buildRefreshIndicator(),
        
        // Position sections
        ..._buildPositionSections(playersByPosition),
      ],
    );
  }
  
  Widget _buildRefreshIndicator() {
    return Container(
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
    );
  }
  
  Map<String, List<PlayerProps>> _groupPlayersByPosition(List<PlayerProps> players) {
    final grouped = <String, List<PlayerProps>>{};
    
    for (final player in players) {
      final position = _getPositionCategory(player.position);
      if (!grouped.containsKey(position)) {
        grouped[position] = [];
      }
      grouped[position]!.add(player);
    }
    
    // Sort players within each position: stars first, then by prop count
    grouped.forEach((position, playerList) {
      playerList.sort((a, b) {
        // Stars first
        if (a.isStar && !b.isStar) return -1;
        if (!a.isStar && b.isStar) return 1;
        // Then by prop count
        return b.propCount.compareTo(a.propCount);
      });
    });
    
    return grouped;
  }
  
  String _getPositionCategory(String position) {
    // Group positions into categories
    if (['P', 'SP', 'RP', 'CP', 'Pitcher'].contains(position)) {
      return 'PITCHERS';
    } else if (['C'].contains(position)) {
      return 'CATCHERS';
    } else if (['1B', '2B', '3B', 'SS', 'INF'].contains(position)) {
      return 'INFIELDERS';
    } else if (['LF', 'CF', 'RF', 'OF'].contains(position)) {
      return 'OUTFIELDERS';
    } else if (['DH'].contains(position)) {
      return 'DESIGNATED HITTERS';
    } else {
      return 'PLAYERS'; // Generic fallback
    }
  }
  
  List<Widget> _buildPositionSections(Map<String, List<PlayerProps>> playersByPosition) {
    final sections = <Widget>[];
    
    // Build sections in order
    final orderedCategories = [
      'PITCHERS',
      'CATCHERS', 
      'INFIELDERS',
      'OUTFIELDERS',
      'DESIGNATED HITTERS',
      'PLAYERS',
    ];
    
    for (final category in orderedCategories) {
      final players = playersByPosition[category];
      if (players != null && players.isNotEmpty) {
        sections.add(_buildPositionSection(category, players));
      }
    }
    
    return sections;
  }
  
  Widget _buildPositionSection(String position, List<PlayerProps> players) {
    final isExpanded = _expandedPositions[position] ?? true;
    final displayPlayers = isExpanded 
        ? (players.length > 5 ? players.take(5).toList() : players)
        : [];
    final hasMore = players.length > 5;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedPositions[position] = !isExpanded;
              });
            },
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  position,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${players.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          if (isExpanded) ...[
            const SizedBox(height: 12),
            
            // Player grid (2 columns)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: displayPlayers.length,
              itemBuilder: (context, index) {
                return _buildPlayerCard(displayPlayers[index]);
              },
            ),
            
            // Show all button
            if (hasMore)
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    // Show all players in this position
                    _showAllPlayersInPosition(position, players);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    'Show all ${players.length} ${position.toLowerCase()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPlayerCard(PlayerProps player) {
    return GestureDetector(
      onTap: () {
        // Navigate to player props detail screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PropsPlayerDetail(
              player: player,
              propsData: widget.propsData,
              onBetSelected: widget.onBetSelected,
              selectedBetIds: widget.selectedBetIds,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: player.isStar ? Colors.amber.withOpacity(0.5) : Colors.grey[300]!,
            width: player.isStar ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Star indicator
            if (player.isStar)
              Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 24,
                ),
              ),
            
            // Player photo placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(player.name),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Player name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                player.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Position
            Text(
              player.position,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Props count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${player.propCount} props',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }
  
  void _showAllPlayersInPosition(String position, List<PlayerProps> players) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'All $position (${players.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Players grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  return _buildPlayerCard(players[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}