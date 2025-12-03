import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/interview_model.dart';
import '../models/message_model.dart'; // ✅ ADD THIS IMPORT for MessageType
import 'notification_helper.dart';
import 'messaging_service.dart';

class InterviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessagingService _messagingService = MessagingService();

  // Schedule an interview
  Future<void> scheduleInterview({
    required String applicationId,
    required String jobId,
    required String jobTitle,
    required String applicantId,
    required String applicantName,
    required DateTime interviewDate,
    required String interviewType,
    required String interviewLink,
    required String notes,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get recruiter info
      final recruiterName = currentUser.displayName ?? 'Recruiter';

      // Create interview document
      final interviewId = _firestore.collection('interviews').doc().id;
      final interviewData = InterviewModel(
        id: interviewId,
        applicationId: applicationId,
        jobId: jobId,
        jobTitle: jobTitle,
        applicantId: applicantId,
        applicantName: applicantName,
        recruiterId: currentUser.uid,
        recruiterName: recruiterName,
        interviewDate: interviewDate,
        interviewType: interviewType,
        interviewLink: interviewLink,
        notes: notes,
        status: 'scheduled',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save interview
      await _firestore
          .collection('interviews')
          .doc(interviewId)
          .set(interviewData.toMap());

      // Update application status
      await _firestore
          .collection('applications')
          .doc(applicationId)
          .update({'status': 'interview_scheduled'});

      // Get or create conversation
      final conversationId = await _messagingService.getOrCreateConversation(
        jobSeekerId: applicantId,
        recruiterId: currentUser.uid,
        jobId: jobId,
        jobTitle: jobTitle,
        applicationId: applicationId,
      );

      // ✅ FIXED: Now MessageType is imported
      // Send interview invitation via message
      await _messagingService.sendMessage(
        conversationId: conversationId,
        recipientId: applicantId,
        content: '''
🎉 **Interview Scheduled!**

**Position:** $jobTitle
**Date:** ${DateFormat('MMMM dd, yyyy - hh:mm a').format(interviewDate)}
**Type:** ${interviewType.replaceAll('_', ' ').toTitleCase()}
**Link:** $interviewLink

**Notes:** $notes

Please confirm your availability.
''',
        jobId: jobId,
        applicationId: applicationId,
        type: MessageType.interview_invite,
      );

      // ✅ FIXED: Call the correct method - we'll create sendInterviewNotification
      // Send notification to applicant
      await NotificationHelper.sendInterviewNotification(
        applicantId: applicantId,
        jobTitle: jobTitle,
        company: recruiterName,
        interviewDate: interviewDate,
        interviewType: interviewType,
        interviewLink: interviewLink,
        jobId: jobId,
      );

      print('✅ Interview scheduled successfully');
    } catch (e) {
      print('❌ Error scheduling interview: $e');
      rethrow;
    }
  }

  // Get interviews for recruiter
  Stream<List<InterviewModel>> getRecruiterInterviews() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('interviews')
        .where('recruiterId', isEqualTo: userId)
        .orderBy('interviewDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => InterviewModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get interviews for job seeker
  Stream<List<InterviewModel>> getJobSeekerInterviews() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('interviews')
        .where('applicantId', isEqualTo: userId)
        .orderBy('interviewDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => InterviewModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Confirm interview (by job seeker)
  Future<void> confirmInterview(String interviewId) async {
    try {
      await _firestore.collection('interviews').doc(interviewId).update({
        'status': 'confirmed',
        'isConfirmed': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get interview details for notification
      final interviewDoc =
      await _firestore.collection('interviews').doc(interviewId).get();
      final interviewData = interviewDoc.data();
      if (interviewData != null) {
        await NotificationHelper.sendStatusUpdateNotification(
          applicantId: interviewData['recruiterId'],
          status: 'interview_confirmed',
          jobTitle: interviewData['jobTitle'],
          company: interviewData['applicantName'],
          jobId: interviewData['jobId'],
        );
      }
    } catch (e) {
      print('❌ Error confirming interview: $e');
    }
  }

  // Cancel interview
  Future<void> cancelInterview(String interviewId, String reason) async {
    try {
      await _firestore.collection('interviews').doc(interviewId).update({
        'status': 'cancelled',
        'notes': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error cancelling interview: $e');
    }
  }
}

extension StringExtension on String {
  String toTitleCase() {
    return split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}