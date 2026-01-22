// lib/screens/chatbot_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import '../services/realtime_database_service.dart';
import '../utils/responsive_helper.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();

  // Replace with your ngrok URL
  static const String API_URL = 'https://katherina-homophonic-unmalignantly.ngrok-free.dev/chat';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserProfile();
    _addMessage(
      'Hello! I\'m HireHub AI Assistant. I can help you with:\n\n• Job search tips\n• Application guidance\n• Career advice\n• Account questions\n\nHow can I assist you today?',
      isUser: false,
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _databaseService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Widget _getProfileAvatar(double radius, ResponsiveHelper responsive) {
    final base64Image = _userProfile?['photoBase64']?.toString();

    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        final bytes = base64.decode(base64Image);
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        print('Error loading base64 image: $e');
      }
    }

    final user = _currentUser;
    if (user?.photoURL != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
        child: ClipOval(
          child: Image.network(
            user!.photoURL!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                color: const Color(0xFFFF2D55),
                size: radius,
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
      child: Icon(
        Icons.person,
        color: const Color(0xFFFF2D55),
        size: radius,
      ),
    );
  }

  void _addMessage(String text, {required bool isUser}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();
    _addMessage(userMessage, isUser: true);

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(API_URL),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'message': userMessage}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final botResponse = data['reply'] ?? 'Sorry, I couldn\'t understand that.'; // ✅ Changed from 'response' to 'reply'
        _addMessage(botResponse, isUser: false);
      } else {
        _addMessage('Error: Unable to get response. Please try again.', isUser: false);
      }
    } catch (e) {
      _addMessage('Error: Connection failed. Please check your internet.', isUser: false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: responsive.width(36),
              height: responsive.width(36),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2D55), Color(0xFFFF6B9D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(responsive.radius(10)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withOpacity(0.3),
                    blurRadius: responsive.radius(8),
                    offset: Offset(0, responsive.height(2)),
                  ),
                ],
              ),
              child: Icon(Icons.smart_toy, color: Colors.white, size: responsive.iconSize(18)),
            ),
            SizedBox(width: responsive.width(12)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HireHub AI',
                  style: TextStyle(
                    fontSize: responsive.fontSize(18),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Your career assistant',
                  style: TextStyle(
                    fontSize: responsive.fontSize(12),
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF2D55),
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(responsive.radius(16)),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(responsive.padding(16)),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(
                  message: _messages[index],
                  isDarkMode: isDarkMode,
                  userAvatar: _getProfileAvatar(responsive.width(18), responsive),
                  responsive: responsive,
                );
              },
            ),
          ),
          if (_isLoading)
            Container(
              padding: EdgeInsets.symmetric(vertical: responsive.padding(12)),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: responsive.width(20),
                    height: responsive.width(20),
                    child: CircularProgressIndicator(
                      strokeWidth: responsive.width(2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFFFF2D55),
                      ),
                    ),
                  ),
                  SizedBox(width: responsive.width(12)),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: responsive.fontSize(14),
                    ),
                  ),
                ],
              ),
            ),
          _buildInputArea(isDarkMode, responsive),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDarkMode, ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: responsive.radius(8),
            offset: Offset(0, -responsive.height(2)),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(responsive.radius(24)),
                  border: Border.all(
                    color: const Color(0xFFFF2D55).withOpacity(0.3),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontSize: responsive.fontSize(14),
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Ask about jobs, applications, or career advice...',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                      fontSize: responsive.fontSize(14),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: responsive.padding(20),
                      vertical: responsive.padding(14),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: responsive.width(12)),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2D55), Color(0xFFFF6B9D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(responsive.radius(24)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withOpacity(0.4),
                    blurRadius: responsive.radius(8),
                    offset: Offset(0, responsive.height(2)),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(responsive.radius(24)),
                  onTap: _isLoading ? null : _sendMessage,
                  child: Container(
                    padding: EdgeInsets.all(responsive.padding(14)),
                    child: Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: responsive.iconSize(22),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDarkMode;
  final Widget userAvatar;
  final ResponsiveHelper responsive;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isDarkMode,
    required this.userAvatar,
    required this.responsive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: responsive.padding(16)),
      child: Row(
        mainAxisAlignment:
        message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: responsive.width(36),
              height: responsive.width(36),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2D55), Color(0xFFFF6B9D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(responsive.radius(10)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2D55).withOpacity(0.3),
                    blurRadius: responsive.radius(6),
                    offset: Offset(0, responsive.height(2)),
                  ),
                ],
              ),
              child: Icon(Icons.smart_toy, color: Colors.white, size: responsive.iconSize(18)),
            ),
            SizedBox(width: responsive.width(8)),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: responsive.padding(16),
                    vertical: responsive.padding(12),
                  ),
                  decoration: BoxDecoration(
                    gradient: message.isUser
                        ? const LinearGradient(
                      colors: [Color(0xFFFF2D55), Color(0xFFFF6B9D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    color: message.isUser ? null : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(responsive.radius(18)).copyWith(
                      topLeft: message.isUser
                          ? Radius.circular(responsive.radius(18))
                          : Radius.circular(responsive.radius(6)),
                      topRight: message.isUser
                          ? Radius.circular(responsive.radius(6))
                          : Radius.circular(responsive.radius(18)),
                    ),
                    border: Border.all(
                      color: message.isUser
                          ? Colors.transparent
                          : const Color(0xFFFF2D55).withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: responsive.radius(4),
                        offset: Offset(0, responsive.height(2)),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
                      fontSize: responsive.fontSize(15),
                      height: 1.4,
                    ),
                  ),
                ),
                SizedBox(height: responsive.height(6)),
                Padding(
                  padding: EdgeInsets.only(
                    left: message.isUser ? 0 : responsive.padding(12),
                    right: message.isUser ? responsive.padding(12) : 0,
                  ),
                  child: Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                      fontSize: responsive.fontSize(11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: responsive.width(8)),
            // Use the actual user profile photo from profile
            userAvatar,
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
}