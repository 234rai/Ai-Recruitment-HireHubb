// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // For jsonDecode
import 'package:major_project/main.dart'; // For navigatorKey

// CRITICAL: Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
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
      // Get FCM token
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        print('📱 FCM Token: $token');
        await _saveTokenToFirestore(token);
      }

      // Listen for token refresh
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToFirestore);
    } catch (e) {
      print('❌ Error getting FCM token: $e');
    }
  }

  // Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
          'platform': 'android',
        }, SetOptions(merge: true));
        print('✅ FCM token saved to Firestore');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
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

    // Save to Firestore
    await _saveNotificationToFirestore(message);
  }

  // Handle notification tap
  Future<void> _handleNotificationTap(RemoteMessage message) async {
    print('👆 Notification tapped');
    print('Data: ${message.data}');

    // Save to Firestore if not already saved
    await _saveNotificationToFirestore(message);

    // TODO: Navigate to specific screen based on notification data
  }

  // Handle local notification tap
  // In notification_service.dart - REPLACE _onNotificationTapped method:
  void _onNotificationTapped(NotificationResponse response) {
    print('👆 Local notification tapped');
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      // No payload, just open notifications screen
      navigatorKey.currentState?.pushNamed('/main');
      return;
    }

    try {
      // Parse payload as JSON
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      final jobId = data['jobId'] as String?;

      print('🔍 Notification type: $type, jobId: $jobId');

      // Navigate based on type
      switch (type) {
        case 'new_application':
        // For recruiters - go to applications screen
          navigatorKey.currentState?.pushNamed('/main');
          break;

        case 'application_status':
        // For job seekers - go to applications screen
          navigatorKey.currentState?.pushNamed('/main');
          break;

        case 'message':
          final conversationId = data['conversationId'] as String?;
          if (conversationId != null) {
            // TODO: Navigate to chat screen when messaging is implemented
            navigatorKey.currentState?.pushNamed('/main');
          }
          break;

        default:
        // Default: go to main screen
          navigatorKey.currentState?.pushNamed('/main');
      }
    } catch (e) {
      print('❌ Error handling notification tap: $e');
      // Fallback: just open main screen
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
      payload: message.data['jobId']?.toString(),
    );

    print('✅ Local notification displayed');
  }

  // REPLACE THE ENTIRE _saveNotificationToFirestore METHOD WITH THIS:
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('⚠️ No user logged in, skipping Firestore save');
        return;
      }

      final notificationData = {
        'userId': user.uid,
        'recipientId': user.uid,
        'title': message.notification?.title ?? 'Job Update',
        'body': message.notification?.body ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'type': message.data['type'] ?? 'general',
        'isRead': false,
        'jobId': message.data['jobId'],
        'company': message.data['company'] ?? '',
        'recipientType': message.data['recipientType'] ?? 'general',
        'data': message.data,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ✅ SAVE TO TOP-LEVEL COLLECTION (not subcollection)
      await _firestore
          .collection('notifications')
          .add(notificationData);

      print('✅ Notification saved to Firestore (top-level)');
    } catch (e) {
      print('❌ Error saving notification to Firestore: $e');
    }
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
}