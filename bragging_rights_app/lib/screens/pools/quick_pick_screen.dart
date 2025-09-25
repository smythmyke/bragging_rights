import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/fight_card_model.dart';
import '../../models/pool_model.dart';
import '../../models/fight_card_scoring.dart';
import '../../services/fight_card_service.dart';
import '../../services/fighter_data_service.dart';
import '../../theme/app_theme.dart';

/// Quick Pick screen for rapid fight selections
class QuickPickScreen extends StatefulWidget {
  final FightCardEventModel event;
  final Pool pool;
  final String userId;
  
  const QuickPickScreen({
    Key? key,
    required this.event,
    required this.pool,
    required this.userId,
  }) : super(key: key);
  
  @override
  State<QuickPickScreen> createState() => _QuickPickScreenState();
}

class _QuickPickScreenState extends State<QuickPickScreen> {
  final FightCardService _fightService = FightCardService();
  final FighterDataService _fighterService = FighterDataService();
  
  // Track selections: fightId -> fighterId
  final Map<String, String> _selections = {};
  
  // Fighter data cache
  final Map<String, FighterData> _fighterData = {};
  
  // Loading states
  bool _isLoadingFighters = true;
  bool _isSubmitting = false;
  
  // Scroll controller for smooth scrolling
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadFighterData();
    _loadExistingPicks();
  }
  
  Future<void> _loadFighterData() async {
    setState(() => _isLoadingFighters = true);
    
    try {
      // Create fighter requests for batch loading
      final requests = <FighterRequest>[];
      
      for (final fight in widget.event.typedFights) {
        // Add fighter 1 - Use ESPN ID if available, fall back to name-based ID
        final fighter1EspnId = fight.fighter1EspnId ?? fight.fighter1Id;
        requests.add(FighterRequest(
          fighterId: fighter1EspnId,
          fighterName: fight.fighter1Name,
          espnId: fighter1EspnId,
        ));

        // Add fighter 2 - Use ESPN ID if available, fall back to name-based ID
        final fighter2EspnId = fight.fighter2EspnId ?? fight.fighter2Id;
        requests.add(FighterRequest(
          fighterId: fighter2EspnId,
          fighterName: fight.fighter2Name,
          espnId: fighter2EspnId,
        ));
      }
      
      // Batch fetch all fighters
      final fighterData = await _fighterService.batchGetFighters(requests);
      
      setState(() {
        _fighterData.addAll(fighterData);
        _isLoadingFighters = false;
      });
    } catch (e) {
      debugPrint('Error loading fighter data: $e');
      setState(() => _isLoadingFighters = false);
    }
  }
  
  Future<void> _loadExistingPicks() async {
    try {
      final picks = await _fightService.getUserPicks(
        userId: widget.userId,
        poolId: widget.pool.id,
      );
      
      setState(() {
        for (final pick in picks) {
          _selections[pick.fightId] = pick.pickedFighterId;
        }
      });
    } catch (e) {
      debugPrint('Error loading existing picks: $e');
    }
  }
  
  void _selectFighter(String fightId, String fighterId) {
    debugPrint('[QUICK_PICK] Selecting fighter: fightId=$fightId, fighterId=$fighterId');
    debugPrint('[QUICK_PICK] Current selections before: $_selections');

    setState(() {
      _selections[fightId] = fighterId;
    });

    debugPrint('[QUICK_PICK] Current selections after: $_selections');

    // Haptic feedback
    HapticFeedback.lightImpact();
  }
  
  Future<void> _submitAllPicks() async {
    if (_selections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please make at least one selection')),
      );
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      // Create FightPick objects
      final picks = <FightPick>[];
      
      for (final entry in _selections.entries) {
        picks.add(FightPick(
          id: '${widget.userId}_${widget.pool.id}_${entry.key}',
          userId: widget.userId,
          poolId: widget.pool.id,
          eventId: widget.event.id,
          fightId: entry.key,
          pickedFighterId: entry.value,
          confidence: 1, // Default confidence for quick picks
          pickMethod: 'quick', // Track that this was a quick pick
          timestamp: DateTime.now(),
        ));
      }
      
      // Submit all picks
      await _fightService.submitPicks(picks);
      
      // Show success
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Submitted ${picks.length} picks!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back
      Navigator.pop(context, true);
      
    } catch (e) {
      debugPrint('Error submitting picks: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final pickedCount = _selections.length;
    final totalFights = widget.event.typedFights.length;
    final progress = totalFights > 0 ? pickedCount / totalFights : 0.0;
    
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppTheme.deepBlue,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.eventName,
                    style: const TextStyle(fontSize: 18),
                  ),
                  Text(
                    '$pickedCount / $totalFights picks',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Progress Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? Colors.green : AppTheme.primaryRed,
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progress == 1.0 
                      ? 'All picks complete! 🎉'
                      : 'Tap fighter photos to make your picks',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Main Card Section
          if (widget.event.mainCard.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader('🏆 MAIN CARD'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildFightCard(widget.event.mainCard[index]),
                childCount: widget.event.mainCard.length,
              ),
            ),
          ],
          
          // Prelims Section
          if (widget.event.prelims.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader('PRELIMINARY CARD'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildFightCard(widget.event.prelims[index]),
                childCount: widget.event.prelims.length,
              ),
            ),
          ],
          
          // Early Prelims Section
          if (widget.event.earlyPrelims.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader('EARLY PRELIMS'),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildFightCard(widget.event.earlyPrelims[index]),
                childCount: widget.event.earlyPrelims.length,
              ),
            ),
          ],
          
          // Submit Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAllPicks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: progress == 1.0 ? Colors.green : AppTheme.primaryRed,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      progress == 1.0 
                        ? 'Submit All Picks'
                        : 'Submit ${pickedCount} Pick${pickedCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black.withOpacity(0.3),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildFightCard(Fight fight) {
    // Use ESPN IDs if available for proper fighter identification
    final fighter1Id = fight.fighter1EspnId ?? fight.fighter1Id;
    final fighter2Id = fight.fighter2EspnId ?? fight.fighter2Id;

    final isSelected1 = _selections[fight.id] == fighter1Id;
    final isSelected2 = _selections[fight.id] == fighter2Id;
    final fighter1Data = _fighterData[fighter1Id];
    final fighter2Data = _fighterData[fighter2Id];

    debugPrint('[QUICK_PICK] Building fight card: ${fight.id}');
    debugPrint('[QUICK_PICK]   Fighter1: ${fight.fighter1Name} (ESPN ID: $fighter1Id) - Selected: $isSelected1');
    debugPrint('[QUICK_PICK]   Fighter2: ${fight.fighter2Name} (ESPN ID: $fighter2Id) - Selected: $isSelected2');
    debugPrint('[QUICK_PICK]   Current selection for this fight: ${_selections[fight.id]}');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isSelected1 || isSelected2) 
            ? AppTheme.primaryRed 
            : Colors.white.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Fight info header
          if (fight.isChampionship || fight.isMainEvent)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Center(
                child: Text(
                  fight.isMainEvent ? 'MAIN EVENT' : 
                  fight.isTitle ? 'TITLE FIGHT' : 
                  fight.positionLabel,
                  style: TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          
          // Fighters
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Fighter 1
                Expanded(
                  child: _buildFighterCard(
                    fight: fight,
                    fighterId: fighter1Id,
                    fighterName: fight.fighter1Name,
                    fighterData: fighter1Data,
                    isSelected: isSelected1,
                    onTap: () => _selectFighter(fight.id, fighter1Id),
                  ),
                ),
                
                // VS divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fight.rounds} RDS',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Fighter 2
                Expanded(
                  child: _buildFighterCard(
                    fight: fight,
                    fighterId: fighter2Id,
                    fighterName: fight.fighter2Name,
                    fighterData: fighter2Data,
                    isSelected: isSelected2,
                    onTap: () => _selectFighter(fight.id, fighter2Id),
                  ),
                ),
              ],
            ),
          ),
          
          // Weight class
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Center(
              child: Text(
                fight.weightClass.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFighterCard({
    required Fight fight,
    required String fighterId,
    required String fighterName,
    FighterData? fighterData,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected 
            ? AppTheme.primaryRed.withOpacity(0.2)
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? AppTheme.primaryRed
              : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Fighter image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: fighterData?.headshotUrl != null
                    ? CachedNetworkImage(
                        imageUrl: fighterData!.headshotUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => _buildFighterPlaceholder(),
                      )
                    : _buildFighterPlaceholder(),
                ),
                
                // Selection indicator
                if (isSelected)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryRed,
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
            
            const SizedBox(height: 8),
            
            // Fighter name
            Text(
              fighterName.split(' ').last, // Last name only for space
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            // Record
            if (fighterData != null)
              Text(
                fighterData.formattedRecord,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFighterPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.person,
        color: Colors.grey[600],
        size: 40,
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}