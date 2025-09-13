import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/fight_card_model.dart';
import '../../models/pool_model.dart';
import '../../models/fight_card_scoring.dart';
import '../../services/fight_card_service.dart';
import '../../services/fight_odds_service.dart';
// Removed custom app bar import - using standard AppBar
import 'fight_pick_detail_screen.dart';
import '../../theme/app_theme.dart';

/// Screen showing all fights in a card for picking
class FightCardScreen extends StatefulWidget {
  final FightCardEventModel event;
  final Pool pool;
  final String userId;
  
  const FightCardScreen({
    Key? key,
    required this.event,
    required this.pool,
    required this.userId,
  }) : super(key: key);
  
  @override
  State<FightCardScreen> createState() => _FightCardScreenState();
}

class _FightCardScreenState extends State<FightCardScreen> {
  final FightCardService _fightService = FightCardService();
  final FightOddsService _oddsService = FightOddsService();
  
  // Track user picks
  final Map<String, FightPick> _userPicks = {};
  Map<String, FightOdds> _fightOdds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  // Track which fights are required
  List<Fight> _requiredFights = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load fight odds
      _fightOdds = await _oddsService.getFightCardOdds(event: widget.event);
      
      // Determine required fights based on pool rules
      _determineRequiredFights();
      
      // Load existing picks if any
      final existingPicks = await _fightService.getUserPicks(
        userId: widget.userId,
        poolId: widget.pool.id,
      );
      
