// lib/services/application_service.dart - UPDATED WITH NOTIFICATIONS
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_helper.dart'; // 🚀 IMPORT THIS
import 'messaging_service.dart';
import '../models/notification_type.dart';
// import 'interview_service.dart'; // ✅ REMOVE THIS IF NOT USED

class ApplicationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final MessagingService _messagingService = MessagingService(); // ADD THIS
  // final InterviewService _interviewService = InterviewService(); // ✅ REMOVE IF NOT USED

  // 🚀 UPDATED: Now takes recruiterId and sends notification
  Future<bool> applyForJob({
    required String jobId,
    required String jobTitle,
    required String company,
    required String recruiterId, // 🚀 NEW PARAMETER
    String companyLogo = '🏢',
    List<String>? interviewRounds,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      final userName = _auth.currentUser?.displayName ?? 'Anonymous';

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Check if already applied
      final existingApplication = await _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .where('jobId', isEqualTo: jobId)
          .get();

      if (existingApplication.docs.isNotEmpty) {
        return false; // Already applied
      }

      // Default interview rounds if not provided
      final rounds = interviewRounds ?? [
        'Application Review',
        'Technical Screening',
        'Technical Interview',
        'Final HR Round',
      ];

      // Create interview rounds
      final List<Map<String, dynamic>> roundsList = rounds.asMap().entries.map((entry) {
        return {
          'name': entry.value,
          'status': entry.key == 0 ? 'current' : 'upcoming',
          'date': entry.key == 0
              ? Timestamp.fromDate(DateTime.now().add(const Duration(days: 3)))
              : null,
        };
      }).toList();

      // Create application document
      final applicationData = {
        'userId': userId,
        'userName': userName, // 🚀 NEW
        'jobId': jobId,
        'jobTitle': jobTitle,
        'company': company,
        'companyLogo': companyLogo,
        'recruiterId': recruiterId, // 🚀 NEW - CRITICAL FOR NOTIFICATIONS
        'appliedDate': Timestamp.fromDate(DateTime.now()),
        'status': 'applied',
        'currentStage': rounds.first,
        'nextRound': rounds.length > 1 ? rounds[1] : 'None',
        'rounds': roundsList,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ✅ FIXED: Save application and get the document reference
      final applicationDocRef = await _firestore.collection('applications').add(applicationData);
      final applicationId = applicationDocRef.id;

      // Update job document to increment application count
      await _firestore.collection('jobs').doc(jobId).update({
        'applicationsCount': FieldValue.increment(1),
      });

      // ✅ FIXED: Create conversation after saving the application
      final conversationId = await _messagingService.getOrCreateConversation(
        jobSeekerId: userId,
        recruiterId: recruiterId,
        jobId: jobId,
        jobTitle: jobTitle,
        applicationId: applicationId, // ✅ NOW USING THE ACTUAL APPLICATION ID
      );

      print('✅ Conversation created: $conversationId');

      // 🚀 SEND NOTIFICATION TO RECRUITER
      await NotificationHelper.sendApplicationNotification(
        recruiterId: recruiterId,
        applicantId: userId,
        applicantName: userName,
        jobTitle: jobTitle,
        company: company,
        jobId: jobId,
      );

      print('✅ Application submitted and recruiter notified');
      return true;
    } catch (e) {
      print('Error applying for job: $e');
      return false;
    }
  }

  // 🚀 UPDATED: Now sends notification when status changes
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    try {
      // Get application data first
      final appDoc = await _firestore.collection('applications').doc(applicationId).get();
      final appData = appDoc.data();

      if (appData == null) return;

      // Update status
      await _firestore.collection('applications').doc(applicationId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 🚀 SEND NOTIFICATION TO APPLICANT
      await NotificationHelper.sendStatusUpdateNotification(
        applicantId: appData['userId'],
        status: status,
        jobTitle: appData['jobTitle'],
        company: appData['company'],
        jobId: appData['jobId'],
      );

      print('✅ Status updated and applicant notified');
    } catch (e) {
      print('Error updating application status: $e');
    }
  }

  // Update interview round
  Future<void> updateInterviewRound({
    required String applicationId,
    required int roundIndex,
    required String status,
    DateTime? date,
  }) async {
    try {
      final doc = await _firestore.collection('applications').doc(applicationId).get();
      final data = doc.data();
      if (data != null) {
        final rounds = List<Map<String, dynamic>>.from(data['rounds'] ?? []);

        if (roundIndex < rounds.length) {
          rounds[roundIndex]['status'] = status;
          if (date != null) {
            rounds[roundIndex]['date'] = Timestamp.fromDate(date);
          }

          // Update current stage and next round
          String currentStage = data['currentStage'];
          String nextRound = 'None';

          // Find current round
          for (int i = 0; i < rounds.length; i++) {
            if (rounds[i]['status'] == 'current') {
              currentStage = rounds[i]['name'];
              if (i + 1 < rounds.length) {
                nextRound = rounds[i + 1]['name'];
              }
              break;
            }
          }

          await _firestore.collection('applications').doc(applicationId).update({
            'rounds': rounds,
            'currentStage': currentStage,
            'nextRound': nextRound,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error updating interview round: $e');
    }
  }

  // Move to next round
  Future<void> moveToNextRound(String applicationId) async {
    try {
      final doc = await _firestore.collection('applications').doc(applicationId).get();
      final data = doc.data();
      if (data != null) {
        final rounds = List<Map<String, dynamic>>.from(data['rounds'] ?? []);

        // Find current round and mark as completed
        int currentIndex = -1;
        for (int i = 0; i < rounds.length; i++) {
          if (rounds[i]['status'] == 'current') {
            currentIndex = i;
            rounds[i]['status'] = 'completed';
            break;
          }
        }

        // Set next round as current
        if (currentIndex != -1 && currentIndex + 1 < rounds.length) {
          rounds[currentIndex + 1]['status'] = 'current';
          rounds[currentIndex + 1]['date'] = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 5)),
          );

          String nextRound = 'None';
          if (currentIndex + 2 < rounds.length) {
            nextRound = rounds[currentIndex + 2]['name'];
          }

          await _firestore.collection('applications').doc(applicationId).update({
            'rounds': rounds,
            'currentStage': rounds[currentIndex + 1]['name'],
            'nextRound': nextRound,
            'status': 'inProcess',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 🚀 SEND NOTIFICATION TO APPLICANT
          await NotificationHelper.sendStatusUpdateNotification(
            applicantId: data['userId'],
            status: 'inProcess',
            jobTitle: data['jobTitle'],
            company: data['company'],
            jobId: data['jobId'],
          );

        } else {
          // All rounds completed
          await _firestore.collection('applications').doc(applicationId).update({
            'rounds': rounds,
            'status': 'completed',
            'nextRound': 'None',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // 🚀 SEND NOTIFICATION TO APPLICANT
          await NotificationHelper.sendStatusUpdateNotification(
            applicantId: data['userId'],
            status: 'completed',
            jobTitle: data['jobTitle'],
            company: data['company'],
            jobId: data['jobId'],
          );
        }
      }
    } catch (e) {
      print('Error moving to next round: $e');
    }
  }

  // Check if user has already applied to a job
  Future<bool> hasApplied(String jobId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final result = await _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      return result.docs.isNotEmpty;
    } catch (e) {
      print('Error checking application status: $e');
      return false;
    }
  }

  // Get application for a specific job
  Future<DocumentSnapshot?> getApplicationForJob(String jobId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final result = await _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) {
        return result.docs.first;
      }
      return null;
    } catch (e) {
      print('Error getting application: $e');
      return null;
    }
  }

  // Delete application
  Future<void> deleteApplication(String applicationId) async {
    try {
      await _firestore.collection('applications').doc(applicationId).delete();
    } catch (e) {
      print('Error deleting application: $e');
    }
  }

  // Stream of user applications
  Stream<QuerySnapshot> getUserApplications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('applications')
        .where('userId', isEqualTo: userId)
        .orderBy('appliedDate', descending: true)
        .snapshots();
  }

  // Get application statistics
  Future<Map<String, int>> getApplicationStats() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return {'applied': 0, 'inProcess': 0, 'completed': 0, 'rejected': 0};
      }

      final snapshot = await _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .get();

      int applied = 0, inProcess = 0, completed = 0, rejected = 0;

      for (var doc in snapshot.docs) {
        final status = doc['status'] as String?;
        switch (status) {
          case 'applied':
            applied++;
            break;
          case 'inProcess':
            inProcess++;
            break;
          case 'completed':
            completed++;
            break;
          case 'rejected':
            rejected++;
            break;
        }
      }

      return {
        'applied': applied,
        'inProcess': inProcess,
        'completed': completed,
        'rejected': rejected,
      };
    } catch (e) {
      print('Error getting application stats: $e');
      return {'applied': 0, 'inProcess': 0, 'completed': 0, 'rejected': 0};
    }
  }
}