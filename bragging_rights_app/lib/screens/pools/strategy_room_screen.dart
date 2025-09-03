import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/pool_model.dart';
import '../../data/card_definitions.dart';
import '../../models/intel_product.dart';
import '../../services/wallet_service.dart';
import '../../services/pool_service.dart';
import '../../services/sound_service.dart';

class StrategyRoomScreen extends StatefulWidget {
  final String poolId;
  final Pool pool;
  final Map<String, dynamic> picks;
  final List<IntelProduct> consumedIntel;
  final int intelCost;

  const StrategyRoomScreen({
    super.key,
    required this.poolId,
    required this.pool,
    required this.picks,
    required this.consumedIntel,
    required this.intelCost,
  });

  @override
  State<StrategyRoomScreen> createState() => _StrategyRoomScreenState();
}

class _StrategyRoomScreenState extends State<StrategyRoomScreen> {
  final WalletService _walletService = WalletService();
  final PoolService _poolService = PoolService();
  final SoundService _soundService = SoundService();
  
  // Selected cards for each phase
  PowerCard? _preGameCard;
  PowerCard? _midGameCard;
  PowerCard? _postGameCard;
  
  // Trigger conditions
  TriggerCondition? _midGameTrigger;
  ResultCondition _postGameCondition = ResultCondition.ifLosing;
  
  // UI state
  int _currentPhase = 0;
  bool _isSubmitting = false;
  
  // Calculate total cost
  int get _totalPowerCardCost {
    int cost = 0;
    if (_preGameCard != null) cost += _getCardPrice(_preGameCard!.rarity);
    if (_midGameCard != null) cost += _getCardPrice(_midGameCard!.rarity);
    if (_postGameCard != null) cost += _getCardPrice(_postGameCard!.rarity);
    return cost;
  }
  
