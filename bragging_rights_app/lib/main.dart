import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/pool_management_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/sports_selection_screen.dart';
import 'screens/home/home_screen.dart' as home;
import 'screens/pools/pool_selection_screen.dart';
import 'screens/game/game_detail_screen.dart';
import 'screens/betting/bet_selection_screen.dart';
import 'screens/premium/edge_screen_v2.dart';
import 'screens/splash/lottie_splash_screen.dart';
import 'screens/bets/active_bets_screen.dart';
import 'screens/pools/my_pools_screen.dart';
import 'screens/transactions/transaction_history_screen.dart';
import 'screens/wagers/active_wagers_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Start pool management service
  PoolManagementService().startPoolManagement();
  
  runApp(const BraggingRightsApp());
}

class BraggingRightsApp extends StatelessWidget {
  const BraggingRightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bragging Rights',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LottieSplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/sports-selection': (context) => const SportsSelectionScreen(),
        '/home': (context) => const home.HomeScreen(),
        '/game-detail': (context) => const GameDetailScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/pool-selection') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => PoolSelectionScreen(
              gameTitle: args['gameTitle'] ?? 'Game',
              sport: args['sport'] ?? 'Sport',
            ),
          );
        } else if (settings.name == '/bet-selection') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => BetSelectionScreen(
              gameTitle: args['gameTitle'] ?? 'Game',
              sport: args['sport'] ?? 'Sport',
              poolName: args['poolName'] ?? 'Pool',
              poolId: args['poolId'],
              gameId: args['gameId'],
            ),
          );
        } else if (settings.name == '/edge') {
          final args = settings.arguments as Map<String, String>;
          return MaterialPageRoute(
            builder: (context) => EdgeScreenV2(
              gameTitle: args['gameTitle'] ?? 'Game',
              gameId: args['gameId'] ?? '',
              sport: args['sport'] ?? 'nba',
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
        }
        return null;
      },
    );
  }
}

