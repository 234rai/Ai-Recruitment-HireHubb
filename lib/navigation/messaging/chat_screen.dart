import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/messaging_service.dart';
import '../../services/presence_service.dart';
import '../../services/user_service.dart'; // NEW
import '../../models/message_model.dart';
import '../../providers/role_provider.dart';
import '../../widgets/typing_indicator.dart';
import '../../widgets/online_status_badge.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherParticipantId;
  final String jobTitle;
  final String? otherParticipantName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherParticipantId,
    required this.jobTitle,
    this.otherParticipantName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final MessagingService _messagingService = MessagingService();
  final PresenceService _presenceService = PresenceService();
  final UserService _userService = UserService(); // NEW
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    _messagingService.markConversationAsRead(widget.conversationId);
    
    // Listen to text changes for typing indicator
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _presenceService.stopTyping(widget.conversationId);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty) {
      _presenceService.setTyping(widget.conversationId);
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _presenceService.stopTyping(widget.conversationId);

    _messagingService.sendMessage(
      conversationId: widget.conversationId,
      recipientId: widget.otherParticipantId,
      content: message,
    );

    _messageController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _auth.currentUser;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: FutureBuilder(
          future: _userService.getAppUser(widget.otherParticipantId),
          builder: (context, snapshot) {
            // Use fetched name or fallback to passed name
            final userName = snapshot.data?.displayName ?? widget.otherParticipantName ?? 'User';
            final userPhoto = snapshot.data?.photoURL;
            
            return Row(
              children: [
                AvatarWithStatus(
                  userId: widget.otherParticipantId,
                  imageUrl: userPhoto,
                  fallbackText: userName,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.jobTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Online Status Text
                          OnlineStatusWithText(
                            userId: widget.otherParticipantId,
                            textStyle: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _messagingService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading messages',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start the conversation',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to begin',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUser?.uid;

                    return _buildMessageBubble(message, isMe, isDarkMode);
                  },
                );
              },
            ),
          ),
          
          // NEW: Typing indicator
          StreamBuilder<bool>(
            stream: _presenceService.getTypingStream(
              widget.conversationId,
              widget.otherParticipantId,
            ),
            builder: (context, snapshot) {
              final isTyping = snapshot.data ?? false;
              if (!isTyping) return const SizedBox.shrink();
              
              return Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 16, bottom: 8),
                child: TypingIndicatorWithText(
                  userName: widget.otherParticipantName ?? 'User',
                ),
              );
            },
          ),
          
          // Message input
          _buildMessageInput(isDarkMode),
        ],
      ),
    );
  }

  // NEW: Extracted message bubble with read receipts
  Widget _buildMessageBubble(MessageModel message, bool isMe, bool isDarkMode) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFFFF2D55)
              : (isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade200),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12,
                  color: isMe ? Colors.white70 : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (!isMe) const SizedBox(height: 4),
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey.shade500,
                  ),
                ),
                // NEW: Read receipt icons (only for sent messages)
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildReadReceipt(message),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Read receipt indicator
  Widget _buildReadReceipt(MessageModel message) {
    if (message.isRead) {
      // Double check (read) - blue
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 14, color: Colors.lightBlueAccent),
        ],
      );
    } else {
      // Single check (sent/delivered) - white
      return const Icon(Icons.done, size: 14, color: Colors.white70);
    }
  }

  // Message input area
  Widget _buildMessageInput(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null, // Allow multi-line
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55),
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}