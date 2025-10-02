import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/pool_management_service.dart';
import 'services/game_cache_service.dart';
import 'services/challenge_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/sports_selection_screen.dart';
import 'screens/home/home_screen.dart' as home;
import 'screens/settings/preferences_settings_screen.dart';
import 'screens/pools/pool_selection_screen.dart';
import 'screens/game/game_detail_screen.dart';
import 'screens/game/game_details_screen.dart';
import 'screens/fighter/fighter_details_screen.dart';
import 'screens/boxing/boxing_details_screen.dart';
import 'screens/mma/mma_details_screen.dart';
import 'models/boxing_event_model.dart';
import 'screens/betting/bet_selection_screen.dart';
import 'screens/betting/fight_card_grid_screen.dart';
import 'screens/betting/quick_pick_screen.dart';
import 'screens/premium/edge_screen_v2.dart';
// import 'screens/splash/video_splash_screen.dart'; // Disabled - going directly to login
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
import 'services/mma_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Firebase - wrapped in try-catch for web compatibility
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Firebase App Check with debug provider for development
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
    );

    // Initialize notification service
    await NotificationService().initialize();
  } catch (e) {
    print('⚠️ Firebase initialization error (continuing without Firebase): $e');
    // Continue without Firebase for testing
  }

  // Initialize game cache service
  await GameCacheService().initialize();

  // Initialize challenge service
  ChallengeService().init();

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
      initialRoute: '/home', // Bypass login for web testing
      routes: {
        '/': (context) => const LoginScreen(),
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
              gameTime: args['gameTime'] as DateTime?,
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

          // Use MMADetailsScreen for MMA/UFC events
          if (sport == 'MMA' || sport == 'UFC') {
            final gameId = args['gameId']?.toString() ?? '';
            final gameData = args['gameData'];

            return MaterialPageRoute(
              builder: (context) => MMADetailsScreen(
                eventId: gameId,
                eventName: gameData != null
                  ? '${gameData.homeTeam} vs ${gameData.awayTeam}'
                  : 'MMA Event',
                eventDate: gameData?.gameTime,
                gameData: gameData?.toJson(),
              ),
            );
          }

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
        } else if (settings.name == '/mma-details') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => MMADetailsScreen(
              eventId: args['eventId']?.toString() ?? '',
              eventName: args['eventName']?.toString() ?? 'MMA Event',
              eventDate: args['eventDate'] as DateTime?,
              gameData: args['gameData'] as Map<String, dynamic>?,
            ),
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
                  print('⚠️ =================================================');
                  print('⚠️ CREATING FALLBACK FIGHT CARD EVENT');
                  print('⚠️ Reason: Event not found in Firestore');
                  print('⚠️ Arguments received:');
                  print('⚠️   gameId: ${args['gameId']}');
                  print('⚠️   gameTitle: ${args['gameTitle']}');
                  print('⚠️   sport: ${args['sport']}');
                  print('⚠️   poolId: ${args['poolId']}');
                  print('⚠️   poolName: ${args['poolName']}');
                  print('⚠️ =================================================');

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

                  print('⚠️ Created fallback event with:');
                  print('⚠️   ID: ${event.id}');
                  print('⚠️   Name: ${event.eventName}');
                  print('⚠️   Main Event: ${event.mainEventTitle}');
                  print('⚠️   Total Fights: ${event.totalFights}');
                  print('⚠️ NOTE: This event has NO FIGHTS - odds loading will fail');
                  print('⚠️ =================================================');

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
      print('🔍 =================================================');
      print('🔍 LOADING FIGHT CARD EVENT');
      print('🔍 Event ID: $eventId');
      print('🔍 Timestamp: ${DateTime.now().toIso8601String()}');
      print('🔍 =================================================');

      // Fetch game data from Firestore which should have full fight card
      print('📡 Attempting to fetch from Firestore games collection...');
      final gameDoc = await FirebaseFirestore.instance
          .collection('games')
          .doc(eventId)
          .get();

      if (!gameDoc.exists) {
        print('❌ Game not found in Firestore: $eventId');
        print('❌ Document path: games/$eventId');
        print('🔄 Attempting to fetch from ESPN as fallback...');

        // Try to fetch from ESPN for MMA/Boxing events
        try {
          final mmaService = MMAService();
          final espnEvent = await mmaService.getEventWithFights(eventId);

          if (espnEvent != null) {
            print('✅ Successfully fetched event from ESPN!');
            print('   Event: ${espnEvent.name}');
            print('   Fights: ${espnEvent.fights.length}');

            // Get main event fighters for home/away
            final mainEvent = espnEvent.mainEvent;
            final homeTeam = mainEvent?.fighter2?.name ?? 'TBD';
            final awayTeam = mainEvent?.fighter1?.name ?? 'TBD';

            // Save to Firestore for future use
            await FirebaseFirestore.instance.collection('games').doc(eventId).set({
              'id': eventId,
              'sport': 'MMA',
              'gameTitle': espnEvent.name,
              'homeTeam': homeTeam,
              'awayTeam': awayTeam,
              'gameTime': Timestamp.fromDate(espnEvent.date),
              'venue': espnEvent.venue,
              'fights': espnEvent.fights.map((f) => {
                'id': f.id,
                'fighter1Name': f.fighter1?.name ?? '',
                'fighter2Name': f.fighter2?.name ?? '',
                'fighter1Id': f.fighter1?.espnId,
                'fighter2Id': f.fighter2?.espnId,
                'weightClass': f.weightClass,
                'cardPosition': f.cardPosition,
                'fightOrder': f.fightOrder,
              }).toList(),
            }, SetOptions(merge: true));
            print('💾 Saved ESPN event to Firestore for future use');

            // Return null - let the fallback event be created
            // (easier than converting MMAEvent to proper structure)
            return null;
          }
        } catch (e) {
          print('❌ ESPN fallback failed: $e');
        }

        print('❌ Will return null and use fallback event');
        return null;
      }

      final data = gameDoc.data()!;
      print('✅ Game document found in Firestore!');
      print('📄 Document data keys: ${data.keys.toList()}');
      print('📄 Game details:');
      print('   - homeTeam: ${data['homeTeam']}');
      print('   - awayTeam: ${data['awayTeam']}');
      print('   - sport: ${data['sport']}');
      print('   - league: ${data['league']}');
      print('   - gameTime: ${data['gameTime']}');
      print('   - status: ${data['status']}');
      print('   - venue: ${data['venue']}');
      print('   - fights array length: ${(data['fights'] as List?)?.length ?? 0}');
      print('   - fights array present: ${data.containsKey('fights')}');

      final fights = data['fights'] as List<dynamic>? ?? [];
      print('🥊 Processing ${fights.length} fights from document...');

      List<Fight> fightObjects = [];
      String mainEventTitle = 'TBD vs TBD';

      // If no fights array but we have homeTeam and awayTeam (from Odds API)
      if (fights.isEmpty && data['homeTeam'] != null && data['awayTeam'] != null) {
        print('✅ No fights array but found homeTeam/awayTeam - creating main event fight');
        // Create a single main event fight from the game data
        mainEventTitle = '${data['awayTeam']} vs ${data['homeTeam']}';
        print('   Main event title: $mainEventTitle');

        fightObjects = [
          Fight(
            id: '${eventId}_main',
            eventId: eventId,
            fighter1Id: data['awayTeam']?.toString().replaceAll(' ', '_').toLowerCase() ?? '',
            fighter2Id: data['homeTeam']?.toString().replaceAll(' ', '_').toLowerCase() ?? '',
            fighter1Name: data['awayTeam']?.toString() ?? 'TBD',
            fighter2Name: data['homeTeam']?.toString() ?? 'TBD',
            fighter1Record: '',  // Not available from Odds API
            fighter2Record: '',  // Not available from Odds API
            fighter1Country: '',
            fighter2Country: '',
            weightClass: data['league']?.toString() ?? 'Main Event',
            rounds: 5,  // Main events are typically 5 rounds
            cardPosition: 'main',
            fightOrder: 1,
          ),
        ];
        print('   Created fight: ${fightObjects.first.fighter1Name} vs ${fightObjects.first.fighter2Name}');
      } else if (fights.isNotEmpty) {
        print('✅ Found ${fights.length} fights in array');
        // Convert fight data to Fight objects - handle different field names
        fightObjects = fights.map((fightData) {
          final fight = fightData as Map<String, dynamic>;
          // Handle both field naming conventions
          final fighter1Name = fight['fighter1Name'] ?? fight['fighter1'] ?? 'TBD';
          final fighter2Name = fight['fighter2Name'] ?? fight['fighter2'] ?? 'TBD';

          print('   Processing fight: $fighter1Name vs $fighter2Name');
          print('   Fight data keys: ${fight.keys}');
          print('   Weight class in data: ${fight['weightClass']}');

          // Determine weight class based on fight position and event type
          String weightClass = 'TBD';
          if (fight['weightClass'] != null && fight['weightClass'].toString().isNotEmpty) {
            weightClass = fight['weightClass'].toString();
          } else if (fight['division'] != null && fight['division'].toString().isNotEmpty) {
            weightClass = fight['division'].toString();
          } else if (fight['cardPosition'] == 'main' || fight['fightOrder'] == 13) {
            // Main events often don't specify weight class in the data
            weightClass = 'Light Heavyweight'; // Default for main events, should be fetched from ESPN
          }

          return Fight(
            id: fight['id'] ?? '',
            eventId: eventId,
            fighter1Id: fight['fighter1Id'] ?? fighter1Name.toString().replaceAll(' ', '_').toLowerCase(),
            fighter2Id: fight['fighter2Id'] ?? fighter2Name.toString().replaceAll(' ', '_').toLowerCase(),
            fighter1Name: fighter1Name.toString(),
            fighter2Name: fighter2Name.toString(),
            fighter1Record: fight['fighter1Record'] ?? '',
            fighter2Record: fight['fighter2Record'] ?? '',
            fighter1Country: '',  // Not available
            fighter2Country: '',  // Not available
            fighter1ImageUrl: fight['fighter1ImageUrl'],  // Add image URLs
            fighter2ImageUrl: fight['fighter2ImageUrl'],  // Add image URLs
            weightClass: weightClass,
            rounds: fight['rounds'] ?? 3,
            cardPosition: fight['cardPosition']?.toString().toLowerCase() ?? 'main',
            fightOrder: fight['fightOrder'] ?? 1,
          );
        }).toList();

        // Get main event title from last fight
        if (fightObjects.isNotEmpty) {
          final mainFight = fightObjects.last;
          mainEventTitle = '${mainFight.fighter1Name} vs ${mainFight.fighter2Name}';
        }
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

      final eventModel = FightCardEventModel(
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

      print('✅ =================================================');
      print('✅ SUCCESSFULLY CREATED FightCardEventModel');
      print('✅ Event ID: ${eventModel.id}');
      print('✅ Event Name: ${eventModel.eventName}');
      print('✅ Total Fights: ${eventModel.totalFights}');
      print('✅ Main Event: ${eventModel.mainEventTitle}');
      print('✅ Promotion: ${eventModel.promotion}');
      print('✅ Status: ${eventModel.status}');
      print('✅ Game Time: ${eventModel.gameTime}');
      print('✅ Venue: ${eventModel.venue ?? 'Not specified'}');
      print('✅ Fight Details:');
      if (eventModel.typedFights.isNotEmpty) {
        for (var i = 0; i < eventModel.typedFights.length; i++) {
          var fight = eventModel.typedFights[i];
          print('✅   Fight ${i+1}: ${fight.fighter1Name} vs ${fight.fighter2Name}');
          print('✅     - Weight Class: ${fight.weightClass}');
          print('✅     - Rounds: ${fight.rounds}');
          print('✅     - Position: ${fight.cardPosition}');
        }
      } else {
        print('✅   No fights in event - will be created empty');
      }
      print('✅ =================================================');

      return eventModel;
    } catch (e, stack) {
      print('❌ =================================================');
      print('❌ ERROR LOADING FIGHT CARD EVENT');
      print('❌ Event ID: $eventId');
      print('❌ Error: $e');
      print('❌ Stack trace:');
      print(stack.toString().split('\n').take(10).join('\n'));
      print('❌ =================================================');
      return null;
    }
  }
}

