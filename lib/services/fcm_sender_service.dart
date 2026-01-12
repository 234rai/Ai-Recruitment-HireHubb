import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FCMSenderService {
  // ✅ YOUR CLOUDFLARE WORKER URL
  static const String _workerUrl = 'https://long-band-6217.fcm-notification-worker.workers.dev';

  static Future<void> sendPushNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📤 Sending push notification to $recipientId');

      // Send via Cloudflare Worker
      final response = await http.post(
        Uri.parse(_workerUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'recipientId': recipientId,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Push notification sent successfully');
        print('Response: ${response.body}');
      } else {
        print('❌ Push notification failed: ${response.statusCode}');
        print('Error: ${response.body}');
      }
    } catch (e) {
      print('❌ FCM sender error: $e');
    }
  }
}