  int get _totalCost => widget.pool.buyIn + widget.intelCost + _totalPowerCardCost;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Strategy Room'),
        actions: [
          // Balance display
          StreamBuilder<int>(
            stream: _walletService.getBalanceStream(),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              final canAfford = balance >= _totalCost;
              
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: canAfford ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: canAfford ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.coins,
                      size: 18,
                      color: canAfford ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$balance BR',
                      style: TextStyle(
                        color: canAfford ? Colors.green : Colors.red,
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
      body: Column(
        children: [
          // Phase indicator
          _buildPhaseIndicator(),
          
          // Content
          Expanded(
            child: IndexedStack(
              index: _currentPhase,
              children: [
                _buildPreGamePhase(),
                _buildMidGamePhase(),
                _buildPostGamePhase(),
                _buildReviewPhase(),
              ],
            ),
          ),
          
          // Bottom navigation
          _buildBottomNavigation(),
        ],
      ),
    );
  }
  
  Widget _buildPhaseIndicator() {
    final phases = ['Pre-Game', 'Mid-Game', 'Post-Game', 'Review'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: phases.asMap().entries.map((entry) {
          final index = entry.key;
          final phase = entry.value;
          final isActive = index == _currentPhase;
          final isCompleted = index < _currentPhase;
          
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : 
                           isActive ? Colors.blue : 
                           Colors.grey[800],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phase,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.grey,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildPreGamePhase() {
    final preGameCards = CardDefinitions.allCards.values
        .where((card) => _isPreGameCard(card))
        .toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Pre-Game Card',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This card will activate before the game starts',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Option to skip
          _buildSkipOption('pre'),
          
          const SizedBox(height: 16),
          
          // Card grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: preGameCards.length,
            itemBuilder: (context, index) {
              final card = preGameCards[index];
              final isSelected = _preGameCard?.id == card.id;
              final price = _getCardPrice(card.rarity);
              
              return _buildCardOption(card, price, isSelected, () async {
                // Play card selection sound
                if (!isSelected) {
                  await _soundService.playCardSelect(card.id);
                }
                setState(() {
                  _preGameCard = isSelected ? null : card;
                });
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildMidGamePhase() {
    final midGameCards = CardDefinitions.allCards.values
        .where((card) => _isMidGameCard(card))
        .toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Mid-Game Card',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This card will activate when your trigger condition is met',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Option to skip
          _buildSkipOption('mid'),
          
          const SizedBox(height: 16),
          
          // Trigger configuration
          if (_midGameCard != null) ...[
            _buildTriggerConfiguration(),
            const SizedBox(height: 24),
          ],
          
          // Card grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: midGameCards.length,
            itemBuilder: (context, index) {
              final card = midGameCards[index];
              final isSelected = _midGameCard?.id == card.id;
              final price = _getCardPrice(card.rarity);
              
              return _buildCardOption(card, price, isSelected, () async {
                // Play card selection sound
                if (!isSelected) {
                  await _soundService.playCardSelect(card.id);
                }
                setState(() {
                  _midGameCard = isSelected ? null : card;
                  if (!isSelected) {
                    // Set default trigger
                    _midGameTrigger = TriggerCondition(
                      type: TriggerType.round,
                      value: 3,
                      comparison: 'equals',
                    );
                  }
                });
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostGamePhase() {
    final postGameCards = CardDefinitions.allCards.values
        .where((card) => _isPostGameCard(card))
        .toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Post-Game Card',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This card will activate based on the game result',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Option to skip
          _buildSkipOption('post'),
          
          const SizedBox(height: 16),
          
          // Result condition
          if (_postGameCard != null) ...[
            _buildResultCondition(),
            const SizedBox(height: 24),
          ],
          
          // Card grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.75,
            ),
            itemCount: postGameCards.length,
            itemBuilder: (context, index) {
              final card = postGameCards[index];
              final isSelected = _postGameCard?.id == card.id;
              final price = _getCardPrice(card.rarity);
              
              return _buildCardOption(card, price, isSelected, () async {
                // Play card selection sound
                if (!isSelected) {
                  await _soundService.playCardSelect(card.id);
                }
                setState(() {
                  _postGameCard = isSelected ? null : card;
                });
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewPhase() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Your Strategy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Strategy summary
          _buildStrategySummary(),
          
          const SizedBox(height: 24),
          
          // Cost breakdown
          _buildCostBreakdown(),
          
          const SizedBox(height: 24),
          
          // Warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.warning, color: Colors.orange),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'All cards will be consumed regardless of whether their triggers activate',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCardOption(PowerCard card, int price, bool isSelected, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[800]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[900],
        ),
        child: Stack(
          children: [
            // Card image or icon
            if (card.imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  card.imagePath!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Text(
                        card.icon,
                        style: const TextStyle(fontSize: 40),
                      ),
                    );
                  },
                ),
              )
            else
              Center(
                child: Text(
                  card.icon,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            
            // Card details
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$price BR',
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
            
            // Selection indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSkipOption(String phase) {
    return GestureDetector(
      onTap: () {
        setState(() {
          switch (phase) {
            case 'pre':
              _preGameCard = null;
              break;
            case 'mid':
              _midGameCard = null;
              _midGameTrigger = null;
              break;
            case 'post':
              _postGameCard = null;
              break;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsRegular.prohibit, color: Colors.grey),
            const SizedBox(width: 8),
            const Text(
              'Skip this phase (Save BR)',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTriggerConfiguration() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set Trigger Condition',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Simplified trigger options
          Row(
            children: [
              const Text('Activate at Round: ', style: TextStyle(color: Colors.grey)),
              DropdownButton<int>(
                value: _midGameTrigger?.value ?? 3,
                dropdownColor: Colors.grey[800],
                items: List.generate(5, (i) => i + 1)
                    .map((round) => DropdownMenuItem(
                          value: round,
                          child: Text('$round', style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _midGameTrigger = TriggerCondition(
                      type: TriggerType.round,
                      value: value!,
                      comparison: 'equals',
                    );
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildResultCondition() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activation Condition',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Radio<ResultCondition>(
                value: ResultCondition.ifWinning,
                groupValue: _postGameCondition,
                onChanged: (value) {
                  setState(() {
                    _postGameCondition = value!;
                  });
                },
              ),
              const Text('If Winning', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 24),
              Radio<ResultCondition>(
                value: ResultCondition.ifLosing,
                groupValue: _postGameCondition,
                onChanged: (value) {
                  setState(() {
                    _postGameCondition = value!;
                  });
                },
              ),
              const Text('If Losing', style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStrategySummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Strategy',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          _buildStrategyItem(
            'Pre-Game',
            _preGameCard?.name ?? 'None',
            _preGameCard != null ? _getCardPrice(_preGameCard!.rarity) : 0,
          ),
          const SizedBox(height: 8),
          _buildStrategyItem(
            'Mid-Game',
            _midGameCard != null
                ? '${_midGameCard!.name} (Round ${_midGameTrigger?.value})'
                : 'None',
            _midGameCard != null ? _getCardPrice(_midGameCard!.rarity) : 0,
          ),
          const SizedBox(height: 8),
          _buildStrategyItem(
            'Post-Game',
            _postGameCard != null
                ? '${_postGameCard!.name} (${_postGameCondition == ResultCondition.ifWinning ? "If Win" : "If Lose"})'
                : 'None',
            _postGameCard != null ? _getCardPrice(_postGameCard!.rarity) : 0,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStrategyItem(String phase, String card, int cost) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              phase,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              card,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        Text(
          cost > 0 ? '$cost BR' : 'FREE',
          style: TextStyle(
            color: cost > 0 ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCostBreakdown() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildCostLine('Pool Entry', widget.pool.buyIn),
          const SizedBox(height: 8),
          _buildCostLine('Intel Cards', widget.intelCost),
          const SizedBox(height: 8),
          _buildCostLine('Power Cards', _totalPowerCardCost),
          const Divider(color: Colors.blue),
          _buildCostLine('TOTAL', _totalCost, isTotal: true),
        ],
      ),
    );
  }
  
  Widget _buildCostLine(String label, int amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : Colors.grey,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
          ),
        ),
        Text(
          '$amount BR',
          style: TextStyle(
            color: isTotal ? Colors.blue : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isTotal ? 18 : 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          if (_currentPhase > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentPhase--;
                  });
                },
                child: const Text('Back'),
              ),
            ),
          if (_currentPhase > 0) const SizedBox(width: 16),
          Expanded(
            child: StreamBuilder<int>(
              stream: _walletService.getBalanceStream(),
              builder: (context, snapshot) {
                final balance = snapshot.data ?? 0;
                final canAfford = balance >= _totalCost;
                
                return ElevatedButton(
                  onPressed: (_currentPhase == 3 && canAfford && !_isSubmitting)
                      ? _submitStrategy
                      : (_currentPhase < 3)
                          ? () {
                              setState(() {
                                _currentPhase++;
                              });
                            }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _currentPhase == 3 ? Colors.green : Colors.blue,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _currentPhase == 3
                              ? 'Submit Strategy'
                              : 'Next',
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _submitStrategy() async {
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Play strategy locked sound
      await _soundService.playStrategyLocked();
      
      // Calculate total cost
      final totalCost = 25 + widget.intelCost + _totalPowerCardCost; // Default entry fee of 25
      
      // Check balance
      final balance = await _walletService.getCurrentBalance();
      if (balance < totalCost) {
        await _soundService.playInsufficientFunds();
        throw Exception('Insufficient funds. Need $totalCost BR but have $balance BR');
      }
      
      // Submit strategy to pool service
      final strategy = {
        'poolId': widget.poolId,
        'userId': FirebaseAuth.instance.currentUser!.uid,
        'picks': widget.picks,
        'strategy': {
          'preCard': _preGameCard != null ? {
            'id': _preGameCard!.id,
            'cost': _getCardPrice(_preGameCard!.rarity),
          } : null,
          'midCard': _midGameCard != null ? {
            'id': _midGameCard!.id,
            'cost': _getCardPrice(_midGameCard!.rarity),
            'trigger': {
              'type': _midGameTrigger?.type.toString().split('.').last,
              'value': _midGameTrigger?.value,
              'comparison': _midGameTrigger?.comparison,
            }
          } : null,
          'postCard': _postGameCard != null ? {
            'id': _postGameCard!.id,
            'cost': _getCardPrice(_postGameCard!.rarity),
            'condition': _postGameCondition.toString().split('.').last,
          } : null,
        },
        'costs': {
          'entry': 25, // Default entry fee
          'intel': widget.intelCost,
          'powerCards': _totalPowerCardCost,
          'total': totalCost,
        },
        'submittedAt': FieldValue.serverTimestamp(),
        'locked': true,
      };
      
      // Submit to Firebase
      await FirebaseFirestore.instance
          .collection('pools')
          .doc(widget.poolId)
          .collection('strategies')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set(strategy);
      
      // Deduct costs from wallet
      await _walletService.updateBalance(-totalCost);
      
      // Navigate back with success
      Navigator.pop(context, {
        'success': true,
        'strategy': strategy,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Strategy locked in successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  // Helper methods
  bool _isPreGameCard(PowerCard card) {
    return ['mulligan', 'crystal_ball', 'copycat', 'time_freeze'].contains(card.id);
  }
  
  bool _isMidGameCard(PowerCard card) {
    return ['double_down', 'shield', 'hot_hand', 'hedge', 'split_bet'].contains(card.id);
  }
  
  bool _isPostGameCard(PowerCard card) {
    return ['insurance', 'second_chance', 'lucky_charm'].contains(card.id);
  }
  
  int _getCardPrice(CardRarity rarity) {
    switch (rarity) {
      case CardRarity.common:
        return 18;
      case CardRarity.uncommon:
        return 28;
      case CardRarity.rare:
        return 38;
      case CardRarity.legendary:
        return 48;
    }
  }
}

// Supporting classes
enum TriggerType {
  round,
  score,
  time,
  percentage,
}

class TriggerCondition {
  final TriggerType type;
  final dynamic value;
  final String comparison;
  
  TriggerCondition({
    required this.type,
    required this.value,
    required this.comparison,
  });
}

enum ResultCondition {
  ifWinning,
  ifLosing,
  always,
}