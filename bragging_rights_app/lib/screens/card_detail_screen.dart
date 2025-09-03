import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../data/card_definitions.dart';
import '../services/wallet_service.dart';
import '../services/card_service.dart';
import '../services/sound_service.dart';

class CardDetailScreen extends StatefulWidget {
  final PowerCard card;
  final bool isOwned;
  final int quantity;

  const CardDetailScreen({
    super.key,
    required this.card,
    required this.isOwned,
    required this.quantity,
  });

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final CardService _cardService = CardService();
  final SoundService _soundService = SoundService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int _getCardPrice() {
    switch (widget.card.rarity) {
      case CardRarity.common:
        return 100;
      case CardRarity.uncommon:
        return 250;
      case CardRarity.rare:
        return 500;
      case CardRarity.legendary:
        return 1000;
    }
  }

  Color _getRarityColor() {
    switch (widget.card.rarity) {
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

  String _getRarityName() {
    switch (widget.card.rarity) {
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

  String _getCardTypeName() {
    switch (widget.card.type) {
      case CardType.offensive:
        return 'Offensive';
      case CardType.defensive:
        return 'Defensive';
      case CardType.special:
        return 'Special';
    }
  }

  Color _getCardTypeColor() {
    switch (widget.card.type) {
      case CardType.offensive:
        return Colors.red;
      case CardType.defensive:
        return Colors.blue;
      case CardType.special:
        return Colors.purple;
    }
  }

  Future<void> _purchaseCard() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final price = _getCardPrice();
      final success = await _cardService.purchaseCard(widget.card.id, price);
      
      if (mounted) {
        if (success) {
          // Play purchase sound
          await _soundService.playCardPurchase(widget.card.id);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.card.name} purchased successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate purchase
        } else {
          // Play insufficient funds sound if balance issue
          final balance = await _walletService.getBalance();
          if (balance < price) {
            await _soundService.playInsufficientFunds();
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase failed. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _getCardPrice();
    final rarityColor = _getRarityColor();
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.card.name),
        actions: [
          // Balance Display
          StreamBuilder<int>(
            stream: _walletService.getBalanceStream(),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.coins,
                      size: 18,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$balance BR',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card Display
                Center(
                  child: Hero(
                    tag: 'card-${widget.card.id}',
                    child: Container(
                      width: 280,
                      height: 400,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isOwned 
                                ? Colors.amber.withOpacity(0.5)
                                : rarityColor.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Card Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: widget.card.imagePath != null
                                ? Image.asset(
                                    widget.card.imagePath!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildFallbackCard(rarityColor);
                                    },
                                  )
                                : _buildFallbackCard(rarityColor),
                          ),
                          
                          // Owned indicator
                          if (widget.isOwned)
                            Positioned(
                              top: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Owned x${widget.quantity}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Card Name and Type
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.card.name,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getCardTypeColor().withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getCardTypeColor().withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  _getCardTypeName(),
                                  style: TextStyle(
                                    color: _getCardTypeColor(),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: rarityColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: rarityColor.withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  _getRarityName(),
                                  style: TextStyle(
                                    color: rarityColor,
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
                
                const SizedBox(height: 24),
                
                // Power Description
                _buildInfoSection(
                  'Power',
                  widget.card.effect,
                  PhosphorIconsRegular.lightning,
                  Colors.yellow,
                ),
                
                const SizedBox(height: 16),
                
                // When to Use
                _buildInfoSection(
                  'When to Use',
                  widget.card.whenToUse,
                  PhosphorIconsRegular.clock,
                  Colors.blue,
                ),
                
                const SizedBox(height: 16),
                
                // How to Use
                _buildInfoSection(
                  'How to Use',
                  widget.card.howToUse,
                  PhosphorIconsRegular.info,
                  Colors.green,
                ),
                
                const SizedBox(height: 32),
                
                // Action Button
                StreamBuilder<int>(
                  stream: _walletService.getBalanceStream(),
                  builder: (context, snapshot) {
                    final balance = snapshot.data ?? 0;
                    final canAfford = balance >= price;
                    
                    if (widget.isOwned) {
                      return ElevatedButton(
                        onPressed: null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'CARD OWNED',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    }
                    
                    return ElevatedButton(
                      onPressed: canAfford && !_isPurchasing ? _purchaseCard : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: canAfford ? Colors.green : Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isPurchasing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  canAfford ? 'GET FOR ' : 'INSUFFICIENT FUNDS - ',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  PhosphorIconsRegular.coins,
                                  size: 20,
                                  color: canAfford ? Colors.white : Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$price BR',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: canAfford ? Colors.white : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCard(Color rarityColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            rarityColor.withOpacity(0.8),
            rarityColor.withOpacity(0.3),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Text(
          widget.card.icon,
          style: const TextStyle(fontSize: 100),
        ),
      ),
    );
  }
}