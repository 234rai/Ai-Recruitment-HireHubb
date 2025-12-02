import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADD THIS
import 'package:major_project/models/user_role.dart';
import 'package:major_project/services/user_service.dart'; // ADD THIS

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // ADD THIS
  final UserService _userService = UserService(); // ADD THIS

  // Updated GoogleSignIn configuration to force account selection
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    signInOption: SignInOption.standard, // Force account selection
    scopes: [
      'email',
      'profile',
    ],
  );

  // Sign in with Google - UPDATED to force account selection
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // First, sign out to clear any cached account
      await _googleSignIn.signOut();

      // Trigger the authentication flow - this will now always show account selection
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If user cancels the sign-in
      if (googleUser == null) {
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  // Check if user is new (first time sign-in)
  Future<bool> isNewUser(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      return !doc.exists;
    } catch (e) {
      print('Error checking if user is new: $e');
      return true; // Assume new user on error
    }
  }

  // Save user role to Firestore
  Future<void> saveUserRole({
    required String uid,
    required String email,
    required String displayName,
    required String role,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      print('✅ User role saved: $role');
    } catch (e) {
      print('❌ Error saving user role: $e');
      rethrow;
    }
  }

  // Sign out - NO CHANGES NEEDED
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Get current user - NO CHANGES NEEDED
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}