      for (final pick in existingPicks) {
        _userPicks[pick.fightId] = pick;
      }
    } catch (e) {
      debugPrint('Error loading fight card data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _determineRequiredFights() {
    final poolMetadata = widget.pool.metadata ?? {};
    final requireFullCard = poolMetadata['requireFullCard'] ?? false;
    final allowSkipPrelims = poolMetadata['allowSkipPrelims'] ?? true;
    
    if (requireFullCard) {
      _requiredFights = widget.event.typedFights;
    } else if (allowSkipPrelims) {
      // Only main card required
      _requiredFights = widget.event.mainCard;
    } else {
      // Main card + prelims (not early prelims)
      _requiredFights = [
        ...widget.event.mainCard,
        ...widget.event.prelims,
      ];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.event.eventName),
            Text(
              widget.pool.name,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressBar(),
                _buildFightCategories(),
                Expanded(child: _buildFightGrid()),
                _buildBottomBar(),
              ],
            ),
    );
  }
  
  Widget _buildProgressBar() {
    final totalRequired = _requiredFights.length;
    final pickedCount = _userPicks.values
        .where((pick) => _requiredFights.any((f) => f.id == pick.fightId))
        .length;
    
    final progress = totalRequired > 0 ? pickedCount / totalRequired : 0.0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        border: Border(
          bottom: BorderSide(color: AppTheme.surfaceBlue!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Picks Progress',
                style: TextStyle(
                  color: AppTheme.surfaceBlue,
                  fontSize: 14,
                ),
              ),
              Text(
                '$pickedCount / $totalRequired',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.surfaceBlue,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? AppTheme.neonGreen : AppTheme.primaryCyan,
            ),
            minHeight: 6,
          ),
          if (pickedCount < totalRequired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pick ${totalRequired - pickedCount} more fight${totalRequired - pickedCount > 1 ? 's' : ''} to submit',
                style: TextStyle(
                  color: AppTheme.warningAmber[400],
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildFightCategories() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip('All', widget.event.typedFights.length, true),
          _buildCategoryChip('Main Card', widget.event.mainCard.length, false),
          if (widget.event.prelims.isNotEmpty)
            _buildCategoryChip('Prelims', widget.event.prelims.length, false),
          if (widget.event.earlyPrelims.isNotEmpty)
            _buildCategoryChip('Early Prelims', widget.event.earlyPrelims.length, false),
        ],
      ),
    );
  }
  
  Widget _buildCategoryChip(String label, int count, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: isSelected,
        onSelected: (selected) {
          // TODO: Implement filtering
        },
        backgroundColor: AppTheme.surfaceBlue,
        selectedColor: AppTheme.primaryCyan[900],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppTheme.surfaceBlue,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
  
  Widget _buildFightGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widget.event.typedFights.length,
      itemBuilder: (context, index) {
        final fight = widget.event.typedFights[index];
        return _buildFightCard(fight);
      },
    );
  }
  
  Widget _buildFightCard(Fight fight) {
    final userPick = _userPicks[fight.id];
    final odds = _fightOdds[fight.id];
    final isRequired = _requiredFights.contains(fight);
    
    return GestureDetector(
      onTap: () => _openFightDetail(fight),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: userPick != null
                ? AppTheme.neonGreen
                : isRequired
                    ? AppTheme.warningAmber[800]!
                    : AppTheme.surfaceBlue!,
            width: userPick != null ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fight category badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: _getCategoryColor(fight),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Center(
                child: Text(
                  _getCategoryLabel(fight),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            // Fighters
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Fighter 1
                    _buildFighterRow(
                      fight.fighter1Name,
                      fight.fighter1Record,
                      odds?.fighter1OddsDisplay,
                      userPick?.winnerId == fight.fighter1Id,
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: AppTheme.surfaceBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    // Fighter 2
                    _buildFighterRow(
                      fight.fighter2Name,
                      fight.fighter2Record,
                      odds?.fighter2OddsDisplay,
                      userPick?.winnerId == fight.fighter2Id,
                    ),
                  ],
                ),
              ),
            ),
            
            // Pick indicator
            if (userPick != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.neonGreen[900],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppTheme.neonGreen),
                    const SizedBox(width: 4),
                    Text(
                      'Picked',
                      style: TextStyle(
                        color: AppTheme.neonGreen[300],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else if (isRequired)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber[900],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(11),
                    bottomRight: Radius.circular(11),
                  ),
                ),
                child: Center(
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: AppTheme.warningAmber[300],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFighterRow(
    String name,
    String record,
    String? odds,
    bool isPicked,
  ) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            color: isPicked ? AppTheme.neonGreen : Colors.white,
            fontSize: 13,
            fontWeight: isPicked ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              record,
              style: TextStyle(
                color: AppTheme.surfaceBlue,
                fontSize: 10,
              ),
            ),
            if (odds != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: odds.startsWith('+') ? AppTheme.neonGreen[900] : AppTheme.errorPink[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  odds,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
  
  Color _getCategoryColor(Fight fight) {
    if (fight.isMainEvent) return AppTheme.errorPink[800]!;
    if (fight.isCoMain) return AppTheme.warningAmber[800]!;
    if (fight.isMainCard) return AppTheme.primaryCyan[800]!;
    if (fight.isPrelim) return Colors.purple[800]!;
    return AppTheme.surfaceBlue!;
  }
  
  String _getCategoryLabel(Fight fight) {
    if (fight.isMainEvent) return 'MAIN EVENT';
    if (fight.isCoMain) return 'CO-MAIN';
    if (fight.isMainCard) return 'MAIN CARD';
    if (fight.isPrelim) return 'PRELIMS';
    return 'EARLY PRELIMS';
  }
  
  Widget _buildBottomBar() {
    final totalRequired = _requiredFights.length;
    final pickedCount = _userPicks.values
        .where((pick) => _requiredFights.any((f) => f.id == pick.fightId))
        .length;
    
    final canSubmit = pickedCount >= totalRequired;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        border: Border(
          top: BorderSide(color: AppTheme.surfaceBlue!),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Entry Fee: ${widget.pool.buyIn} BR',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Prize Pool: ${widget.pool.prizePool} BR',
                    style: TextStyle(
                      color: AppTheme.surfaceBlue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: canSubmit && !_isSubmitting ? _submitPicks : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canSubmit ? AppTheme.neonGreen : AppTheme.surfaceBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      canSubmit ? 'Submit Picks' : 'Complete Picks',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _openFightDetail(Fight fight) async {
    final result = await Navigator.push<FightPick>(
      context,
      MaterialPageRoute(
        builder: (context) => FightPickDetailScreen(
          fight: fight,
          event: widget.event,
          odds: _fightOdds[fight.id],
          existingPick: _userPicks[fight.id],
          poolId: widget.pool.id,
          userId: widget.userId,
        ),
      ),
    );
    
    if (result != null) {
      setState(() {
        _userPicks[fight.id] = result;
      });
    }
  }
  
  Future<void> _submitPicks() async {
    setState(() => _isSubmitting = true);
    
    try {
      final picks = _userPicks.values.toList();
      
      await _fightService.submitPicks(
        userId: widget.userId,
        poolId: widget.pool.id,
        eventId: widget.event.id,
        picks: picks,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picks submitted successfully!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorPink,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}