// lib/models/notification_type.dart
enum NotificationType {
  // Job Seeker notifications
  applicationStatus('application_status', '📋'),
  jobMatch('job_match', '🎯'),
  interviewScheduled('interview_scheduled', '🎉'),
  messageReceived('message', '💬'),

  // Recruiter notifications
  newApplication('new_application', '👤'),
  candidateMessage('candidate_message', '💬'),
  interviewConfirmed('interview_confirmed', '✅'),

  // General
  systemAlert('system_alert', '🔔'),
  test('test', '🧪');

  final String value;
  final String emoji;
  const NotificationType(this.value, this.emoji);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
          (e) => e.value == value,
      orElse: () => NotificationType.systemAlert,
    );
  }

  String get displayName {
    switch (this) {
      case NotificationType.applicationStatus:
        return 'Application Update';
      case NotificationType.jobMatch:
        return 'Job Match';
      case NotificationType.interviewScheduled:
        return 'Interview Scheduled';
      case NotificationType.messageReceived:
        return 'New Message';
      case NotificationType.newApplication:
        return 'New Application';
      case NotificationType.candidateMessage:
        return 'Candidate Message';
      case NotificationType.interviewConfirmed:
        return 'Interview Confirmed';
      case NotificationType.systemAlert:
        return 'System Alert';
      case NotificationType.test:
        return 'Test Notification';
    }
  }
}