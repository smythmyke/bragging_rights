import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/fight_card_model.dart';
import '../../models/fight_card_scoring.dart';
import '../../services/fight_odds_service.dart';
// Removed custom app bar import - using standard AppBar

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
  
  @override
  void initState() {
    super.initState();
    _loadOddsAndPicks();
  }
  
  Future<void> _loadOddsAndPicks() async {
    setState(() => _isLoading = true);
    
    try {
      // Load odds for all fights
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.eventName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.poolName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInstructions,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
      color: Colors.grey[900],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$pickedFights of $totalFights picks made',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : Colors.orange,
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
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
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
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Weight class and fight details
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  fight.weightClass.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (fight.isTitle) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TITLE',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  '${fight.rounds} ROUNDS',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Fighter cards
          Row(
            children: [
              Expanded(
                child: _buildFighterCard(
                  fight: fight,
                  fighterId: fight.fighter1Id,
                  fighterName: fight.fighter1Name,
                  record: fight.fighter1Record,
                  country: fight.fighter1Country,
                  odds: odds?.fighter1OddsDisplay,
                  isLeft: true,
                  pick: pick,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: _buildFighterCard(
                  fight: fight,
                  fighterId: fight.fighter2Id,
                  fighterName: fight.fighter2Name,
                  record: fight.fighter2Record,
                  country: fight.fighter2Country,
                  odds: odds?.fighter2OddsDisplay,
                  isLeft: false,
                  pick: pick,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFighterCard({
    required Fight fight,
    required String fighterId,
    required String fighterName,
    required String record,
    required String country,
    String? odds,
    required bool isLeft,
    FightPickState? pick,
  }) {
    final isSelected = pick?.winnerId == fighterId;
    final isTie = pick?.method == 'TIE';
    final isOpponentSelected = pick?.winnerId != null && 
                               pick?.winnerId != fighterId && 
                               !isTie;
    
    return GestureDetector(
      onTap: () => _handleFighterTap(fight, fighterId, fighterName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected || isTie
              ? Colors.green.withOpacity(0.15)
              : Colors.grey[900],
          border: Border.all(
            color: isSelected || isTie
                ? Colors.green
                : isOpponentSelected
                    ? Colors.grey[700]!
                    : Colors.grey[800]!,
            width: isSelected || isTie ? 2 : 1,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: isLeft ? const Radius.circular(8) : Radius.zero,
            bottomRight: !isLeft ? const Radius.circular(8) : Radius.zero,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Fighter avatar placeholder
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.grey[800],
              child: Text(
                fighterName.split(' ').map((n) => n[0]).join(),
                style: TextStyle(
                  color: isSelected || isTie ? Colors.green : Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Fighter name
            Text(
              fighterName.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected || isTie ? Colors.green : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Record
            Text(
              record,
              style: TextStyle(
                color: isSelected || isTie ? Colors.green[300] : Colors.white60,
                fontSize: 11,
              ),
            ),
            if (odds != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: odds.startsWith('+') 
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  odds,
                  style: TextStyle(
                    color: odds.startsWith('+') ? Colors.blue : Colors.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            // Method indicator
            if (isSelected && pick?.method != null && pick?.method != 'TIE') ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pick!.method!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            // TIE indicator
            if (isTie) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'TIE',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
      // If same fighter tapped, cycle through methods
      else if (currentPick.winnerId == fighterId && currentPick.method != 'TIE') {
        final methods = ['KO', 'TKO', 'SUB', 'DEC', 'TIE', null];
        final currentIndex = methods.indexOf(currentPick.method);
        final nextIndex = (currentIndex + 1) % methods.length;
        final nextMethod = methods[nextIndex];
        
        if (nextMethod == 'TIE') {
          // Set TIE for both fighters
          _picks[fight.id] = FightPickState(
            winnerId: null,
            winnerName: null,
            method: 'TIE',
          );
        } else if (nextMethod == null) {
          // Back to basic winner pick
          _picks[fight.id] = FightPickState(
            winnerId: fighterId,
            winnerName: fighterName,
          );
        } else {
          // Set specific method
          _picks[fight.id] = FightPickState(
            winnerId: fighterId,
            winnerName: fighterName,
            method: nextMethod,
          );
        }
      }
      // If different fighter tapped, switch selection
      else if (currentPick.winnerId != fighterId || currentPick.method == 'TIE') {
        _picks[fight.id] = FightPickState(
          winnerId: fighterId,
          winnerName: fighterName,
        );
      }
    });
  }
  
  Widget _buildSubmitButton() {
    final hasAnyPicks = _picks.values.any((p) => p.winnerId != null || p.method == 'TIE');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: hasAnyPicks ? _showAdvancedOptions : null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.green.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'ADVANCED BETS',
                style: TextStyle(color: Colors.green),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: hasAnyPicks && !_isSaving ? _savePicks : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'SAVE PICKS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
        backgroundColor: Colors.grey[900],
        title: const Text(
          'How to Pick',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. TAP fighter to select winner (green outline)',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              '2. TAP AGAIN to add method (KO, TKO, SUB, DEC)',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              '3. Keep TAPPING to cycle through methods or TIE',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 8),
            Text(
              '4. TAP opponent to switch selection',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }
  
  Color _getSectionColor(String section) {
    if (section.contains('MAIN CARD')) return Colors.red;
    if (section.contains('PRELIM')) return Colors.blue;
    return Colors.grey;
  }
}

/// State for a single fight pick
class FightPickState {
  final String? winnerId;
  final String? winnerName;
  final String? method; // KO, TKO, SUB, DEC, TIE
  final int confidence;
  
  FightPickState({
    this.winnerId,
    this.winnerName,
    this.method,
    this.confidence = 3,
  });
}