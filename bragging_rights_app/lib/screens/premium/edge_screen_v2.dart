import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/edge/edge_card_widget.dart';
import '../../widgets/edge/edge_card_collection.dart';
import '../../widgets/edge/edge_card_types.dart';
import '../../widgets/edge/sport_card_generator.dart';
import '../../services/edge/edge_intelligence_service.dart';
import '../../services/wallet_service.dart';
import 'edge_detail_screen_v2.dart';

/// Enhanced Edge Screen with new Edge Cards UI System
class EdgeScreenV2 extends StatefulWidget {
  final String gameTitle;
  final String sport;
  final String? gameId;
  final String? eventId;
  final DateTime? gameTime;
  
  const EdgeScreenV2({
    super.key,
    required this.gameTitle,
    required this.sport,
    this.gameId,
    this.eventId,
    this.gameTime,
  });

  @override
  State<EdgeScreenV2> createState() => _EdgeScreenV2State();
}

class _EdgeScreenV2State extends State<EdgeScreenV2> with TickerProviderStateMixin {
  // Services
  final EdgeIntelligenceService _intelligenceService = EdgeIntelligenceService();
  final WalletService _walletService = WalletService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Data
  EdgeIntelligence? _intelligence;
  List<EdgeCardData> _cards = [];
  int _userBRBalance = 0;
  bool _isLoading = true;
  String? _error;
  
  // UI State
  final Set<String> _unlockedCardIds = {};
  EdgeCardCategory? _selectedCategory;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Load user BR balance
      final user = _auth.currentUser;
      if (user != null) {
        final balance = await _walletService.getBalance(user.uid);
        setState(() {
          _userBRBalance = balance;
        });
      }
      
      // Parse teams from game title
      final teams = widget.gameTitle.split(' vs ');
      String homeTeam = teams.length > 0 ? teams[0].trim() : 'Team 1';
      String awayTeam = teams.length > 1 ? teams[1].trim() : 'Team 2';
      
      // Load Edge Intelligence
      _intelligence = await _intelligenceService.getEventIntelligence(
        eventId: widget.eventId ?? 'game_${DateTime.now().millisecondsSinceEpoch}',
        sport: widget.sport.toLowerCase(),
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        eventDate: widget.gameTime ?? DateTime.now(),
      );
      
      // Generate cards from intelligence
      _cards = SportCardGenerator.generateCardsFromIntelligence(_intelligence!);
      
