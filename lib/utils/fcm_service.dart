import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Firebase Cloud Messaging Service
/// Handles all FCM related operations including:
/// - Requesting notification permissions
/// - Getting FCM Token
/// - Handling notifications in different app states
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  /// Initialize FCM service
  /// This should be called in main.dart after Firebase.initializeApp()
  static Future<void> initialize() async {
    try {
      // Request notification permissions (required for Android 13+)
      final NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM: User granted notification permission');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ FCM: User granted provisional notification permission');
      } else {
        debugPrint('❌ FCM: User declined or has not accepted notification permission');
        return;
      }

      // Get FCM Token
      await _getFCMToken();

      // Handle foreground messages (when app is open)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background messages (when app is in background and user taps notification)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // Handle initial message (when app was terminated and opened from notification)
      _handleInitialMessage();

      // Handle token refresh
      _messaging.onTokenRefresh.listen((String newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
      });

      debugPrint('✅ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ FCM Service initialization error: $e');
    }
  }

  /// Get FCM Token and print it to console
  /// This token is needed to send notifications to this specific device
  static Future<String?> _getFCMToken() async {
    try {
      final String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');
        debugPrint('💡 Copy this token to send notifications to this device');
        return token;
      } else {
        debugPrint('⚠️ FCM: Token is null');
        return null;
      }
    } catch (e) {
      debugPrint('❌ FCM: Error getting token: $e');
      return null;
    }
  }

  /// Get FCM Token (public method for external use)
  static Future<String?> getToken() async {
    return _getFCMToken();
  }

  /// Handle foreground messages (when app is open)
  /// This is called when a notification arrives while the app is in the foreground
  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 FCM Foreground Message received:');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // You can show a custom in-app notification here
    // For now, we just log it. You can use flutter_local_notifications
    // to show a custom notification even when app is in foreground
  }

  /// Handle background messages (when app is in background and user taps notification)
  /// This is called when user taps a notification while app is in background
  static void _handleBackgroundMessage(RemoteMessage message) {
    debugPrint('📨 FCM Background Message opened:');
    debugPrint('   Title: ${message.notification?.title}');
    debugPrint('   Body: ${message.notification?.body}');
    debugPrint('   Data: ${message.data}');

    // Handle navigation or other actions based on message data
    // Example: Navigate to a specific screen based on message.data['route']
  }

  /// Handle initial message (when app was terminated and opened from notification)
  /// Check if app was opened from a notification when it was completely closed
  static Future<void> _handleInitialMessage() async {
    final RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    
    if (initialMessage != null) {
      debugPrint('📨 FCM Initial Message (app opened from terminated state):');
      debugPrint('   Title: ${initialMessage.notification?.title}');
      debugPrint('   Body: ${initialMessage.notification?.body}');
      debugPrint('   Data: ${initialMessage.data}');

      // Handle navigation or other actions
      // Note: This needs to be handled in main.dart where BuildContext is available
    }
  }

  /// Subscribe to a topic
  /// Topics allow you to send notifications to multiple devices subscribed to the same topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('✅ FCM: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ FCM: Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('✅ FCM: Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ FCM: Error unsubscribing from topic $topic: $e');
    }
  }
}


