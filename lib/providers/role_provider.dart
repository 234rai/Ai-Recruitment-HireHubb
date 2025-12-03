// lib/providers/role_provider.dart - UPDATED WITH APP LIFECYCLE
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';
import '../services/user_service.dart';

class RoleProvider extends ChangeNotifier with WidgetsBindingObserver {
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppUser? _currentUser;
  bool _isLoading = true;
  String? _error;
  bool _isInitialized = false;

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
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 App Lifecycle State: $state');

    if (state == AppLifecycleState.resumed) {
      _handleAppResume();
    }
  }

  Future<void> _handleAppResume() async {
    print('🔄 App resumed, refreshing user data...');

    // CRITICAL FIX: Longer delay to ensure Firebase is ready
    await Future.delayed(const Duration(milliseconds: 800));

    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      print('🔄 User found after resume: ${currentFirebaseUser.uid}');

      // CRITICAL: Always force refresh from server on app resume
      await _loadUser(currentFirebaseUser.uid, forceRefresh: true);

      // Double-check the role was loaded
      if (_currentUser == null) {
        print('⚠️ User still null after load, retrying...');
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadUser(currentFirebaseUser.uid, forceRefresh: true);
      }

      print('✅ Resume complete - Role: ${_currentUser?.role.displayName}');
    } else {
      print('⚠️ No Firebase user found after resume');
      _clearUser();
    }
  }

  /// Initialize provider and listen to auth changes
  Future<void> _initialize() async {
    print('🎯 RoleProvider: Starting initialization...');

    // Wait a bit for Firebase to initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Load initial user if exists
    final currentFirebaseUser = _auth.currentUser;
    if (currentFirebaseUser != null) {
      print('🎯 RoleProvider: Found existing user: ${currentFirebaseUser.uid}');
      await _loadUser(currentFirebaseUser.uid, forceRefresh: true);
    } else {
      print('🎯 RoleProvider: No existing user found');
      _isLoading = false;
      notifyListeners();
    }

    // Listen for auth changes
    _auth.authStateChanges().listen((User? firebaseUser) async {
      print('🎯 RoleProvider: Auth state changed - User: ${firebaseUser?.uid}');
      if (firebaseUser != null) {
        await _loadUser(firebaseUser.uid, forceRefresh: true);
      } else {
        _clearUser();
      }
    });

    _isInitialized = true;
  }

  /// Load user data from Firestore
  Future<void> _loadUser(String uid, {bool forceRefresh = false}) async {
    try {
      print('🎯 RoleProvider: Loading user data for: $uid (force: $forceRefresh)');
      _isLoading = true;
      _error = null;
      notifyListeners();

      // CRITICAL FIX: Always clear cache on force refresh
      if (forceRefresh) {
        _userService.clearCache();
        print('🧹 Cache cleared for force refresh');

        // Add small delay after cache clear
        await Future.delayed(const Duration(milliseconds: 200));
      }

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

        // CRITICAL: Retry once if user not found
        print('🔄 Retrying user load...');
        await Future.delayed(const Duration(milliseconds: 500));
        final retryUser = await _userService.getAppUser(uid);

        if (retryUser != null) {
          _currentUser = retryUser;
          _error = null;
          print('✅ Retry successful - Role: ${retryUser.role.displayName}');
        } else {
          _currentUser = null;
          print('❌ Retry failed - user still not found');
        }
      }
    } catch (e) {
      _error = e.toString();
      print('❌ RoleProvider: Error loading user: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      print('🎯 RoleProvider: Loading complete. Role: ${_currentUser?.role.displayName}');
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
  Future<void> refreshUser({bool force = false}) async {
    print('🔄 RoleProvider: Manual refresh requested (force: $force)');
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _loadUser(uid, forceRefresh: force);
    } else {
      print('⚠️ RoleProvider: No user to refresh');
    }
  }

  /// Force refresh user data (bypass all caches)
  Future<void> forceRefresh() async {
    await refreshUser(force: true);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Helper to check if provider is still mounted (for async operations)
  bool get mounted => _isInitialized;
}