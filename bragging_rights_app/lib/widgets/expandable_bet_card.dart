import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/betting_models.dart';
import '../utils/glassmorphism_container.dart';

class ExpandableBetCard extends StatefulWidget {
  final GameOdds gameOdds;
  final Function(BetSlipItem) onBetSelected;
  final VoidCallback? onExpansionChanged;

  const ExpandableBetCard({
    Key? key,
    required this.gameOdds,
    required this.onBetSelected,
    this.onExpansionChanged,
  }) : super(key: key);

  @override
  State<ExpandableBetCard> createState() => _ExpandableBetCardState();
}

class _ExpandableBetCardState extends State<ExpandableBetCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 0.5,
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

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onExpansionChanged?.call();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bettingOptions = widget.gameOdds.getAllBettingOptions();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphismContainer(
        blur: 10,
        opacity: 0.1,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  SizeTransition(
                    sizeFactor: _expandAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildBettingOptions(bettingOptions),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Row(
      children: [
        _buildTeamColumn(),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.gameOdds.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatGameTime(widget.gameOdds.gameTime),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        RotationTransition(
          turns: _rotateAnimation,
          child: Icon(
            Icons.expand_more,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamColumn() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _getSportIcon(widget.gameOdds.sport),
            const SizedBox(width: 8),
            Text(
              widget.gameOdds.awayTeam,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 24),
            Text(
              'vs',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const SizedBox(width: 24),
            Text(
              widget.gameOdds.homeTeam,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBettingOptions(List<BettingOption> options) {
    return Column(
      children: options.map((option) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildBettingOptionRow(option),
        );
      }).toList(),
    );
  }

  Widget _buildBettingOptionRow(BettingOption option) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _getBetTypeIcon(option.type),
            const SizedBox(width: 8),
            Text(
              option.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildOptionButtons(option),
      ],
    );
  }

  Widget _buildOptionButtons(BettingOption option) {
    switch (option.type) {
      case BetType.moneyline:
        return _buildMoneylineButtons(option);
      case BetType.spread:
        return _buildSpreadButtons(option);
      case BetType.total:
        return _buildTotalButtons(option);
      default:
        return _buildGenericButtons(option);
    }
  }

  Widget _buildMoneylineButtons(BettingOption option) {
    return Row(
      children: [
        Expanded(
          child: _buildBetButton(
            label: widget.gameOdds.awayTeam,
            odds: AmericanOdds.fromValue(option.options['away']),
            onTap: () => _showBetSlip(option, 'away'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBetButton(
            label: widget.gameOdds.homeTeam,
            odds: AmericanOdds.fromValue(option.options['home']),
            onTap: () => _showBetSlip(option, 'home'),
          ),
        ),
      ],
    );
  }

  Widget _buildSpreadButtons(BettingOption option) {
    return Row(
      children: [
        Expanded(
          child: _buildBetButton(
            label: '${widget.gameOdds.awayTeam} ${option.options['awaySpread']}',
            odds: AmericanOdds.fromValue(option.options['awayOdds']),
            onTap: () => _showBetSlip(option, 'away'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBetButton(
            label: '${widget.gameOdds.homeTeam} ${option.options['homeSpread']}',
            odds: AmericanOdds.fromValue(option.options['homeOdds']),
            onTap: () => _showBetSlip(option, 'home'),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalButtons(BettingOption option) {
    return Row(
      children: [
        Expanded(
          child: _buildBetButton(
            label: 'Over ${option.options['line']}',
            odds: AmericanOdds.fromValue(option.options['overOdds']),
            onTap: () => _showBetSlip(option, 'over'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildBetButton(
            label: 'Under ${option.options['line']}',
            odds: AmericanOdds.fromValue(option.options['underOdds']),
            onTap: () => _showBetSlip(option, 'under'),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericButtons(BettingOption option) {
    // For prop bets and other types
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: option.options.entries.map((entry) {
        return _buildBetButton(
          label: entry.key,
          odds: AmericanOdds.fromValue(entry.value),
          onTap: () => _showBetSlip(option, entry.key),
        );
      }).toList(),
    );
  }

  Widget _buildBetButton({
    required String label,
    required AmericanOdds odds,
    required VoidCallback onTap,
  }) {
    return GlassmorphismContainer(
      blur: 5,
      opacity: 0.15,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  odds.displayValue,
                  style: TextStyle(
                    color: odds.value > 0 ? Colors.greenAccent : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBetSlip(BettingOption option, String selection) {
    HapticFeedback.mediumImpact();
    // Show bottom sheet with BR amount selection
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BetSlipSheet(
        option: option,
        selection: selection,
        gameOdds: widget.gameOdds,
        onConfirm: widget.onBetSelected,
      ),
    );
  }

  Widget _getSportIcon(Sport sport) {
    IconData icon;
    Color color;
    
    switch (sport) {
      case Sport.nba:
        icon = Icons.sports_basketball;
        color = Colors.orange;
        break;
      case Sport.nfl:
        icon = Icons.sports_football;
        color = Colors.brown;
        break;
      case Sport.mlb:
        icon = Icons.sports_baseball;
        color = Colors.red;
        break;
      case Sport.nhl:
        icon = Icons.sports_hockey;
        color = Colors.lightBlue;
        break;
      case Sport.soccer:
        icon = Icons.sports_soccer;
        color = Colors.green;
        break;
      case Sport.tennis:
        icon = Icons.sports_tennis;
        color = Colors.yellow;
        break;
      case Sport.golf:
        icon = Icons.golf_course;
        color = Colors.lightGreen;
        break;
      case Sport.mma:
        icon = Icons.sports_mma;
        color = Colors.redAccent;
        break;
    }
    
    return Icon(icon, color: color, size: 20);
  }

  Widget _getBetTypeIcon(BetType type) {
    IconData icon;
    
    switch (type) {
      case BetType.moneyline:
        icon = Icons.attach_money;
        break;
      case BetType.spread:
        icon = Icons.compare_arrows;
        break;
      case BetType.total:
        icon = Icons.trending_up;
        break;
      case BetType.playerProp:
        icon = Icons.person;
        break;
      case BetType.gameProp:
        icon = Icons.stars;
        break;
      case BetType.parlay:
        icon = Icons.layers;
        break;
    }
    
    return Icon(icon, color: Colors.white60, size: 16);
  }

  String _formatGameTime(DateTime gameTime) {
    final now = DateTime.now();
    final difference = gameTime.difference(now);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ${difference.inMinutes % 60}m';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Starting Soon';
    }
  }
}

class BetSlipSheet extends StatefulWidget {
  final BettingOption option;
  final String selection;
  final GameOdds gameOdds;
  final Function(BetSlipItem) onConfirm;

  const BetSlipSheet({
    Key? key,
    required this.option,
    required this.selection,
    required this.gameOdds,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<BetSlipSheet> createState() => _BetSlipSheetState();
}

class _BetSlipSheetState extends State<BetSlipSheet> {
  BRAmount _selectedAmount = BRAmount.ten;
  final TextEditingController _customController = TextEditingController();
  late AmericanOdds _odds;

  @override
  void initState() {
    super.initState();
    _calculateOdds();
  }

  void _calculateOdds() {
    int oddsValue = 0;
    switch (widget.option.type) {
      case BetType.moneyline:
        oddsValue = widget.selection == 'away' 
          ? widget.option.options['away'] 
          : widget.option.options['home'];
        break;
      case BetType.spread:
        oddsValue = widget.selection == 'away'
          ? widget.option.options['awayOdds']
          : widget.option.options['homeOdds'];
        break;
      case BetType.total:
        oddsValue = widget.selection == 'over'
          ? widget.option.options['overOdds']
          : widget.option.options['underOdds'];
        break;
      default:
        oddsValue = widget.option.options[widget.selection] ?? -110;
    }
    _odds = AmericanOdds.fromValue(oddsValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wagerAmount = _selectedAmount == BRAmount.custom
        ? (int.tryParse(_customController.text) ?? 0)
        : _selectedAmount.value;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black87,
            Colors.black,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Place Your Bet',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildBetDetails(),
          const SizedBox(height: 24),
          Text(
            'Select BR Amount',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          _buildAmountSelection(),
          const SizedBox(height: 20),
          _buildPayoutInfo(wagerAmount.toDouble()),
          const SizedBox(height: 24),
          _buildConfirmButton(wagerAmount.toDouble()),
        ],
      ),
    );
  }

  Widget _buildBetDetails() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.gameOdds.awayTeam} vs ${widget.gameOdds.homeTeam}',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.option.description,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                widget.selection.toUpperCase(),
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Odds',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                _odds.displayValue,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSelection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAmountChip(BRAmount.ten),
            _buildAmountChip(BRAmount.twentyFive),
            _buildAmountChip(BRAmount.fifty),
            _buildAmountChip(BRAmount.hundred),
          ],
        ),
        const SizedBox(height: 12),
        _buildCustomAmountField(),
      ],
    );
  }

  Widget _buildAmountChip(BRAmount amount) {
    final isSelected = _selectedAmount == amount;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAmount = amount;
          _customController.clear();
        });
        HapticFeedback.selectionClick();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.greenAccent : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.greenAccent : Colors.white30,
            width: 1,
          ),
        ),
        child: Text(
          '${amount.value} BR',
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAmountField() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAmount = BRAmount.custom;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _selectedAmount == BRAmount.custom 
            ? Colors.white10 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedAmount == BRAmount.custom
              ? Colors.greenAccent
              : Colors.white30,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Text(
              'Custom: ',
              style: TextStyle(color: Colors.white70),
            ),
            Expanded(
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                  suffixText: 'BR',
                  suffixStyle: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  setState(() {
                    _selectedAmount = BRAmount.custom;
                  });
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutInfo(double wager) {
    if (wager <= 0) return const SizedBox.shrink();
    
    final payout = _odds.calculatePayout(wager);
    final profit = _odds.calculateProfit(wager);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.greenAccent.withOpacity(0.1),
            Colors.greenAccent.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Wager', style: TextStyle(color: Colors.white70)),
              Text('${wager.toStringAsFixed(0)} BR', 
                style: TextStyle(color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Potential Profit', style: TextStyle(color: Colors.white70)),
              Text('+${profit.toStringAsFixed(0)} BR',
                style: TextStyle(color: Colors.greenAccent)),
            ],
          ),
          const Divider(color: Colors.white30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Payout', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${payout.toStringAsFixed(0)} BR',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton(double wager) {
    final isValid = wager > 0;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isValid ? _confirmBet : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.greenAccent,
          disabledBackgroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Confirm Bet',
          style: TextStyle(
            color: isValid ? Colors.black : Colors.white54,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _confirmBet() {
    final wager = _selectedAmount == BRAmount.custom
        ? double.tryParse(_customController.text) ?? 0
        : _selectedAmount.value.toDouble();
    
    if (wager > 0) {
      final betSlipItem = BetSlipItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        option: widget.option,
        selection: widget.selection,
        odds: _odds,
        wager: wager,
      );
      
      widget.onConfirm(betSlipItem);
      Navigator.pop(context);
      HapticFeedback.heavyImpact();
    }
  }
}