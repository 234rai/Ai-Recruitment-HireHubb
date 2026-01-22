import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMSenderService {
  // ✅ YOUR CLOUDFLARE WORKER URL
  static const String _workerUrl = 'https://long-band-6217.fcm-notification-worker.workers.dev';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Send push notification with retry logic and stale token handling
  /// FIX #1 & #2 by Antigravity: Added retry and invalid token detection
  static Future<void> sendPushNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    int maxRetries = 3,
  }) async {
    // 🚀 FIX: Fetch FCM token client-side to ensure robustness
    String? recipientToken;
    try {
      final userDoc = await _firestore.collection('users').doc(recipientId).get();
      recipientToken = userDoc.data()?['fcmToken'];
      
      if (recipientToken == null) {
        print('⚠️ No FCM token found for user $recipientId. Notification might fail.');
      } else {
        print('✅ Found FCM token for user $recipientId');
      }
    } catch (e) {
      print('⚠️ Error fetching FCM token for $recipientId: $e');
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('📤 Sending push notification to $recipientId (attempt $attempt/$maxRetries)');

        // Send via Cloudflare Worker
        final response = await http.post(
          Uri.parse(_workerUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'recipientId': recipientId,
            'token': recipientToken, // 🚀 PASS TOKEN EXPLICITLY
            'title': title,
            'body': body,
            'data': data ?? {},
          }),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw Exception('Request timeout');
          },
        );

        if (response.statusCode == 200) {
          print('✅ Push notification sent successfully');
          
          // FIX #1: Check for invalid token errors in response
          try {
            final responseData = jsonDecode(response.body);
            final errorMessage = responseData['error']?.toString().toLowerCase() ?? '';
            
            // Check for FCM token invalidation errors
            if (errorMessage.contains('notregistered') ||
                errorMessage.contains('invalidregistration') ||
                errorMessage.contains('unregistered') ||
                errorMessage.contains('invalid-argument')) {
              print('⚠️ FCM token is invalid/stale for user $recipientId');
              await _removeStaleToken(recipientId);
            }
          } catch (parseError) {
            // Response might not be JSON, that's okay
            print('Response: ${response.body}');
          }
          return; // Success, exit retry loop
        } else if (response.statusCode == 404 || response.statusCode == 400) {
          // User not found or invalid request - don't retry
          print('❌ Push notification failed: ${response.statusCode}');
          print('Error: ${response.body}');
          
          // Check if token-related error
          if (response.body.contains('token') || response.body.contains('not found')) {
            await _removeStaleToken(recipientId);
          }
          return; // Don't retry for client errors
        } else {
          // Server error - retry
          print('⚠️ Push notification attempt $attempt failed: ${response.statusCode}');
          if (attempt == maxRetries) {
            print('❌ Push notification failed after $maxRetries attempts');
            print('Final error: ${response.body}');
          }
        }
      } catch (e) {
        print('⚠️ Push notification attempt $attempt error: $e');
        if (attempt == maxRetries) {
          print('❌ Push notification failed after $maxRetries attempts: $e');
          return;
        }
      }
      
      // FIX #2: Exponential backoff before retry
      if (attempt < maxRetries) {
        final delaySeconds = attempt * 2; // 2s, 4s, 6s
        print('⏳ Retrying in $delaySeconds seconds...');
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  /// FIX #1: Remove stale FCM token from Firestore
  /// When FCM returns NotRegistered/InvalidRegistration, the token is no longer valid
  static Future<void> _removeStaleToken(String userId) async {
    try {
      print('🗑️ Removing stale FCM token for user $userId');
      
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenStaleAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Stale token removed, user will get new token on next login');
    } catch (e) {
      print('⚠️ Error removing stale token: $e');
    }
  }
}