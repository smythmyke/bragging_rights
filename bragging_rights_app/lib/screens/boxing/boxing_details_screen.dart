import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../models/boxing_event_model.dart';
import '../../models/boxing_fight_model.dart';
import '../../models/boxing_fighter_model.dart';
import '../../services/boxing_service.dart';
import '../../services/boxing_odds_service.dart';
import '../../theme/app_theme.dart';
import 'tabs/fight_card_tab.dart';
import 'tabs/event_info_tab.dart';
import 'tabs/fighters_tab.dart';
import 'tabs/broadcast_tab.dart';
import 'tabs/basic_event_info_tab.dart';
import 'tabs/espn_preview_tab.dart';

class BoxingDetailsScreen extends StatefulWidget {
  final BoxingEvent event;

  const BoxingDetailsScreen({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  State<BoxingDetailsScreen> createState() => _BoxingDetailsScreenState();
}

class _BoxingDetailsScreenState extends State<BoxingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BoxingService _boxingService = BoxingService();

  List<BoxingFight>? _fightCard;
  bool _isLoadingFights = true;
  BoxingEvent? _fullEventDetails;

  @override
  void initState() {
    super.initState();
    // Dynamic tab count based on data availability
    final tabCount = widget.event.hasFullData ? 4 : 2;
    _tabController = TabController(length: tabCount, vsync: this);

    _loadEventData();
  }

  Future<void> _loadEventData() async {
    // Load full event details
    final fullDetails = await _boxingService.getEventDetails(
      widget.event.id,
      widget.event.source,
    );

    if (fullDetails != null) {
      setState(() {
        _fullEventDetails = fullDetails;
      });
    }

    // Load fight card if we have full data
    if (widget.event.hasFullData) {
      await _loadFightCard();
    } else {
      setState(() {
        _isLoadingFights = false;
      });
    }
  }

  Future<void> _loadFightCard() async {
    try {
      // First check if the event already has fights with enriched data
      if (widget.event is BoxingEventWithFights) {
        final eventWithFights = widget.event as BoxingEventWithFights;
        setState(() {
          _fightCard = eventWithFights.fights;
          _isLoadingFights = false;
        });
        return;
      }

      // Otherwise load from Firestore (will not have images)
      final fights = await _boxingService.getFightCard(widget.event.id);
      setState(() {
        _fightCard = fights;
        _isLoadingFights = false;
      });
    } catch (e) {
      print('Error loading fight card: $e');
      setState(() {
        _isLoadingFights = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = _fullEventDetails ?? widget.event;

    return Scaffold(
      backgroundColor: AppTheme.cardBlue,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 240.0,  // Increased from 200 to prevent overlap
              floating: false,
              pinned: true,
              backgroundColor: AppTheme.deepBlue,
              leading: IconButton(
                icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold)),
                onPressed: () => Navigator.pop(context),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(
                  left: 16.0,
                  bottom: 60.0,  // Increased bottom padding to move title up from tabs
                ),
                title: Text(
                  event.title,
                  style: const TextStyle(
                    fontFamily: 'Bebas Neue',
                    fontSize: 18,  // Slightly smaller to fit better
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (event.posterUrl != null)
                      Image.network(
                        event.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  AppTheme.deepBlue,
                                  AppTheme.cardBlue,
                                ],
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIcons.boxingGlove(PhosphorIconsStyle.fill),
                                size: 80,
                                color: AppTheme.surfaceBlue,
                              ),
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppTheme.deepBlue,
                              AppTheme.cardBlue,
                            ],
                          ),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),  // Lighter overlay at top
                            AppTheme.deepBlue.withOpacity(0.9),  // Darker at bottom for text contrast
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48.0),
                child: Container(
                  color: AppTheme.deepBlue,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.neonGreen,
                    indicatorWeight: 3,
                    labelColor: AppTheme.neonGreen,
                    unselectedLabelColor: Colors.grey,
                    tabs: _buildTabs(),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: _buildTabViews(event),
        ),
      ),
    );
  }

  List<Tab> _buildTabs() {
    if (widget.event.hasFullData) {
      return const [
        Tab(text: 'FIGHT CARD'),
        Tab(text: 'EVENT INFO'),
        Tab(text: 'FIGHTERS'),
        Tab(text: 'BROADCAST'),
      ];
    } else {
      // ESPN fallback - limited tabs
      return const [
        Tab(text: 'EVENT INFO'),
        Tab(text: 'PREVIEW'),
      ];
    }
  }

  List<Widget> _buildTabViews(BoxingEvent event) {
    if (widget.event.hasFullData) {
      return [
        FightCardTab(
          fights: _fightCard,
          isLoading: _isLoadingFights,
        ),
        EventInfoTab(event: event),
        FightersTab(
          fights: _fightCard,
          boxingService: _boxingService,
        ),
        BroadcastTab(event: event),
      ];
    } else {
      // ESPN fallback - limited views
      return [
        BasicEventInfoTab(event: event),
        ESPNPreviewTab(event: event),
      ];
    }
  }
}

// Data source indicator widget
class DataSourceIndicator extends StatelessWidget {
  final DataSource source;

  const DataSourceIndicator({
    Key? key,
    required this.source,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isFullData = source == DataSource.boxingData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isFullData ? AppTheme.neonGreen.withOpacity(0.2) : AppTheme.warningAmber.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isFullData ? AppTheme.neonGreen : AppTheme.warningAmber,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFullData
                ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                : PhosphorIcons.info(PhosphorIconsStyle.fill),
            size: 12,
            color: isFullData ? AppTheme.neonGreen : AppTheme.warningAmber,
          ),
          const SizedBox(width: 4),
          Text(
            isFullData ? 'Full Data' : 'Basic Info',
            style: TextStyle(
              fontSize: 10,
              color: isFullData ? AppTheme.neonGreen : AppTheme.warningAmber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}