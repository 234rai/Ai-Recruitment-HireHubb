import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message_model.dart';
import '../models/conversation_model.dart';
import 'notification_helper.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a text message
  Future<void> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String? jobId,
    String? applicationId,
    MessageType type = MessageType.text,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final messageId = _firestore.collection('messages').doc().id;
      final messageData = {
        'id': messageId,
        'conversationId': conversationId,
        'senderId': currentUser.uid,
        'recipientId': recipientId,
        'senderName': currentUser.displayName ?? 'User',
        'content': content,
        'type': type.toString().split('.').last,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'jobId': jobId,
        'applicationId': applicationId,
      };

      // Save message
      await _firestore.collection('messages').doc(messageId).set(messageData);

      // Update conversation with last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': messageData,
        'lastMessagePreview': content.length > 50
            ? '${content.substring(0, 50)}...'
            : content,
        'hasUnread': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ✅ FIXED: Use correct parameter name 'messagePreview' instead of 'message'
      // Send notification to recipient
      await NotificationHelper.sendMessageNotification(
        recipientId: recipientId,
        senderId: currentUser.uid,
        senderName: currentUser.displayName ?? 'User',
        messagePreview: content, // ✅ CHANGED FROM 'message' TO 'messagePreview'
        conversationId: conversationId,
      );

      print('✅ Message sent successfully');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // Get or create conversation between two users for a job application
  Future<String> getOrCreateConversation({
    required String jobSeekerId,
    required String recruiterId,
    required String jobId,
    required String jobTitle,
    required String applicationId,
  }) async {
    try {
      // Check if conversation already exists
      final query = await _firestore
          .collection('conversations')
          .where('participants', arrayContains: jobSeekerId)
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final conversation = query.docs.first;
        // Ensure both participants are in the conversation
        if (!conversation.data()['participants'].contains(recruiterId)) {
          await conversation.reference.update({
            'participants': FieldValue.arrayUnion([recruiterId]),
          });
        }
        return conversation.id;
      }

      // Create new conversation
      final conversationData = {
        'participants': [jobSeekerId, recruiterId],
        'jobId': jobId,
        'jobTitle': jobTitle,
        'applicationId': applicationId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'hasUnread': false,
        'lastMessagePreview': 'Conversation started',
      };

      final docRef = await _firestore.collection('conversations').add(conversationData);
      return docRef.id;
    } catch (e) {
      print('❌ Error creating conversation: $e');
      rethrow;
    }
  }

  // Get user's conversations
  Stream<List<ConversationModel>> getUserConversations() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Get messages for a conversation
  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .orderBy('timestamp', descending: false) // ✅ FIXED: Use 'descending' instead of 'ascending'
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
        .toList());
  }

  // Mark messages as read
  Future<void> markConversationAsRead(String conversationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Get unread messages in this conversation
      final query = await _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .where('recipientId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      // Batch update all unread messages
      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Update conversation's hasUnread flag
      batch.update(
        _firestore.collection('conversations').doc(conversationId),
        {'hasUnread': false},
      );

      await batch.commit();
    } catch (e) {
      print('❌ Error marking messages as read: $e');
    }
  }

  // Get unread conversation count
  Stream<int> getUnreadConversationCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .where('hasUnread', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}