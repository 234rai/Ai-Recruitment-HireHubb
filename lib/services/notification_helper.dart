// lib/services/notification_helper.dart - NEW FILE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Add this import if not already present

class NotificationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> sendNotification({
    required String userId,
    required String type,
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
        'userId': userId, // ✅ RECIPIENT'S USER ID
        'recipientId': userId,
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'type': type,
        'isRead': false,
        'jobId': jobId,
        'company': company,
        'recipientType': recipientType ?? 'general',
        'senderId': currentUser?.uid,
        'senderName': currentUser?.displayName ?? 'HireHubb',
        'data': additionalData ?? {},
        'createdAt': FieldValue.serverTimestamp(),
      };

      // ✅ SAVE TO TOP-LEVEL COLLECTION
      await _firestore
          .collection('notifications')
          .add(notificationData);

      print('✅ Notification sent to user: $userId');
      return true;

    } catch (e) {
      print('❌ Error sending notification: $e');
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
      type: 'new_application',
      title: '👤 New Application',
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
  static Future<void> sendStatusUpdateNotification({
    required String applicantId,
    required String status,
    required String jobTitle,
    required String company,
    required String jobId,
  }) async {
    String title = '';
    String body = '';

    switch (status) {
      case 'reviewing':
      case 'inProcess':
        title = '👀 Application Under Review';
        body = 'Your application for $jobTitle at $company is being reviewed';
        break;
      case 'interview':
        title = '🎉 Interview Scheduled!';
        body = 'You have an interview for $jobTitle at $company';
        break;
      case 'completed':
        title = '🎊 Congratulations!';
        body = 'You\'ve been selected for $jobTitle at $company';
        break;
      case 'rejected':
        title = '📋 Application Update';
        body = 'Thank you for applying to $jobTitle at $company';
        break;
      default:
        title = '📋 Application Update';
        body = 'Your application for $jobTitle has been updated';
    }

    await sendNotification(
      userId: applicantId,
      type: 'application_status',
      title: title,
      body: body,
      jobId: jobId,
      company: company,
      recipientType: 'job_seeker',
      additionalData: {
        'status': status,
      },
    );
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
      type: 'message',
      title: '💬 New Message',
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
      type: 'interview_scheduled',
      title: '🎉 Interview Scheduled!',
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