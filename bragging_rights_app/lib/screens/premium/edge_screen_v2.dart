import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/edge/edge_card_widget.dart';
import '../../widgets/edge/edge_card_collection.dart';
import '../../widgets/edge/edge_card_types.dart';
import '../../widgets/edge/sport_card_generator.dart';
import '../../services/edge/edge_intelligence_service.dart';
import '../../services/wallet_service.dart';
import '../../widgets/loading_video_overlay.dart';
import 'edge_detail_screen_v2.dart';
import '../../models/intel_card_model.dart';
import '../../models/injury_model.dart';
import '../../services/injury_service.dart';
import '../../services/intel_card_service.dart';
import '../../widgets/injury_intel_card_widget.dart';
import '../../widgets/injury_report_widget.dart';

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
  final InjuryService _injuryService = InjuryService();
  final IntelCardService _intelCardService = IntelCardService();

  // Data
  EdgeIntelligence? _intelligence;
  List<EdgeCardData> _cards = [];
  int _userBRBalance = 0;
  bool _isLoading = true;
  String? _error;

  // Injury Intel Cards
  List<IntelCard> _availableIntelCards = [];
  Map<String, UserIntelCard> _ownedIntelCards = {};
  Map<String, GameInjuryReport> _injuryReports = {};

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

      // Load Injury Intel Cards if sport supports it
      if (_injuryService.sportSupportsInjuries(widget.sport)) {
        // Generate cards (only if injuries exist)
        _availableIntelCards = await _intelCardService.generateGameIntelCards(
          gameId: widget.gameId ?? widget.eventId ?? '',
          sport: widget.sport,
          gameTime: widget.gameTime ?? DateTime.now(),
          homeTeamId: widget.gameId ?? '', // TODO: Extract real team IDs
          awayTeamId: widget.eventId ?? '', // TODO: Extract real team IDs
        );

        // Check user ownership for each card (only if cards were generated)
        if (_availableIntelCards.isNotEmpty && user != null) {
          for (final card in _availableIntelCards) {
            final userCard = await _intelCardService.getUserIntelCard(
              userId: user.uid,
              cardId: card.id,
            );

            if (userCard != null) {
              _ownedIntelCards[card.id] = userCard;

              // Fetch injury data if owned
              if (userCard.injuryData == null) {
                final report = await _loadInjuryReport(card, homeTeam, awayTeam);
                if (report != null) {
                  _injuryReports[card.id] = report;
                }
              } else {
                _injuryReports[card.id] = userCard.injuryData!;
              }
            }
          }
        }
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
    // Convert real intelligence data to EdgeCardData
    if (_intelligence != null) {
      _createCardsFromIntelligence();
    } else {
      // Only use demo cards as absolute fallback
      _createFallbackCards();
    }
  }
  
  void _createCardsFromIntelligence() {
    if (_intelligence == null) return;
    
    final realCards = <EdgeCardData>[];
    final now = DateTime.now();
    
    // Create cards from insights
    for (final insight in _intelligence!.insights) {
      EdgeCardCategory category;
      EdgeCardRarity rarity;
      int cost;
      List<EdgeCardBadge> badges = [];
      
      // Map insight category to card category
      switch (insight.category) {
        case 'injuries':
          category = EdgeCardCategory.injury;
          rarity = insight.impact == 'high' ? EdgeCardRarity.epic : EdgeCardRarity.rare;
          cost = insight.impact == 'high' ? 20 : 15;
          badges.add(EdgeCardBadge.verified);
          if (insight.insight.toLowerCase().contains('questionable') || 
              insight.insight.toLowerCase().contains('doubtful')) {
            badges.add(EdgeCardBadge.breaking);
          }
          break;
        case 'weather':
          category = EdgeCardCategory.weather;
          rarity = insight.impact == 'high' ? EdgeCardRarity.rare : EdgeCardRarity.uncommon;
          cost = insight.impact == 'high' ? 15 : 10;
          badges.add(EdgeCardBadge.verified);
          break;
        case 'momentum':
        case 'home_advantage':
        case 'matchup':
          category = EdgeCardCategory.matchup;
          rarity = EdgeCardRarity.uncommon;
          cost = 10;
          badges.add(EdgeCardBadge.trending);
          break;
        case 'betting_line':
          category = EdgeCardCategory.betting;
          rarity = EdgeCardRarity.rare;
          cost = 15;
          badges.add(EdgeCardBadge.hot);
          break;
        default:
          category = EdgeCardCategory.social;
          rarity = EdgeCardRarity.common;
          cost = 5;
      }
      
      // Create detailed content from data points
      String fullContent = insight.insight;
      
      // Add related data points
      for (final dataPoint in _intelligence!.dataPoints) {
        if (dataPoint.type.contains(insight.category) || 
            (insight.category == 'injuries' && dataPoint.type == 'injury_report') ||
            (insight.category == 'weather' && dataPoint.type == 'weather_conditions')) {
          fullContent += '\n\nSource: ${dataPoint.source}';
          if (dataPoint.data is Map) {
            final data = dataPoint.data as Map<String, dynamic>;
            data.forEach((key, value) {
              if (value != null && value.toString().isNotEmpty) {
                fullContent += '\n• ${_formatKey(key)}: $value';
              }
            });
          }
          fullContent += '\nConfidence: ${(dataPoint.confidence * 100).toStringAsFixed(0)}%';
        }
      }
      
      realCards.add(EdgeCardData(
        id: 'real_${insight.category}_${DateTime.now().millisecondsSinceEpoch}_${realCards.length}',
        category: category,
        title: _getTitleForInsight(insight),
        teaserText: insight.insight.length > 50 
            ? insight.insight.substring(0, 50) + '...' 
            : insight.insight,
        fullContent: fullContent,
        metadata: {'impact': insight.impact, 'source': 'Live API'},
        timestamp: now.subtract(Duration(minutes: realCards.length * 15)),
        rarity: rarity,
        badges: badges,
        currentCost: cost,
        confidence: _intelligence!.overallConfidence,
        impactText: _getImpactText(insight),
      ));
    }
    
    // Add betting suggestions as cards if available
    if (_intelligence!.predictions['suggestedBets'] != null) {
      final suggestions = _intelligence!.predictions['suggestedBets'] as List;
      for (final suggestion in suggestions) {
        if (suggestion is Map<String, dynamic>) {
          realCards.add(EdgeCardData(
            id: 'suggestion_${DateTime.now().millisecondsSinceEpoch}_${realCards.length}',
            category: EdgeCardCategory.betting,
            title: 'Betting Insight',
            teaserText: suggestion['type'] ?? 'Strategic bet suggestion',
            fullContent: 'Suggested Bet: ${suggestion['type']}\n\n'
                'Reasoning: ${suggestion['reasoning']}\n\n'
                'Confidence: ${((suggestion['confidence'] ?? 0.5) * 100).toStringAsFixed(0)}%\n\n'
                'Based on current game intelligence and statistical analysis.',
            metadata: suggestion,
            timestamp: now.subtract(Duration(minutes: realCards.length * 10)),
            rarity: EdgeCardRarity.rare,
            badges: [EdgeCardBadge.exclusive, EdgeCardBadge.verified],
            currentCost: 15,
            confidence: suggestion['confidence'] ?? 0.5,
            impactText: 'Strategic edge',
          ));
        }
      }
    }
    
    // Add social sentiment if available
    for (final dataPoint in _intelligence!.dataPoints) {
      if (dataPoint.source.toLowerCase().contains('reddit') && dataPoint.data is Map) {
        final data = dataPoint.data as Map<String, dynamic>;
        String sentimentText = 'Community sentiment analysis';
        String fullContent = 'Reddit Analysis from ${dataPoint.source}\n\n';
        
        data.forEach((key, value) {
          fullContent += '• ${_formatKey(key)}: $value\n';
          if (key.toLowerCase().contains('sentiment') && value is num) {
            sentimentText = '${(value * 100).toStringAsFixed(0)}% positive sentiment';
          }
        });
        
        realCards.add(EdgeCardData(
          id: 'social_reddit_${DateTime.now().millisecondsSinceEpoch}',
          category: EdgeCardCategory.social,
          title: 'Reddit Community',
          teaserText: sentimentText,
          fullContent: fullContent,
          metadata: data,
          timestamp: now.subtract(Duration(hours: 1)),
          rarity: EdgeCardRarity.common,
          badges: [EdgeCardBadge.trending, EdgeCardBadge.hot],
          currentCost: 5,
          confidence: dataPoint.confidence,
          impactText: 'Fan insights',
        ));
        break; // Only add one Reddit card
      }
    }
    
    // If we have real cards, use them
    if (realCards.isNotEmpty) {
      setState(() {
        _cards.addAll(realCards);
      });
    } else {
      // Fallback to minimal demo cards if no real data
      _createFallbackCards();
    }
  }
  
  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty 
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }
  
  String _getTitleForInsight(EdgeInsight insight) {
    switch (insight.category) {
      case 'injuries':
        return 'Injury Update';
      case 'weather':
        return 'Weather Impact';
      case 'momentum':
        return 'Team Momentum';
      case 'home_advantage':
        return 'Home Advantage';
      case 'matchup':
        return 'Key Matchup';
      case 'betting_line':
        return 'Line Movement';
      default:
        return 'Game Intelligence';
    }
  }
  
  String _getImpactText(EdgeInsight insight) {
    switch (insight.impact) {
      case 'high':
        return 'Major impact';
      case 'medium':
        return 'Moderate impact';
      case 'low':
        return 'Minor factor';
      default:
        return 'Game factor';
    }
  }
  
  void _createFallbackCards() {
    // Minimal fallback cards only if no real data available
    final demoCards = [
      EdgeCardData(
        id: 'demo_loading_${DateTime.now().millisecondsSinceEpoch}',
        category: EdgeCardCategory.injury,
        title: 'Loading Intelligence',
        teaserText: 'Gathering real-time data...',
        fullContent: 'Edge Intelligence is gathering real-time data for this game.\n'
            'Please check back in a few moments for live insights.',
        metadata: {'type': 'placeholder'},
        timestamp: DateTime.now(),
        rarity: EdgeCardRarity.common,
        badges: [EdgeCardBadge.newItem],
        currentCost: 5,
        confidence: 0.0,
        impactText: 'Pending',
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

  Future<GameInjuryReport?> _loadInjuryReport(
    IntelCard card,
    String homeTeam,
    String awayTeam,
  ) async {
    try {
      // TODO: Extract team IDs from ESPN event data
      // For now, pass team names and let the service handle team ID lookup
      final report = await _injuryService.getGameInjuries(
        sport: widget.sport.toLowerCase(),
        homeTeamId: widget.gameId ?? '', // Placeholder - needs team ID extraction
        homeTeamName: homeTeam,
        homeTeamLogo: null, // Will be fetched by service if available
        awayTeamId: widget.eventId ?? '', // Placeholder - needs team ID extraction
        awayTeamName: awayTeam,
        awayTeamLogo: null, // Will be fetched by service if available
      );

      return report;
    } catch (e) {
      debugPrint('Error loading injury report: $e');
      return null;
    }
  }

  Future<void> _purchaseIntelCard(IntelCard card) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showError('Please sign in to purchase Intel Cards');
      return;
    }

    // Check BR balance
    if (_userBRBalance < card.brCost) {
      _showInsufficientBRDialog(card.brCost);
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Purchase Injury Intel',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.healing, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Purchase complete injury reports for both teams?',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cost: ${card.brCost} BR',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your balance: $_userBRBalance BR',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
            ),
            child: Text('Buy for ${card.brCost} BR'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Purchase
    final result = await _intelCardService.purchaseIntelCard(
      userId: user.uid,
      card: card,
    );

    // Close loading
    Navigator.pop(context);

    if (result.success) {
      // Load injury data
      final teams = widget.gameTitle.split(' vs ');
      String homeTeam = teams.length > 0 ? teams[0].trim() : 'Team 1';
      String awayTeam = teams.length > 1 ? teams[1].trim() : 'Team 2';

      final report = await _loadInjuryReport(card, homeTeam, awayTeam);

      setState(() {
        _ownedIntelCards[card.id] = result.userCard!;
        if (report != null) {
          _injuryReports[card.id] = report;
        }
        _userBRBalance -= card.brCost;
      });

      _showSuccess('Injury Intel unlocked! 🏥');
    } else {
      _showError(result.message);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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
                            'Analyzing game intelligence...',
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

            // Injury Intel Cards Section
            if (_availableIntelCards.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INJURY INTELLIGENCE',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Complete injury reports for both teams',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Render each Intel Card
                    ..._availableIntelCards.map((card) {
                      final owned = _ownedIntelCards.containsKey(card.id);

                      return Column(
                        children: [
                          // Intel Card Widget
                          InjuryIntelCardWidget(
                            card: card,
                            owned: owned,
                            onPurchase: () => _purchaseIntelCard(card),
                            onView: owned ? () {
                              // Scroll to report or show in modal
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Scroll down to view your Injury Report'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            } : null,
                          ),

                          // Injury Report (if owned)
                          if (owned && _injuryReports.containsKey(card.id)) ...[
                            const SizedBox(height: 16),
                            InjuryReportWidget(
                              report: _injuryReports[card.id]!,
                            ),
                          ],

                          const SizedBox(height: 16),
                        ],
                      );
                    }).toList(),
                  ],
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