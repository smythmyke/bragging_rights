import 'package:flutter/material.dart';
import '../../models/head_to_head_model.dart';
import '../../models/fight_card_model.dart';
import '../../models/pool_model.dart';
import '../../services/head_to_head_service.dart';
// Removed custom app bar import - using standard AppBar
import 'fight_pick_detail_screen.dart';
import 'strategy_room_screen.dart';

/// Screen for making picks in a head-to-head challenge
class H2HPicksScreen extends StatefulWidget {
  final HeadToHeadChallenge challenge;
  final FightCardEventModel event;
  final String userId;
  
  const H2HPicksScreen({
    Key? key,
    required this.challenge,
    required this.event,
    required this.userId,
  }) : super(key: key);
  
  @override
  State<H2HPicksScreen> createState() => _H2HPicksScreenState();
}

class _H2HPicksScreenState extends State<H2HPicksScreen> {
  final HeadToHeadService _h2hService = HeadToHeadService();
  final Map<String, FightPick> _userPicks = {};
  List<Fight> _requiredFights = [];
  bool _isSubmitting = false;
  
  @override
  void initState() {
    super.initState();
    _determineRequiredFights();
  }
  
  void _determineRequiredFights() {
    if (widget.challenge.isFullCard) {
      _requiredFights = widget.event.typedFights;
    } else if (widget.challenge.requiredFightIds != null) {
      _requiredFights = widget.event.typedFights
          .where((f) => widget.challenge.requiredFightIds!.contains(f.id))
          .toList();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isChallenger = widget.challenge.challengerId == widget.userId;
    final opponentName = isChallenger
        ? widget.challenge.opponentName ?? 'Waiting for opponent'
        : widget.challenge.challengerName;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Head-to-Head Picks', style: TextStyle(fontSize: 18)),
            Text(widget.event.eventName, style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildChallengeHeader(opponentName),
          _buildProgressBar(),
          Expanded(child: _buildFightsList()),
          _buildSubmitButton(),
        ],
      ),
    );
  }
  
  Widget _buildChallengeHeader(String opponentName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue[900]!.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  const Icon(Icons.person, color: Colors.blue, size: 40),
                  const SizedBox(height: 4),
                  Text(
                    'You',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Column(
                children: [
                  Icon(
                    Icons.person,
                    color: widget.challenge.opponentId != null
                        ? Colors.red
                        : Colors.grey,
                    size: 40,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    opponentName,
                    style: TextStyle(
                      color: widget.challenge.opponentId != null
                          ? Colors.white
                          : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Winner Takes: ${widget.challenge.totalPot} BR',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
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
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
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
                  color: Colors.grey[400],
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
            backgroundColor: Colors.grey[800],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress == 1.0 ? Colors.green : Colors.blue,
            ),
            minHeight: 6,
          ),
        ],
      ),
    );
  }
  
  Widget _buildFightsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requiredFights.length,
      itemBuilder: (context, index) {
        final fight = _requiredFights[index];
        final userPick = _userPicks[fight.id];
        
        return _buildFightCard(fight, userPick);
      },
    );
  }
  
  Widget _buildFightCard(Fight fight, FightPick? userPick) {
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openFightDetail(fight),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(fight).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getCategoryLabel(fight),
                      style: TextStyle(
                        color: _getCategoryColor(fight),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (userPick != null)
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Picked',
                          style: TextStyle(
                            color: Colors.green[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFighterInfo(
                      fight.fighter1Name,
                      fight.fighter1Record,
                      userPick?.winnerId == fight.fighter1Id,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildFighterInfo(
                      fight.fighter2Name,
                      fight.fighter2Record,
                      userPick?.winnerId == fight.fighter2Id,
                    ),
                  ),
                ],
              ),
              if (userPick != null) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey[800]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (userPick.method != null) ...[
                      _buildPickChip(
                        Icons.sports_mma,
                        userPick.method!,
                        Colors.orange,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (userPick.round != null) ...[
                      _buildPickChip(
                        Icons.timer,
                        'Round ${userPick.round}',
                        Colors.purple,
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < userPick.confidence
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 14,
                        );
                      }),
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
  
  Widget _buildFighterInfo(String name, String record, bool isPicked) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          name,
          style: TextStyle(
            color: isPicked ? Colors.green : Colors.white,
            fontSize: 14,
            fontWeight: isPicked ? FontWeight.bold : FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          record,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPickChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getCategoryColor(Fight fight) {
    if (fight.isMainEvent) return Colors.red;
    if (fight.isCoMain) return Colors.orange;
    if (fight.isMainCard) return Colors.blue;
    if (fight.isPrelim) return Colors.purple;
    return Colors.grey;
  }
  
  String _getCategoryLabel(Fight fight) {
    if (fight.isMainEvent) return 'MAIN EVENT';
    if (fight.isCoMain) return 'CO-MAIN';
    if (fight.isMainCard) return 'MAIN CARD';
    if (fight.isPrelim) return 'PRELIMS';
    return 'EARLY PRELIMS';
  }
  
  Widget _buildSubmitButton() {
    final totalRequired = _requiredFights.length;
    final pickedCount = _userPicks.values
        .where((pick) => _requiredFights.any((f) => f.id == pick.fightId))
        .length;
    
    final canSubmit = pickedCount >= totalRequired &&
        widget.challenge.opponentId != null;
    
    String buttonText;
    if (widget.challenge.opponentId == null) {
      buttonText = 'Waiting for Opponent';
    } else if (pickedCount < totalRequired) {
      buttonText = 'Complete All Picks';
    } else {
      buttonText = 'Submit Picks';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canSubmit && !_isSubmitting ? _submitPicks : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSubmit ? Colors.green : Colors.grey[800],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                    buttonText,
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
  
  Future<void> _openFightDetail(Fight fight) async {
    final result = await Navigator.push<FightPick>(
      context,
      MaterialPageRoute(
        builder: (context) => FightPickDetailScreen(
          fight: fight,
          event: widget.event,
          existingPick: _userPicks[fight.id],
          poolId: widget.challenge.id,  // Use challenge ID as pool ID
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
      // Convert picks to H2H format
      final fightPicks = <String, FightPick>{};
      for (final pick in _userPicks.values) {
        fightPicks[pick.fightId] = pick;
      }
      
      // Navigate to Strategy Room (optional)
      final strategyResult = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Power Up Your Picks?'),
          content: const Text(
            'Add power cards to boost your strategy and gain an edge over your opponent!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StrategyRoomScreen(
                      poolId: widget.challenge.id,
                      pool: Pool(
                        id: widget.challenge.id,
                        name: 'H2H Challenge',
                        gameId: widget.event.id,
                        gameTitle: widget.event.eventName,
                        sport: 'MMA',
                        type: PoolType.tournament,
                        status: PoolStatus.inProgress,
                        buyIn: 0,
                        minPlayers: 2,
                        maxPlayers: 2,
                        currentPlayers: 2,
                        playerIds: [widget.challenge.challengerId, widget.challenge.opponentId ?? ''],
                        startTime: widget.event.gameTime,
                        closeTime: widget.event.gameTime,
                        prizePool: 0,
                        prizeStructure: {},
                        createdAt: DateTime.now(),
                      ),
                      picks: fightPicks,
                      consumedIntel: [],
                      intelCost: 0,
                    ),
                  ),
                );
                return result;
              },
              child: const Text('Add Power Cards'),
            ),
          ],
        ),
      );
      
      final h2hPicks = H2HPicks(
        challengeId: widget.challenge.id,
        userId: widget.userId,
        userName: widget.challenge.challengerId == widget.userId
            ? widget.challenge.challengerName
            : widget.challenge.opponentName!,
        fightPicks: fightPicks,
        submittedAt: DateTime.now(),
        isLocked: true,
      );
      
      await _h2hService.submitPicks(
        challengeId: widget.challenge.id,
        userId: widget.userId,
        picks: h2hPicks,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Picks submitted! Good luck!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
}