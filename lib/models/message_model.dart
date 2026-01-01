import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final DateTime? readAt; // NEW: When the message was read
  final String? jobId;
  final String? applicationId;
  final MessageType type;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    required this.isRead,
    this.readAt, // NEW
    this.jobId,
    this.applicationId,
    this.type = MessageType.text,
  });

  factory MessageModel.fromMap(Map<String, dynamic> data, String id) {
    return MessageModel(
      id: id,
      conversationId: data['conversationId'] ?? '',
      senderId: data['senderId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      content: data['content'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      readAt: data['readAt'] != null ? (data['readAt'] as Timestamp).toDate() : null, // NEW
      jobId: data['jobId'],
      applicationId: data['applicationId'],
      type: MessageType.values.firstWhere(
            (e) => e.toString().split('.').last == (data['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'recipientId': recipientId,
      'senderName': senderName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null, // NEW
      'jobId': jobId,
      'applicationId': applicationId,
      'type': type.toString().split('.').last,
    };
  }
}

enum MessageType {
  text,
  interview_invite,
  status_update,
  application_update,
  system,
}