      // Add some demo cards if we don't have enough
      if (_cards.length < 6) {
        _addDemoCards();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading Edge data: $e');
      setState(() {
        _error = 'Failed to load intelligence. Please try again.';
        _isLoading = false;
      });
      
      // Load demo cards as fallback
      _addDemoCards();
    }
  }
  
  void _addDemoCards() {
    final demoCards = [
      EdgeCardData(
        id: 'demo_injury_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.injury,
        title: 'Injury Report',
        teaserText: 'Key player questionable',
        fullContent: 'Star player listed as questionable with ankle injury.\n'
            'Participated in limited practice.\n'
            'Game-time decision expected.\n'
            'Backup has performed well in previous starts.',
        metadata: {'severity': 'moderate', 'player': 'Star Player'},
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
        rarity: EdgeCardRarity.rare,
        badges: [EdgeCardBadge.verified, EdgeCardBadge.newItem],
        currentCost: 15,
        confidence: 0.85,
        impactText: '-3.5 points if out',
      ),
      EdgeCardData(
        id: 'demo_weather_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.weather,
        title: 'Weather Impact',
        teaserText: '15+ mph winds expected',
        fullContent: 'Wind speeds: 15-20 mph\n'
            'Direction: Crosswind\n'
            'Temperature: 42°F\n'
            'Precipitation: 30% chance\n'
            'Impact: Affects passing game and field goals',
        metadata: {'windSpeed': 18, 'temperature': 42},
        timestamp: DateTime.now().subtract(Duration(minutes: 30)),
        rarity: EdgeCardRarity.uncommon,
        badges: [EdgeCardBadge.verified],
        currentCost: 10,
        confidence: 0.90,
        impactText: 'Favor under',
      ),
      EdgeCardData(
        id: 'demo_social_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.social,
        title: 'Reddit Sentiment',
        teaserText: '78% bullish on home team',
        fullContent: 'r/${widget.sport.toLowerCase()} Analysis:\n'
            '• 78% positive sentiment for home team\n'
            '• Key discussion: Recent win streak\n'
            '• Concerns about road performance\n'
            '• 2.3k comments in game thread',
        metadata: {'sentiment': 0.78, 'comments': 2300},
        timestamp: DateTime.now().subtract(Duration(hours: 2)),
        rarity: EdgeCardRarity.common,
        badges: [EdgeCardBadge.hot, EdgeCardBadge.trending],
        currentCost: 5,
        confidence: 0.65,
        impactText: 'High fan confidence',
      ),
      EdgeCardData(
        id: 'demo_matchup_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.matchup,
        title: 'Key Matchup',
        teaserText: 'Historical advantage detected',
        fullContent: 'Head-to-Head History:\n'
            '• Home team: 7-3 last 10 meetings\n'
            '• Average margin: +8.5 points\n'
            '• Home court: 5-0 last 5\n'
            '• Key factor: Defense vs offense clash',
        metadata: {'h2h': '7-3', 'margin': 8.5},
        timestamp: DateTime.now().subtract(Duration(hours: 3)),
        rarity: EdgeCardRarity.uncommon,
        badges: [EdgeCardBadge.verified],
        currentCost: 10,
        confidence: 0.75,
        impactText: 'Historical edge',
      ),
      EdgeCardData(
        id: 'demo_breaking_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.breaking,
        title: 'Breaking News',
        teaserText: 'Lineup change announced',
        fullContent: 'BREAKING: Starting lineup change\n'
            '• Rookie promoted to starting five\n'
            '• Coach cites matchup advantages\n'
            '• First career start\n'
            '• Veteran moved to bench',
        metadata: {'type': 'lineup', 'impact': 'moderate'},
        timestamp: DateTime.now().subtract(Duration(minutes: 15)),
        rarity: EdgeCardRarity.epic,
        badges: [EdgeCardBadge.breaking, EdgeCardBadge.newItem, EdgeCardBadge.exclusive],
        currentCost: 20,
        confidence: 1.0,
        impactText: 'Lineup volatility',
      ),
      EdgeCardData(
        id: 'demo_betting_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.betting,
        title: 'Sharp Money',
        teaserText: 'Line movement detected',
        fullContent: 'Betting Line Movement:\n'
            '• Open: -3.5\n'
            '• Current: -5.5\n'
            '• Sharp money on favorite\n'
            '• Public: 65% on underdog\n'
            '• Total dropped from 220 to 216',
        metadata: {'lineMove': 2, 'sharpSide': 'favorite'},
        timestamp: DateTime.now().subtract(Duration(hours: 1)),
        rarity: EdgeCardRarity.rare,
        badges: [EdgeCardBadge.trending, EdgeCardBadge.verified],
        currentCost: 15,
        confidence: 0.80,
        impactText: 'Sharp action',
      ),
    ];
    
    setState(() {
      _cards.addAll(demoCards);
    });
  }
  
  Future<void> _unlockCard(EdgeCardData card) async {
    // Check balance
    if (_userBRBalance < card.currentCost) {
      _showInsufficientBRDialog(card.currentCost);
      return;
    }
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Unlock ${card.title}?',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: EdgeCardConfigs.getRarityColor(card.rarity).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: EdgeCardConfigs.getRarityColor(card.rarity),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    EdgeCardConfigs.getConfig(card.category).icon,
                    color: EdgeCardConfigs.getRarityColor(card.rarity),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      card.teaserText,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on, color: Colors.green, size: 20),
                SizedBox(width: 4),
                Text(
                  '${card.currentCost} BR',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Your balance: $_userBRBalance BR',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Unlock'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // Process unlock
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Deduct BR
        await _walletService.deductFromWallet(
          user.uid,
          card.currentCost,
          'Edge Intel: ${card.title}',
          metadata: {
            'type': 'edge_card',
            'cardId': card.id,
            'category': card.category.name,
          },
        );
        
        // Update state
        setState(() {
          _userBRBalance -= card.currentCost;
          _unlockedCardIds.add(card.id);
          
          // Update card's lock status
          final index = _cards.indexWhere((c) => c.id == card.id);
          if (index != -1) {
            _cards[index] = card.copyWithLockStatus(false);
          }
        });
        
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlocked ${card.title} for ${card.currentCost} BR'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Log analytics
        await FirebaseFirestore.instance.collection('edge_unlocks').add({
          'userId': user.uid,
          'cardId': card.id,
          'category': card.category.name,
          'rarity': card.rarity.name,
          'cost': card.currentCost,
          'sport': widget.sport,
          'gameTitle': widget.gameTitle,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error unlocking card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to unlock card. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _showInsufficientBRDialog(int requiredBR) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Insufficient BR',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'You need $requiredBR BR to unlock this intel',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Your balance: $_userBRBalance BR',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showBRPurchaseOptions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: Text('Buy BR'),
          ),
        ],
      ),
    );
  }
  
  void _showBRPurchaseOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Purchase BR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            _buildBRPackage('Starter Pack', 100, 0.99),
            _buildBRPackage('Value Pack', 550, 4.99, isBestValue: true),
            _buildBRPackage('Pro Pack', 1200, 9.99),
            _buildBRPackage('Elite Pack', 2500, 19.99),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBRPackage(String name, int amount, double price, {bool isBestValue = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isBestValue
            ? LinearGradient(colors: [Colors.green, Colors.teal])
            : null,
        color: isBestValue ? null : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBestValue ? Colors.green : Colors.grey[700]!,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.monetization_on,
              color: isBestValue ? Colors.white : Colors.green,
              size: 32,
            ),
            if (isBestValue)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$amount BR',
          style: TextStyle(color: Colors.white70),
        ),
        trailing: ElevatedButton(
          onPressed: () async {
            // TODO: Implement actual in-app purchase
            // For now, just add BR for testing
            setState(() {
              _userBRBalance += amount;
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchased $amount BR for \$$price!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isBestValue ? Colors.white : Colors.green,
            foregroundColor: isBestValue ? Colors.green : Colors.white,
          ),
          child: Text('\$${price.toStringAsFixed(2)}'),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('The Edge', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          // BR Balance
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green[700],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.monetization_on, color: Colors.white, size: 20),
                SizedBox(width: 4),
                Text(
                  '$_userBRBalance BR',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              Colors.purple[900]!,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.gameTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    widget.sport.toUpperCase(),
                    style: TextStyle(
                      color: Colors.purple[300],
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  if (widget.gameTime != null) ...[
                    SizedBox(height: 4),
                    Text(
                      _getTimeUntilGame(),
                      style: TextStyle(
                        color: Colors.amber[300],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.purple),
                          SizedBox(height: 16),
                          Text(
                            'Gathering Intelligence...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.warning, color: Colors.amber, size: 48),
                              SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(color: Colors.white70),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: Icon(Icons.refresh),
                                label: Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        )
                      : EdgeCardCollection(
                          cards: _cards.map((card) {
                            // Update lock status based on unlocked IDs
                            if (_unlockedCardIds.contains(card.id)) {
                              return card.copyWithLockStatus(false);
                            }
                            return card;
                          }).toList(),
                          onCardUnlock: _unlockCard,
                          onCardTap: (card) {
                            if (!card.isLocked) {
                              // Show detailed view for unlocked cards
                              _showCardDetail(card);
                            }
                          },
                          sportFilter: widget.sport,
                        ),
            ),
            
            // Bundle offer (if applicable)
            if (_cards.length >= 4 && _unlockedCardIds.length < 2)
              Container(
                padding: EdgeInsets.all(16),
                child: EdgeCardBundle(
                  title: 'Game Bundle',
                  description: 'Unlock all ${_cards.length} cards for this game',
                  cards: _cards,
                  originalPrice: _cards.fold(0, (sum, card) => sum + card.currentCost),
                  bundlePrice: (_cards.fold(0, (sum, card) => sum + card.currentCost) * 0.7).round(),
                  onPurchase: () => _unlockAllCards(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _getTimeUntilGame() {
    if (widget.gameTime == null) return '';
    
    final now = DateTime.now();
    final diff = widget.gameTime!.difference(now);
    
    if (diff.isNegative) {
      return 'Game in progress';
    } else if (diff.inMinutes < 60) {
      return 'Starts in ${diff.inMinutes} minutes';
    } else if (diff.inHours < 24) {
      return 'Starts in ${diff.inHours} hours';
    } else {
      return 'Starts in ${diff.inDays} days';
    }
  }
  
  void _showCardDetail(EdgeCardData card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: EdgeCardConfigs.getConfig(card.category).gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          EdgeCardConfigs.getConfig(card.category).icon,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                EdgeCardConfigs.getConfig(card.category).title,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: EdgeCardConfigs.getRarityColor(card.rarity),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            card.rarity.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    
                    // Full content
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.fullContent,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              if (card.impactText != null) ...[
                                SizedBox(height: 16),
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white10,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white30),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.analytics, color: Colors.white70),
                                      SizedBox(width: 8),
                                      Text(
                                        'Impact: ${card.impactText}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Metadata
                    SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMetadataChip(
                          'Confidence',
                          '${(card.confidence * 100).toInt()}%',
                          Icons.verified,
                        ),
                        SizedBox(width: 8),
                        _buildMetadataChip(
                          'Age',
                          card.ageText,
                          Icons.access_time,
                        ),
                        if (card.viewCount != null) ...[
                          SizedBox(width: 8),
                          _buildMetadataChip(
                            'Views',
                            card.viewCount.toString(),
                            Icons.remove_red_eye,
                          ),
                        ],
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
  
  Widget _buildMetadataChip(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _unlockAllCards() async {
    final totalCost = _cards
        .where((card) => !_unlockedCardIds.contains(card.id))
        .fold(0, (sum, card) => sum + card.currentCost);
    
    final bundlePrice = (totalCost * 0.7).round();
    
    if (_userBRBalance < bundlePrice) {
      _showInsufficientBRDialog(bundlePrice);
      return;
    }
    
    // Process bundle purchase
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _walletService.deductFromWallet(
          user.uid,
          bundlePrice,
          'Edge Bundle: ${widget.gameTitle}',
          metadata: {
            'type': 'edge_bundle',
            'gameTitle': widget.gameTitle,
            'cardCount': _cards.where((c) => c.isLocked).length,
          },
        );
        
        setState(() {
          _userBRBalance -= bundlePrice;
          for (final card in _cards) {
            _unlockedCardIds.add(card.id);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unlocked all cards for $bundlePrice BR!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error purchasing bundle: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to purchase bundle'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}