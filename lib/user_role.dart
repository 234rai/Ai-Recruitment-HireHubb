// lib/models/user_role.dart
enum UserRole {
  jobSeeker('job_seeker', 'Job Seeker'),
  recruiter('recruiter', 'Recruiter');

  final String value;
  final String displayName;

  const UserRole(this.value, this.displayName);

  // Convert string to UserRole
  static UserRole fromString(String?  value) {
    switch (value?. toLowerCase()) {
      case 'recruiter':
        return UserRole. recruiter;
      case 'job_seeker':
      default:
        return UserRole. jobSeeker;
    }
  }

  // Check if user is recruiter
  bool get isRecruiter => this == UserRole.recruiter;

  // Check if user is job seeker
  bool get isJobSeeker => this == UserRole.jobSeeker;
}

// User model with role
class AppUser {
  final String uid;
  final String email;
  final String?  displayName;
  final String? photoURL;
  final UserRole role;
  final DateTime createdAt;
  final DateTime?  updatedAt;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.role,
    required this.createdAt,
    this.updatedAt,
  });

  // Create from Firebase User + role
  factory AppUser.fromFirebase({
    required String uid,
    required String email,
    String?  displayName,
    String? photoURL,
    required UserRole role,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
      role: role,
      createdAt: DateTime.now(),
    );
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role.value,
      'createdAt': createdAt. toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      role: UserRole.fromString(map['role']),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: map['updatedAt'] != null ?  DateTime.parse(map['updatedAt']) : null,
    );
  }

  // Copy with method for updates
  AppUser copyWith({
    String? displayName,
    String? photoURL,
    UserRole? role,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this. photoURL,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ??  DateTime.now(),
    );
  }
}