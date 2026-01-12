// lib/services/notification_helper.dart - NEW FILE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/notification_type.dart';
import 'fcm_sender_service.dart';

class NotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> sendNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? jobId,
    String? company,
    String? recipientType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final currentUser = _auth.currentUser;

      final notificationData = {
        'userId': userId,
        'recipientId': userId,
        'title': '${type.emoji} $title',
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type.value,
        'isRead': false,
        'jobId': jobId,
        'company': company,
        'recipientType': recipientType ?? 'general',
        'senderId': currentUser?.uid,
        'senderName': currentUser?.displayName ?? 'HireHubb',
        'data': additionalData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to Firestore
      await _firestore.collection('notifications').add(notificationData);

      // ✅ NEW: Send push notification via Cloudflare Worker
      await FCMSenderService.sendPushNotification(
        recipientId: userId,
        title: '${type.emoji} $title',
        body: body,
        data: additionalData,
      );

      print('✅ Notification sent: ${type.displayName} to $userId');
      return true;

    } catch (e) {
      print('❌ Notification error: $e');
      return false;
    }
  }

  /// Send application notification (when job seeker applies)
  static Future<void> sendApplicationNotification({
    required String recruiterId,
    required String applicantId,
    required String applicantName,
    required String jobTitle,
    required String company,
    required String jobId,
  }) async {
    // Notify recruiter about new application
    await sendNotification(
      userId: recruiterId,
      type: NotificationType.newApplication,  // ✅ Enum
      title: 'New Application', // ✅ Emoji auto-added
      body: '$applicantName applied for $jobTitle',
      jobId: jobId,
      company: company,
      recipientType: 'recruiter',
      additionalData: {
        'applicantId': applicantId,
        'applicantName': applicantName,
      },
    );
  }

  /// Send status update notification (when recruiter updates status)
  /// Send status update notification (when recruiter updates status)
  static Future<void> sendStatusUpdateNotification({
    required String applicantId,
    required String status,
    required String jobTitle,
    required String company,
    required String jobId,
  }) async {
    final (title, body) = _getStatusMessage(status, jobTitle, company);

    await sendNotification(
      userId: applicantId,
      type: NotificationType.applicationStatus,
      title: title,
      body: body,
      jobId: jobId,
      company: company,
      recipientType: 'job_seeker',
      additionalData: {'status': status},
    );
  }

// ✅ ADD THIS PRIVATE HELPER METHOD at the end of the class
  static (String, String) _getStatusMessage(String status, String jobTitle, String company) {
    switch (status) {
      case 'reviewing':
      case 'inProcess':
        return ('Application Under Review', 'Your application for $jobTitle at $company is being reviewed');
      case 'interview':
        return ('Interview Scheduled!', 'You have an interview for $jobTitle at $company');
      case 'completed':
        return ('Congratulations!', 'You\'ve been selected for $jobTitle at $company');
      case 'rejected':
        return ('Application Update', 'Thank you for applying to $jobTitle at $company');
      default:
        return ('Application Update', 'Your application for $jobTitle has been updated');
    }
  }

  /// Send message notification
  static Future<void> sendMessageNotification({
    required String recipientId,
    required String senderName,
    required String messagePreview, // ✅ This should be 'messagePreview' not 'message'
    required String conversationId,
    String? senderId,
  }) async {
    await sendNotification(
      userId: recipientId,
      type: NotificationType.messageReceived,
      title: 'New Message',
      body: '$senderName: $messagePreview',
      recipientType: 'general',
      additionalData: {
        'conversationId': conversationId,
        'senderId': senderId,
        'senderName': senderName,
      },
    );
  }

  /// Send interview notification (when recruiter schedules interview)
  static Future<void> sendInterviewNotification({
    required String applicantId,
    required String jobTitle,
    required String company,
    required DateTime interviewDate,
    required String interviewType,
    required String interviewLink,
    required String jobId,
  }) async {
    final formattedDate = DateFormat('MMMM dd, yyyy - hh:mm a').format(interviewDate);

    await sendNotification(
      userId: applicantId,
      type: NotificationType.interviewScheduled,
      title: 'Interview Scheduled!',
      body: 'You have a $interviewType interview for $jobTitle at $company on $formattedDate',
      jobId: jobId,
      company: company,
      recipientType: 'job_seeker',
      additionalData: {
        'interviewDate': interviewDate.toIso8601String(),
        'interviewType': interviewType,
        'interviewLink': interviewLink,
        'jobTitle': jobTitle,
      },
    );
  }
}