import 'package:firebase_messaging/firebase_messaging.dart';

/// Background message handler
/// This is a top-level function that must be registered in main.dart
/// It handles notifications when the app is in the background (not terminated)
/// 
/// Note: This function must be a top-level or static function
/// It cannot be an instance method or use BuildContext
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This function runs when app is in background and a notification arrives
  // It must be a top-level function (not a class method)
  
  print('📨 FCM Background Handler: Notification received');
  print('   Title: ${message.notification?.title}');
  print('   Body: ${message.notification?.body}');
  print('   Data: ${message.data}');
  
  // You can perform background tasks here
  // For example: update local database, cache data, etc.
  // Note: You cannot show UI or use BuildContext here
}


