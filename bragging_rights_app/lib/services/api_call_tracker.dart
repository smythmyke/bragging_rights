import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks all API calls made by the app for analysis and optimization
class APICallTracker {
  static int espnCalls = 0;
  static int sportsDBCalls = 0;
  static int oddsAPICalls = 0;
  static int firebaseAuthCalls = 0;
  static int firestoreReads = 0;
  static int firestoreWrites = 0;

  static List<Map<String, dynamic>> callLog = [];
  static DateTime? sessionStart;

  static void startSession() {
    sessionStart = DateTime.now();
    espnCalls = 0;
    sportsDBCalls = 0;
    oddsAPICalls = 0;
    firebaseAuthCalls = 0;
    firestoreReads = 0;
    firestoreWrites = 0;
    callLog.clear();

    print('🟢 ============= API TRACKING SESSION STARTED =============');
    print('🟢 Time: ${DateTime.now()}');
    print('🟢 ======================================================');
  }

  static void logAPICall(String source, String endpoint, {String? details, bool cached = false}) {
    if (sessionStart == null) startSession();

    // Increment counters
    switch (source.toUpperCase()) {
      case 'ESPN':
        espnCalls++;
        break;
      case 'SPORTSDB':
        sportsDBCalls++;
        break;
      case 'ODDS':
      case 'THE-ODDS-API':
        oddsAPICalls++;
        break;
    }

    final totalAPICalls = espnCalls + sportsDBCalls + oddsAPICalls;

    // Create log entry
    final logEntry = {
      'timestamp': DateTime.now().toIso8601String(),
      'source': source,
      'endpoint': endpoint,
      'details': details,
      'cached': cached,
      'callNumber': totalAPICalls,
      'sessionDuration': DateTime.now().difference(sessionStart!).inSeconds,
    };

    callLog.add(logEntry);

    // Print to console with color coding
    final icon = cached ? '🟡' : '🔴';
    final cacheStatus = cached ? ' (CACHED)' : '';

    print('$icon API CALL #$totalAPICalls$cacheStatus: $source - $endpoint');
    if (details != null) {
      print('   └─ Details: $details');
    }
  }

  static void logFirestoreRead(String collection, {String? docId, int documents = 1}) {
    firestoreReads += documents;
    print('📘 Firestore READ: $collection${docId != null ? '/$docId' : ''} ($documents docs) - Total reads: $firestoreReads');
  }

  static void logFirestoreWrite(String collection, {String? docId}) {
    firestoreWrites++;
    print('📗 Firestore WRITE: $collection${docId != null ? '/$docId' : ''} - Total writes: $firestoreWrites');
  }

  static void printSummary() {
    if (sessionStart == null) {
      print('No tracking session active');
      return;
    }

    final duration = DateTime.now().difference(sessionStart!);
    final totalAPICalls = espnCalls + sportsDBCalls + oddsAPICalls;

    print('');
    print('🔵 ============= API CALL SUMMARY =============');
    print('🔵 Session Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
    print('🔵 ==========================================');
    print('🔵 ESPN API Calls:        $espnCalls');
    print('🔵 SportsDB API Calls:    $sportsDBCalls');
    print('🔵 The Odds API Calls:    $oddsAPICalls');
    print('🔵 ------------------------------------------');
    print('🔵 Total API Calls:       $totalAPICalls');
    print('🔵 ==========================================');
    print('🔵 Firestore Reads:       $firestoreReads');
    print('🔵 Firestore Writes:      $firestoreWrites');
    print('🔵 ==========================================');

    // Calculate costs (estimated)
    final oddsAPICost = oddsAPICalls * 0.003; // $30/10000 calls = $0.003 per call
    final firestoreReadCost = firestoreReads * 0.00000036; // $0.36 per million
    final firestoreWriteCost = firestoreWrites * 0.00000108; // $1.08 per million
    final totalCost = oddsAPICost + firestoreReadCost + firestoreWriteCost;

    print('🔵 Estimated Session Cost: \$${totalCost.toStringAsFixed(6)}');

    if (duration.inSeconds > 0) {
      final callsPerMinute = (totalAPICalls / duration.inMinutes).toStringAsFixed(1);
      print('🔵 API Calls/Minute:      $callsPerMinute');
    }

    print('🔵 ==========================================');

    // Show top 5 most called endpoints
    final endpointCounts = <String, int>{};
    for (final call in callLog) {
      final key = '${call['source']}: ${call['endpoint']}';
      endpointCounts[key] = (endpointCounts[key] ?? 0) + 1;
    }

    final sortedEndpoints = endpointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEndpoints.isNotEmpty) {
      print('🔵 Top Called Endpoints:');
      for (int i = 0; i < sortedEndpoints.length && i < 5; i++) {
        print('🔵   ${i + 1}. ${sortedEndpoints[i].key} (${sortedEndpoints[i].value} calls)');
      }
      print('🔵 ==========================================');
    }
  }

  static Future<void> saveToFirestore() async {
    if (sessionStart == null || callLog.isEmpty) return;

    try {
      final summary = {
        'timestamp': FieldValue.serverTimestamp(),
        'sessionStart': sessionStart,
        'sessionDuration': DateTime.now().difference(sessionStart!).inSeconds,
        'espnCalls': espnCalls,
        'sportsDBCalls': sportsDBCalls,
        'oddsAPICalls': oddsAPICalls,
        'totalAPICalls': espnCalls + sportsDBCalls + oddsAPICalls,
        'firestoreReads': firestoreReads,
        'firestoreWrites': firestoreWrites,
        'callLog': callLog,
      };

      await FirebaseFirestore.instance
          .collection('api_tracking')
          .add(summary);

      print('✅ API tracking data saved to Firestore');
    } catch (e) {
      print('❌ Failed to save API tracking data: $e');
    }
  }

  static void reset() {
    startSession();
  }

  static String getSessionReport() {
    if (sessionStart == null) return 'No active session';

    final duration = DateTime.now().difference(sessionStart!);
    final totalAPICalls = espnCalls + sportsDBCalls + oddsAPICalls;

    return '''
API TRACKING REPORT
===================
Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s
Total API Calls: $totalAPICalls
- ESPN: $espnCalls
- SportsDB: $sportsDBCalls
- The Odds API: $oddsAPICalls
Firestore Reads: $firestoreReads
Firestore Writes: $firestoreWrites
''';
  }
}