import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../services/card_service.dart';
import '../../data/card_definitions.dart';

class CardInventoryScreen extends StatefulWidget {
  final CardType cardType;
  
  const CardInventoryScreen({
    super.key,
    required this.cardType,
  });

  @override
  State<CardInventoryScreen> createState() => _CardInventoryScreenState();
}

class _CardInventoryScreenState extends State<CardInventoryScreen> {
  final CardService _cardService = CardService();
  List<PowerCard> _cards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    
    final cards = await _cardService.getUserCardsByType(widget.cardType);
    
    setState(() {
      _cards = cards;
      _isLoading = false;
    });
  }

  Color _getRarityColor(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return Colors.grey;
      case CardRarity.uncommon:
        return Colors.green;
      case CardRarity.rare:
        return Colors.blue;
      case CardRarity.legendary:
        return Colors.orange;
    }
  }

  String _getRarityText(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 'Common';
      case CardRarity.uncommon:
        return 'Uncommon';
      case CardRarity.rare:
        return 'Rare';
      case CardRarity.legendary:
        return 'Legendary';
    }
  }

  IconData _getTypeIcon(CardType type) {
    switch (type) {
      case CardType.offensive:
        return PhosphorIconsRegular.target;
      case CardType.defensive:
        return PhosphorIconsRegular.shield;
      case CardType.special:
        return PhosphorIconsRegular.star;
    }
  }

  String _getTypeTitle(CardType type) {
    switch (type) {
      case CardType.offensive:
        return 'Offensive Cards';
      case CardType.defensive:
        return 'Defensive Cards';
      case CardType.special:
        return 'Special Cards';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_getTypeIcon(widget.cardType)),
            const SizedBox(width: 8),
            Text(_getTypeTitle(widget.cardType)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.shoppingCart),
            onPressed: () {
              // TODO: Navigate to card shop
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card shop coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            tooltip: 'Card Shop',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? _buildEmptyState()
              : _buildCardGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.cardsThree,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No ${_getTypeTitle(widget.cardType)} Yet',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Win pools or visit the shop to get cards',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to shop
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card shop coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(PhosphorIconsRegular.shoppingCart),
            label: const Text('Visit Shop'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final card = _cards[index];
        return _buildCardItem(card);
      },
    );
  }

  Widget _buildCardItem(PowerCard card) {
    final rarityColor = _getRarityColor(card.rarity);
    final isDisabled = card.quantity == 0;
    
    return GestureDetector(
      onTap: () {
        _showCardDetails(card);
      },
      child: Card(
        elevation: isDisabled ? 1 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDisabled ? Colors.grey : rarityColor,
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDisabled
                  ? [Colors.grey[800]!, Colors.grey[900]!]
                  : [
                      rarityColor.withOpacity(0.1),
                      rarityColor.withOpacity(0.05),
                    ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Card Icon and Quantity
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            card.icon,
                            style: TextStyle(
                              fontSize: 48,
                              color: isDisabled ? Colors.grey : null,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (card.quantity > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'x${card.quantity}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Card Name
                    Text(
                      card.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDisabled ? Colors.grey : null,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                // Rarity Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDisabled ? Colors.grey : rarityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getRarityText(card.rarity),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCardDetails(PowerCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Card Details
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Header
                    Row(
                      children: [
                        Text(
                          card.icon,
                          style: const TextStyle(fontSize: 64),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getRarityColor(card.rarity),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getRarityText(card.rarity),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (card.quantity > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Owned: ${card.quantity}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Effect Section
                    _buildDetailSection(
                      icon: PhosphorIconsRegular.sparkle,
                      title: 'Effect',
                      content: card.effect,
                    ),
                    const SizedBox(height: 24),
                    
                    // When to Use Section
                    _buildDetailSection(
                      icon: PhosphorIconsRegular.clock,
                      title: 'When to Use',
                      content: card.whenToUse,
                    ),
                    const SizedBox(height: 24),
                    
                    // How to Use Section
                    _buildDetailSection(
                      icon: PhosphorIconsRegular.info,
                      title: 'How to Use',
                      content: card.howToUse,
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    if (card.quantity > 0)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Navigate to active pools where card can be used
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Navigate to your active pools to use this card'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                          ),
                          child: const Text(
                            'Use Card',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            // TODO: Navigate to shop
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Card shop coming soon!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Get More Cards',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}