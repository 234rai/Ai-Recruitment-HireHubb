// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_role.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for current user role with timestamp
  AppUser? _cachedUser;
  DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 10); // Cache for 10 minutes

  // ==================== USER ROLE OPERATIONS ====================

  /// Create user profile with role in Firestore
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required UserRole role,
    String? displayName,
    String? photoURL,
    String? companyName, // For recruiters
  }) async {
    try {
      final appUser = AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoURL: photoURL,
        role: role,
        createdAt: DateTime.now(),
      );

      // Base user data
      final userData = appUser.toMap();

      // Add company name for recruiters
      if (role.isRecruiter && companyName != null) {
        userData['companyName'] = companyName;
      }

      // Save to Firestore
      await _firestore.collection('users').doc(uid).set(userData);

      // Cache the user with timestamp
      _cachedUser = appUser;
      _cacheTimestamp = DateTime.now();

      print('✅ User profile created: ${role.displayName}');
    } catch (e) {
      print('❌ Error creating user profile: $e');
      rethrow;
    }
  }

  /// Get user role from Firestore with cache validation
  Future<UserRole?> getUserRole([String? userId]) async {
    try {
      final uid = userId ?? _auth.currentUser?.uid;
      if (uid == null) return null;

      // Check cache validity first
      if (_isCacheValid(uid)) {
        print('📦 Using cached user role');
        return _cachedUser!.role;
      }

      // Fetch from Firestore with server source to bypass local cache
      print('📡 Fetching fresh user role from server');
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(GetOptions(source: Source.server));

      if (!doc.exists) {
        print('⚠️ User document not found for: $uid');
        return null;
      }

      final role = UserRole.fromString(doc.data()?['role']);

      // Create a minimal AppUser for cache
      if (_cachedUser == null || _cachedUser!.uid != uid) {
        _cachedUser = AppUser(
          uid: uid,
          email: doc.data()?['email'] ?? '',
          displayName: doc.data()?['displayName'],
          photoURL: doc.data()?['photoURL'],
          role: role,
          createdAt: doc.data()?['createdAt'] != null
              ? DateTime.parse(doc.data()!['createdAt'])
              : DateTime.now(),
        );
      } else {
        _cachedUser = _cachedUser!.copyWith(role: role);
      }

      _cacheTimestamp = DateTime.now();
      return role;
    } catch (e) {
      print('❌ Error getting user role: $e');
      return null;
    }
  }

  /// Get full AppUser object with cache validation
  Future<AppUser?> getAppUser([String? userId]) async {
    try {
      final uid = userId ?? _auth.currentUser?.uid;
      if (uid == null) return null;

      // Check cache validity
      if (_isCacheValid(uid)) {
        print('📦 Using cached app user');
        return _cachedUser;
      }

      // Fetch from Firestore with server source
      print('📡 Fetching fresh app user from server');
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(GetOptions(source: Source.server));

      if (!doc.exists) {
        print('⚠️ User document not found for: $uid');
        return null;
      }

      final appUser = AppUser.fromMap(doc.data()!);

      // Update cache with timestamp
      _cachedUser = appUser;
      _cacheTimestamp = DateTime.now();

      return appUser;
    } catch (e) {
      print('❌ Error getting app user: $e');
      return null;
    }
  }

  /// Check if cache is still valid
  bool _isCacheValid(String uid) {
    if (_cachedUser == null || _cachedUser!.uid != uid) {
      return false;
    }

    if (_cacheTimestamp == null) {
      return false;
    }

    final age = DateTime.now().difference(_cacheTimestamp!);
    if (age > _cacheDuration) {
      print('⏰ Cache expired (${age.inMinutes}m old)');
      return false;
    }

    return true;
  }

  /// Check if current user is recruiter
  Future<bool> isRecruiter() async {
    final role = await getUserRole();
    return role?.isRecruiter ?? false;
  }

  /// Check if current user is job seeker
  Future<bool> isJobSeeker() async {
    final role = await getUserRole();
    return role?.isJobSeeker ?? true; // Default to job seeker
  }

  /// Get current user role synchronously from cache
  UserRole? get cachedUserRole => _cachedUser?.role;

  /// Check if user has completed profile setup
  Future<bool> hasCompletedProfile() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      print('❌ Error checking profile: $e');
      return false;
    }
  }

  /// Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) throw Exception('No user logged in');

      updates['updatedAt'] = DateTime.now().toIso8601String();

      await _firestore.collection('users').doc(uid).update(updates);

      // Clear cache to force refresh
      clearCache();

      print('✅ User profile updated');
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }

  /// Stream of user role changes
  Stream<UserRole?> userRoleStream([String? userId]) {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return UserRole.fromString(doc.data()?['role']);
    });
  }

  /// Stream of full AppUser changes
  Stream<AppUser?> appUserStream([String? userId]) {
    final uid = userId ?? _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final appUser = AppUser.fromMap(doc.data()!);
      _cachedUser = appUser; // Update cache
      _cacheTimestamp = DateTime.now();
      return appUser;
    });
  }

  /// Clear cached user (call on logout or when forcing refresh)
  void clearCache() {
    _cachedUser = null;
    _cacheTimestamp = null;
    print('🗑️ User cache cleared');
  }

  /// Force refresh user data (bypass cache)
  Future<AppUser?> forceRefreshUser([String? userId]) async {
    clearCache();
    return await getAppUser(userId);
  }

  /// Initialize user on app start
  Future<void> initializeUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        clearCache();
        return;
      }

      // Load user with cache validation
      await getAppUser(currentUser.uid);
      print('✅ User initialized: ${_cachedUser?.role.displayName}');
    } catch (e) {
      print('❌ Error initializing user: $e');
    }
  }

  // ==================== ROLE-SPECIFIC CHECKS ====================

  /// Get company name for recruiter
  Future<String?> getRecruiterCompanyName() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['companyName'];
    } catch (e) {
      print('❌ Error getting company name: $e');
      return null;
    }
  }

  /// Check if email already exists with different role
  Future<bool> emailExistsWithRole(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking email: $e');
      return false;
    }
  }

  /// Get user by email
  Future<AppUser?> getUserByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      return AppUser.fromMap(query.docs.first.data());
    } catch (e) {
      print('❌ Error getting user by email: $e');
      return null;
    }
  }
}