import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  String? _fcmToken;
  
  // Notification preferences
  final Map<String, bool> _defaultPreferences = {
    'betWon': true,
    'betLost': false,
    'weeklyAllowance': true,
    'poolInvitations': true,
    'friendRequests': true,
    'gameReminders': true,
    'leaderboardAchievements': true,
  };

  /// Initialize notification service
  Future<void> initialize() async {
    try {
      // Request permission
      await _requestPermission();
      
      // Get FCM token
      await _getToken();
      
      // Set up message handlers
      _setupMessageHandlers();
      
      // Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      
      print('Notification service initialized successfully');
    } catch (e) {
      print('Error initializing notification service: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    
    print('Notification permission status: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('Notifications not authorized');
    }
  }

  /// Get and register FCM token
  Future<void> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      
      if (_fcmToken != null) {
        print('FCM Token: $_fcmToken');
        await _registerToken(_fcmToken!);
      }
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _registerToken(newToken);
      });
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Register FCM token with backend
  Future<void> _registerToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final platform = _getPlatformName();
      
      final callable = _functions.httpsCallable('registerFCMToken');
      await callable({
        'token': token,
        'platform': platform,
      });
      
      print('FCM token registered successfully');
    } catch (e) {
      print('Error registering FCM token: $e');
    }
  }

  /// Get platform name
  String _getPlatformName() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
    } catch (e) {
      // Platform not available
    }
    return 'unknown';
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      
      if (message.notification != null) {
        print('Message notification: ${message.notification!.title}');
        _handleForegroundNotification(message);
      }
    });
    
    // Message opened app from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
      _handleNotificationClick(message);
    });
    
    // Check if app was opened from terminated state
    _checkInitialMessage();
  }

  /// Check if app was opened from notification
  Future<void> _checkInitialMessage() async {
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    
    if (initialMessage != null) {
      print('App opened from terminated state by notification');
      _handleNotificationClick(initialMessage);
    }
  }

  /// Handle foreground notification
  void _handleForegroundNotification(RemoteMessage message) {
    // Show in-app notification
    // This would typically show a snackbar or custom notification UI
    print('Show in-app notification: ${message.notification?.title}');
  }

  /// Handle notification click
  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    final screen = data['screen'];
    
    if (screen != null) {
      // Navigate to appropriate screen
      _navigateToScreen(screen, data);
    }
  }

  /// Navigate to screen based on notification data
  void _navigateToScreen(String screen, Map<String, dynamic> data) {
    // This would be implemented with your navigation service
    print('Navigate to: $screen with data: $data');
    
    switch (screen) {
      case '/bet-details':
        // Navigate to bet details with betId
        break;
      case '/wallet':
        // Navigate to wallet screen
        break;
      case '/pool-invitation':
        // Navigate to pool invitation with poolId
        break;
      case '/friend-requests':
        // Navigate to friend requests
        break;
      case '/active-bets':
        // Navigate to active bets
        break;
      case '/leaderboard':
        // Navigate to leaderboard
        break;
      default:
        // Navigate to home
        break;
    }
  }

  /// Update notification preferences
  Future<void> updatePreferences(Map<String, bool> preferences) async {
    try {
      final callable = _functions.httpsCallable('updateNotificationPreferences');
      await callable({
        'preferences': preferences,
      });
      
      print('Notification preferences updated');
    } catch (e) {
      print('Error updating notification preferences: $e');
      throw e;
    }
  }

  /// Get user's notification preferences
  Future<Map<String, bool>> getPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return _defaultPreferences;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      
      if (data != null && data['notificationPreferences'] != null) {
        return Map<String, bool>.from(data['notificationPreferences']);
      }
      
      return _defaultPreferences;
    } catch (e) {
      print('Error getting notification preferences: $e');
      return _defaultPreferences;
    }
  }

  /// Get notification history
  Stream<List<NotificationModel>> getNotificationHistory() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Mark notifications as read
  Future<void> markAsRead(List<String> notificationIds) async {
    try {
      final callable = _functions.httpsCallable('markNotificationsRead');
      await callable({
        'notificationIds': notificationIds,
      });
      
      print('Marked ${notificationIds.length} notifications as read');
    } catch (e) {
      print('Error marking notifications as read: $e');
      throw e;
    }
  }

  /// Get unread notification count
  Stream<int> getUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Send test notification (Admin only)
  Future<void> sendTestNotification(String userId, String title, String body) async {
    try {
      final callable = _functions.httpsCallable('sendTestNotification');
      await callable({
        'userId': userId,
        'title': title,
        'body': body,
      });
      
      print('Test notification sent');
    } catch (e) {
      print('Error sending test notification: $e');
      throw e;
    }
  }
}

/// Notification model
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? icon;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime timestamp;
  final DateTime? readAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.icon,
    required this.data,
    required this.read,
    required this.timestamp,
    this.readAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      icon: map['icon'],
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      read: map['read'] ?? false,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      readAt: map['readAt'] != null 
          ? (map['readAt'] as Timestamp).toDate()
          : null,
    );
  }
}