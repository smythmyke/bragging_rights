import 'package:flutter/material.dart';
import 'edge_card_widget.dart';
import 'edge_card_types.dart';

/// Collection widget that manages and displays multiple Edge cards
class EdgeCardCollection extends StatefulWidget {
  final List<EdgeCardData> cards;
  final Function(EdgeCardData) onCardUnlock;
  final Function(EdgeCardData)? onCardTap;
  final String? sportFilter;
  final bool showPriorityOrder;

  const EdgeCardCollection({
    Key? key,
    required this.cards,
    required this.onCardUnlock,
    this.onCardTap,
    this.sportFilter,
    this.showPriorityOrder = true,
  }) : super(key: key);

  @override
  State<EdgeCardCollection> createState() => _EdgeCardCollectionState();
}

class _EdgeCardCollectionState extends State<EdgeCardCollection> {
  EdgeCardCategory? _selectedCategory;
  EdgeCardRarity? _selectedRarity;
  bool _showOnlyLocked = false;
  bool _showOnlyFresh = false;

  List<EdgeCardData> get _filteredCards {
    var cards = widget.cards;

    // Apply category filter
    if (_selectedCategory != null) {
      cards = cards.where((c) => c.category == _selectedCategory).toList();
    }

    // Apply rarity filter
    if (_selectedRarity != null) {
      cards = cards.where((c) => c.rarity == _selectedRarity).toList();
    }

    // Apply locked filter
    if (_showOnlyLocked) {
      cards = cards.where((c) => c.isLocked).toList();
    }

    // Apply fresh filter
    if (_showOnlyFresh) {
      cards = cards.where((c) => c.isFresh).toList();
    }

    // Sort by priority if enabled
    if (widget.showPriorityOrder) {
      cards.sort((a, b) {
        final configA = EdgeCardConfigs.getConfig(a.category);
        final configB = EdgeCardConfigs.getConfig(b.category);
        
        // Compare priority
        final priorityCompare = configB.priority.index.compareTo(
          configA.priority.index,
        );
        if (priorityCompare != 0) return priorityCompare;
        
        // If same priority, sort by freshness
        return b.timestamp.compareTo(a.timestamp);
      });
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter bar
        _buildFilterBar(),
        
        const SizedBox(height: 16),
        
        // Stats bar
        _buildStatsBar(),
        
        const SizedBox(height: 16),
        
        // Cards grid
        Expanded(
          child: _buildCardsGrid(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Category filters
          _buildFilterChip(
            label: 'All Categories',
            isSelected: _selectedCategory == null,
            onSelected: (_) => setState(() => _selectedCategory = null),
          ),
          ...EdgeCardCategory.values.map((category) {
            final config = EdgeCardConfigs.getConfig(category);
            return _buildFilterChip(
              label: config.title,
              icon: config.icon,
              isSelected: _selectedCategory == category,
              onSelected: (_) => setState(() {
                _selectedCategory = 
                    _selectedCategory == category ? null : category;
              }),
            );
          }),
          
          const SizedBox(width: 16),
          const VerticalDivider(),
          const SizedBox(width: 16),
          
          // Rarity filters
          _buildFilterChip(
            label: 'All Rarities',
            isSelected: _selectedRarity == null,
            onSelected: (_) => setState(() => _selectedRarity = null),
          ),
          ...EdgeCardRarity.values.map((rarity) {
            return _buildFilterChip(
              label: rarity.name.toUpperCase(),
              color: EdgeCardConfigs.getRarityColor(rarity),
              isSelected: _selectedRarity == rarity,
              onSelected: (_) => setState(() {
                _selectedRarity = _selectedRarity == rarity ? null : rarity;
              }),
            );
          }),
          
          const SizedBox(width: 16),
          const VerticalDivider(),
          const SizedBox(width: 16),
          
          // Quick filters
          _buildFilterChip(
            label: 'Locked Only',
            icon: Icons.lock,
            isSelected: _showOnlyLocked,
            onSelected: (selected) => setState(() {
              _showOnlyLocked = selected;
            }),
          ),
          _buildFilterChip(
            label: 'Fresh Intel',
            icon: Icons.new_releases,
            isSelected: _showOnlyFresh,
            onSelected: (selected) => setState(() {
              _showOnlyFresh = selected;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    Color? color,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
            ],
            Text(label),
          ],
        ),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: color?.withOpacity(0.3) ?? 
            Theme.of(context).primaryColor.withOpacity(0.3),
        checkmarkColor: color ?? Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildStatsBar() {
    final totalCards = _filteredCards.length;
    final lockedCards = _filteredCards.where((c) => c.isLocked).length;
    final totalValue = _filteredCards
        .where((c) => c.isLocked)
        .fold<int>(0, (sum, card) => sum + card.currentCost);
    
    final rarityBreakdown = <EdgeCardRarity, int>{};
    for (final card in _filteredCards) {
      rarityBreakdown[card.rarity] = (rarityBreakdown[card.rarity] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildStatItem(
            icon: Icons.style,
            label: 'Total',
            value: totalCards.toString(),
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            icon: Icons.lock,
            label: 'Locked',
            value: lockedCards.toString(),
          ),
          const SizedBox(width: 24),
          _buildStatItem(
            icon: Icons.monetization_on,
            label: 'Total Value',
            value: '$totalValue BR',
            color: Colors.green,
          ),
          const Spacer(),
          
          // Rarity breakdown
          ...rarityBreakdown.entries.map((entry) {
            final count = entry.value;
            if (count == 0) return const SizedBox.shrink();
            
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: EdgeCardConfigs.getRarityColor(entry.key)
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: EdgeCardConfigs.getRarityColor(entry.key),
                    width: 1,
                  ),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: EdgeCardConfigs.getRarityColor(entry.key),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.white70),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCardsGrid() {
    if (_filteredCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No cards match your filters',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = null;
                  _selectedRarity = null;
                  _showOnlyLocked = false;
                  _showOnlyFresh = false;
                });
              },
              child: const Text('Clear Filters'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 4
            : constraints.maxWidth > 800
                ? 3
                : constraints.maxWidth > 500
                    ? 2
                    : 1;

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
          ),
          itemCount: _filteredCards.length,
          itemBuilder: (context, index) {
            final card = _filteredCards[index];
            
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: EdgeCardWidget(
                key: ValueKey(card.id),
                cardData: card,
                onUnlock: () => widget.onCardUnlock(card),
                onTap: () => widget.onCardTap?.call(card),
              ),
            );
          },
        );
      },
    );
  }
}

/// Bundle offer widget for multiple cards
class EdgeCardBundle extends StatelessWidget {
  final String title;
  final String description;
  final List<EdgeCardData> cards;
  final int originalPrice;
  final int bundlePrice;
  final VoidCallback onPurchase;

  const EdgeCardBundle({
    Key? key,
    required this.title,
    required this.description,
    required this.cards,
    required this.originalPrice,
    required this.bundlePrice,
    required this.onPurchase,
  }) : super(key: key);

  int get savings => originalPrice - bundlePrice;
  double get savingsPercentage => (savings / originalPrice) * 100;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.2),
            Colors.blue.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SAVE ${savingsPercentage.toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.local_offer,
                color: Colors.purple,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          
          // Card previews
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];
                final config = EdgeCardConfigs.getConfig(card.category);
                
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: config.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        config.icon,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        config.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Price and purchase button
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$originalPrice BR',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    '$bundlePrice BR',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: onPurchase,
                icon: const Icon(Icons.shopping_cart),
                label: Text('Purchase Bundle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}