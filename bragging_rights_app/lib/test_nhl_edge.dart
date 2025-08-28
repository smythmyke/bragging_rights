import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/edge/edge_intelligence_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(TestNhlEdgeApp());
}

class TestNhlEdgeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NHL Edge Test',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Color(0xFF0A0E27),
      ),
      home: TestNhlEdgeScreen(),
    );
  }
}

class TestNhlEdgeScreen extends StatefulWidget {
  @override
  _TestNhlEdgeScreenState createState() => _TestNhlEdgeScreenState();
}

class _TestNhlEdgeScreenState extends State<TestNhlEdgeScreen> {
  final EdgeIntelligenceService _edgeService = EdgeIntelligenceService();
  
  bool _loading = false;
  String _status = 'Press button to test NHL Edge Intelligence';
  EdgeIntelligence? _intelligence;
  
  Future<void> _testNhlEdge() async {
    setState(() {
      _loading = true;
      _status = 'Testing NHL Edge Intelligence...';
      _intelligence = null;
    });
    
    try {
      // Test with sample NHL game
      final intelligence = await _edgeService.getEventIntelligence(
        eventId: 'nhl_test_2025',
        sport: 'nhl',
        homeTeam: 'New York Rangers',
        awayTeam: 'Boston Bruins',
        eventDate: DateTime.now(),
      );
      
      setState(() {
        _intelligence = intelligence;
        _status = '✅ NHL Edge Intelligence Retrieved Successfully!';
      });
      
    } catch (e) {
      setState(() {
        _status = '❌ Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🏒 NHL Edge Intelligence Test'),
        backgroundColor: Colors.blue[900],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Test Button
            Center(
              child: ElevatedButton(
                onPressed: _loading ? null : _testNhlEdge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: Text(
                  _loading ? 'Testing...' : 'Test NHL Edge Intelligence',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Status
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _status.contains('✅') ? Colors.green :
                        _status.contains('❌') ? Colors.red : Colors.blue,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(fontSize: 16),
              ),
            ),
            
            // Intelligence Results
            if (_intelligence != null) ...[
              SizedBox(height: 24),
              
              // Game Info
              _buildSection(
                '🏒 Game Information',
                [
                  'Event: ${_intelligence!.homeTeam} vs ${_intelligence!.awayTeam}',
                  'Sport: ${_intelligence!.sport.toUpperCase()}',
                  'Date: ${_intelligence!.eventDate.toString().split(' ')[0]}',
                  'Confidence: ${(_intelligence!.overallConfidence * 100).toStringAsFixed(1)}%',
                ],
              ),
              
              // Data Sources
              if (_intelligence!.dataPoints.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildSection(
                  '📊 Data Sources',
                  _intelligence!.dataPoints.map((dp) => 
                    '${dp.source}: ${dp.type} (${(dp.confidence * 100).toStringAsFixed(0)}% confidence)'
                  ).toList(),
                ),
              ],
              
              // Key Insights
              if (_intelligence!.insights.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildSection(
                  '💡 Key Insights',
                  _intelligence!.insights.map((insight) => 
                    '[${insight.impact.toUpperCase()}] ${insight.category}: ${insight.insight}'
                  ).toList(),
                ),
              ],
              
              // Predictions
              if (_intelligence!.predictions.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildSection(
                  '🎯 Predictions',
                  _buildPredictionsList(),
                ),
              ],
              
              // Raw Data Points (Debug)
              SizedBox(height: 16),
              ExpansionTile(
                title: Text('🔍 Debug: Raw Data Points'),
                children: _intelligence!.dataPoints.map((dp) => 
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Source: ${dp.source}', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Type: ${dp.type}'),
                          Text('Data: ${dp.data.toString().substring(0, dp.data.toString().length > 200 ? 200 : dp.data.toString().length)}...'),
                        ],
                      ),
                    ),
                  )
                ).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, List<String> items) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text('• $item'),
          )),
        ],
      ),
    );
  }
  
  List<String> _buildPredictionsList() {
    final predictions = <String>[];
    
    if (_intelligence!.predictions['suggestedBets'] != null) {
      final bets = _intelligence!.predictions['suggestedBets'] as List;
      for (final bet in bets) {
        predictions.add('${bet['type']}: ${bet['reasoning']}');
      }
    }
    
    if (_intelligence!.predictions['confidence'] != null) {
      predictions.add('Overall Confidence: ${(_intelligence!.predictions['confidence'] * 100).toStringAsFixed(1)}%');
    }
    
    return predictions.isEmpty ? ['No predictions available'] : predictions;
  }
}