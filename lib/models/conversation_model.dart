import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

class ConversationModel {
  final String id;
  final List<String> participants;
  final String jobId;
  final String jobTitle;
  final String applicationId;
  final DateTime createdAt;
  final DateTime lastMessageAt;
  final MessageModel? lastMessage;
  final bool hasUnread;
  final String? lastMessagePreview;

  ConversationModel({
    required this.id,
    required this.participants,
    required this.jobId,
    required this.jobTitle,
    required this.applicationId,
    required this.createdAt,
    required this.lastMessageAt,
    this.lastMessage,
    required this.hasUnread,
    this.lastMessagePreview,
  });

  factory ConversationModel.fromMap(Map<String, dynamic> data, String id) {
    return ConversationModel(
      id: id,
      participants: List<String>.from(data['participants'] ?? []),
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      applicationId: data['applicationId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp).toDate(),
      lastMessage: data['lastMessage'] != null
          ? MessageModel.fromMap(
          Map<String, dynamic>.from(data['lastMessage']), '')
          : null,
      hasUnread: data['hasUnread'] ?? false,
      lastMessagePreview: data['lastMessagePreview'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'participants': participants,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'applicationId': applicationId,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'lastMessage': lastMessage?.toMap(),
      'hasUnread': hasUnread,
      'lastMessagePreview': lastMessagePreview,
    };
  }

  // Helper method to get the other participant ID
  String getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
          (id) => id != currentUserId,
      orElse: () => '',
    );
  }
}