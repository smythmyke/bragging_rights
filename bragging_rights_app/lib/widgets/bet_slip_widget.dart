import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/betting_models.dart';
import '../utils/glassmorphism_container.dart';

class BetSlipWidget extends StatefulWidget {
  final List<BetSlipItem> items;
  final Function(List<BetSlipItem>) onUpdate;
  final VoidCallback onClear;
  final Function(BetSlip) onPlaceBet;
  final double userBalance;

  const BetSlipWidget({
    Key? key,
    required this.items,
    required this.onUpdate,
    required this.onClear,
    required this.onPlaceBet,
    required this.userBalance,
  }) : super(key: key);

  @override
  State<BetSlipWidget> createState() => _BetSlipWidgetState();
}

class _BetSlipWidgetState extends State<BetSlipWidget> 
    with SingleTickerProviderStateMixin {
  bool _isParlay = false;
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _totalWager {
    if (_isParlay) {
      // For parlays, use the first item's wager as the total
      return widget.items.isNotEmpty ? widget.items.first.wager : 0;
    }
    return widget.items.fold(0, (sum, item) => sum + item.wager);
  }

  double get _potentialPayout {
    if (_isParlay && widget.items.isNotEmpty) {
      double combinedOdds = 1;
      for (var item in widget.items) {
        combinedOdds *= item.odds.payout;
      }
      return widget.items.first.wager * combinedOdds;
    }
    return widget.items.fold(0, (sum, item) => sum + item.potentialPayout);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return _buildEmptyState();
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.7,
      builder: (context, scrollController) {
        return GlassmorphismContainer(
          blur: 15,
          opacity: 0.95,
          color: Colors.black,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: Colors.greenAccent.withOpacity(0.3),
            width: 2,
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.items.length > 1) _buildParlayToggle(),
                    ...widget.items.map(_buildBetItem),
                    const SizedBox(height: 16),
                    _buildSummary(),
                    const SizedBox(height: 16),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 80,
      padding: const EdgeInsets.all(16),
      child: GlassmorphismContainer(
        blur: 10,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        child: const Center(
          child: Text(
            'Your bet slip is empty',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white30,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                _isParlay ? Icons.layers : Icons.receipt_long,
                color: Colors.greenAccent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isParlay 
                  ? 'Parlay (${widget.items.length} legs)' 
                  : 'Bet Slip (${widget.items.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.white54),
            onPressed: () {
              HapticFeedback.mediumImpact();
              widget.onClear();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildParlayToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassmorphismContainer(
        blur: 5,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isParlay 
            ? Colors.greenAccent.withOpacity(0.5)
            : Colors.white.withOpacity(0.1),
          width: 1,
        ),
        child: SwitchListTile(
          title: const Text(
            'Combine as Parlay',
            style: TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            _isParlay 
              ? 'Higher risk, higher reward'
              : 'Individual bets',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          value: _isParlay,
          activeColor: Colors.greenAccent,
          onChanged: (value) {
            setState(() {
              _isParlay = value;
            });
            HapticFeedback.selectionClick();
          },
        ),
      ),
    );
  }

  Widget _buildBetItem(BetSlipItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        final updatedItems = List<BetSlipItem>.from(widget.items)
          ..removeWhere((i) => i.id == item.id);
        widget.onUpdate(updatedItems);
        HapticFeedback.mediumImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: GlassmorphismContainer(
          blur: 5,
          opacity: 0.1,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item.option.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    item.odds.displayValue,
                    style: TextStyle(
                      color: item.odds.value > 0 
                        ? Colors.greenAccent 
                        : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.selection,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              if (!_isParlay) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wager: ${item.wager.toStringAsFixed(0)} BR',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'To Win: ${item.potentialProfit.toStringAsFixed(0)} BR',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final hasEnoughBalance = widget.userBalance >= _totalWager;
    
    return GlassmorphismContainer(
      blur: 10,
      opacity: 0.15,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.greenAccent.withOpacity(0.3),
        width: 1,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Your Balance',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '${widget.userBalance.toStringAsFixed(0)} BR',
                style: TextStyle(
                  color: hasEnoughBalance ? Colors.white : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Wager',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '${_totalWager.toStringAsFixed(0)} BR',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Potential Payout',
                style: TextStyle(color: Colors.white70),
              ),
              Text(
                '${_potentialPayout.toStringAsFixed(0)} BR',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          if (_isParlay) ...[
            const Divider(color: Colors.white30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Parlay Multiplier',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  '${(_potentialPayout / (_totalWager > 0 ? _totalWager : 1)).toStringAsFixed(2)}x',
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (!hasEnoughBalance) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.redAccent, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Insufficient BR balance',
                      style: TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasEnoughBalance = widget.userBalance >= _totalWager;
    
    return Row(
      children: [
        Expanded(
          child: GlassmorphicButton(
            text: 'Clear All',
            onPressed: widget.onClear,
            color: Colors.red,
            opacity: 0.2,
            icon: const Icon(Icons.clear, color: Colors.white, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: GlassmorphicButton(
              text: 'Place Bet',
              onPressed: hasEnoughBalance ? _placeBet : () {},
              color: hasEnoughBalance ? Colors.greenAccent : Colors.grey,
              opacity: hasEnoughBalance ? 0.3 : 0.1,
              icon: Icon(
                Icons.check_circle,
                color: hasEnoughBalance ? Colors.white : Colors.white54,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _placeBet() {
    final betSlip = BetSlip(
      items: widget.items,
      totalWager: _totalWager,
      potentialPayout: _potentialPayout,
      isParlay: _isParlay,
    );
    
    widget.onPlaceBet(betSlip);
    HapticFeedback.heavyImpact();
    
    // Show success animation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isParlay 
                  ? 'Parlay placed! Good luck!'
                  : 'Bet${widget.items.length > 1 ? 's' : ''} placed! Good luck!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}