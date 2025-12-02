// lib/providers/role_provider.dart - UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    print('🎯 RoleProvider: Constructor called');
    _initialize();
  }

  /// Initialize provider and listen to auth changes
  Future<void> _initialize() async {
    print('🎯 RoleProvider: Starting initialization...');

    // Load initial user if exists
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      print('🎯 RoleProvider: Found existing user: ${currentFirebaseUser.uid}');
      await _loadUser(currentFirebaseUser.uid);
    } else {
      print('🎯 RoleProvider: No existing user found');
      _isLoading = false;
      notifyListeners();
    }

    // Listen for auth changes
    _auth.authStateChanges().listen((User? firebaseUser) async {
      print('🎯 RoleProvider: Auth state changed - User: ${firebaseUser?.uid}');
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
      print('🎯 RoleProvider: Loading user data for: $uid');
      _isLoading = true;
      _error = null;
      notifyListeners();

      final appUser = await _userService.getAppUser(uid);

      if (appUser != null) {
        _currentUser = appUser;
        print('✅ RoleProvider: User loaded successfully!');
        print('✅ Role: ${appUser.role.displayName}');
        print('✅ isRecruiter: ${appUser.role.isRecruiter}');
        print('✅ isJobSeeker: ${appUser.role.isJobSeeker}');
      } else {
        _error = 'User profile not found';
        print('⚠️ RoleProvider: User profile not found for: $uid');
      }
    } catch (e) {
      _error = e.toString();
      print('❌ RoleProvider: Error loading user: $e');
    } finally {
      _isLoading = false;
      print('🎯 RoleProvider: Loading complete. isLoading = false');
      notifyListeners();
    }
  }

  /// Clear user data on logout
  void _clearUser() {
    print('🗑️ RoleProvider: Clearing user data');
    _currentUser = null;
    _isLoading = false;
    _error = null;
    _userService.clearCache();
    notifyListeners();
  }

  /// Refresh user data - CRITICAL FOR AFTER LOGIN/SIGNUP
  Future<void> refreshUser() async {
    print('🔄 RoleProvider: Manual refresh requested');
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _loadUser(uid);
    } else {
      print('⚠️ RoleProvider: No user to refresh');
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
}