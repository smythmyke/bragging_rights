import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/pool_management_service.dart';
import 'services/game_cache_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/sports_selection_screen.dart';
import 'screens/home/home_screen.dart' as home;
import 'screens/settings/preferences_settings_screen.dart';
import 'screens/pools/pool_selection_screen.dart';
import 'screens/game/game_detail_screen.dart';
import 'screens/game/game_details_screen.dart';
import 'screens/fighter/fighter_details_screen.dart';
import 'screens/boxing/boxing_details_screen.dart';
import 'models/boxing_event_model.dart';
import 'screens/betting/bet_selection_screen.dart';
import 'screens/betting/fight_card_grid_screen.dart';
import 'screens/betting/quick_pick_screen.dart';
import 'screens/premium/edge_screen_v2.dart';
import 'screens/splash/video_splash_screen.dart';
import 'screens/bets/active_bets_screen.dart';
import 'screens/pools/my_pools_screen.dart';
import 'screens/transactions/transaction_history_screen.dart';
import 'screens/wagers/active_wagers_screen.dart';
import 'screens/leaderboard/leaderboard_screen.dart';
import 'screens/friends/invite_friends_screen.dart';
import 'screens/test/mlb_debug_screen.dart';
import 'screens/test/espn_resolver_test_screen.dart';
import 'screens/test/soccer_resolver_test_screen.dart';
import 'models/fight_card_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check with debug provider for development
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );

  // Initialize game cache service
  await GameCacheService().initialize();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Don't start pool management here - wait for authentication
  // PoolManagementService().startPoolManagement();
  
  runApp(const BraggingRightsApp());
}

