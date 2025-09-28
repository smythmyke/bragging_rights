import 'package:flutter/material.dart';
import '../../models/fight_card_model.dart';
import '../../models/fight_card_scoring.dart';
// Removed custom app bar import - using standard AppBar

/// Detailed screen for picking a fight winner and method
class FightPickDetailScreen extends StatefulWidget {
  final Fight fight;
  final FightCardEventModel event;
  final FightOdds? odds;
  final FightPick? existingPick;
  final String poolId;
  final String userId;
  
  const FightPickDetailScreen({
    Key? key,
    required this.fight,
    required this.event,
    this.odds,
    this.existingPick,
    required this.poolId,
    required this.userId,
  }) : super(key: key);
  
  @override
  State<FightPickDetailScreen> createState() => _FightPickDetailScreenState();
}

class _FightPickDetailScreenState extends State<FightPickDetailScreen> {
  // Selected values
  String? _selectedWinnerId;
  String? _selectedWinnerName;
  String? _selectedMethod;
  int? _selectedRound;
  int _confidence = 3;
  
  // Method options - determined by sport
  List<String> get _methodOptions {
    final sport = widget.event.sport.toUpperCase();

    if (sport.contains('BOXING')) {
      return [
        'KO/TKO',
        'Decision',
        'Draw',
        'DQ',
      ];
    } else {
      // MMA/UFC
      return [
        'KO/TKO',
        'Submission',
        'Decision',
      ];
    }
  }
  
  @override
  void initState() {
    super.initState();
    
    // Load existing pick if available
    if (widget.existingPick != null) {
      _selectedWinnerId = widget.existingPick!.winnerId;
      _selectedWinnerName = widget.existingPick!.winnerName;
      _selectedMethod = widget.existingPick!.method;
      _selectedRound = widget.existingPick!.round;
      _confidence = widget.existingPick!.confidence;
    }
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
            Text(_getFightTitle()),
            Text(
              widget.event.eventName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFightHeader(),
            _buildFighterSelection(),
            if (_selectedWinnerId != null) ...[
              _buildMethodSelection(),
              _buildRoundSelection(),
              _buildConfidenceSelection(),
            ],
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
  
  String _getFightTitle() {
    if (widget.fight.isMainEvent) return 'MAIN EVENT';
    if (widget.fight.isCoMain) return 'CO-MAIN EVENT';
    if (widget.fight.isMainCard) return 'MAIN CARD';
    if (widget.fight.isPrelim) return 'PRELIMS';
    return 'EARLY PRELIMS';
  }
  
  Widget _buildFightHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getCategoryColor().withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            widget.fight.weightClass,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.fight.isTitle)
            const Text(
              'TITLE FIGHT',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
  
  Widget _buildFighterSelection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'SELECT WINNER',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildFighterCard(
                  widget.fight.fighter1Id,
                  widget.fight.fighter1Name,
                  widget.fight.fighter1Record,
                  widget.odds?.fighter1OddsDisplay,
                  widget.odds?.fighter1IsFavorite ?? false,
                ),
              ),
              Container(
                width: 1,
                height: 120,
                color: Colors.grey[800],
              ),
              Expanded(
                child: _buildFighterCard(
                  widget.fight.fighter2Id,
                  widget.fight.fighter2Name,
                  widget.fight.fighter2Record,
                  widget.odds?.fighter2OddsDisplay,
                  widget.odds?.fighter2IsFavorite ?? false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFighterCard(
    String fighterId,
    String name,
    String record,
    String? odds,
    bool isFavorite,
  ) {
    final isSelected = _selectedWinnerId == fighterId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWinnerId = fighterId;
          _selectedWinnerName = name;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[900]?.withOpacity(0.3) : Colors.transparent,
          border: isSelected
              ? Border.all(color: Colors.blue, width: 2)
              : null,
        ),
        child: Column(
          children: [
            // Fighter icon placeholder
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Icon(
                Icons.person,
                color: isSelected ? Colors.blue : Colors.grey[600],
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.white,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              record,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
            if (odds != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isFavorite ? Colors.red[900] : Colors.green[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  odds,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SELECTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMethodSelection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'METHOD OF VICTORY',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BONUS',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _methodOptions.map((method) {
              final isSelected = _selectedMethod == method;
              return ChoiceChip(
                label: Text(method),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedMethod = selected ? method : null;
                    if (!selected) _selectedRound = null;
                  });
                },
                backgroundColor: Colors.grey[800],
                selectedColor: Colors.blue[900],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
          if (_selectedMethod != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+0.3 bonus points for correct method',
                style: TextStyle(
                  color: Colors.green[400],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRoundSelection() {
    if (_selectedMethod == null || _selectedMethod == 'Decision') return const SizedBox();

    // Determine max rounds based on sport
    final sport = widget.event.sport.toUpperCase();
    final int rounds;

    if (sport.contains('BOXING')) {
      // Boxing: 12 rounds for championship/main events, 10 for others
      rounds = (widget.fight.isMainEvent || widget.fight.isTitle) ? 12 : 10;
    } else {
      // MMA: 5 rounds for championship/main events, 3 for others
      rounds = (widget.fight.isMainEvent || widget.fight.isTitle) ? 5 : 3;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'ROUND',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple[900],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'BONUS',
                  style: TextStyle(
                    color: Colors.purple,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(rounds, (index) {
              final round = index + 1;
              final isSelected = _selectedRound == round;
              return ChoiceChip(
                label: Text('Round $round'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedRound = selected ? round : null;
                  });
                },
                backgroundColor: Colors.grey[800],
                selectedColor: Colors.purple[900],
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[400],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              );
            }),
          ),
          if (_selectedRound != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+0.2 bonus points for correct round',
                style: TextStyle(
                  color: Colors.purple[400],
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildConfidenceSelection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONFIDENCE LEVEL',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              return IconButton(
                icon: Icon(
                  star <= _confidence ? Icons.star : Icons.star_border,
                  color: star <= _confidence ? Colors.amber : Colors.grey[600],
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _confidence = star;
                  });
                },
              );
            }),
          ),
          Center(
            child: Text(
              _getConfidenceText(),
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Multiplier: ${(0.8 + (_confidence * 0.1)).toStringAsFixed(1)}x',
              style: TextStyle(
                color: Colors.amber[400],
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getConfidenceText() {
    switch (_confidence) {
      case 1: return 'Very Uncertain';
      case 2: return 'Uncertain';
      case 3: return 'Neutral';
      case 4: return 'Confident';
      case 5: return 'Very Confident';
      default: return 'Neutral';
    }
  }
  
  Widget _buildSubmitButton() {
    final canSubmit = _selectedWinnerId != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canSubmit ? _savePick : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Colors.blue : Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              widget.existingPick != null ? 'Update Pick' : 'Save Pick',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getCategoryColor() {
    if (widget.fight.isMainEvent) return Colors.red;
    if (widget.fight.isCoMain) return Colors.orange;
    if (widget.fight.isMainCard) return Colors.blue;
    if (widget.fight.isPrelim) return Colors.purple;
    return Colors.grey;
  }
  
  void _savePick() {
    if (_selectedWinnerId == null) return;
    
    final pick = FightPick(
      id: widget.existingPick?.id ?? '',
      fightId: widget.fight.id,
      userId: widget.userId,
      poolId: widget.poolId,
      eventId: widget.event.id,
      winnerId: _selectedWinnerId,
      winnerName: _selectedWinnerName,
      method: _selectedMethod,
      round: _selectedRound,
      confidence: _confidence,
      pickedAt: DateTime.now(),
    );
    
    Navigator.pop(context, pick);
  }
}