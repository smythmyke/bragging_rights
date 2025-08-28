import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/screens/premium/edge_screen_v2.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(EdgeTestApp());
}

class EdgeTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Edge Integration Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: EdgeTestScreen(),
    );
  }
}

class EdgeTestScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edge Intelligence Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Edge Cards UI Integration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EdgeScreenV2(
                      gameTitle: 'Lakers vs Celtics',
                      gameId: 'test-game-123',
                      sport: 'nba',
                    ),
                  ),
                );
              },
              child: Text('Open NBA Edge Screen'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EdgeScreenV2(
                      gameTitle: 'Rangers vs Bruins',
                      gameId: 'test-game-456',
                      sport: 'nhl',
                    ),
                  ),
                );
              },
              child: Text('Open NHL Edge Screen'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EdgeScreenV2(
                      gameTitle: 'Chiefs vs Bills',
                      gameId: 'test-game-789',
                      sport: 'nfl',
                    ),
                  ),
                );
              },
              child: Text('Open NFL Edge Screen'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EdgeScreenV2(
                      gameTitle: 'Yankees vs Red Sox',
                      gameId: 'test-game-101',
                      sport: 'mlb',
                    ),
                  ),
                );
              },
              child: Text('Open MLB Edge Screen'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EdgeScreenV2(
                      gameTitle: 'UFC 300: Main Event',
                      gameId: 'test-game-102',
                      sport: 'mma',
                    ),
                  ),
                );
              },
              child: Text('Open MMA Edge Screen'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EdgeScreenV2(
                      gameTitle: 'Wilder vs Fury',
                      gameId: 'test-game-103',
                      sport: 'boxing',
                    ),
                  ),
                );
              },
              child: Text('Open Boxing Edge Screen'),
            ),
          ],
        ),
      ),
    );
  }
}