class BraggingRightsApp extends StatelessWidget {
  const BraggingRightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bragging Rights',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Force dark theme for Neon Cyber
      initialRoute: '/',
      routes: {
        '/': (context) => const VideoSplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/sports-selection': (context) => const SportsSelectionScreen(),
        '/home': (context) => const home.HomeScreen(),
        '/game-detail': (context) => const GameDetailScreen(),
        '/preferences': (context) => const PreferencesSettingsScreen(),
        '/leaderboard': (context) => const LeaderboardScreen(),
        '/invite-friends': (context) => const InviteFriendsScreen(),
        '/mlb-debug': (context) => const MlbDebugScreen(),
        '/test-resolver': (context) => const EspnResolverTestScreen(),
        '/soccer-resolver-test': (context) => const SoccerResolverTestScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/pool-selection') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => PoolSelectionScreen(
              gameTitle: args['gameTitle']?.toString() ?? 'Game',
              sport: args['sport']?.toString() ?? 'Sport',
              gameId: args['gameId']?.toString(),
            ),
          );
        } else if (settings.name == '/bet-selection') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => BetSelectionScreen(
              gameTitle: args['gameTitle']?.toString() ?? 'Game',
              sport: args['sport']?.toString() ?? 'Sport',
              poolName: args['poolName']?.toString() ?? 'Pool',
              poolId: args['poolId']?.toString(),
              gameId: args['gameId']?.toString(),
            ),
          );
        } else if (settings.name == '/quick-pick') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => QuickPickScreen(
              gameTitle: args['gameTitle']?.toString() ?? 'Game',
              sport: args['sport']?.toString() ?? 'Sport',
              poolName: args['poolName']?.toString() ?? 'Pool',
              poolId: args['poolId']?.toString() ?? '',
              gameId: args['gameId']?.toString(),
            ),
          );
        } else if (settings.name == '/edge') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => EdgeScreenV2(
              gameTitle: args['gameTitle']?.toString() ?? 'Game',
              gameId: args['gameId']?.toString() ?? '',
              sport: args['sport']?.toString() ?? 'nba',
            ),
          );
        } else if (settings.name == '/active-bets') {
          return MaterialPageRoute(
            builder: (context) => const ActiveBetsScreen(),
          );
        } else if (settings.name == '/my-pools') {
          return MaterialPageRoute(
            builder: (context) => const MyPoolsScreen(),
          );
        } else if (settings.name == '/transactions') {
          return MaterialPageRoute(
            builder: (context) => const TransactionHistoryScreen(),
          );
        } else if (settings.name == '/active-wagers') {
          return MaterialPageRoute(
            builder: (context) => const ActiveWagersScreen(),
          );
        } else if (settings.name == '/game-details') {
          final args = settings.arguments as Map<String, dynamic>;
          final sport = args['sport']?.toString().toUpperCase() ?? '';

          // Use BoxingDetailsScreen for boxing events
          if (sport == 'BOXING') {
            // Try to get from our cached boxing events first
            final gameId = args['gameId']?.toString() ?? '';
            final gameData = args['gameData'];

            // Create a basic BoxingEvent from the game data
            final boxingEvent = BoxingEvent(
              id: gameId,
              title: gameData != null
                ? '${gameData.homeTeam} vs ${gameData.awayTeam}'
                : 'Boxing Match',
              date: gameData?.gameTime ?? DateTime.now(),
              venue: gameData?.venue ?? '',
              location: '', // Will be filled from cache or API
              posterUrl: null,
              promotion: 'Boxing',
              broadcasters: [],
              source: DataSource.espn, // Start with ESPN, will check cache
              hasFullData: false, // Will be updated if cache has data
            );

            return MaterialPageRoute(
              builder: (context) => BoxingDetailsScreen(event: boxingEvent),
            );
          }

          // Use regular GameDetailsScreen for other sports
          return MaterialPageRoute(
            builder: (context) => GameDetailsScreen(
              gameId: args['gameId']?.toString() ?? '',
              sport: args['sport']?.toString() ?? '',
              gameData: args['gameData'],
            ),
          );
        } else if (settings.name == '/boxing-details') {
          final args = settings.arguments as Map<String, dynamic>;
          final event = args['event'] as BoxingEvent;
          return MaterialPageRoute(
            builder: (context) => BoxingDetailsScreen(event: event),
          );
        } else if (settings.name == '/fighter-details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => FighterDetailsScreen(
              fighterId: args['fighterId']?.toString() ?? '',
              fighterName: args['fighterName']?.toString() ?? 'Unknown Fighter',
              record: args['record']?.toString(),
              sport: args['sport']?.toString() ?? 'MMA',
              espnId: args['espnId']?.toString(),
            ),
          );
        } else if (settings.name == '/fight-card-grid') {
          final args = settings.arguments as Map<String, dynamic>;
          // For combat sports, we need to fetch the full fight card event
          // This is a temporary solution - ideally the event should be passed from previous screen
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<FightCardEventModel?>(
              future: _loadFightCardEvent(args['gameId']?.toString() ?? ''),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    backgroundColor: Colors.black,
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (snapshot.data == null) {
                  // Fallback - create a basic event from the args
                  final event = FightCardEventModel(
                    id: args['gameId']?.toString() ?? '',
                    gameTime: DateTime.now(),
                    status: 'scheduled',
                    eventName: args['gameTitle']?.toString() ?? 'UFC Event',
                    promotion: 'UFC',
                    totalFights: 0,
                    mainEventTitle: args['gameTitle']?.toString() ?? '',
                    fights: [],
                  );
                  
                  return FightCardGridScreen(
                    event: event,
                    poolId: args['poolId']?.toString() ?? '',
                    poolName: args['poolName']?.toString() ?? 'Pool',
                  );
                }
                
                return FightCardGridScreen(
                  event: snapshot.data!,
                  poolId: args['poolId']?.toString() ?? '',
                  poolName: args['poolName']?.toString() ?? 'Pool',
                );
              },
            ),
          );
        }
        return null;
      },
    );
  }
  
  // Helper function to load fight card event from Firestore
  static Future<FightCardEventModel?> _loadFightCardEvent(String eventId) async {
    try {
      // Fetch game data from Firestore which should have full fight card
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(eventId)
          .get();
      
      if (!gameDoc.exists) {
        print('Game not found in Firestore: $eventId');
        return null;
      }
      
      final data = gameDoc.data()!;
      final fights = data['fights'] as List<dynamic>? ?? [];
      
      // Convert fight data to Fight objects
      final fightObjects = fights.map((fightData) {
        final fight = fightData as Map<String, dynamic>;
        return Fight(
          id: fight['id'] ?? '',
          eventId: eventId,
          fighter1Id: fight['fighter1Id'] ?? '',
          fighter2Id: fight['fighter2Id'] ?? '',
          fighter1Name: fight['fighter1Name'] ?? 'TBD',
          fighter2Name: fight['fighter2Name'] ?? 'TBD',
          fighter1Record: fight['fighter1Record'] ?? '',
          fighter2Record: fight['fighter2Record'] ?? '',
          fighter1Country: '',  // Not available in ESPN data
          fighter2Country: '',  // Not available in ESPN data
          weightClass: fight['weightClass'] ?? 'Catchweight',
          rounds: fight['rounds'] ?? 3,
          cardPosition: fight['cardPosition']?.toString().toLowerCase() ?? 'main',
          fightOrder: fight['fightOrder'] ?? 1,
        );
      }).toList();
      
      // Get main event title from last fight
      String mainEventTitle = 'TBD vs TBD';
      if (fightObjects.isNotEmpty) {
        final mainFight = fightObjects.last;
        mainEventTitle = '${mainFight.fighter1Name} vs ${mainFight.fighter2Name}';
      }
      
      // Handle both Timestamp and int types for gameTime
      DateTime gameTime;
      if (data['gameTime'] is Timestamp) {
        gameTime = (data['gameTime'] as Timestamp).toDate();
      } else if (data['gameTime'] is int) {
        gameTime = DateTime.fromMillisecondsSinceEpoch(data['gameTime'] as int);
      } else {
        gameTime = DateTime.now(); // Fallback
      }

      return FightCardEventModel(
        id: eventId,
        gameTime: gameTime,
        status: data['status'] ?? 'scheduled',
        eventName: data['awayTeam'] ?? 'Event',  // Event name is stored in awayTeam
        promotion: data['league'] ?? 'UFC',
        totalFights: fightObjects.length,
        mainEventTitle: mainEventTitle,
        fights: fightObjects,
        venue: data['venue'],
      );
    } catch (e) {
      print('Error loading fight card from Firestore: $e');
      return null;
    }
  }
}

