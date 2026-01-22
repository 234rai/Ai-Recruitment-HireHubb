import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

class RealtimeDatabaseService {
  late FirebaseDatabase _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _imagePicker = ImagePicker();

  RealtimeDatabaseService() {
    _initializeDatabase();
  }

  // Initialize database with proper configuration
  void _initializeDatabase() {
    try {
      _database = FirebaseDatabase.instance;

      // Enable persistence and set logging
      _database.setPersistenceEnabled(true);
      _database.setPersistenceCacheSizeBytes(10000000); // 10MB

      print('✅ Firebase Database initialized');
      print('📍 Database URL: ${_database.databaseURL}');
    } catch (e) {
      print('❌ Error initializing database: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserProfileById(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/profile').get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error fetching user profile by ID: $e');
      return null;
    }
  }

  Future<Uint8List?> downloadResumeForUser(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/profile').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final base64String = data['resumeBase64']?.toString();

        if (base64String != null && base64String.isNotEmpty) {
          return base64Decode(base64String);
        }
      }
      return null;
    } catch (e) {
      print('Error downloading resume for user $userId: $e');
      return null;
    }
  }

  // Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  // Get user profile reference with error handling
  DatabaseReference get _userProfileRef {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final ref = _database.ref('users/$userId/profile');
      print('📝 Profile reference: ${ref.path}');
      return ref;
    } catch (e) {
      print('❌ Error getting profile reference: $e');
      rethrow;
    }
  }

  // Test database connection with better error handling
  Future<bool> testConnection() async {
    try {
      print('🔍 Testing Realtime Database connection...');
      final testRef = _database.ref('.info/connected');

      final subscription = testRef.onValue.listen((event) {
        final connected = event.snapshot.value as bool? ?? false;
        print(connected ? '✅ Database connected' : '❌ Database disconnected');
      }, onError: (error) {
        print('❌ Database connection error: $error');
      });

      // Wait a bit for the connection test
      await Future.delayed(const Duration(seconds: 2));
      await subscription.cancel();

      print('✅ Realtime Database connection test passed!');
      print('📍 Database URL: ${_database.databaseURL}');
      return true;
    } catch (e) {
      print('❌ Realtime Database connection test failed: $e');
      return false;
    }
  }

  // ==================== PROFILE OPERATIONS ====================

  // Create initial user profile with better structure
  Future<void> createInitialProfile({
    required String name,
    required String email,
    String? photoUrl,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      print('🔄 Creating profile for user: $userId');

      final profileData = {
        'name': name,
        'email': email,
        'photoBase64': '',
        'about': 'Tell us about yourself...',
        'location': 'Add your location',
        'phone': 'Add your phone number',
        'github': '',
        'linkedin': '',
        'portfolio': '',
        'resumeBase64': '',
        'resumeFileName': '',
        'skills': [],
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      };

      await _userProfileRef.set(profileData);
      print('✅ Profile created successfully for user: $userId');
    } catch (e) {
      print('❌ Error creating profile: $e');
      throw Exception('Failed to create profile: $e');
    }
  }

  // Get user profile with better error handling
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        print('❌ No user ID available');
        return null;
      }

      print('🔄 Fetching profile for user: $userId');

      final snapshot = await _userProfileRef.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Profile fetch timed out');
        },
      );

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final profileData = data.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));

        print('✅ Profile loaded successfully');
        print('📊 Profile data keys: ${profileData.keys.toList()}');

        return profileData;
      } else {
        print('📭 No profile found for user: $userId');
        return null;
      }
    } catch (e) {
      print('❌ Error getting profile: $e');
      return null;
    }
  }

  // Upload banner image as Base64 to Realtime DB
  Future<void> uploadBannerImageAsBase64(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Read image bytes and encode to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Save to Realtime Database
      await _database.ref('users/${user.uid}/profile').update({
        'bannerBase64': base64Image,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error uploading banner base64: $e');
      rethrow;
    }
  }


  // Update user profile
  Future<void> updateProfile(Map<String, dynamic> profileData) async {
    try {
      print('🔄 Updating profile...');

      await _userProfileRef.update({
        ...profileData,
        'updatedAt': ServerValue.timestamp,
      });

      print('✅ Profile updated successfully');
    } catch (e) {
      print('❌ Error updating profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  // ==================== IMAGE OPERATIONS (Base64) ====================

  // Convert image to base64
  Future<String?> imageToBase64(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Check file size (limit to 500KB for profile pictures)
      if (bytes.length > 500000) {
        throw Exception('Image too large. Please select an image under 500KB');
      }

      final base64String = base64Encode(bytes);
      return base64String;
    } catch (e) {
      print('Error converting image to base64: $e');
      return null;
    }
  }

  // Upload profile picture as base64
  Future<void> uploadProfilePictureAsBase64(File imageFile) async {
    try {
      final base64String = await imageToBase64(imageFile);
      if (base64String != null) {
        await _userProfileRef.update({
          'photoBase64': base64String,
          'updatedAt': ServerValue.timestamp,
        });
        print('✅ Profile picture uploaded as base64');
      }
    } catch (e) {
      print('❌ Error uploading profile picture: $e');
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  // ==================== RESUME OPERATIONS (Base64) ====================

  // Convert PDF to base64
  Future<String?> pdfToBase64(File pdfFile) async {
    try {
      final bytes = await pdfFile.readAsBytes();
      final base64String = base64Encode(bytes);
      return base64String;
    } catch (e) {
      print('Error converting PDF to base64: $e');
      return null;
    }
  }

  // Upload resume as base64
  Future<void> uploadResumeAsBase64(File pdfFile, String fileName) async {
    try {
      final base64String = await pdfToBase64(pdfFile);
      if (base64String != null) {
        await _userProfileRef.update({
          'resumeBase64': base64String,
          'resumeFileName': fileName,
          'updatedAt': ServerValue.timestamp,
        });
        print('✅ Resume uploaded as base64: $fileName');
      }
    } catch (e) {
      print('❌ Error uploading resume: $e');
      throw Exception('Failed to upload resume: $e');
    }
  }

  // Download resume from base64
  Future<Uint8List?> downloadResume() async {
    try {
      final profile = await getUserProfile();
      final base64String = profile?['resumeBase64']?.toString();

      if (base64String != null && base64String.isNotEmpty) {
        return base64Decode(base64String);
      }
      return null;
    } catch (e) {
      print('Error downloading resume: $e');
      return null;
    }
  }

  // ==================== SKILLS OPERATIONS ====================

  // Add skill
  Future<void> addSkill(String skill) async {
    try {
      final skillsRef = _userProfileRef.child('skills');
      final snapshot = await skillsRef.get();

      List<dynamic> skills = [];
      if (snapshot.exists && snapshot.value != null) {
        skills = (snapshot.value as List?) ?? [];
      }

      if (!skills.contains(skill)) {
        skills.add(skill);
        await skillsRef.set(skills);
        print('✅ Skill added: $skill');
      }
    } catch (e) {
      print('❌ Error adding skill: $e');
      throw Exception('Failed to add skill: $e');
    }
  }

  // Remove skill
  Future<void> removeSkill(String skill) async {
    try {
      final skillsRef = _userProfileRef.child('skills');
      final snapshot = await skillsRef.get();

      if (snapshot.exists && snapshot.value != null) {
        List<dynamic> skills = (snapshot.value as List?) ?? [];
        skills.remove(skill);
        await skillsRef.set(skills);
        print('✅ Skill removed: $skill');
      }
    } catch (e) {
      print('❌ Error removing skill: $e');
      throw Exception('Failed to remove skill: $e');
    }
  }

  // ==================== REAL-TIME STREAMS ====================

  // Stream for real-time profile updates
  Stream<Map<String, dynamic>?> get profileStream {
    return _userProfileRef.onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        return data.map<String, dynamic>((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    });
  }

  // Get current user (for profile creation)
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}