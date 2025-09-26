import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/fight_card_model.dart';
import '../../models/fight_card_scoring.dart';
import '../../services/fight_odds_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/fighter_card.dart';
import 'widgets/round_selector.dart';
import 'widgets/event_badge.dart';
import 'widgets/scoring_info.dart';

/// Quick Pick Grid for entire fight card
class FightCardGridScreen extends StatefulWidget {
  final FightCardEventModel event;
  final String poolId;
  final String poolName;
  
  const FightCardGridScreen({
    Key? key,
    required this.event,
    required this.poolId,
    required this.poolName,
  }) : super(key: key);
  
  @override
  State<FightCardGridScreen> createState() => _FightCardGridScreenState();
}

class _FightCardGridScreenState extends State<FightCardGridScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FightOddsService _oddsService = FightOddsService();
  final Map<String, FightPickState> _picks = {};
  Map<String, FightOdds> _odds = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _scoringExpanded = false;
  
  @override
  void initState() {
    super.initState();
    print('🎯 FightCardGridScreen initState called');
    print('   Event ID: ${widget.event.id}');
    print('   Event name: ${widget.event.eventName}');
    print('   Total fights: ${widget.event.totalFights}');
    print('   Pool ID: ${widget.poolId}');
    print('   Pool name: ${widget.poolName}');
    _loadOddsAndPicks();
  }
  
  Future<void> _loadOddsAndPicks() async {
    setState(() => _isLoading = true);

    try {
      // Load odds for all fights (kept for future use, not displayed in UI)
      // Currently using point-based scoring system instead of real odds
      _odds = await _oddsService.getFightCardOdds(event: widget.event);
      
      // Load existing picks if any
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final picksDoc = await _firestore
            .collection('pools')
            .doc(widget.poolId)
            .collection('picks')
            .doc(userId)
            .get();
            
        if (picksDoc.exists) {
          final data = picksDoc.data();
          final fights = data?['fights'] as Map<String, dynamic>? ?? {};
          
          fights.forEach((fightId, pickData) {
            _picks[fightId] = FightPickState(
              winnerId: pickData['winnerId'],
              winnerName: pickData['winnerName'],
              method: pickData['method'],
              confidence: pickData['confidence'] ?? 3,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading odds and picks: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    print('🎨 FightCardGridScreen BUILD method called');
    print('   Is Loading: $_isLoading');
    print('   Odds loaded: ${_odds.length}');
    print('   Picks made: ${_picks.length}');

    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.eventName,
              style: AppTheme.neonText(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryCyan,
              ),
            ),
            Text(
              widget.poolName,
              style: TextStyle(fontSize: 12, color: AppTheme.primaryCyan.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: AppTheme.primaryCyan),
            onPressed: _showInstructions,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryCyan))
          : Column(
              children: [
                _buildProgressBar(),
                ScoringInfo(
                  isExpanded: _scoringExpanded,
                  onToggle: () {
                    setState(() {
                      _scoringExpanded = !_scoringExpanded;
                    });
                  },
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInstructionText(),
                        if (widget.event.mainCard.isNotEmpty) ...[
                          _buildSectionHeader('MAIN CARD'),
                          ..._buildFightCards(widget.event.mainCard),
                        ],
                        if (widget.event.prelims.isNotEmpty) ...[
                          _buildSectionHeader('PRELIMINARIES'),
                          ..._buildFightCards(widget.event.prelims),
                        ],
                        if (widget.event.earlyPrelims.isNotEmpty) ...[
                          _buildSectionHeader('EARLY PRELIMS'),
                          ..._buildFightCards(widget.event.earlyPrelims),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildSubmitButton(),
              ],
            ),
    );
  }
  
  Widget _buildProgressBar() {
    final totalFights = widget.event.typedFights.length;
    final pickedFights = _picks.values.where((p) => p.winnerId != null).length;
    final progress = totalFights > 0 ? pickedFights / totalFights : 0.0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surfaceBlue.withOpacity(0.8), AppTheme.cardBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pickedFights of $totalFights picks made',
                style: TextStyle(color: AppTheme.primaryCyan.withOpacity(0.7), fontSize: 12),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(color: AppTheme.primaryCyan.withOpacity(0.7), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.deepBlue.withOpacity(0.5),
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? AppTheme.neonGreen : AppTheme.primaryCyan,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            color: _getSectionColor(title),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTheme.neonText(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
            ).copyWith(letterSpacing: 1.2),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildFightCards(List<Fight> fights) {
    return fights.map((fight) => _buildFightRow(fight)).toList();
  }
  
  Widget _buildFightRow(Fight fight) {
    final pick = _picks[fight.id];
    final odds = _odds[fight.id];
    final fightIndex = widget.event.typedFights.indexOf(fight);
    final isMainEvent = fightIndex == widget.event.typedFights.length - 1 && widget.event.mainCard.contains(fight);
    final isCoMain = fightIndex == widget.event.typedFights.length - 2 && widget.event.mainCard.contains(fight);

    // Debug logging for weight class and images
    print('🥊 Fight ${fight.id}:');
    print('   Weight Class: "${fight.weightClass}"');
    print('   Fighter1 Image: ${fight.fighter1ImageUrl}');
    print('   Fighter2 Image: ${fight.fighter2ImageUrl}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // Weight class and fight details
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceBlue.withOpacity(0.9), AppTheme.cardBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              border: Border(
                top: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
                left: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
                right: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fight.weightClass.toUpperCase(),
                      style: TextStyle(
                        color: fight.isTitle ? AppTheme.warningAmber : AppTheme.primaryCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (fight.isTitle) ...[
                      const SizedBox(width: 8),
                      Text(
                        'CHAMPIONSHIP',
                        style: TextStyle(
                          color: AppTheme.warningAmber.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${fight.rounds} ROUNDS',
                  style: TextStyle(
                    color: AppTheme.primaryCyan.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // Fighter cards container
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.surfaceBlue.withOpacity(0.4), AppTheme.cardBlue.withOpacity(0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                left: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
                right: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
                bottom: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // Fighter cards
                Row(
                  children: [
                    Expanded(
                      child: FighterCard(
                        fight: fight,
                        fighterId: fight.fighter1Id,
                        fighterName: fight.fighter1Name,
                        record: fight.fighter1Record,
                        country: fight.fighter1Country,
                        odds: null, // odds?.fighter1OddsDisplay - kept for future use
                        imageUrl: fight.fighter1ImageUrl,
                        isLeft: true,
                        pick: pick,
                        onTap: () => _handleFighterTap(fight, fight.fighter1Id, fight.fighter1Name),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: AppTheme.primaryCyan.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: FighterCard(
                        fight: fight,
                        fighterId: fight.fighter2Id,
                        fighterName: fight.fighter2Name,
                        record: fight.fighter2Record,
                        country: fight.fighter2Country,
                        odds: null, // odds?.fighter2OddsDisplay - kept for future use
                        imageUrl: fight.fighter2ImageUrl,
                        isLeft: false,
                        pick: pick,
                        onTap: () => _handleFighterTap(fight, fight.fighter2Id, fight.fighter2Name),
                      ),
                    ),
                  ],
                ),
                // Round selector
                if (pick?.winnerId != null && pick?.method != 'TIE') ...[
                  const SizedBox(height: 12),
                  Center(
                    child: RoundSelector(
                      currentRound: pick?.round,
                      maxRounds: fight.rounds,
                      isActive: true,
                      onTap: () => _cycleRound(fight.id, fight.rounds),
                    ),
                  ),
                ],
                // TIE button
                const SizedBox(height: 12),
                Center(
                  child: _buildTieButton(fight, pick),
                ),
                // Event badge
                if (isMainEvent || isCoMain || fight.isTitle) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: EventBadge(
                      type: isMainEvent
                          ? EventType.mainEvent
                          : isCoMain
                              ? EventType.coMain
                              : EventType.titleFight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
  void _cycleRound(String fightId, int maxRounds) {
    final currentPick = _picks[fightId];
    if (currentPick?.winnerId == null) return; // Must select fighter first

    setState(() {
      int nextRound = ((currentPick?.round ?? 0) % maxRounds) + 1;

      _picks[fightId] = FightPickState(
        winnerId: currentPick!.winnerId,
        winnerName: currentPick.winnerName,
        method: currentPick.method,
        round: nextRound,
        confidence: currentPick.confidence,
      );
    });
  }

  void _handleFighterTap(Fight fight, String fighterId, String fighterName) {
    setState(() {
      final currentPick = _picks[fight.id];

      // If no pick exists, create new with winner
      if (currentPick == null) {
        _picks[fight.id] = FightPickState(
          winnerId: fighterId,
          winnerName: fighterName,
        );
      }
      // If same fighter tapped, cycle through methods (excluding TIE)
      else if (currentPick.winnerId == fighterId && currentPick.method != 'TIE') {
        final methods = ['KO/TKO', 'SUBMISSION', 'DECISION', null];
        final currentIndex = methods.indexOf(currentPick.method);
        final nextIndex = (currentIndex + 1) % methods.length;
        final nextMethod = methods[nextIndex];

        if (nextMethod == null) {
          // Back to basic winner pick
          _picks[fight.id] = FightPickState(
            winnerId: fighterId,
            winnerName: fighterName,
            round: null, // Clear round when cycling back
          );
        } else {
          // Set specific method, preserve round selection if exists
          _picks[fight.id] = FightPickState(
            winnerId: fighterId,
            winnerName: fighterName,
            method: nextMethod,
            round: currentPick.round, // Preserve existing round
          );
        }
      }
      // If different fighter tapped, switch selection
      else if (currentPick.winnerId != fighterId || currentPick.method == 'TIE') {
        _picks[fight.id] = FightPickState(
          winnerId: fighterId,
          winnerName: fighterName,
          round: null, // Clear round when switching fighters
        );
      }
    });
  }

  Widget _buildTieButton(Fight fight, FightPickState? pick) {
    final isTie = pick?.method == 'TIE';

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isTie) {
            // Clear tie selection
            _picks.remove(fight.id);
          } else {
            // Set tie
            _picks[fight.id] = FightPickState(
              winnerId: null,
              winnerName: null,
              method: 'TIE',
            );
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isTie
              ? LinearGradient(
                  colors: [AppTheme.warningAmber.withOpacity(0.3), AppTheme.warningAmber.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isTie ? AppTheme.surfaceBlue.withOpacity(0.3) : null,
          border: Border.all(
            color: isTie ? AppTheme.warningAmber : AppTheme.warningAmber.withOpacity(0.3),
            width: isTie ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: isTie
              ? AppTheme.neonGlow(
                  color: AppTheme.warningAmber,
                  intensity: 0.3,
                )
              : null,
        ),
        child: Text(
          'DRAW / NO CONTEST',
          style: TextStyle(
            color: isTie ? AppTheme.warningAmber : AppTheme.warningAmber.withOpacity(0.7),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    final hasAnyPicks = _picks.values.any((p) => p.winnerId != null || p.method == 'TIE');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.surfaceBlue, AppTheme.cardBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          top: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryCyan.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: hasAnyPicks ? _showAdvancedOptions : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.warningAmber.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Center(
                child: Text(
                  'ADVANCED BETS',
                  style: TextStyle(
                    color: hasAnyPicks ? AppTheme.warningAmber : AppTheme.warningAmber.withOpacity(0.3),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: hasAnyPicks && !_isSaving
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primaryCyan, AppTheme.secondaryCyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: AppTheme.neonGlow(
                        color: AppTheme.primaryCyan,
                        intensity: 0.5,
                      ),
                    )
                  : null,
              child: ElevatedButton(
                onPressed: hasAnyPicks && !_isSaving ? _savePicks : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasAnyPicks && !_isSaving ? Colors.transparent : AppTheme.cardBlue,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryCyan,
                          strokeWidth: 2,
                        ),
                      )
                    : Center(
                        child: Text(
                          'SAVE PICKS (${_picks.values.where((p) => p.winnerId != null || p.method == 'TIE').length}/${widget.event.typedFights.length})',
                          style: TextStyle(
                            color: hasAnyPicks ? Colors.white : AppTheme.primaryCyan.withOpacity(0.3),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _savePicks() async {
    setState(() => _isSaving = true);
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Convert picks to Firestore format
      final picksData = <String, dynamic>{};
      _picks.forEach((fightId, pick) {
        if (pick.winnerId != null || pick.method == 'TIE') {
          picksData[fightId] = {
            'winnerId': pick.winnerId,
            'winnerName': pick.winnerName,
            'method': pick.method,
            'round': pick.round, // Include round prediction
            'confidence': pick.confidence,
            'pickedAt': FieldValue.serverTimestamp(),
          };
        }
      });
      
      // Save to Firestore
      await _firestore
          .collection('pools')
          .doc(widget.poolId)
          .collection('picks')
          .doc(userId)
          .set({
        'eventId': widget.event.id,
        'userId': userId,
        'fights': picksData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picks saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving picks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() => _isSaving = false);
  }
  
  void _showAdvancedOptions() {
    // Navigate to advanced betting screen
    // TODO: Implement navigation to detailed betting view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Advanced betting coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: AppTheme.primaryCyan, size: 24),
            const SizedBox(width: 8),
            Text(
              'How to Make Picks',
              style: TextStyle(color: AppTheme.primaryCyan, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInstructionItem(
              '1',
              'TAP fighter to select winner',
              'Green highlight shows selection',
              AppTheme.neonGreen,
            ),
            const SizedBox(height: 12),
            _buildInstructionItem(
              '2',
              'TAP AGAIN to cycle methods',
              'KO/TKO → SUBMISSION → DECISION',
              AppTheme.primaryCyan,
            ),
            const SizedBox(height: 12),
            _buildInstructionItem(
              '3',
              'Select round prediction',
              'Tap round selector after picking method',
              AppTheme.secondaryCyan,
            ),
            const SizedBox(height: 12),
            _buildInstructionItem(
              '4',
              'Or select DRAW/NO CONTEST',
              'Use the button below fighters',
              AppTheme.warningAmber,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text(
              'GOT IT',
              style: TextStyle(
                color: AppTheme.neonGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Color _getSectionColor(String section) {
    if (section.contains('MAIN CARD')) return AppTheme.errorPink;
    if (section.contains('PRELIM')) return AppTheme.primaryCyan;
    return AppTheme.primaryCyan.withOpacity(0.5);
  }

  Widget _buildInstructionText() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: AppTheme.primaryCyan.withOpacity(0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tap fighter to select winner → Tap again to cycle methods → Select round below',
              style: TextStyle(
                color: AppTheme.primaryCyan.withOpacity(0.7),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// State for a single fight pick
class FightPickState {
  final String? winnerId;
  final String? winnerName;
  final String? method; // KO, TKO, SUB, DEC, TIE
  final int? round; // Round prediction (1-3 or 1-5)
  final int confidence;

  FightPickState({
    this.winnerId,
    this.winnerName,
    this.method,
    this.round,
    this.confidence = 3,
  });
}