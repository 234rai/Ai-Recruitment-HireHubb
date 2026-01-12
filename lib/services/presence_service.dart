// lib/services/presence_service.dart
// Handles online/offline status and typing indicators using Firebase Realtime Database

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Typing debounce timer
  Timer? _typingTimer;
  String? _currentTypingConversation;

  // Initialize presence system
  Future<void> initialize() async {
    print('🟢 Initializing Presence Service...');
    
    // Listen to auth changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _setupPresence(user.uid);
      }
    });

    // If already logged in, setup presence
    if (_auth.currentUser != null) {
      _setupPresence(_auth.currentUser!.uid);
    }

    print('✅ Presence Service initialized');
  }

  // Setup presence for a user
  void _setupPresence(String userId) {
    final userPresenceRef = _database.ref('presence/$userId');
    final connectedRef = _database.ref('.info/connected');
    final typingRef = _database.ref('typing');
    userPresenceRef.onDisconnect().update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
    // Also remove any typing entries for this user
    typingRef.child(userId).onDisconnect().remove();
    // Listen to connection state
    connectedRef.onValue.listen((event) {
      final isConnected = event.snapshot.value as bool? ?? false;

      if (isConnected) {
        // User is online
        userPresenceRef.set({
          'online': true,
          'lastSeen': ServerValue.timestamp,
        });

        // When disconnected, update status
        userPresenceRef.onDisconnect().set({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });
  }

  // Set user as online
  Future<void> setOnline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _database.ref('presence/$userId').update({
      'online': true,
      'lastSeen': ServerValue.timestamp,
    });
  }

  // Set user as offline
  Future<void> setOffline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _database.ref('presence/$userId').update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
  }

  // Start typing in a conversation
  Future<void> setTyping(String conversationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Cancel previous timer
    _typingTimer?.cancel();
    _currentTypingConversation = conversationId;

    // Set typing to true
    await _database.ref('typing/$conversationId/$userId').set(true);

    // Auto-stop typing after 3 seconds of inactivity
    _typingTimer = Timer(const Duration(seconds: 3), () {
      stopTyping(conversationId);
    });
  }

  // Stop typing in a conversation
  Future<void> stopTyping(String conversationId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _typingTimer?.cancel();
    _currentTypingConversation = null;

    await _database.ref('typing/$conversationId/$userId').remove();
  }

  // Stop typing in current conversation (for cleanup)
  Future<void> stopCurrentTyping() async {
    if (_currentTypingConversation != null) {
      await stopTyping(_currentTypingConversation!);
    }
  }

  // Stream to listen for other user's typing status in a conversation
  Stream<bool> getTypingStream(String conversationId, String otherUserId) {
    return _database
        .ref('typing/$conversationId/$otherUserId')
        .onValue
        .map((event) => event.snapshot.value as bool? ?? false);
  }

  // Stream to listen for user's online status
  Stream<Map<String, dynamic>> getUserPresenceStream(String userId) {
    return _database.ref('presence/$userId').onValue.map((event) {
      if (event.snapshot.value == null) {
        return {'online': false, 'lastSeen': null};
      }
      
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return {
        'online': data['online'] ?? false,
        'lastSeen': data['lastSeen'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int)
            : null,
      };
    });
  }

  // Get last seen formatted string
  static String formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return 'Last seen ${difference.inDays}d ago';
    } else {
      return 'Offline';
    }
  }

  // Dispose resources
  void dispose() {
    _typingTimer?.cancel();
    stopCurrentTyping();
  }
}
