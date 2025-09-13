import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../widgets/br_app_bar.dart';

class QuickPickScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  final String poolName;
  final String poolId;
  final String? gameId;
  
  const QuickPickScreen({
    super.key,
    required this.gameTitle,
    required this.sport,
    required this.poolName,
    required this.poolId,
    this.gameId,
  });

  @override
  State<QuickPickScreen> createState() => _QuickPickScreenState();
}

class _QuickPickScreenState extends State<QuickPickScreen> 
    with TickerProviderStateMixin {
  
  late AnimationController _swipeController;
  late AnimationController _nextCardController;
  late Animation<Offset> _swipeAnimation;
  late Animation<double> _nextCardScaleAnimation;
  
  // Mock data for demonstration
  final List<Map<String, dynamic>> _mockFights = [
    {
      'id': '1',
      'fighter1': 'Jon Jones',
      'fighter2': 'Stipe Miocic',
      'fighter1Record': '27-1-0',
      'fighter2Record': '20-4-0',
      'odds1': -250,
      'odds2': 200,
      'eventName': 'UFC 295',
      'isMainEvent': true,
      'weightClass': 'Heavyweight',
    },
    {
      'id': '2',
      'fighter1': 'Alex Pereira',
      'fighter2': 'Jiri Prochazka',
      'fighter1Record': '8-2-0',
      'fighter2Record': '30-3-1',
      'odds1': -150,
      'odds2': 130,
      'eventName': 'UFC 295',
      'isMainEvent': false,
      'weightClass': 'Light Heavyweight',
    },
    {
      'id': '3',
      'fighter1': 'Beneil Dariush',
      'fighter2': 'Arman Tsarukyan',
      'fighter1Record': '22-5-1',
      'fighter2Record': '20-3-0',
      'odds1': 110,
      'odds2': -130,
      'eventName': 'UFC 295',
      'isMainEvent': false,
      'weightClass': 'Lightweight',
    },
  ];
  
  Map<String, String> _picks = {};
  int _currentIndex = 0;
  double _dragX = 0;
  
  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }
  
  void _setupAnimations() {
    _swipeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _nextCardController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
    
    _nextCardScaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _nextCardController,
      curve: Curves.easeOut,
    ));
  }
  
  void _handleSwipe(DragUpdateDetails details) {
    setState(() {
      _dragX = details.localPosition.dx - MediaQuery.of(context).size.width / 2;
    });
  }
  
  void _handleSwipeEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final velocity = details.velocity.pixelsPerSecond.dx;
    
    if (_dragX.abs() > screenWidth * 0.3 || velocity.abs() > 800) {
      // Swipe is significant enough
      if (_dragX > 0) {
        _pickFighter(2); // Right swipe - pick fighter 2
      } else {
        _pickFighter(1); // Left swipe - pick fighter 1
      }
    } else {
      // Return to center
      setState(() {
        _dragX = 0;
      });
    }
  }
  
  void _pickFighter(int fighterNumber) {
    final fight = _mockFights[_currentIndex];
    final pickId = fighterNumber == 1 ? 'fighter1' : 'fighter2';
    
    setState(() {
      _picks[fight['id']] = fight[pickId];
    });
    
    // Animate swipe
    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(fighterNumber == 1 ? -2.0 : 2.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: Curves.easeOut,
    ));
    
    _swipeController.forward().then((_) {
      _nextCard();
      _swipeController.reset();
    });
    
    _nextCardController.forward();
  }
  
  void _nextCard() {
    if (_currentIndex < _mockFights.length - 1) {
      setState(() {
        _currentIndex++;
        _dragX = 0;
      });
      _nextCardController.reset();
    } else {
      _submitPicks();
    }
  }
  
  Future<void> _submitPicks() async {
    // Show confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Submit Picks?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You picked ${_picks.length} winners'),
            const SizedBox(height: 16),
            const Text('Ready to submit your picks?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
              });
            },
            child: const Text('Review'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Navigate to success screen or pool screen
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/my-pools',
                (route) => route.isFirst,
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Picks submitted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _swipeController.dispose();
    _nextCardController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: BRAppBar(
        title: 'Quick Pick',
        showBackButton: true,
        actions: [
          if (_mockFights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_currentIndex + 1}/${_mockFights.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Pool info header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.poolName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.gameTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        PhosphorIconsRegular.lightning,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_picks.length} picks',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Instructions
          if (_currentIndex == 0 && _dragX == 0)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.arrowLeft,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Swipe to pick your winner',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    PhosphorIconsRegular.arrowRight,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          
          // Swipeable cards
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Next card (behind)
                if (_currentIndex < _mockFights.length - 1)
                  ScaleTransition(
                    scale: _nextCardScaleAnimation,
                    child: _buildFightCard(
                      _mockFights[_currentIndex + 1],
                      isInteractive: false,
                    ),
                  ),
                
                // Current card (front)
                if (_currentIndex < _mockFights.length)
                  GestureDetector(
                    onPanUpdate: _handleSwipe,
                    onPanEnd: _handleSwipeEnd,
                    child: SlideTransition(
                      position: _swipeAnimation,
                      child: Transform.translate(
                        offset: Offset(_dragX, 0),
                        child: Transform.rotate(
                          angle: _dragX * 0.0002,
                          child: _buildFightCard(
                            _mockFights[_currentIndex],
                            isInteractive: true,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Quick action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0
                      ? () {
                          setState(() {
                            _currentIndex--;
                            _dragX = 0;
                          });
                        }
                      : null,
                  icon: const Icon(PhosphorIconsRegular.arrowLeft),
                  iconSize: 32,
                ),
                FloatingActionButton(
                  onPressed: () => _pickFighter(1),
                  backgroundColor: Colors.red,
                  child: Text(
                    _mockFights[_currentIndex]['fighter1']
                        .split(' ')
                        .last
                        .substring(0, 1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                FloatingActionButton(
                  onPressed: () => _pickFighter(2),
                  backgroundColor: Colors.blue,
                  child: Text(
                    _mockFights[_currentIndex]['fighter2']
                        .split(' ')
                        .last
                        .substring(0, 1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_currentIndex < _mockFights.length - 1) {
                      setState(() {
                        _currentIndex++;
                        _dragX = 0;
                      });
                    } else {
                      _submitPicks();
                    }
                  },
                  icon: Icon(
                    _currentIndex < _mockFights.length - 1
                        ? PhosphorIconsRegular.arrowRight
                        : PhosphorIconsRegular.check,
                  ),
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFightCard(Map<String, dynamic> fight, {required bool isInteractive}) {
    final isSwipingLeft = _dragX < -20;
    final isSwipingRight = _dragX > 20;
    
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Event header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: fight['isMainEvent'] == true
                  ? Colors.amber.withOpacity(0.2)
                  : const Color(0xFFF5F5F5),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                if (fight['isMainEvent'] == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'MAIN EVENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                Text(
                  fight['eventName'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (fight['weightClass']?.isNotEmpty ?? false)
                  Text(
                    fight['weightClass'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          
          // Fighters
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Fighter 1
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSwipingLeft && isInteractive
                          ? Colors.red.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSwipingLeft && isInteractive
                            ? Colors.red
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              fight['fighter1']
                                  .split(' ')
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fight['fighter1'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (fight['fighter1Record']?.isNotEmpty ?? false)
                          Text(
                            fight['fighter1Record'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatOdds(fight['odds1']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // VS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isInteractive && _dragX.abs() > 20)
                        Icon(
                          isSwipingLeft
                              ? PhosphorIconsRegular.arrowLeft
                              : PhosphorIconsRegular.arrowRight,
                          color: isSwipingLeft ? Colors.red : Colors.blue,
                          size: 24,
                        ),
                    ],
                  ),
                ),
                
                // Fighter 2
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSwipingRight && isInteractive
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSwipingRight && isInteractive
                            ? Colors.blue
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              fight['fighter2']
                                  .split(' ')
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join(),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          fight['fighter2'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (fight['fighter2Record']?.isNotEmpty ?? false)
                          Text(
                            fight['fighter2Record'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _formatOdds(fight['odds2']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatOdds(dynamic odds) {
    if (odds == null) return 'N/A';
    final oddsNum = odds is int ? odds : int.tryParse(odds.toString()) ?? 0;
    return oddsNum > 0 ? '+$oddsNum' : '$oddsNum';
  }
}