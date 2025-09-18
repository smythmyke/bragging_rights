import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import '../../models/mma_event_model.dart';
import '../../models/mma_fighter_model.dart';
import '../../services/mma_service.dart';
import '../../theme/app_theme.dart';
import 'widgets/tale_of_tape_widget.dart';
import 'widgets/fight_card_item.dart';

class MMADetailsScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final DateTime? eventDate;
  final Map<String, dynamic>? gameData;

  const MMADetailsScreen({
    Key? key,
    required this.eventId,
    required this.eventName,
    this.eventDate,
    this.gameData,
  }) : super(key: key);

  @override
  State<MMADetailsScreen> createState() => _MMADetailsScreenState();
}

class _MMADetailsScreenState extends State<MMADetailsScreen> {
  final MMAService _mmaService = MMAService();
  final ScrollController _scrollController = ScrollController();

  MMAEvent? _event;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🎯 MMADetailsScreen loading event: ${widget.eventId}');
      print('📝 Event name: ${widget.eventName}');

      final event = await _mmaService.getEventWithFights(
        widget.eventId,
        gameData: widget.gameData,
      );

      if (mounted) {
        if (event != null) {
          print('✅ Event loaded successfully');
          setState(() {
            _event = event;
            _isLoading = false;
          });
        } else {
          print('⚠️ No event data available');
          setState(() {
            _event = null;
            _error = 'Unable to load event details. Please check your connection and try again.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error loading MMA event: $e');
      if (mounted) {
        setState(() {
          _event = null;
          _error = 'Failed to load event details: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.neonGreen,
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.warning,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadEventDetails,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryCyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_event == null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadEventDetails,
      color: AppTheme.neonGreen,
      backgroundColor: AppTheme.surfaceBlue,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 220.0,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.deepBlue,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    _event!.shortName ?? _event!.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _event!.formattedDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              background: _buildEventHeader(),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _shareEvent,
              ),
            ],
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Main Event Tale of the Tape
                if (_event!.mainEvent != null)
                  _buildMainEventSection(),

                // Fight Card
                _buildFightCard(),

                // Event Information
                _buildEventInfo(),

                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryCyan.withOpacity(0.3),
            AppTheme.deepBlue,
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Promotion Logo
            if (_event!.promotionLogoUrl != null)
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: _event!.promotionLogoUrl!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.neonGreen,
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Text(
                      _event!.promotion ?? 'MMA',
                      style: const TextStyle(
                        color: AppTheme.neonGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.borderCyan.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    _event!.promotion ?? 'MMA',
                    style: const TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Venue Info Only (Date moved to title)
            if (_event!.venueName != null || _event!.venueCity != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.mapPin,
                    size: 16,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _event!.venueLocation,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainEventSection() {
    final mainEvent = _event!.mainEvent!;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFD700).withOpacity(0.1),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Main Event Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star,
                  color: Colors.black,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  mainEvent.isTitleFight ? 'MAIN EVENT - TITLE FIGHT' : 'MAIN EVENT',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.star,
                  color: Colors.black,
                  size: 20,
                ),
              ],
            ),
          ),

          // Tale of the Tape
          if (mainEvent.fighter1 != null && mainEvent.fighter2 != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TaleOfTapeWidget(
                fighter1: mainEvent.fighter1!,
                fighter2: mainEvent.fighter2!,
                weightClass: mainEvent.weightClass,
                rounds: mainEvent.rounds,
                isTitle: mainEvent.isTitleFight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFightCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Main Card
          if (_event!.mainCardFights.isNotEmpty) ...[
            _buildCardSection(
              title: 'MAIN CARD',
              fights: _event!.mainCardFights,
              color: AppTheme.neonGreen,
              broadcast: _event!.broadcasters?.firstWhere(
                (b) => b.contains('PPV') || b.contains('ESPN+'),
                orElse: () => 'ESPN+',
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Preliminary Card
          if (_event!.prelimFights.isNotEmpty) ...[
            _buildCardSection(
              title: 'PRELIMINARY CARD',
              fights: _event!.prelimFights,
              color: AppTheme.primaryCyan,
              broadcast: _event!.broadcasters?.firstWhere(
                (b) => b.contains('ESPN') && !b.contains('+'),
                orElse: () => 'ESPN',
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Early Prelims
          if (_event!.earlyPrelimFights.isNotEmpty) ...[
            _buildCardSection(
              title: 'EARLY PRELIMS',
              fights: _event!.earlyPrelimFights,
              color: Colors.grey,
              broadcast: 'UFC Fight Pass',
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required List<MMAFight> fights,
    required Color color,
    String? broadcast,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.1),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(
                  color: color.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                if (broadcast != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      broadcast,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Fights List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fights.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: AppTheme.borderCyan.withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              return FightCardItem(
                fight: fights[index],
                onTap: () => _showFightDetails(fights[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventInfo() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.borderCyan.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EVENT INFORMATION',
            style: TextStyle(
              color: AppTheme.neonGreen,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),

          // Venue
          _buildInfoRow(
            icon: PhosphorIconsRegular.buildings,
            label: 'Venue',
            value: _event!.venueName ?? 'TBA',
          ),
          const SizedBox(height: 12),

          // Location
          _buildInfoRow(
            icon: PhosphorIconsRegular.mapPin,
            label: 'Location',
            value: _event!.venueLocation,
          ),
          const SizedBox(height: 12),

          // Broadcast
          if (_event!.broadcasters != null &&
              _event!.broadcasters!.isNotEmpty) ...[
            _buildInfoRow(
              icon: PhosphorIconsRegular.television,
              label: 'Broadcast',
              value: _event!.broadcasters!.join(', '),
            ),
            const SizedBox(height: 12),
          ],

          // Total Fights
          _buildInfoRow(
            icon: PhosphorIconsRegular.boxingGlove,
            label: 'Total Fights',
            value: '${_event!.fights.length}',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppTheme.primaryCyan,
        ),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showFightDetails(MMAFight fight) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.cardBlue,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Fighter Images Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Fighter 1
                        _buildFighterImageWithName(fight.fighter1, true),
                        // VS
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.neonGreen.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              color: AppTheme.neonGreen,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Fighter 2
                        _buildFighterImageWithName(fight.fighter2, false),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Fight Description
                    Text(
                      fight.fightDescription,
                      style: const TextStyle(
                        color: AppTheme.neonGreen,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Tale of the Tape
                    if (fight.fighter1 != null && fight.fighter2 != null)
                      TaleOfTapeWidget(
                        fighter1: fight.fighter1!,
                        fighter2: fight.fighter2!,
                        weightClass: fight.weightClass,
                        rounds: fight.rounds,
                        isTitle: fight.isTitleFight,
                        showExtended: true,
                      ),

                    const SizedBox(height: 20),

                    // View Profile Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close modal
                              _navigateToFighterProfile(fight.fighter1);
                            },
                            icon: const Icon(PhosphorIconsRegular.user),
                            label: Text(
                              'View ${fight.fighter1?.shortName ?? "Fighter 1"} Profile',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryCyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context); // Close modal
                              _navigateToFighterProfile(fight.fighter2);
                            },
                            icon: const Icon(PhosphorIconsRegular.user),
                            label: Text(
                              'View ${fight.fighter2?.shortName ?? "Fighter 2"} Profile',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryCyan,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFighterImageWithName(MMAFighter? fighter, bool isRedCorner) {
    final borderColor = isRedCorner ? Colors.red : Colors.blue;
    final cornerText = isRedCorner ? 'RED' : 'BLUE';

    return Column(
      children: [
        // Corner indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: borderColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            cornerText,
            style: TextStyle(
              color: borderColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Fighter image
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 3,
            ),
            color: AppTheme.surfaceBlue,
          ),
          child: ClipOval(
            child: fighter?.headshotUrl != null
                ? CachedNetworkImage(
                    imageUrl: fighter!.headshotUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.neonGreen,
                      ),
                    ),
                    errorWidget: (context, url, error) => Center(
                      child: Text(
                        fighter.shortName.substring(0, 2).toUpperCase(),
                        style: TextStyle(
                          color: borderColor,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      fighter?.shortName.substring(0, min(2, fighter.shortName.length)).toUpperCase() ?? '?',
                      style: TextStyle(
                        color: borderColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // Fighter name
        SizedBox(
          width: 100,
          child: Text(
            fighter?.name ?? 'TBD',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Record
        if (fighter?.record != null)
          Text(
            fighter!.record,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
      ],
    );
  }

  void _navigateToFighterProfile(MMAFighter? fighter) {
    if (fighter == null) return;

    Navigator.pushNamed(
      context,
      '/fighter-details',
      arguments: {
        'fighterId': fighter.id,
        'fighterName': fighter.name,
        'record': fighter.record,
        'sport': 'MMA',
        'espnId': fighter.espnId,
      },
    );
  }

  void _shareEvent() {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality coming soon!'),
        backgroundColor: AppTheme.surfaceBlue,
      ),
    );
  }
}