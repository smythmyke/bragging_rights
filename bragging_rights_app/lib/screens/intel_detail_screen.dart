import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/intel_product.dart';
import '../services/wallet_service.dart';
import '../services/sound_service.dart';

class IntelDetailScreen extends StatefulWidget {
  final IntelProduct intel;

  const IntelDetailScreen({
    super.key,
    required this.intel,
  });

  @override
  State<IntelDetailScreen> createState() => _IntelDetailScreenState();
}

class _IntelDetailScreenState extends State<IntelDetailScreen>
    with SingleTickerProviderStateMixin {
  final WalletService _walletService = WalletService();
  final SoundService _soundService = SoundService();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isPurchasing = false;
  Map<String, dynamic>? _intelData;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _purchaseIntel() async {
    setState(() {
      _isPurchasing = true;
    });

    try {
      final balance = await _walletService.getCurrentBalance();
      if (balance < widget.intel.price) {
        await _soundService.playInsufficientFunds();
        throw Exception('Insufficient funds');
      }

      // Deduct balance
      await _walletService.updateBalance(-widget.intel.price);
      
      // Play purchase sound
      await _soundService.playCardPurchase('intel_${widget.intel.id}');
      
      // Simulate fetching intel data
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _intelData = _generateMockIntelData();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.intel.name} unlocked!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
        });
      }
    }
  }

  Map<String, dynamic> _generateMockIntelData() {
    // Mock data based on intel type
    switch (widget.intel.id) {
      case 'injury_reports':
        return {
          'reports': [
            {'player': 'Player A', 'status': 'Questionable', 'injury': 'Ankle'},
            {'player': 'Player B', 'status': 'Probable', 'injury': 'Shoulder'},
          ],
        };
      case 'weather_report':
        return {
          'temperature': '72°F',
          'conditions': 'Clear',
          'wind': '5 mph SE',
          'humidity': '45%',
        };
      case 'pre_game_analysis':
        return {
          'advantage': 'Home Team',
          'confidence': '67%',
          'key_factors': ['Strong defense', 'Recent winning streak', 'Home field advantage'],
        };
      case 'expert_picks':
        return {
          'experts': [
            {'name': 'Expert 1', 'pick': 'Team A', 'confidence': '75%'},
            {'name': 'Expert 2', 'pick': 'Team A', 'confidence': '60%'},
            {'name': 'Expert 3', 'pick': 'Team B', 'confidence': '55%'},
          ],
        };
      default:
        return {'data': 'Premium intel data'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.intel.name),
        actions: [
          StreamBuilder<int>(
            stream: _walletService.getBalanceStream(),
            builder: (context, snapshot) {
              final balance = snapshot.data ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      PhosphorIconsRegular.coins,
                      size: 18,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$balance BR',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Intel Icon/Visual
                Center(
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: widget.intel.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.intel.color,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        widget.intel.icon,
                        size: 80,
                        color: widget.intel.color,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Intel Info
                Text(
                  widget.intel.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  widget.intel.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Intel Data (if purchased)
                if (_intelData != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.intel.color.withOpacity(0.5)),
                    ),
                    child: _buildIntelDataView(),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Features
                ...widget.intel.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: widget.intel.color,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          feature,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                
                const SizedBox(height: 32),
                
                // Action Button
                if (_intelData == null)
                  StreamBuilder<int>(
                    stream: _walletService.getBalanceStream(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data ?? 0;
                      final canAfford = balance >= widget.intel.price;
                      
                      return ElevatedButton(
                        onPressed: canAfford && !_isPurchasing ? _purchaseIntel : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: canAfford ? widget.intel.color : Colors.grey[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isPurchasing
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    canAfford ? 'UNLOCK FOR ' : 'INSUFFICIENT FUNDS - ',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(
                                    PhosphorIconsRegular.coins,
                                    size: 20,
                                    color: canAfford ? Colors.white : Colors.grey,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.intel.price} BR',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: canAfford ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                      );
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Intel Unlocked',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntelDataView() {
    if (_intelData == null) return const SizedBox.shrink();
    
    // Customize based on intel type
    if (widget.intel.id == 'injury_reports') {
      final reports = _intelData!['reports'] as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INJURY REPORTS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...reports.map((report) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: report['status'] == 'Questionable' 
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report['status'],
                    style: TextStyle(
                      color: report['status'] == 'Questionable' 
                          ? Colors.orange
                          : Colors.green,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${report['player']} - ${report['injury']}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          )),
        ],
      );
    } else if (widget.intel.id == 'weather_report') {
      return Column(
        children: [
          const Text(
            'GAME TIME WEATHER',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildWeatherStat('Temp', _intelData!['temperature']),
              _buildWeatherStat('Wind', _intelData!['wind']),
              _buildWeatherStat('Humidity', _intelData!['humidity']),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Conditions: ${_intelData!['conditions']}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    } else if (widget.intel.id == 'expert_picks') {
      final experts = _intelData!['experts'] as List;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EXPERT PREDICTIONS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...experts.map((expert) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  expert['name'],
                  style: const TextStyle(color: Colors.grey),
                ),
                Row(
                  children: [
                    Text(
                      expert['pick'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        expert['confidence'],
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
        ],
      );
    }
    
    // Default view
    return Text(
      _intelData.toString(),
      style: const TextStyle(color: Colors.white),
    );
  }

  Widget _buildWeatherStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}