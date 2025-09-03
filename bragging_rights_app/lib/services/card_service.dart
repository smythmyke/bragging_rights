import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/card_definitions.dart';
import 'wallet_service.dart';

class UserCardInventory {
  final int offensiveCount;
  final int defensiveCount;
  final int specialCount;
  final Map<String, int> cardQuantities;

  UserCardInventory({
    required this.offensiveCount,
    required this.defensiveCount,
    required this.specialCount,
    required this.cardQuantities,
  });

  factory UserCardInventory.empty() {
    return UserCardInventory(
      offensiveCount: 0,
      defensiveCount: 0,
      specialCount: 0,
      cardQuantities: {},
    );
  }
}

class CardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static CardService? _instance;
  factory CardService() {
    _instance ??= CardService._internal();
    return _instance!;
  }
  CardService._internal();

  // Get user's card inventory
  Stream<UserCardInventory> getUserCardInventory() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return Stream.value(UserCardInventory.empty());
    }

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('cards')
        .snapshots()
        .map((snapshot) {
      int offensiveCount = 0;
      int defensiveCount = 0;
      int specialCount = 0;
      Map<String, int> quantities = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final cardId = doc.id;
        final quantity = (data['quantity'] ?? 0) as int;
        
        quantities[cardId] = quantity;
        
        // Get card definition to determine type
        final card = CardDefinitions.getCard(cardId);
        if (card != null) {
          switch (card.type) {
            case CardType.offensive:
              offensiveCount += quantity;
              break;
            case CardType.defensive:
              defensiveCount += quantity;
              break;
            case CardType.special:
              specialCount += quantity;
              break;
          }
        }
      }

      return UserCardInventory(
        offensiveCount: offensiveCount,
        defensiveCount: defensiveCount,
        specialCount: specialCount,
        cardQuantities: quantities,
      );
    });
  }

  // Get cards of a specific type
  Future<List<PowerCard>> getUserCardsByType(CardType type) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('cards')
        .get();

    List<PowerCard> userCards = [];
    
    for (final doc in snapshot.docs) {
      final cardId = doc.id;
      final quantity = doc.data()['quantity'] ?? 0;
      
      final card = CardDefinitions.getCard(cardId);
      if (card != null && (card.type == type || type == CardType.special)) {
        userCards.add(card.copyWith(quantity: quantity));
      }
    }

    // Sort by rarity (legendary first) then by name
    userCards.sort((a, b) {
      final rarityCompare = b.rarity.index.compareTo(a.rarity.index);
      if (rarityCompare != 0) return rarityCompare;
      return a.name.compareTo(b.name);
    });

    return userCards;
  }

  // Add cards to user inventory
  Future<void> addCardsToUser(String cardId, int quantity) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final cardRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('cards')
        .doc(cardId);

    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(cardRef);
      
      if (doc.exists) {
        final currentQuantity = doc.data()?['quantity'] ?? 0;
        transaction.update(cardRef, {
          'quantity': currentQuantity + quantity,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(cardRef, {
          'quantity': quantity,
          'acquiredAt': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Use a card (decrements quantity)
  Future<bool> useCard(String cardId, String poolId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    try {
      final cardRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(cardId);

      return await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(cardRef);
        
        if (!doc.exists) return false;
        
        final currentQuantity = doc.data()?['quantity'] ?? 0;
        if (currentQuantity <= 0) return false;
        
        // Decrement card quantity
        transaction.update(cardRef, {
          'quantity': currentQuantity - 1,
          'lastUsed': FieldValue.serverTimestamp(),
        });
        
        // Log card usage
        transaction.set(
          _firestore.collection('card_usage').doc(),
          {
            'userId': userId,
            'cardId': cardId,
            'poolId': poolId,
            'usedAt': FieldValue.serverTimestamp(),
          },
        );
        
        return true;
      });
    } catch (e) {
      print('Error using card: $e');
      return false;
    }
  }

  // Check if user can use a card in current game context
  bool canUseCard(PowerCard card, String? gameStatus, int? gamePeriod) {
    if (gameStatus == null) return false;
    
    switch (card.id) {
      case 'double_down':
        return gameStatus == 'live' && (gamePeriod ?? 0) < 3; // Before halftime
      case 'mulligan':
        return gameStatus == 'pregame';
      case 'insurance':
        return gameStatus == 'live' && (gamePeriod ?? 0) < 4; // Before 4th quarter
      case 'split_bet':
        return gameStatus == 'live' && (gamePeriod ?? 0) < 3;
      case 'time_freeze':
        return gameStatus == 'pregame';
      case 'crystal_ball':
      case 'copycat':
        return gameStatus == 'pregame';
      case 'hedge':
        return gameStatus == 'live';
      default:
        return false;
    }
  }

  // Purchase a card with BR coins
  Future<bool> purchaseCard(String cardId, int price) async {
    print('Starting purchase for card: $cardId, price: $price');
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      print('Purchase failed: No user logged in');
      return false;
    }
    
    try {
      // Import wallet service
      final walletService = WalletService();
      
      // Check if user has enough balance
      print('Checking wallet balance for user: $userId');
      final balance = await walletService.getBalance(userId);
      print('Current balance: $balance, required: $price');
      
      if (balance < price) {
        print('Purchase failed: Insufficient balance');
        return false;
      }
      
      // Deduct from wallet
      print('Deducting $price from wallet...');
      final success = await walletService.deductFromWallet(
        userId,
        price,
        'Purchased power card: $cardId',
        metadata: {'cardId': cardId},
      );
      
      if (!success) {
        print('Purchase failed: Could not deduct from wallet');
        return false;
      }
      
      // Add card to user inventory
      print('Adding card to inventory...');
      await addCardsToUser(cardId, 1);
      
      print('Purchase successful!');
      return true;
    } catch (e) {
      print('Error purchasing card: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow; // Rethrow to see the error in UI
    }
  }
  
  // Give starter cards to new users
  Future<void> giveStarterCards(String userId) async {
    // Give new users some starter cards
    final starterCards = {
      'mulligan': 3,
      'insurance': 2,
      'double_down': 2,
      'split_bet': 1,
      'crystal_ball': 1,
    };

    final batch = _firestore.batch();
    
    for (final entry in starterCards.entries) {
      final cardRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('cards')
          .doc(entry.key);
          
      batch.set(cardRef, {
        'quantity': entry.value,
        'acquiredAt': FieldValue.serverTimestamp(),
        'isStarter': true,
      });
    }

    await batch.commit();
    print('Starter cards given to user $userId');
  }

  // Purchase card pack (for future shop implementation)
  Future<bool> purchaseCardPack(String packType, int brCost) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    // This would integrate with WalletService to deduct BR
    // and then grant random cards based on pack type
    
    // For now, return false as shop is not implemented
    return false;
  }
}