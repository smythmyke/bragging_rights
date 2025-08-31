import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final List<ProductDetails> _products = [];
  bool _available = false;
  
  // Product IDs for BR Coins packages (1 BR Coin = $0.02)
  static const Set<String> _productIds = {
    'br_coins_250',    // 250 BR Coins for $5.00
    'br_coins_500',    // 500 BR Coins for $10.00
  };

  // Product details (1 BR Coin = $0.02 exactly)
  static const Map<String, Map<String, dynamic>> _productDetails = {
    'br_coins_250': {
      'coins': 250,
      'price': 5.00,
      'name': '250 BR Coins',
      'description': 'Get 250 BR Coins',
      'bonus': 0,
      'popularTag': false,
      'bestValue': false,
    },
    'br_coins_500': {
      'coins': 550,  // 500 + 50 bonus (10% bonus)
      'price': 10.00,
      'name': '500 BR Coins',
      'description': 'Get 500 BR Coins + 50 Bonus',
      'bonus': 50,
      'popularTag': true,
      'bestValue': true,
    },
  };

  /// Initialize the purchase service
  Future<void> initialize() async {
    try {
      print('Starting PurchaseService initialization...');
      
      // Check if in-app purchases are available
      _available = await _inAppPurchase.isAvailable();
      print('In-app purchases available: $_available');
      
      if (!_available) {
        print('In-app purchases not available on this device');
        print('Make sure:');
        print('  1. Google Play Store is installed and updated');
        print('  2. Device has internet connection');
        print('  3. Google Play services are available');
        return;
      }
      
      // Load products
      await _loadProducts();
      
      // Set up purchase listener
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: _onPurchaseError,
      );
      
      print('Purchase service initialization complete');
      print('Products available: ${_products.length}');
    } catch (e) {
      print('Error initializing purchase service: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Load available products
  Future<void> _loadProducts() async {
    try {
      print('Attempting to load products: $_productIds');
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds);
      
      if (response.error != null) {
        print('Error loading products: ${response.error}');
        print('Error details: ${response.error!.message}');
        return;
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        print('Products not found in store: ${response.notFoundIDs}');
        print('Make sure these product IDs exist in Google Play Console:');
        for (final id in response.notFoundIDs) {
          print('  - $id');
        }
      }
      
      _products.clear();
      _products.addAll(response.productDetails);
      
      // Sort products by price
      _products.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
      
      print('Successfully loaded ${_products.length} products:');
      for (final product in _products) {
        print('  - ${product.id}: ${product.title} - ${product.price}');
      }
    } catch (e) {
      print('Exception loading products: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  /// Get available products
  List<ProductDetails> getProducts() {
    return List.unmodifiable(_products);
  }

  /// Get product info including bonus details
  Map<String, dynamic>? getProductInfo(String productId) {
    return _productDetails[productId];
  }

  /// Purchase BR coins
  Future<bool> purchaseProduct(String productId) async {
    if (!_available) {
      throw Exception('In-app purchases not available');
    }
    
    final product = _products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );
    
    final PurchaseParam purchaseParam = PurchaseParam(
      productDetails: product,
    );
    
    try {
      // For consumable products (BR coins)
      return await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (e) {
      print('Error purchasing product: $e');
      throw e;
    }
  }

  /// Handle purchase updates
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      print('Purchase status: ${purchaseDetails.status}');
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI
        print('Purchase pending...');
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Handle error
          print('Purchase error: ${purchaseDetails.error}');
          _handlePurchaseError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Verify and deliver purchase
          await _deliverProduct(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          // Handle cancellation
          print('Purchase canceled');
        }
        
        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// Handle purchase errors
  void _onPurchaseError(dynamic error) {
    print('Purchase stream error: $error');
  }

  /// Handle specific purchase error
  void _handlePurchaseError(IAPError error) {
    print('Purchase error: ${error.code} - ${error.message}');
  }

  /// Deliver purchased product
  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Get product info
      final productInfo = _productDetails[purchaseDetails.productID];
      if (productInfo == null) {
        throw Exception('Product info not found');
      }
      
      // Verify purchase with backend
      await _verifyPurchase(purchaseDetails);
      
      // Add coins to user's wallet
      final coinsToAdd = productInfo['coins'] as int;
      await _addCoinsToWallet(user.uid, coinsToAdd, purchaseDetails);
      
      print('Successfully delivered ${coinsToAdd} BR coins');
    } catch (e) {
      print('Error delivering product: $e');
      // Optionally retry or log for manual resolution
    }
  }

  /// Verify purchase with backend
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final callable = _functions.httpsCallable('verifyPurchase');
      
      final result = await callable({
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'verificationData': purchaseDetails.verificationData.serverVerificationData,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      
      if (result.data['valid'] != true) {
        throw Exception('Purchase verification failed');
      }
    } catch (e) {
      print('Error verifying purchase: $e');
      throw e;
    }
  }

  /// Add coins to user's wallet
  Future<void> _addCoinsToWallet(String userId, int coins, PurchaseDetails purchaseDetails) async {
    final walletRef = _firestore.collection('users').doc(userId).collection('wallet').doc('current');
    final transactionRef = _firestore.collection('transactions').doc();
    
    await _firestore.runTransaction((transaction) async {
      final walletDoc = await transaction.get(walletRef);
      
      if (!walletDoc.exists) {
        throw Exception('Wallet not found');
      }
      
      final currentBalance = walletDoc.data()!['balance'] ?? 0;
      final newBalance = currentBalance + coins;
      
      // Update wallet
      transaction.update(walletRef, {
        'balance': newBalance,
        'lifetimeEarned': FieldValue.increment(coins),
        'lastPurchase': FieldValue.serverTimestamp(),
      });
      
      // Create transaction record
      transaction.set(transactionRef, {
        'userId': userId,
        'type': 'purchase',
        'amount': coins,
        'description': 'BR Coins Purchase - ${purchaseDetails.productID}',
        'balanceBefore': currentBalance,
        'balanceAfter': newBalance,
        'timestamp': FieldValue.serverTimestamp(),
        'purchaseId': purchaseDetails.purchaseID,
        'productId': purchaseDetails.productID,
        'status': 'completed',
      });
    });
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      print('Restore purchases initiated');
    } catch (e) {
      print('Error restoring purchases: $e');
      throw e;
    }
  }

  /// Check if purchases are available
  bool get isAvailable => _available;

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
  }
}

/// Product display model
class BRCoinPackage {
  final String id;
  final String name;
  final String description;
  final int coins;
  final int bonus;
  final double price;
  final String priceString;
  final bool isBestValue;

  BRCoinPackage({
    required this.id,
    required this.name,
    required this.description,
    required this.coins,
    required this.bonus,
    required this.price,
    required this.priceString,
    this.isBestValue = false,
  });

  int get totalCoins => coins + bonus;
  double get pricePerCoin => price / totalCoins;
  
  factory BRCoinPackage.fromProductDetails(ProductDetails product, Map<String, dynamic> info) {
    return BRCoinPackage(
      id: product.id,
      name: info['name'] ?? product.title,
      description: info['description'] ?? product.description,
      coins: info['coins'] - info['bonus'],
      bonus: info['bonus'],
      price: product.rawPrice,
      priceString: product.price,
      isBestValue: info['bestValue'] ?? false,
    );
  }
}