// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For jsonDecode
import 'package:major_project/main.dart'; // For navigatorKey
import 'package:major_project/navigation/messaging/chat_screen.dart'; // NEW
import 'package:major_project/navigation/application_screen.dart'; // NEW

// CRITICAL: Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.messageId}');

  // Show notification even when app is killed
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'job_alerts_channel',
    'Job Alerts',
    channelDescription: 'Notifications for job updates and alerts',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
    color: Color(0xFFFF2D55),
  );

  const NotificationDetails details = NotificationDetails(android: androidDetails);

  await notifications.show(
    message.hashCode,
    message.notification?.title ?? 'New Message',
    message.notification?.body ?? 'You have a new notification',
    details,
  );
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    print('🔔 Initializing Notification Service...');

    // STEP 1: Request notification permissions (Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('📋 Permission status: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted notification permission');
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      print('⚠️ User granted provisional permission');
    } else {
      print('❌ User declined notification permission');
      return; // Don't proceed if permission denied
    }

    // STEP 2: Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // STEP 3: Initialize local notifications
    await _initializeLocalNotifications();

    // STEP 4: Create notification channel (Android)
    await _createNotificationChannel();

    // STEP 5: Get and save FCM token
    await _setupFCMToken();

    // STEP 6: Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // STEP 7: Handle notification tap (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // STEP 8: Check if app was opened from a terminated state
    RemoteMessage? initialMessage =
    await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🚀 App opened from terminated state via notification');
      _handleNotificationTap(initialMessage);
    }

    print('✅ Notification Service initialized successfully');
  }

  // Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('✅ Local notifications initialized');
  }

  // Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'job_alerts_channel', // ID
      'Job Alerts', // Name
      description: 'Notifications for job updates and alerts',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ Notification channel created');
  }

  // Setup FCM token and handle refresh
  Future<void> _setupFCMToken() async {
    try {
      print('🔑 Requesting FCM token...');

      String? token = await _firebaseMessaging.getToken();

      if (token != null) {
        print('📱 FCM Token: $token');
        print('🔄 Now saving to Firestore...');
        await _saveTokenToFirestore(token);
      }

      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (e, stackTrace) {
      print('❌ Error in _setupFCMToken: $e');
      print('Stack: $stackTrace');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      print('💾 [SAVING TOKEN] Starting...');

      final user = _auth.currentUser;

      if (user == null) {
        print('❌ [SAVING TOKEN] No user logged in!');
        await Future.delayed(Duration(seconds: 2));
        final retryUser = _auth.currentUser;
        if (retryUser == null) {
          print('❌ [SAVING TOKEN] Still no user after retry');
          return;
        }
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      print('💾 [SAVING TOKEN] User ID: $userId');
      print('💾 [SAVING TOKEN] Token: ${token.substring(0, 30)}...');

      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': 'android',
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ [SAVING TOKEN] FCM token saved successfully!');

      // Verify
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists && doc.data()?['fcmToken'] == token) {
        print('✅ [VERIFICATION] Token verified in Firestore!');
      }

    } catch (e, stackTrace) {
      print('❌ [SAVING TOKEN] Error: $e');
      print('❌ Stack: $stackTrace');
    }
  }

  // Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 Foreground message received');
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Data: ${message.data}');

    // Show local notification
    await _showLocalNotification(message);

    // ✅ Notification already saved by NotificationHelper when triggered
    // No need to save again here
  }

  // Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('👆 Notification tapped');
    print('Data: ${message.data}');

    _navigateBasedOnPayload(message.data);
  }

  // Helper method to handle navigation based on payload
  void _navigateBasedOnPayload(Map<String, dynamic> data) {
    try {
      final type = data['type'] as String?;
       
      print('🔍 Navigating for type: $type');

      switch (type) {
        case 'message':
        case 'conversation': // Handle both types
          final conversationId = data['conversationId'] as String?;
          final senderId = data['senderId'] as String?;
          final senderName = data['senderName'] as String?;
          
          if (conversationId != null && senderId != null) {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  conversationId: conversationId,
                  otherParticipantId: senderId,
                  jobTitle: 'Message', // Default title
                  otherParticipantName: senderName,
                ),
              ),
            );
          } else {
            // Fallback
            navigatorKey.currentState?.pushNamed('/main');
          }
          break;

        case 'new_application':
        case 'application_status':
        case 'interview_scheduled':
          // Navigate to main screen (applications tab handling would be ideal primarily)
          navigatorKey.currentState?.pushNamed('/main');
          break;
          
        default:
          navigatorKey.currentState?.pushNamed('/main');
      }
    } catch (e) {
      print('❌ Error navigating from notification: $e');
      navigatorKey.currentState?.pushNamed('/main');
    }
  }

  // Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Local notification tapped');
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      navigatorKey.currentState?.pushNamed('/main');
      return;
    }

    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      _navigateBasedOnPayload(data);
    } catch (e) {
      print('❌ Error handling notification tap: $e');
      navigatorKey.currentState?.pushNamed('/main');
    }
  }

  // Show local notification - FIXED VERSION
  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Use non-const constructor for AndroidNotificationDetails
    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'job_alerts_channel',
      'Job Alerts',
      channelDescription: 'Notifications for job updates and alerts',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      color: const Color(0xFFFF2D55),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      message.hashCode, // Unique ID
      message.notification?.title ?? 'Job Update',
      message.notification?.body ?? 'You have a new notification',
      details,
      payload: jsonEncode(message.data), // ✅ Pass full data as JSON
    );

    print('✅ Local notification displayed');
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }

  // Listen to auth changes and save token when user logs in
  void setupAuthListener() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        print('🔐 User logged in, saving FCM token...');
        _firebaseMessaging.getToken().then((token) {
          if (token != null) {
            _saveTokenToFirestore(token);
          }
        });
      }
    });
  }
}