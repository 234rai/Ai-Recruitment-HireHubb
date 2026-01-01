// lib/navigation/notification_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:major_project/providers/role_provider.dart';

// ✅ REMOVED unnecessary imports
// import 'package:major_project/services/notification_manager_service.dart';
// import 'package:major_project/services/notification_debug_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ FIXED: Updated to use top-level collection
  Stream<QuerySnapshot>? _getNotificationsStream() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ✅ NEW: Get unread notification count for badge
  Stream<int> _getUnreadCountStream(RoleProvider roleProvider) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
      // Filter by role client-side
      final relevantDocs = snapshot.docs.where((doc) {
        final notification = doc.data() as Map<String, dynamic>;
        return _isNotificationRelevantForRole(notification, roleProvider);
      });
      return relevantDocs.length;
    });
  }

  // ✅ FIXED: Updated role-based stream to use top-level collection
  Stream<QuerySnapshot>? _getRoleBasedNotificationsStream(RoleProvider roleProvider) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return null;
    }

    try {
      // ✅ SIMPLIFIED: Only filter by userId and orderBy timestamp
      // Role-based filtering done client-side (see _isNotificationRelevantForRole)
      return _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .snapshots();
    } catch (e) {
      print('Error creating notifications stream: $e');
      return null;
    }
  }

  // ✅ NEW: Client-side role filtering to avoid composite index requirement
  bool _isNotificationRelevantForRole(
      Map<String, dynamic> notification,
      RoleProvider roleProvider,
      ) {
    final recipientType = notification['recipientType'] as String?;

    if (recipientType == null || recipientType == 'general') {
      return true; // General notifications visible to all
    }

    if (roleProvider.isRecruiter) {
      return recipientType == 'recruiter';
    } else {
      return ['job_seeker', 'student', 'general'].contains(recipientType);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final roleProvider = Provider.of<RoleProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ROLE-BASED HEADER
              Row(
                children: [
                  Text(
                    roleProvider.isRecruiter ? 'Recruiter Notifications' : 'Notifications',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ✅ NEW: Unread count badge
                  StreamBuilder<int>(
                    stream: _getUnreadCountStream(roleProvider),
                    builder: (context, snapshot) {
                      final unreadCount = snapshot.data ?? 0;
                      if (unreadCount == 0) return const SizedBox.shrink();

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleProvider.isRecruiter ? Colors.green : const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                roleProvider.isRecruiter
                    ? 'Stay updated with applicant alerts and messages'
                    : 'Stay updated with job alerts and applications',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Notifications List - USE ROLE-BASED STREAM
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getRoleBasedNotificationsStream(roleProvider),
                  builder: (context, snapshot) {
                    // Handle no user case
                    if (_auth.currentUser == null) {
                      return _buildAuthRequiredState(isDarkMode);
                    }

                    // Handle stream null case
                    if (_getNotificationsStream() == null) {
                      return Center(
                        child: Text(
                          'Unable to load notifications',
                          style: TextStyle(
                            color: isDarkMode ? Colors.grey : Colors.black54,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      print('Notification stream error: ${snapshot.error}');
                      return _buildErrorState(snapshot.error.toString(), isDarkMode);
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(isDarkMode, roleProvider);
                    }

                    // ✅ Filter notifications client-side based on role
                    final allNotifications = snapshot.data!.docs;
                    final filteredNotifications = allNotifications.where((doc) {
                      final notification = doc.data() as Map<String, dynamic>;
                      return _isNotificationRelevantForRole(notification, roleProvider);
                    }).toList();

                    // Show empty state if no notifications after filtering
                    if (filteredNotifications.isEmpty) {
                      return _buildEmptyState(isDarkMode, roleProvider);
                    }

                    return ListView.builder(
                      itemCount: filteredNotifications.length,
                      itemBuilder: (context, index) {
                        final notification =
                        filteredNotifications[index].data() as Map<String, dynamic>;
                        final notificationId = filteredNotifications[index].id;

                        return _buildNotificationCard(
                          notification,
                          notificationId,
                          isDarkMode,
                          roleProvider,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              error.length > 100 ? '${error.substring(0, 100)}...' : error,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D55),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthRequiredState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: const Color(0xFFFF2D55).withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Authentication Required',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please log in to view your notifications',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      Map<String, dynamic> notification,
      String notificationId,
      bool isDarkMode,
      RoleProvider roleProvider,
      ) {
    final title = notification['title'] ?? 'Notification';
    final body = notification['body'] ?? '';

    // ROLE-BASED BODY MODIFICATION
    String displayBody = body;
    if (roleProvider.isRecruiter) {
      // For recruiters, emphasize applicant-related content
      if (body.toLowerCase().contains('applied') ||
          body.toLowerCase().contains('applicant') ||
          body.toLowerCase().contains('application')) {
        displayBody = "👤 $body";
      }
    } else {
      // For job seekers, emphasize job-related content
      if (body.toLowerCase().contains('job') ||
          body.toLowerCase().contains('interview') ||
          body.toLowerCase().contains('hired')) {
        displayBody = "💼 $body";
      }
    }

    // IMPROVED: Better timestamp handling
    DateTime timestamp;
    try {
      if (notification['timestamp'] == null) {
        timestamp = DateTime.now();
      } else if (notification['timestamp'] is Timestamp) {
        timestamp = (notification['timestamp'] as Timestamp).toDate();
      } else if (notification['timestamp'] is int) {
        timestamp = DateTime.fromMillisecondsSinceEpoch(notification['timestamp']);
      } else if (notification['timestamp'] is String) {
        timestamp = DateTime.parse(notification['timestamp']);
      } else {
        timestamp = DateTime.now();
      }
    } catch (e) {
      print('Error parsing timestamp: $e');
      timestamp = DateTime.now();
    }

    final type = notification['type'] ?? 'general';
    final isRead = notification['isRead'] ?? false;
    final jobId = notification['jobId'];
    final company = notification['company'] ?? '';
    final senderName = notification['senderName'] ?? '';

    // ROLE-BASED ACTION BUTTON TEXT
    String actionButtonText = 'View Details';
    if (roleProvider.isRecruiter) {
      if (type == 'new_application') {
        actionButtonText = 'Review Applicant';
      } else if (type == 'message') {
        actionButtonText = 'View Message';
      }
    } else {
      if (type == 'application_update') {
        actionButtonText = 'View Application';
      } else if (type == 'interview_scheduled') {
        actionButtonText = 'Schedule Interview';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: () => _markAsRead(notificationId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getNotificationColor(type, roleProvider).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getNotificationIcon(type, roleProvider),
                      color: _getNotificationColor(type, roleProvider),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ROLE-BASED TITLE WITH BADGE
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            if (roleProvider.isRecruiter && type == 'new_application')
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayBody,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            height: 1.4,
                          ),
                        ),
                        // ROLE-BASED SENDER INFO
                        if (senderName.isNotEmpty && roleProvider.isRecruiter) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 12,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'From: $senderName',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (company.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              company,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.grey.shade500
                                    : Colors.grey.shade500,
                              ),
                            ),
                            Row(
                              children: [
                                _buildUsefulButton(notificationId, true, isDarkMode),
                                const SizedBox(width: 8),
                                _buildUsefulButton(notificationId, false, isDarkMode),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: roleProvider.isRecruiter
                            ? Colors.green
                            : const Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              if (jobId != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _markAsRead(notificationId);
                      // TODO: Navigate to job/applicant details based on role
                      if (roleProvider.isRecruiter) {
                        print('Recruiter viewing applicant for job: $jobId');
                      } else {
                        print('Job seeker viewing job: $jobId');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: roleProvider.isRecruiter
                          ? Colors.green
                          : const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(actionButtonText),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsefulButton(String notificationId, bool isUseful, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _handleUsefulFeedback(notificationId, isUseful),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isUseful ? Icons.thumb_up_alt_outlined : Icons.thumb_down_alt_outlined,
              size: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Text(
              isUseful ? 'Yes' : 'No',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode, RoleProvider roleProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            roleProvider.isRecruiter ? Icons.people_outline : Icons.notifications_outlined,
            size: 80,
            color: const Color(0xFFFF2D55).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            roleProvider.isRecruiter ? 'No Applicant Notifications' : 'No Notifications Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              roleProvider.isRecruiter
                  ? 'When candidates apply to your jobs,\nyou\'ll see notifications here'
                  : 'Application updates, interview invites,\nand messages will appear here',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(String type, RoleProvider roleProvider) {
    if (roleProvider.isRecruiter) {
      switch (type) {
        case 'new_application':
          return Colors.green;
        case 'message':
          return Colors.blue;
        case 'interview_scheduled':
          return Colors.purple;
        default:
          return const Color(0xFFFF2D55);
      }
    } else {
      switch (type) {
        case 'application_update':
          return const Color(0xFFFF2D55);
        case 'job_match':
          return const Color(0xFF34C759);
        case 'interview_scheduled':
          return Colors.purple;
        case 'new_job':
          return const Color(0xFFFF9500);
        default:
          return const Color(0xFFFF2D55);
      }
    }
  }

  IconData _getNotificationIcon(String type, RoleProvider roleProvider) {
    if (roleProvider.isRecruiter) {
      switch (type) {
        case 'new_application':
          return Icons.person_add;
        case 'message':
          return Icons.message;
        case 'interview_scheduled':
          return Icons.calendar_today;
        default:
          return Icons.notifications_outlined;
      }
    } else {
      switch (type) {
        case 'application_update':
          return Icons.work_outline;
        case 'job_match':
          return Icons.auto_awesome_outlined;
        case 'interview_scheduled':
          return Icons.calendar_today;
        case 'new_job':
          return Icons.new_releases_outlined;
        default:
          return Icons.notifications_outlined;
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  // ✅ FIXED: Updated to use top-level collection
  void _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications') // Top-level collection
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  // ✅ NEW: Mark all notifications as read
  Future<void> _markAllAsRead(RoleProvider roleProvider) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      // Get all unread notifications
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      // Filter by role and update
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        final notification = doc.data() as Map<String, dynamic>;
        if (_isNotificationRelevantForRole(notification, roleProvider)) {
          batch.update(doc.reference, {'isRead': true});
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: Color(0xFF34C759),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  // ✅ FIXED: Updated to use top-level collection
  void _handleUsefulFeedback(String notificationId, bool isUseful) async {
    try {
      await _firestore
          .collection('notifications') // Top-level collection
          .doc(notificationId)
          .update({
        'feedback': isUseful ? 'useful' : 'not_useful',
        'feedbackTimestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your feedback!'),
            backgroundColor: Color(0xFF34C759),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving feedback: $e');
    }
  }
}