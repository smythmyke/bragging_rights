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
import '../../widgets/fighter_image_widget.dart';

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

  late Stream<MMAEvent> _eventStream;
  MMAEvent? _event; // Store current event for use in nested methods

  @override
  void initState() {
    super.initState();
    _initializeEventStream();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeEventStream() {
    print('🎯 MMADetailsScreen loading event: ${widget.eventId}');
    print('📝 Event name: ${widget.eventName}');
    print('📝 Game data provided: ${widget.gameData != null}');
    if (widget.gameData != null) {
      print('📝 Game data keys: ${widget.gameData!.keys}');
    }

    print('🔄 Creating event stream...');
    _eventStream = _mmaService.getEventWithFightsProgressive(
      widget.eventId,
      gameData: widget.gameData,
    );
    print('✅ Event stream initialized');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      body: StreamBuilder<MMAEvent>(
        stream: _eventStream,
        builder: (context, snapshot) {
          print('🔄 StreamBuilder state: ${snapshot.connectionState}');

          if (snapshot.hasError) {
            print('❌ StreamBuilder error: ${snapshot.error}');
            return _buildErrorState(error: snapshot.error.toString());
          }

          if (snapshot.hasData) {
            final event = snapshot.data!;
            print('📥 StreamBuilder data: ${event.name} with ${event.fights.length} fights');
            return _buildContent(event: event);
          }

          print('⏳ StreamBuilder waiting for data...');
          return _buildLoadingState();
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.neonGreen,
      ),
    );
  }

  Widget _buildErrorState({String? error}) {
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
            error ?? 'Something went wrong',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _initializeEventStream();
              });
            },
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

  Widget _buildContent({required MMAEvent event}) {
    // Store event in a local variable for nested methods
    _event = event;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _initializeEventStream();
          });
        },
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
                titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
                title: Container(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Builder(
                        builder: (context) {
                          final displayName = _event!.shortName ?? _event!.name;
                          print('📺 MMA Details Screen Display:');
                          print('  - Event name: "${_event!.name}"');
                          print('  - Event shortName: "${_event!.shortName}"');
                          print('  - Event promotion: "${_event!.promotion}"');
                          print('  - Displaying: "$displayName"');
                          return Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
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
      ),
      bottomNavigationBar: _buildEnterPoolButton(),
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 20), // Add spacing from top to avoid title overlap
            // Promotion Logo
            if (_event!.promotionLogoUrl != null)
              Container(
                width: 80,
                height: 80,
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceBlue,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.borderCyan.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
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
                onFighterTap: _navigateToFighterProfile,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFightCard() {
    // Log fight card display order and section assignments
    print('=== FIGHT CARD DISPLAY ORDER ===');
    print('Event: ${_event!.name}');
    print('Total fights: ${_event!.fights.length}');

    print('\nMAIN CARD (${_event!.mainCardFights.length} fights):');
    for (int i = 0; i < _event!.mainCardFights.length; i++) {
      final fight = _event!.mainCardFights[i];
      final fighter1Name = fight.fighter1?.name ?? 'Unknown';
      final fighter2Name = fight.fighter2?.name ?? 'Unknown';
      final isMain = fight.isMainEvent == true;
      final isComain = fight.isCoMainEvent == true;
      final cardPos = fight.cardPosition ?? 'unknown';
      print('  ${i + 1}. $fighter1Name vs $fighter2Name'
            '${isMain ? " [MAIN EVENT]" : ""}'
            '${isComain ? " [CO-MAIN]" : ""}'
            ' (cardPosition: $cardPos)');
    }

    print('\nPRELIMS (${_event!.prelimFights.length} fights):');
    for (int i = 0; i < _event!.prelimFights.length; i++) {
      final fight = _event!.prelimFights[i];
      final fighter1Name = fight.fighter1?.name ?? 'Unknown';
      final fighter2Name = fight.fighter2?.name ?? 'Unknown';
      final cardPos = fight.cardPosition ?? 'unknown';
      print('  ${i + 1}. $fighter1Name vs $fighter2Name'
            ' (cardPosition: $cardPos)');
    }

    print('\nEARLY PRELIMS (${_event!.earlyPrelimFights.length} fights):');
    for (int i = 0; i < _event!.earlyPrelimFights.length; i++) {
      final fight = _event!.earlyPrelimFights[i];
      final fighter1Name = fight.fighter1?.name ?? 'Unknown';
      final fighter2Name = fight.fighter2?.name ?? 'Unknown';
      final cardPos = fight.cardPosition ?? 'unknown';
      print('  ${i + 1}. $fighter1Name vs $fighter2Name'
            ' (cardPosition: $cardPos)');
    }
    print('===============================\n');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Main Card - Already in correct order (main event first) from service
          if (_event!.mainCardFights.isNotEmpty) ...[
            _buildCardSection(
              title: 'MAIN CARD',
              fights: _event!.mainCardFights,
              color: AppTheme.neonGreen,
              broadcast: _event!.broadcastByCard?['main'] ??
                        _event!.broadcasters?.firstWhere(
                          (String b) => b.contains('PPV') || b.contains('ESPN+'),
                          orElse: () => 'ESPN+',
                        ) ?? 'ESPN+',
            ),
            const SizedBox(height: 16),
          ],

          // Preliminary Card - Already in correct order from service
          if (_event!.prelimFights.isNotEmpty) ...[
            _buildCardSection(
              title: 'PRELIMINARY CARD',
              fights: _event!.prelimFights,
              color: AppTheme.primaryCyan,
              broadcast: _event!.broadcastByCard?['prelim'] ??
                        _event!.broadcasters?.firstWhere(
                          (String b) => b.contains('ESPN') && !b.contains('+'),
                          orElse: () => 'ESPN',
                        ) ?? 'ESPN',
            ),
            const SizedBox(height: 16),
          ],

          // Early Prelims - Already in correct order from service
          if (_event!.earlyPrelimFights.isNotEmpty) ...[
            _buildCardSection(
              title: 'EARLY PRELIMS',
              fights: _event!.earlyPrelimFights,
              color: Colors.grey,
              broadcast: _event!.broadcastByCard?['early'] ?? 'UFC Fight Pass',
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

  Future<void> _showFightDetails(MMAFight fight) async {
    print('🎯 Opening fight details modal');
    print('📊 Fight: ${fight.fightDescription}');
    print('👤 Fighter 1: ${fight.fighter1?.name ?? 'NULL'} (ID: ${fight.fighter1?.id})');
    print('👤 Fighter 2: ${fight.fighter2?.name ?? 'NULL'} (ID: ${fight.fighter2?.id})');

    // Create a mutable copy of the fight to update with loaded data
    MMAFight updatedFight = fight;

    // Load detailed fighter data if needed
    if (fight.fighter1 != null && (fight.fighter1!.height == null || fight.fighter1!.reach == null)) {
      print('⏳ Loading detailed data for fighter 1: ${fight.fighter1!.name}');
      final fighter1Data = await _mmaService.searchFighterByName(fight.fighter1!.name);
      if (fighter1Data != null) {
        updatedFight = updatedFight.copyWith(fighter1: fighter1Data);
        print('✅ Loaded fighter 1 data');
      }
    }

    if (fight.fighter2 != null && (fight.fighter2!.height == null || fight.fighter2!.reach == null)) {
      print('⏳ Loading detailed data for fighter 2: ${fight.fighter2!.name}');
      final fighter2Data = await _mmaService.searchFighterByName(fight.fighter2!.name);
      if (fighter2Data != null) {
        updatedFight = updatedFight.copyWith(fighter2: fighter2Data);
        print('✅ Loaded fighter 2 data');
      }
    }

    if (updatedFight.fighter1 != null) {
      print('🥊 Fighter 1 details:');
      print('  - Record: ${updatedFight.fighter1!.record}');
      print('  - Height: ${updatedFight.fighter1!.displayHeight ?? updatedFight.fighter1!.heightFeetInches}');
      print('  - Weight: ${updatedFight.fighter1!.displayWeight ?? updatedFight.fighter1!.weight}');
      print('  - Reach: ${updatedFight.fighter1!.displayReach ?? updatedFight.fighter1!.reachInches}');
      print('  - Age: ${updatedFight.fighter1!.age}');
      print('  - Stance: ${updatedFight.fighter1!.stance}');
    }

    if (updatedFight.fighter2 != null) {
      print('🥊 Fighter 2 details:');
      print('  - Record: ${updatedFight.fighter2!.record}');
      print('  - Height: ${updatedFight.fighter2!.displayHeight ?? updatedFight.fighter2!.heightFeetInches}');
      print('  - Weight: ${updatedFight.fighter2!.displayWeight ?? updatedFight.fighter2!.weight}');
      print('  - Reach: ${updatedFight.fighter2!.displayReach ?? updatedFight.fighter2!.reachInches}');
      print('  - Age: ${updatedFight.fighter2!.age}');
      print('  - Stance: ${updatedFight.fighter2!.stance}');
    }

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
                    if (updatedFight.fighter1 != null && updatedFight.fighter2 != null) ...[
                      Text('Tale of Tape for: ${updatedFight.fighter1!.name} vs ${updatedFight.fighter2!.name}',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      TaleOfTapeWidget(
                        fighter1: updatedFight.fighter1!,
                        fighter2: updatedFight.fighter2!,
                        weightClass: updatedFight.weightClass,
                        rounds: updatedFight.rounds,
                        isTitle: updatedFight.isTitleFight,
                        showExtended: true,
                        onFighterTap: (fighter) {
                          Navigator.pop(context); // Close modal
                          _navigateToFighterProfile(fighter);
                        },
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 48),
                            const SizedBox(height: 8),
                            Text(
                              'Fighter data not available',
                              style: TextStyle(color: Colors.red, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fighter 1: ${updatedFight.fighter1?.name ?? "Missing"}',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              'Fighter 2: ${updatedFight.fighter2?.name ?? "Missing"}',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
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
        FighterImageWidget(
          fighterId: fighter?.espnId ?? fighter?.id,
          fallbackUrl: fighter?.headshotUrl,
          size: 80,
          shape: BoxShape.circle,
          borderColor: borderColor,
          borderWidth: 3,
          errorWidget: FighterInitialsWidget(
            name: fighter?.name ?? '?',
            size: 80,
            backgroundColor: AppTheme.surfaceBlue,
            textColor: borderColor,
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
        if (fighter != null)
          Text(
            fighter.record.isNotEmpty ? fighter.record : '0-0',
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

  Widget _buildEnterPoolButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _navigateToPoolSelection,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.neonGreen,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIconsRegular.users, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Enter Quick Pool',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPoolSelection() {
    Navigator.pushNamed(
      context,
      '/pool-selection',
      arguments: {
        'gameTitle': _event!.shortName ?? _event!.name,
        'sport': 'MMA',
        'gameId': widget.eventId,
      },
    );
  }
}