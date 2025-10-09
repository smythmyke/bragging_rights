import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/ad_reward_service.dart';
import '../../services/br_currency_service.dart';
import '../../services/purchase_service.dart';

/// BR Currency Shop Screen
/// Allows users to:
/// 1. Watch rewarded ads to earn 25 BR (5 per day max)
/// 2. Purchase BR with real money (future)
/// 3. Go premium for ad-free experience
class BRShopScreen extends StatefulWidget {
  const BRShopScreen({super.key});

  @override
  State<BRShopScreen> createState() => _BRShopScreenState();
}

class _BRShopScreenState extends State<BRShopScreen> {
  final AdRewardService _adService = AdRewardService();
  final BRCurrencyService _brService = BRCurrencyService();
  final PurchaseService _purchaseService = PurchaseService();

  int _currentBalance = 0;
  bool _isPremium = false;
  bool _isLoading = true;
  AdWatchStatus? _adStatus;
  List<dynamic> _availableProducts = [];
  bool _productsLoaded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🏪 [BR-SHOP] initState() - BR Shop screen initializing');
    _initializePurchaseService();
    _loadUserData();
    _loadAdStatus();
    debugPrint('📥 [BR-SHOP] Calling _adService.loadRewardedAd() to preload ad...');
    _adService.loadRewardedAd(); // Preload ad
  }

  Future<void> _initializePurchaseService() async {
    debugPrint('💳 [BR-SHOP] Initializing PurchaseService...');
    try {
      await _purchaseService.initialize();
      final products = await _purchaseService.getProducts();
      debugPrint('✅ [BR-SHOP] PurchaseService initialized - ${products.length} products available');
      setState(() {
        _availableProducts = products;
        _productsLoaded = true;
      });
    } catch (e) {
      debugPrint('❌ [BR-SHOP] Error initializing PurchaseService: $e');
      setState(() {
        _productsLoaded = true; // Still mark as loaded to show UI
      });
    }
  }

  Future<void> _loadUserData() async {
    debugPrint('👤 [BR-SHOP] _loadUserData() called');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [BR-SHOP] No user logged in');
      return;
    }

    debugPrint('👤 [BR-SHOP] Loading user data for UID: ${user.uid}');
    try {
      // Get isPremium from user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final isPremium = userDoc.data()?['isPremium'] ?? false;

      // Get balance from wallet subcollection (correct source)
      final walletDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('wallet')
          .doc('current')
          .get();

      final balance = walletDoc.data()?['balance'] ?? 0;

      debugPrint('✅ [BR-SHOP] User data loaded - Balance: $balance BR (from wallet/current), Premium: $isPremium');
      setState(() {
        _currentBalance = balance;
        _isPremium = isPremium;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [BR-SHOP] Error loading user data: $e');
      debugPrint('❌ [BR-SHOP] Stack: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAdStatus() async {
    debugPrint('📊 [BR-SHOP] _loadAdStatus() called');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [BR-SHOP] No user logged in for ad status');
      return;
    }

    try {
      debugPrint('📊 [BR-SHOP] Fetching ad watch status for user...');
      final status = await _adService.getAdWatchStatus(user.uid);
      debugPrint('✅ [BR-SHOP] Ad status loaded - Watched: ${status.adsWatchedToday}/${status.maxAdsPerDay}');
      setState(() => _adStatus = status);
    } catch (e, stackTrace) {
      debugPrint('❌ [BR-SHOP] Error loading ad status: $e');
      debugPrint('❌ [BR-SHOP] Stack: $stackTrace');
    }
  }

  Future<void> _watchAd() async {
    debugPrint('🎬 [BR-SHOP] _watchAd() called - User tapped Watch Ad button');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [BR-SHOP] User not logged in, cannot watch ad');
      _showError('Please log in to watch ads');
      return;
    }

    debugPrint('🔍 [BR-SHOP] Checking if ad is ready...');
    final isReady = _adService.isAdReady();
    debugPrint('🔍 [BR-SHOP] Ad ready status: $isReady');

    if (!isReady) {
      debugPrint('⏸️ [BR-SHOP] Ad not ready, attempting to load...');
      _showError('Ad is loading... Please wait a moment');
      _adService.loadRewardedAd(); // Try to load again
      return;
    }

    debugPrint('🎬 [BR-SHOP] Ad is ready! Showing loading dialog and displaying ad...');
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.neonGreen,
        ),
      ),
    );

    debugPrint('📺 [BR-SHOP] Calling _adService.showRewardedAd()...');
    // Show ad
    final result = await _adService.showRewardedAd(user.uid);
    debugPrint('📺 [BR-SHOP] showRewardedAd() completed - Success: ${result.success}, Message: ${result.message}');

    // Close loading
    if (mounted) Navigator.of(context).pop();

    // Show result
    if (result.success) {
      setState(() {
        _currentBalance = result.newBalance;
      });
      await _loadAdStatus(); // Refresh ad count

      _showSuccess(
        'Earned ${result.brAwarded} BR!',
        'New balance: ${result.newBalance} BR',
      );
    } else {
      _showError(result.message);
    }
  }

  void _showSuccess(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(PhosphorIconsRegular.checkCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.neonGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(PhosphorIconsRegular.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorPink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlue,
      appBar: AppBar(
        title: const Text('BR Currency'),
        backgroundColor: AppTheme.surfaceBlue,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryCyan),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Balance Card
                    _buildBalanceCard(),

                    const SizedBox(height: 24),

                    // Watch & Earn Section (only for free users)
                    if (!_isPremium) ...[
                      _buildWatchAndEarnCard(),
                      const SizedBox(height: 24),
                    ],

                    // Premium Upsell (only for free users)
                    if (!_isPremium) ...[
                      _buildPremiumUpsellCard(),
                      const SizedBox(height: 24),
                    ],

                    // Purchase Options
                    _buildPurchaseSection(),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 4, // Highlight "More" since BR Shop is under More section
        onTap: (index) {
          if (index == 4) {
            // Already on More/Shop - do nothing or go back to More tab
            return;
          }
          // Navigate back to home and let it handle tab switching
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.gameController),
            label: 'Games',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.currencyDollar),
            label: 'Bets',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.live_tv),
            label: 'Watch Live',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.lightning),
            label: 'Edge',
          ),
          BottomNavigationBarItem(
            icon: Icon(PhosphorIconsRegular.dotsThreeOutline),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.neonGlow(color: AppTheme.primaryCyan),
      ),
      child: Column(
        children: [
          const Icon(
            PhosphorIconsRegular.wallet,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          const Text(
            'Current Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_currentBalance BR',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchAndEarnCard() {
    final adsWatched = _adStatus?.adsWatchedToday ?? 0;
    final maxAds = _adStatus?.maxAdsPerDay ?? 5;
    final adsRemaining = maxAds - adsWatched;
    final canWatch = adsRemaining > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3), width: 1),
        boxShadow: AppTheme.neonGlow(color: AppTheme.neonGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  PhosphorIconsRegular.videoCamera,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WATCH & EARN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Watch 30-second video',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Earn per video:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '25 BR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Today:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '$adsWatched/$maxAds videos watched',
                      style: TextStyle(
                        color: canWatch ? Colors.white : AppTheme.warningAmber,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (canWatch) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Potential earnings:',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${adsRemaining * 25} BR remaining',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canWatch ? _watchAd : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.neonGreen,
                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                disabledForegroundColor: Colors.white60,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    canWatch
                        ? PhosphorIconsRegular.play
                        : PhosphorIconsRegular.prohibit,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    canWatch
                        ? 'WATCH NOW - EARN 25 BR'
                        : 'DAILY LIMIT REACHED',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumUpsellCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  PhosphorIconsRegular.crown,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Go Premium',
                style: TextStyle(
                  color: AppTheme.primaryCyan,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _buildPremiumFeature('Zero ads forever'),
          _buildPremiumFeature('Real Vegas odds'),
          _buildPremiumFeature('Exclusive premium pools'),
          _buildPremiumFeature('Edge Intelligence AI picks'),

          const SizedBox(height: 16),

          const Text(
            'Less than a coffee per month!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: Navigate to premium subscription screen
                _showError('Premium subscription coming soon!');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryCyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'TRY FREE FOR 7 DAYS',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              'Then \$1.99/month, cancel anytime',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            PhosphorIconsRegular.checkCircle,
            size: 18,
            color: AppTheme.neonGreen,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseSection() {
    if (!_productsLoaded) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: AppTheme.primaryCyan),
        ),
      );
    }

    if (_availableProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlue.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Icon(
              PhosphorIconsRegular.shoppingCartSimple,
              color: Colors.white60,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'No products available',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Check back later',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Purchase BR',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...List.generate(_availableProducts.length, (index) {
          final product = _availableProducts[index];
          final isBestValue = index == 1; // Second product is best value

          return Padding(
            padding: EdgeInsets.only(bottom: index < _availableProducts.length - 1 ? 12 : 0),
            child: _buildBRPackageFromProduct(product, isBestValue: isBestValue),
          );
        }),
      ],
    );
  }

  Widget _buildBRPackageFromProduct(dynamic product, {bool isBestValue = false}) {
    final productInfo = _purchaseService.getProductInfo(product.id);
    final name = productInfo?['name'] ?? product.title;
    final amount = productInfo?['coins'] ?? 0;
    final price = product.price;

    return Container(
      decoration: BoxDecoration(
        gradient: isBestValue
            ? const LinearGradient(
                colors: [AppTheme.neonGreen, AppTheme.primaryCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isBestValue ? null : AppTheme.surfaceBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBestValue
              ? AppTheme.neonGreen
              : AppTheme.borderCyan.withOpacity(0.3),
          width: isBestValue ? 2 : 1,
        ),
        boxShadow: isBestValue ? AppTheme.neonGlow(color: AppTheme.neonGreen, intensity: 0.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isBestValue
                    ? Colors.white.withOpacity(0.2)
                    : AppTheme.primaryCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                PhosphorIconsRegular.coins,
                color: isBestValue ? Colors.white : AppTheme.primaryCyan,
                size: 28,
              ),
            ),
            if (isBestValue)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.warningAmber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    PhosphorIconsRegular.star,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: isBestValue ? Colors.white : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isBestValue) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'BEST VALUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$amount BR',
          style: TextStyle(
            color: isBestValue ? Colors.white.withOpacity(0.9) : Colors.white70,
            fontSize: 14,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _processRealBRPurchase(product.id, productInfo),
          style: ElevatedButton.styleFrom(
            backgroundColor: isBestValue ? Colors.white : AppTheme.primaryCyan,
            foregroundColor: isBestValue ? AppTheme.neonGreen : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: Text(
            price,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _processRealBRPurchase(String productId, Map<String, dynamic>? productInfo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Please log in to purchase BR');
      return;
    }

    debugPrint('💳 [BR-SHOP] Processing purchase for product: $productId');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.neonGreen,
        ),
      ),
    );

    try {
      final success = await _purchaseService.purchaseProduct(productId);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (success && mounted) {
        // Reload balance
        await _loadUserData();

        _showSuccess(
          'Successfully purchased ${productInfo?['coins'] ?? ''} BR!',
          'New balance: $_currentBalance BR',
        );
      }
    } catch (e) {
      debugPrint('❌ [BR-SHOP] Purchase error: $e');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        _showError('Purchase failed: ${e.toString()}');
      }
    }
  }

  @override
  void dispose() {
    _adService.dispose();
    super.dispose();
  }
}
