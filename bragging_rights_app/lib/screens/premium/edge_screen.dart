import 'package:flutter/material.dart';
import 'edge_detail_screen.dart';

class EdgeScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  
  const EdgeScreen({
    super.key,
    required this.gameTitle,
    required this.sport,
  });

  @override
  State<EdgeScreen> createState() => _EdgeScreenState();
}

class _EdgeScreenState extends State<EdgeScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Selected edge cards
  final Set<String> _revealedCards = {};
  int _userBRBalance = 500; // User's BR balance
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('The Edge', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade700,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$_userBRBalance BR',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
              Colors.purple.shade900,
              Colors.black,
            ],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.gameTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose Your Intelligence Cards',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reveal costs vary by intel value',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Edge Cards Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _getEdgeCards().length,
                itemBuilder: (context, index) {
                  final card = _getEdgeCards()[index];
                  return _buildEdgeCard(card);
                },
              ),
            ),
            
            // Bottom Action
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Column(
                children: [
                  if (_userBRBalance < 10)
                    ElevatedButton.icon(
                      onPressed: _purchaseBR,
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Buy More BR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Intel expires when game starts',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<EdgeCard> _getEdgeCards() {
    switch (widget.sport.toUpperCase()) {
      case 'NBA':
        return [
          EdgeCard(
            id: 'injury',
            title: 'Injury Report',
            icon: Icons.healing,
            color: Colors.red,
            data: 'LeBron: Questionable (ankle)\nAD: Probable (knee)\nReaves: Out (hamstring)',
            source: 'Team Medical Staff',
            cost: 20,
            hasAlert: true,
            alertIcon: Icons.healing,
          ),
          EdgeCard(
            id: 'sentiment',
            title: 'Social Sentiment',
            icon: Icons.trending_up,
            color: Colors.blue,
            data: 'Real-time social analysis coming soon',
            source: 'Social Media Analysis',
            cost: 10,
          ),
          EdgeCard(
            id: 'insider',
            title: 'Insider News',
            icon: Icons.newspaper,
            color: Colors.green,
            data: 'Premium insider reports coming soon',
            source: 'Beat Reporter Network',
            cost: 15,
            hasAlert: false,
            alertIcon: Icons.warning,
          ),
          EdgeCard(
            id: 'vegas',
            title: 'Vegas Sharp',
            icon: Icons.attach_money,
            color: Colors.amber,
            data: 'Professional betting insights coming soon',
            source: 'Vegas Insider',
            cost: 25,
          ),
        ];
      case 'MMA':
        return [
          EdgeCard(
            id: 'compubox',
            title: 'CompuBox Stats',
            icon: Icons.sports_mma,
            color: Colors.red,
            data: 'Fighter statistics coming soon',
            source: 'CompuBox',
            cost: 25,
          ),
          EdgeCard(
            id: 'camp',
            title: 'Training Camp',
            icon: Icons.fitness_center,
            color: Colors.orange,
            data: 'Training camp reports coming soon',
            source: 'Camp Sources',
            cost: 20,
            hasAlert: false,
            alertIcon: Icons.warning_amber,
          ),
          EdgeCard(
            id: 'weigh',
            title: 'Weigh-in Intel',
            icon: Icons.monitor_weight,
            color: Colors.purple,
            data: 'Weigh-in analysis coming soon',
            source: 'Backstage Report',
            cost: 15,
            hasAlert: false,
            alertIcon: Icons.scale,
          ),
          EdgeCard(
            id: 'judge',
            title: 'Judge Tendencies',
            icon: Icons.gavel,
            color: Colors.blue,
            data: 'Judge analysis coming soon',
            source: 'Historical Data',
            cost: 30,
          ),
        ];
      default:
        return [
          EdgeCard(
            id: 'generic1',
            title: 'Team News',
            icon: Icons.group,
            color: Colors.blue,
            data: 'Latest team updates and roster changes',
            source: 'Team Sources',
            cost: 15,
          ),
          EdgeCard(
            id: 'generic2',
            title: 'Analytics',
            icon: Icons.analytics,
            color: Colors.green,
            data: 'Advanced statistics and trends',
            source: 'Data Provider',
            cost: 20,
          ),
        ];
    }
  }
  
  Widget _buildEdgeCard(EdgeCard card) {
    final isRevealed = _revealedCards.contains(card.id);
    final canAfford = _userBRBalance >= card.cost;
    
    return AnimatedBuilder(
      animation: card.hasAlert ? _pulseAnimation : AlwaysStoppedAnimation(1.0),
      builder: (context, child) {
        return Transform.scale(
          scale: card.hasAlert && !isRevealed ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () {
              if (!isRevealed && canAfford) {
                _revealCard(card);
              } else if (!isRevealed && !canAfford) {
                _showNeedBRDialog(card.cost);
              } else if (isRevealed) {
                _showDetailedView(card);
              }
            },
            onLongPress: isRevealed ? () => _showDetailedView(card) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                gradient: isRevealed
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          card.color.withOpacity(0.8),
                          card.color.withOpacity(0.4),
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade900,
                          Colors.grey.shade800,
                        ],
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isRevealed 
                      ? card.color 
                      : card.hasAlert 
                          ? card.color.withOpacity(0.5) 
                          : Colors.grey.shade700,
                  width: card.hasAlert && !isRevealed ? 3 : 2,
                ),
                boxShadow: [
                  if (isRevealed || card.hasAlert)
                    BoxShadow(
                      color: card.color.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: isRevealed
                  ? _buildRevealedCard(card)
                  : _buildHiddenCard(card, canAfford),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildHiddenCard(EdgeCard card, bool canAfford) {
    return Stack(
      children: [
        // Background pattern
        Positioned.fill(
          child: CustomPaint(
            painter: CardBackPainter(),
          ),
        ),
        // Alert indicator
        if (card.hasAlert)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: card.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: card.color.withOpacity(0.7),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                card.alertIcon ?? Icons.priority_high,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        // Content
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                canAfford ? Icons.lock_open : Icons.lock,
                color: canAfford ? Colors.grey.shade500 : Colors.grey.shade700,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                card.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: canAfford 
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: canAfford ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on, 
                      color: canAfford ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${card.cost} BR',
                      style: TextStyle(
                        color: canAfford ? Colors.green : Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                canAfford ? 'TAP TO REVEAL' : 'INSUFFICIENT BR',
                style: TextStyle(
                  color: canAfford ? Colors.white54 : Colors.red.shade300,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildRevealedCard(EdgeCard card) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(card.icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        card.data,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green.shade300, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Source: ${card.source}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _revealCard(EdgeCard card) {
    setState(() {
      _revealedCards.add(card.id);
      _userBRBalance -= card.cost;
    });
    
    // Animate the reveal
    _animationController.forward().then((_) {
      _animationController.reset();
    });
    
    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Revealed ${card.title} for ${card.cost} BR'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void _showNeedBRDialog(int requiredBR) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Insufficient BR',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.monetization_on, color: Colors.red.shade300, size: 48),
            const SizedBox(height: 16),
            Text(
              'You need $requiredBR BR to reveal this intel',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your balance: $_userBRBalance BR',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _purchaseBR();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Buy BR'),
          ),
        ],
      ),
    );
  }
  
  void _purchaseBR() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Purchase BR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildBRPackage('Starter Pack', 50, 4.99, false),
            _buildBRPackage('Pro Pack', 500, 39.99, true),
            _buildBRPackage('Elite Pack', 1000, 74.99, false),
          ],
        ),
      ),
    );
  }
  
  void _showDetailedView(EdgeCard card) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EdgeDetailScreen(
          card: card,
          gameTitle: widget.gameTitle,
          sport: widget.sport,
        ),
      ),
    );
  }
  
  Widget _buildBRPackage(String name, int brAmount, double price, bool isBestValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: isBestValue
            ? const LinearGradient(colors: [Colors.green, Colors.teal])
            : null,
        color: isBestValue ? null : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBestValue ? Colors.green : Colors.grey.shade700,
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
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
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
            color: isBestValue ? Colors.white : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '$brAmount BR',
          style: TextStyle(
            color: isBestValue ? Colors.white70 : Colors.white70,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            setState(() {
              _userBRBalance += brAmount;
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Purchased $brAmount BR for \$$price!'),
                backgroundColor: Colors.green,
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isBestValue ? Colors.white : Colors.green,
            foregroundColor: isBestValue ? Colors.green : Colors.white,
          ),
          child: Text('\$$price'),
        ),
      ),
    );
  }
}

class EdgeCard {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final String data;
  final String source;
  final int cost;
  final bool hasAlert;
  final IconData? alertIcon;
  
  EdgeCard({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.data,
    required this.source,
    required this.cost,
    this.hasAlert = false,
    this.alertIcon,
  });
}

class CardBackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Draw diagonal lines pattern
    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}