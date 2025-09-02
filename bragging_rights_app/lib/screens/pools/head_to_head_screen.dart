import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/head_to_head_model.dart';
import '../../models/fight_card_model.dart';
import '../../services/head_to_head_service.dart';
import '../../services/fight_card_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'h2h_picks_screen.dart';

/// Screen for creating and joining head-to-head challenges
class HeadToHeadScreen extends StatefulWidget {
  final FightCardEventModel event;
  final String userId;
  final String userName;
  
  const HeadToHeadScreen({
    Key? key,
    required this.event,
    required this.userId,
    required this.userName,
  }) : super(key: key);
  
  @override
  State<HeadToHeadScreen> createState() => _HeadToHeadScreenState();
}

class _HeadToHeadScreenState extends State<HeadToHeadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final HeadToHeadService _h2hService = HeadToHeadService();
  
  // Challenge creation
  int _selectedEntryFee = 25;
  ChallengeType _selectedType = ChallengeType.open;
  bool _isFullCard = true;
  List<String> _selectedFightIds = [];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CustomAppBar(
        title: 'Head-to-Head',
        subtitle: widget.event.eventName,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'CREATE'),
            Tab(text: 'OPEN'),
            Tab(text: 'MY CHALLENGES'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(),
          _buildOpenChallengesTab(),
          _buildMyChallengesTab(),
        ],
      ),
    );
  }
  
  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('CHALLENGE TYPE'),
          _buildChallengeTypeSelection(),
          
          _buildSectionTitle('ENTRY FEE'),
          _buildEntryFeeSelection(),
          
          _buildSectionTitle('FIGHTS TO PICK'),
          _buildFightSelection(),
          
          _buildPotentialPayout(),
          _buildCreateButton(),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildChallengeTypeSelection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildTypeOption(
            ChallengeType.open,
            'Open Challenge',
            'Anyone can accept',
            Icons.public,
          ),
          Divider(color: Colors.grey[800], height: 1),
          _buildTypeOption(
            ChallengeType.auto,
            'Auto-Match',
            'System finds opponent',
            Icons.shuffle,
          ),
          Divider(color: Colors.grey[800], height: 1),
          _buildTypeOption(
            ChallengeType.direct,
            'Direct Challenge',
            'Challenge specific user',
            Icons.person_add,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTypeOption(
    ChallengeType type,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = _selectedType == type;
    
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.blue : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.blue : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.blue)
          : null,
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
    );
  }
  
  Widget _buildEntryFeeSelection() {
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: H2HEntryTiers.tiers.length,
        itemBuilder: (context, index) {
          final fee = H2HEntryTiers.tiers[index];
          final isSelected = _selectedEntryFee == fee;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$fee BR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    H2HEntryTiers.getTierName(fee),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedEntryFee = fee;
                });
              },
              backgroundColor: Colors.grey[800],
              selectedColor: Colors.blue[900],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildFightSelection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text(
              'Full Card',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Pick all ${widget.event.fights.length} fights',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            value: _isFullCard,
            onChanged: (value) {
              setState(() {
                _isFullCard = value;
                if (value) {
                  _selectedFightIds.clear();
                }
              });
            },
            activeColor: Colors.blue,
          ),
          if (!_isFullCard) ...[
            Divider(color: Colors.grey[800], height: 1),
            _buildQuickSelectOptions(),
            Divider(color: Colors.grey[800], height: 1),
            _buildCustomFightSelection(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildQuickSelectOptions() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK SELECT',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                label: const Text('Main Card'),
                onPressed: () {
                  setState(() {
                    _selectedFightIds = widget.event.mainCard
                        .map((f) => f.id)
                        .toList();
                  });
                },
                backgroundColor: Colors.blue[900],
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              ActionChip(
                label: const Text('Main Event Only'),
                onPressed: () {
                  setState(() {
                    _selectedFightIds = widget.event.fights
                        .where((f) => f.isMainEvent)
                        .map((f) => f.id)
                        .toList();
                  });
                },
                backgroundColor: Colors.red[900],
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomFightSelection() {
    return Container(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: widget.event.fights.length,
        itemBuilder: (context, index) {
          final fight = widget.event.fights[index];
          final isSelected = _selectedFightIds.contains(fight.id);
          
          return CheckboxListTile(
            dense: true,
            title: Text(
              '${fight.fighter1Name} vs ${fight.fighter2Name}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            subtitle: Text(
              _getFightCategory(fight),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            value: isSelected,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedFightIds.add(fight.id);
                } else {
                  _selectedFightIds.remove(fight.id);
                }
              });
            },
            activeColor: Colors.blue,
            checkColor: Colors.white,
          );
        },
      ),
    );
  }
  
  String _getFightCategory(Fight fight) {
    if (fight.isMainEvent) return 'Main Event';
    if (fight.isCoMain) return 'Co-Main Event';
    if (fight.isMainCard) return 'Main Card';
    if (fight.isPrelim) return 'Prelims';
    return 'Early Prelims';
  }
  
  Widget _buildPotentialPayout() {
    final totalPot = _selectedEntryFee * 2;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[900]!, Colors.green[800]!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WINNER TAKES ALL',
                style: TextStyle(
                  color: Colors.green[300],
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalPot BR',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Icon(
            Icons.emoji_events,
            color: Colors.green[300],
            size: 40,
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreateButton() {
    final fightsToPickCount = _isFullCard
        ? widget.event.fights.length
        : _selectedFightIds.length;
    
    final canCreate = fightsToPickCount > 0;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canCreate ? _createChallenge : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canCreate ? Colors.blue : Colors.grey[800],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Create Challenge ($fightsToPickCount fights)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  Widget _buildOpenChallengesTab() {
    return StreamBuilder<List<HeadToHeadChallenge>>(
      stream: Stream.periodic(const Duration(seconds: 5))
          .asyncMap((_) => _h2hService.getOpenChallenges(
                eventId: widget.event.id,
              )),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final challenges = snapshot.data!
            .where((c) => c.challengerId != widget.userId)
            .toList();
        
        if (challenges.isEmpty) {
          return _buildEmptyState(
            'No Open Challenges',
            'Be the first to create a challenge!',
            Icons.sports_mma,
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return _buildChallengeCard(challenge);
          },
        );
      },
    );
  }
  
  Widget _buildChallengeCard(HeadToHeadChallenge challenge) {
    final fightsCount = challenge.isFullCard
        ? widget.event.fights.length
        : (challenge.requiredFightIds?.length ?? 0);
    
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _acceptChallenge(challenge),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.challengerName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getChallengeDescription(challenge, fightsCount),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${challenge.entryFee} BR',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Win: ${challenge.totalPot} BR',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChallengeChip(
                    Icons.sports_mma,
                    '$fightsCount fights',
                  ),
                  const SizedBox(width: 8),
                  _buildChallengeChip(
                    Icons.access_time,
                    _getTimeAgo(challenge.createdAt),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _acceptChallenge(challenge),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'ACCEPT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getChallengeDescription(HeadToHeadChallenge challenge, int fightsCount) {
    if (challenge.isFullCard) {
      return 'Full Card ($fightsCount fights)';
    } else if (challenge.requiredFightIds?.length == 1) {
      return 'Single Fight';
    } else {
      return 'Custom ($fightsCount fights)';
    }
  }
  
  Widget _buildChallengeChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMyChallengesTab() {
    return StreamBuilder<List<HeadToHeadChallenge>>(
      stream: Stream.periodic(const Duration(seconds: 5))
          .asyncMap((_) => _h2hService.getUserChallenges(userId: widget.userId)),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final challenges = snapshot.data!;
        
        if (challenges.isEmpty) {
          return _buildEmptyState(
            'No Active Challenges',
            'Create or join a challenge to get started!',
            Icons.history,
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return _buildMyChallengeCard(challenge);
          },
        );
      },
    );
  }
  
  Widget _buildMyChallengeCard(HeadToHeadChallenge challenge) {
    final isChallenger = challenge.challengerId == widget.userId;
    final opponentName = isChallenger
        ? (challenge.opponentName ?? 'Waiting...')
        : challenge.challengerName;
    
    Color statusColor;
    String statusText;
    
    switch (challenge.status) {
      case ChallengeStatus.open:
        statusColor = Colors.orange;
        statusText = 'WAITING';
        break;
      case ChallengeStatus.matched:
        statusColor = Colors.blue;
        statusText = 'MATCHED';
        break;
      case ChallengeStatus.locked:
        statusColor = Colors.purple;
        statusText = 'LOCKED';
        break;
      case ChallengeStatus.live:
        statusColor = Colors.red;
        statusText = 'LIVE';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'PENDING';
    }
    
    return Card(
      color: Colors.grey[900],
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: challenge.isMatched 
            ? () => _openPicksScreen(challenge)
            : null,
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
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${challenge.totalPot} BR',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'You',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    color: challenge.opponentId != null
                        ? Colors.red
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opponentName,
                    style: TextStyle(
                      color: challenge.opponentId != null
                          ? Colors.white
                          : Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (challenge.isMatched) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _openPicksScreen(challenge),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'MAKE PICKS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
  
  Future<void> _createChallenge() async {
    try {
      final challenge = HeadToHeadChallenge(
        id: '',
        eventId: widget.event.id,
        eventName: widget.event.eventName,
        sport: 'MMA',
        type: _selectedType,
        challengerId: widget.userId,
        challengerName: widget.userName,
        entryFee: _selectedEntryFee,
        status: ChallengeStatus.open,
        createdAt: DateTime.now(),
        isFullCard: _isFullCard,
        requiredFightIds: _isFullCard ? null : _selectedFightIds,
      );
      
      await _h2hService.createChallenge(challenge: challenge);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Switch to My Challenges tab
      _tabController.animateTo(2);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _acceptChallenge(HeadToHeadChallenge challenge) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Accept Challenge?'),
        content: Text(
          'Entry Fee: ${challenge.entryFee} BR\n'
          'Potential Win: ${challenge.totalPot} BR',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await _h2hService.acceptChallenge(
        challengeId: challenge.id,
        userId: widget.userId,
        userName: widget.userName,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge accepted!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Open picks screen
      _openPicksScreen(challenge);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _openPicksScreen(HeadToHeadChallenge challenge) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => H2HPicksScreen(
          challenge: challenge,
          event: widget.event,
          userId: widget.userId,
        ),
      ),
    );
  }
}