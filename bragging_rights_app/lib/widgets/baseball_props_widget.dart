import 'package:flutter/material.dart';
import '../models/props_models.dart';

class BaseballPropsWidget extends StatefulWidget {
  final Map<String, List<PropOption>> propsByCategory;
  final Function(String id, String title, String odds, dynamic type) onBetSelected;
  final Set<String> selectedBetIds;
  
  const BaseballPropsWidget({
    Key? key,
    required this.propsByCategory,
    required this.onBetSelected,
    required this.selectedBetIds,
  }) : super(key: key);
  
  @override
  State<BaseballPropsWidget> createState() => _BaseballPropsWidgetState();
}

class _BaseballPropsWidgetState extends State<BaseballPropsWidget> {
  String? _selectedCategory;
  double? _selectedLine;
  
  // Category display names
  final Map<String, String> _categoryNames = {
    'batter_hits': 'Hits',
    'batter_rbis': 'RBIs',
    'batter_total_bases': 'Total Bases',
    'batter_home_runs': 'Home Runs',
    'pitcher_strikeouts': 'Pitcher Strikeouts',
    'pitcher_hits_allowed': 'Pitcher Hits Allowed',
  };
  
  // Icons for categories
  final Map<String, IconData> _categoryIcons = {
    'batter_hits': Icons.sports_baseball,
    'batter_rbis': Icons.sports_score,
    'batter_total_bases': Icons.trending_up,
    'batter_home_runs': Icons.home,
    'pitcher_strikeouts': Icons.block,
    'pitcher_hits_allowed': Icons.shield,
  };
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category selection grid
        _buildCategorySelection(),
        
        if (_selectedCategory != null) ...[
          const SizedBox(height: 16),
          // Line selection dropdown
          _buildLineSelection(),
        ],
        
        if (_selectedCategory != null && _selectedLine != null) ...[
          const SizedBox(height: 16),
          // Over/Under cards
          _buildOverUnderCards(),
        ],
      ],
    );
  }
  
  Widget _buildCategorySelection() {
    final categories = widget.propsByCategory.keys.toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Prop Category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category;
            
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                  _selectedLine = null; // Reset line selection
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _categoryIcons[category] ?? Icons.sports,
                      size: 20,
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey[700],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _categoryNames[category] ?? category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[800],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildLineSelection() {
    final props = widget.propsByCategory[_selectedCategory!] ?? [];
    if (props.isEmpty) return const SizedBox();
    
    // Extract unique lines from props
    final lines = <double>{};
    for (final prop in props) {
      if (prop.line != null) {
        lines.add(prop.line!);
      }
    }
    final sortedLines = lines.toList()..sort();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Line for ${_categoryNames[_selectedCategory!]}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<double>(
            isExpanded: true,
            value: _selectedLine,
            hint: const Text('Choose a line'),
            underline: const SizedBox(),
            items: sortedLines.map((line) {
              return DropdownMenuItem<double>(
                value: line,
                child: Text(
                  line.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedLine = value;
              });
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildOverUnderCards() {
    final props = widget.propsByCategory[_selectedCategory!] ?? [];
    final selectedProps = props.where((p) => p.line == _selectedLine).toList();
    
    if (selectedProps.isEmpty) return const SizedBox();
    
    final prop = selectedProps.first;
    final categoryName = _categoryNames[_selectedCategory!] ?? _selectedCategory!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$categoryName ${_selectedLine!.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Over card
            if (prop.overOdds != null)
              Expanded(
                child: _buildBetCard(
                  'Over ${_selectedLine!.toStringAsFixed(1)}',
                  _formatOdds(prop.overOdds!),
                  true,
                  prop,
                ),
              ),
            const SizedBox(width: 8),
            // Under card
            if (prop.underOdds != null)
              Expanded(
                child: _buildBetCard(
                  'Under ${_selectedLine!.toStringAsFixed(1)}',
                  _formatOdds(prop.underOdds!),
                  false,
                  prop,
                ),
              ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildBetCard(String title, String odds, bool isOver, PropOption prop) {
    final betId = '${prop.description}_${prop.line}_${isOver ? 'over' : 'under'}';
    final isSelected = widget.selectedBetIds.contains(betId);
    final fullTitle = '${prop.description} - $title';
    
    return InkWell(
      onTap: () {
        widget.onBetSelected(betId, fullTitle, odds, 'prop');
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
            : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isOver ? Icons.trending_up : Icons.trending_down,
              color: isOver ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              odds,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatOdds(int odds) {
    if (odds > 0) return '+$odds';
    return odds.toString();
  }
}