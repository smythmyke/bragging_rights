import 'package:flutter/material.dart';
import '../models/props_models.dart';
import '../screens/betting/bet_selection_screen.dart';

/// Individual player props detail screen
class PropsPlayerDetail extends StatefulWidget {
  final PlayerProps player;
  final PropsTabData propsData;
  final Function(String id, String title, String odds, dynamic type) onBetSelected;
  final Set<String> selectedBetIds;
  
  const PropsPlayerDetail({
    super.key,
    required this.player,
    required this.propsData,
    required this.onBetSelected,
    required this.selectedBetIds,
  });

  @override
  State<PropsPlayerDetail> createState() => _PropsPlayerDetailState();
}

class _PropsPlayerDetailState extends State<PropsPlayerDetail> {
  String? _selectedFilter;
  
  // Prop categories for baseball
  static const Map<String, List<String>> _propCategories = {
    'HITTING': [
      'batter_hits', 'batter_home_runs', 'batter_rbis',
      'batter_runs_scored', 'batter_singles', 'batter_doubles',
      'batter_triples', 'batter_walks', 'batter_strikeouts'
    ],
    'BASES': [
      'batter_total_bases', 'batter_stolen_bases'
    ],
    'PITCHING': [
      'pitcher_strikeouts', 'pitcher_hits_allowed', 
      'pitcher_earned_runs', 'pitcher_walks', 'pitcher_wins',
      'pitcher_outs', 'pitcher_innings'
    ],
  };
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.player.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.player.position} - ${widget.player.team}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.player.isStar)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const Icon(
                Icons.star,
                color: Colors.amber,
                size: 24,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          
          // Props list
          Expanded(
            child: _buildPropsList(),
          ),
          
          // Bet count indicator
          if (widget.selectedBetIds.isNotEmpty)
            _buildBetCountIndicator(),
        ],
      ),
    );
  }
  
  Widget _buildFilterChips() {
    // Get available categories for this player's props
    final availableCategories = _getAvailableCategories();
    
    if (availableCategories.length <= 1) {
      // Don't show filter if only one category
      return const SizedBox.shrink();
    }
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // All filter
          _buildFilterChip('All', null),
          const SizedBox(width: 8),
          
          // Category filters
          ...availableCategories.map((category) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFilterChip(category, category),
            );
          }),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedFilter == value;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : null;
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
    
    for (final prop in widget.player.props) {
      final category = _getPropCategory(prop.marketKey);
      if (category != null) {
        categories.add(category);
      }
    }
    
    return categories.toList()..sort();
  }
  
  String? _getPropCategory(String marketKey) {
    for (final entry in _propCategories.entries) {
      if (entry.value.contains(marketKey)) {
        return entry.key;
      }
    }
    // Default category for unknown props
    if (marketKey.contains('pitcher')) return 'PITCHING';
    if (marketKey.contains('batter')) return 'HITTING';
    return 'OTHER';
  }
  
  Widget _buildPropsList() {
    // Filter props based on selected category
    final filteredProps = _selectedFilter == null
        ? widget.player.props
        : widget.player.props.where((prop) {
            return _getPropCategory(prop.marketKey) == _selectedFilter;
          }).toList();
    
    if (filteredProps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_baseball, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No props available',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }
    
    // Group props by category
    final propsByCategory = <String, List<PropOption>>{};
    for (final prop in filteredProps) {
      final category = _getPropCategory(prop.marketKey) ?? 'OTHER';
      if (!propsByCategory.containsKey(category)) {
        propsByCategory[category] = [];
      }
      propsByCategory[category]!.add(prop);
    }
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...propsByCategory.entries.map((entry) {
          return _buildCategorySection(entry.key, entry.value);
        }),
      ],
    );
  }
  
  Widget _buildCategorySection(String category, List<PropOption> props) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Text(
            category,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          
          // Props in this category
          ...props.map((prop) => _buildPropCard(prop)),
        ],
      ),
    );
  }
  
  Widget _buildPropCard(PropOption prop) {
    final propId = '${widget.player.name}_${prop.marketKey}_${prop.line}';
    final overBetId = '${propId}_over';
    final underBetId = '${propId}_under';
    final isOverSelected = widget.selectedBetIds.contains(overBetId);
    final isUnderSelected = widget.selectedBetIds.contains(underBetId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prop title
            Text(
              prop.displayText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            if (prop.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                prop.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Over/Under buttons
            if (prop.isOverUnder) ...[
              Row(
                children: [
                  // Over button
                  Expanded(
                    child: _buildBetButton(
                      label: 'Over ${prop.formattedLine}',
                      odds: prop.formatOdds(prop.overOdds),
                      isSelected: isOverSelected,
                      onTap: prop.overOdds != null ? () {
                        final betTitle = '${widget.player.name} - ${prop.displayName} Over ${prop.formattedLine}';
                        widget.onBetSelected(
                          overBetId,
                          betTitle,
                          prop.formatOdds(prop.overOdds),
                          BetType.prop,
                        );
                      } : null,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Under button
                  Expanded(
                    child: _buildBetButton(
                      label: 'Under ${prop.formattedLine}',
                      odds: prop.formatOdds(prop.underOdds),
                      isSelected: isUnderSelected,
                      onTap: prop.underOdds != null ? () {
                        final betTitle = '${widget.player.name} - ${prop.displayName} Under ${prop.formattedLine}';
                        widget.onBetSelected(
                          underBetId,
                          betTitle,
                          prop.formatOdds(prop.underOdds),
                          BetType.prop,
                        );
                      } : null,
                    ),
                  ),
                ],
              ),
            ] else if (prop.straightOdds != null) ...[
              // Straight prop (like Anytime TD)
              _buildBetButton(
                label: prop.displayName,
                odds: prop.formatOdds(prop.straightOdds),
                isSelected: widget.selectedBetIds.contains(propId),
                onTap: () {
                  final betTitle = '${widget.player.name} - ${prop.displayName}';
                  widget.onBetSelected(
                    propId,
                    betTitle,
                    prop.formatOdds(prop.straightOdds),
                    BetType.prop,
                  );
                },
              ),
            ],
            
            // Bookmaker
            if (prop.bookmaker.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'via ${prop.bookmaker}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildBetButton({
    required String label,
    required String odds,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              odds.isEmpty ? '--' : odds,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBetCountIndicator() {
    final selectedCount = widget.selectedBetIds.where((id) {
      // Count only bets for this player
      return id.startsWith(widget.player.name);
    }).length;
    
    if (selectedCount == 0) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$selectedCount prop${selectedCount != 1 ? 's' : ''} selected',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'View Bet Slip',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}