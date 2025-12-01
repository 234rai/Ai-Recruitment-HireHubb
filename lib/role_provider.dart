// lib/providers/role_provider.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart'; // ADD THIS IMPORT
import '../models/user_role.dart';
import '../services/user_service.dart';

class RoleProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppUser? _currentUser;
  bool _isLoading = true;
  String? _error;

  // Getters
  AppUser? get currentUser => _currentUser;
  UserRole? get userRole => _currentUser?.role;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Role checks
  bool get isRecruiter => _currentUser?.role.isRecruiter ?? false;
  bool get isJobSeeker => _currentUser?.role.isJobSeeker ?? true;
  bool get isAuthenticated => _currentUser != null;

  RoleProvider() {
    _initialize();
  }

  /// Initialize provider and listen to auth changes
  Future<void> _initialize() async {
    // Load initial user if exists
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      await _loadUser(currentFirebaseUser.uid);
    }

    // Listen for auth changes
    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        await _loadUser(firebaseUser.uid);
      } else {
        _clearUser();
      }
    });
  }

  /// Load user data from Firestore
  Future<void> _loadUser(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final appUser = await _userService.getAppUser(uid);

      if (appUser != null) {
        _currentUser = appUser;
        print('✅ User loaded: ${appUser.role.displayName}');
      } else {
        _error = 'User profile not found';
        print('⚠️ User profile not found for: $uid');
      }
    } catch (e) {
      _error = e.toString();
      print('❌ Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear user data on logout
  void _clearUser() {
    _currentUser = null;
    _isLoading = false;
    _error = null;
    _userService.clearCache();
    notifyListeners();
    print('🗑️ User cleared from provider');
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _loadUser(uid);
    }
  }

  /// Check if user needs to complete profile
  Future<bool> needsProfileCompletion() async {
    return !await _userService.hasCompletedProfile();
  }

  /// Get company name for recruiter
  Future<String?> getCompanyName() async {
    if (isRecruiter) {
      return await _userService.getRecruiterCompanyName();
    }
    return null;
  }

  /// Helper method to quickly check role in UI
  static RoleProvider of(BuildContext context, {bool listen = true}) {
    return Provider.of<RoleProvider>(context, listen: listen);
  }
}