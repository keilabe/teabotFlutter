import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('\n=== Initializing Notification Service ===');
    debugPrint('Timestamp: ${DateTime.now().toIso8601String()}');

    try {
      // Request permissions
      await _requestPermissions();
      
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();
      
      _isInitialized = true;
      debugPrint('Notification service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    debugPrint('Requesting notification permissions...');
    
    // Request notification permissions
    final notificationStatus = await Permission.notification.request();
    debugPrint('Notification permission status: $notificationStatus');
    
    // Request location permissions for regional alerts
    final locationStatus = await Permission.location.request();
    debugPrint('Location permission status: $locationStatus');
  }

  static Future<void> _initializeLocalNotifications() async {
    debugPrint('Initializing local notifications...');
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    debugPrint('Local notifications initialized');
  }

  static Future<void> _initializeFirebaseMessaging() async {
    debugPrint('Initializing Firebase messaging...');
    
    // Get FCM token
    final token = await _firebaseMessaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Subscribe to regional alerts topic
    await _firebaseMessaging.subscribeToTopic('regional_alerts');
    await _firebaseMessaging.subscribeToTopic('disease_outbreaks');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle notification taps when the app is opened from a terminated state
    // We now have to pass a function that takes a RemoteMessage object.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Message opened from a terminated state: ${message.data}');
      _handleNotificationTap(message.data);
    });
    
    debugPrint('Firebase messaging initialized');
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // We can't do anything with the UI here, but we can do some data processing.
    debugPrint('Handling a background message ${message.messageId}');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    // The payload from the local notification is a String, so we'll need to parse it back into a Map
    // This is a simple example, you may have a more complex payload.
    Map<String, dynamic> payloadMap = {};
    if (response.payload != null) {
      try {
        payloadMap = Map<String, dynamic>.from(
            Uri.splitQueryString(response.payload!));
      } catch (e) {
        debugPrint('Error parsing local notification payload: $e');
      }
    }
    _handleNotificationTap(payloadMap);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.notification?.title}');
    
    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'Regional Alert',
      body: message.notification?.body ?? 'New disease outbreak detected',
      payload: message.data.toString(),
    );
  }

  static void _handleNotificationTap(Map<String, dynamic> payload) {
    debugPrint('Notification tapped with payload: $payload');
    // Navigate to appropriate page based on payload
    // This will be handled by the main app navigation
    // The payload is now a Map, making it easier to handle structured data
    // Example: if (payload['type'] == 'outbreak_alert') { ... }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'regional_alerts',
      'Regional Alerts',
      channelDescription: 'Notifications for regional disease outbreaks and alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
    
    debugPrint('Local notification shown: $title');
  }

  // Show outbreak alert notification
  static Future<void> showOutbreakAlert({
    required String regionName,
    required String disease,
    required String severity,
    required List<String> recommendations,
  }) async {
    final title = '🚨 Disease Outbreak Alert';
    final body = '$disease detected in $regionName (${severity.toUpperCase()})';
    
    final payloadMap = {
      'type': 'outbreak_alert',
      'regionName': regionName,
      'disease': disease,
    };

    await _showLocalNotification(
      title: title,
      body: body,
      payload: Uri(queryParameters: payloadMap).toString(),
    );
  }

  // Show regional risk update notification
  static Future<void> showRiskUpdate({
    required String regionName,
    required double riskLevel,
    required int newCases,
  }) async {
    final riskText = _getRiskText(riskLevel);
    final title = '⚠️ Regional Risk Update';
    final body = '$regionName: $riskText risk level ($newCases new cases)';
    
    final payloadMap = {
      'type': 'risk_update',
      'regionName': regionName,
    };

    await _showLocalNotification(
      title: title,
      body: body,
      payload: Uri(queryParameters: payloadMap).toString(),
    );
  }

  // Show farmer activity notification
  static Future<void> showFarmerActivity({
    required String regionName,
    required int activeFarmers,
    required int totalReports,
  }) async {
    final title = '👨‍🌾 Farmer Activity Update';
    final body = '$regionName: $activeFarmers active farmers, $totalReports reports this week';
    
    final payloadMap = {
      'type': 'farmer_activity',
      'regionName': regionName,
    };

    await _showLocalNotification(
      title: title,
      body: body,
      payload: Uri(queryParameters: payloadMap).toString(),
    );
  }

  static String _getRiskText(double riskLevel) {
    if (riskLevel >= 0.8) return 'Critical';
    if (riskLevel >= 0.6) return 'High';
    if (riskLevel >= 0.4) return 'Moderate';
    return 'Low';
  }

  // Subscribe to region-specific topics
  static Future<void> subscribeToRegion(String regionId) async {
    try {
      await _firebaseMessaging.subscribeToTopic('region_$regionId');
      debugPrint('Subscribed to region: $regionId');
    } catch (e) {
      debugPrint('Error subscribing to region $regionId: $e');
    }
  }

  // Unsubscribe from region-specific topics
  static Future<void> unsubscribeFromRegion(String regionId) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('region_$regionId');
      debugPrint('Unsubscribed from region: $regionId');
    } catch (e) {
      debugPrint('Error unsubscribing from region $regionId: $e');
    }
  }

  // Get current FCM token
  static Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  // Clear all notifications
  static Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
    debugPrint('All notifications cleared');
  }

  // Dispose resources
  static Future<void> dispose() async {
    debugPrint('Disposing notification service...');
    // Firebase messaging doesn't need explicit disposal
    _isInitialized = false;
    debugPrint('Notification service disposed');
  }
}
