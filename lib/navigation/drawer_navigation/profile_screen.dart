// profile_screen.dart - READ-ONLY EMAIL + CUSTOM SECTIONS
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '/services/realtime_database_service.dart';
import '../../utils/responsive_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _profileExists = false;
  int _selectedTab = 0;

  // Text controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _githubController = TextEditingController();
  final TextEditingController _linkedinController = TextEditingController();
  final TextEditingController _portfolioController = TextEditingController();

  // Custom sections
  List<Map<String, String>> _customSections = [];

  // Form validation
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _phoneError;

  // Backup controllers for cancel functionality
  String _backupName = '';
  String _backupEmail = '';
  String _backupAbout = '';
  String _backupLocation = '';
  String _backupPhone = '';
  String _backupGithub = '';
  String _backupLinkedin = '';
  String _backupPortfolio = '';
  List<Map<String, String>> _backupCustomSections = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final profile = await _databaseService.getUserProfile();

      if (profile != null) {
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _profileExists = true;
            _isLoading = false;
          });
        }
        _fillFormWithProfileData(profile);
      } else {
        if (mounted) {
          setState(() {
            _profileExists = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() {
          _profileExists = false;
          _isLoading = false;
        });
      }
    }
  }

  void _fillFormWithProfileData(Map<String, dynamic> profile) {
    _nameController.text = profile['name']?.toString() ?? '';
    _emailController.text = profile['email']?.toString() ?? '';
    _aboutController.text = profile['about']?.toString() ?? '';
    _locationController.text = profile['location']?.toString() ?? '';
    _phoneController.text = profile['phone']?.toString() ?? '';
    _githubController.text = profile['github']?.toString() ?? '';
    _linkedinController.text = profile['linkedin']?.toString() ?? '';
    _portfolioController.text = profile['portfolio']?.toString() ?? '';

    // Load custom sections
    if (profile['customSections'] is List) {
      _customSections = List<Map<String, String>>.from(
          profile['customSections'].map((section) =>
          Map<String, String>.from(section)
          )
      );
    } else {
      _customSections = [];
    }
  }

  void _backupCurrentValues() {
    _backupName = _nameController.text;
    _backupEmail = _emailController.text;
    _backupAbout = _aboutController.text;
    _backupLocation = _locationController.text;
    _backupPhone = _phoneController.text;
    _backupGithub = _githubController.text;
    _backupLinkedin = _linkedinController.text;
    _backupPortfolio = _portfolioController.text;
    _backupCustomSections = List.from(_customSections);
    _phoneError = null;
  }

  void _restoreBackupValues() {
    _nameController.text = _backupName;
    _emailController.text = _backupEmail;
    _aboutController.text = _backupAbout;
    _locationController.text = _backupLocation;
    _phoneController.text = _backupPhone;
    _githubController.text = _backupGithub;
    _linkedinController.text = _backupLinkedin;
    _portfolioController.text = _backupPortfolio;
    _customSections = List.from(_backupCustomSections);
    _phoneError = null;
  }

  void _toggleEditMode() {
    if (_isEditing) {
      // Cancel editing - restore backup values
      _restoreBackupValues();
      setState(() => _isEditing = false);
    } else {
      // Start editing - backup current values
      _backupCurrentValues();
      setState(() => _isEditing = true);
    }
  }

  // Phone number validation
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Phone is optional
    }

    // Remove all non-digit characters
    final cleanedPhone = value.replaceAll(RegExp(r'[^\d+]'), '');

    // Basic phone validation - at least 10 digits
    if (cleanedPhone.replaceAll('+', '').length < 10) {
      return 'Enter a valid phone number (at least 10 digits)';
    }

    // Check for invalid patterns
    if (RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Phone number cannot contain letters';
    }

    return null;
  }

  void _validateAndUpdatePhone(String value) {
    setState(() {
      _phoneError = _validatePhone(value);
    });
  }

  // Add custom section
  Future<void> _addCustomSection() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Section Title',
                hintText: 'e.g., Certifications, Projects, Languages',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Enter the content for this section...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  contentController.text.trim().isNotEmpty) {
                setState(() {
                  _customSections.add({
                    'title': titleController.text.trim(),
                    'content': contentController.text.trim(),
                  });
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D8D)),
            child: const Text('Add Section', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Edit custom section
  Future<void> _editCustomSection(int index) async {
    final section = _customSections[index];
    final titleController = TextEditingController(text: section['title']);
    final contentController = TextEditingController(text: section['content']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Custom Section'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Section Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty &&
                  contentController.text.trim().isNotEmpty) {
                setState(() {
                  _customSections[index] = {
                    'title': titleController.text.trim(),
                    'content': contentController.text.trim(),
                  };
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4D8D)),
            child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Delete custom section
  void _deleteCustomSection(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text('Are you sure you want to delete "${_customSections[index]['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _customSections.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _createProfile() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final user = _databaseService.getCurrentUser();
      if (user == null) {
        throw Exception('No user logged in');
      }

      await _databaseService.createInitialProfile(
        name: user.displayName ?? 'Your Name',
        email: user.email ?? '',
        photoUrl: user.photoURL,
      );

      await _loadUserProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating profile: $e');
      if (mounted) setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    // Validate phone number before updating
    if (_phoneController.text.isNotEmpty) {
      final phoneError = _validatePhone(_phoneController.text);
      if (phoneError != null) {
        setState(() => _phoneError = phoneError);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(phoneError),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    try {
      if (mounted) setState(() => _isLoading = true);

      await _databaseService.updateProfile({
        'name': _nameController.text,
        'email': _emailController.text,
        'about': _aboutController.text,
        'location': _locationController.text,
        'phone': _phoneController.text,
        'github': _githubController.text,
        'linkedin': _linkedinController.text,
        'portfolio': _portfolioController.text,
        'customSections': _customSections,
      });

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isLoading = false;
        });
      }

      await _loadUserProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Error updating profile: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfilePicture() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1000,
      );

      if (image != null) {
        if (mounted) setState(() => _isLoading = true);

        final file = File(image.path);
        await _databaseService.uploadProfilePictureAsBase64(file);

        await _loadUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      if (mounted) setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading profile picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadBannerImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1600,
      );

      if (image != null) {
        if (mounted) setState(() => _isLoading = true);

        final file = File(image.path);
        await _databaseService.uploadBannerImageAsBase64(file);

        await _loadUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Banner image updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error uploading banner image: $e');
      if (mounted) setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading banner: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadResume() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        if (mounted) setState(() => _isLoading = true);

        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;

        final fileSize = await file.length();
        if (fileSize > 2097152) {
          if (mounted) setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File too large. Please select a PDF under 2MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Get current date and time
        final now = DateTime.now();
        final uploadDate = now.toIso8601String();

        await _databaseService.uploadResumeAsBase64(file, fileName);

        // Update profile with upload date and file size
        await _databaseService.updateProfile({
          'resumeUploadDate': uploadDate,
          'resumeFileSize': fileSize,
        });

        await _loadUserProfile();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resume uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('Error uploading resume: $e');
      if (mounted) setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadResume() async {
    try {
      if (mounted) setState(() => _isLoading = true);

      final resumeData = await _databaseService.downloadResume();
      final fileName = _userProfile?['resumeFileName'] ?? 'resume.pdf';

      if (resumeData != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Resume downloaded: $fileName'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No resume found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error downloading resume: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteResume() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resume?'),
        content: const Text('Are you sure you want to delete your resume? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (mounted) setState(() => _isLoading = true);

      // Delete resume from database
      await _databaseService.updateProfile({
        'resumeBase64': null,
        'resumeFileName': null,
        'resumeUploadDate': null,
        'resumeFileSize': null,
      });

      await _loadUserProfile();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Resume deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting resume: $e');
      if (mounted) setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting resume: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Format file size to human readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  // Format upload date to readable format without intl package
  String _formatUploadDate(String? isoDate) {
    if (isoDate == null) return 'Unknown date';

    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today • ${_formatTime(date)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday • ${_formatTime(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return _formatDate(date);
      }
    } catch (e) {
      return 'Invalid date';
    }
  }

  Future<void> _launchURL(String url) async {
    if (url.isEmpty) return;

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid URL: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _getProfileImage(double radius, ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base64Image = _userProfile?['photoBase64']?.toString();

    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        final bytes = base64.decode(base64Image);
        return CircleAvatar(
          radius: radius,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        print('Error loading base64 image: $e');
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(Icons.person, size: radius * 0.8, color: isDark ? Colors.grey[400] : Colors.grey[600]),
    );
  }

  Widget _getBanner(double height) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannerBase64 = _userProfile?['bannerBase64']?.toString();

    if (bannerBase64 != null && bannerBase64.isNotEmpty) {
      try {
        final bytes = base64.decode(bannerBase64);
        return Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: MemoryImage(bytes),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
        );
      } catch (e) {
        print('Error loading banner base64: $e');
      }
    }

    // FIXED: Banner now maintains consistent visibility in both light and dark modes
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
            const Color(0xFF667eea),  // Dark blue
            const Color(0xFF764ba2),  // Purple
            const Color(0xFFf093fb),  // Pink
          ]
              : [
            const Color(0xFFFF9A8B),  // Light coral
            const Color(0xFFFF6A88),  // Pink
            const Color(0xFFFF99AC),  // Light pink
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: CustomPaint(
        painter: GeometricPatternPainter(isDark: isDark),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _aboutController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _githubController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
            fontSize: responsive.fontSize(18),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color, size: responsive.iconSize(24)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Add custom section button (only in edit mode)
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFFFF4D8D)),
              onPressed: _addCustomSection,
              tooltip: 'Add Custom Section',
            ),
          // Edit/Cancel button
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit, color: theme.iconTheme.color),
            onPressed: _toggleEditMode,
          ),
          // Save button (only in edit mode)
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFFFF4D8D)),
              onPressed: _updateProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_profileExists || _userProfile == null
          ? _buildCreateProfile()
          : RefreshIndicator(
        onRefresh: _loadUserProfile,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.all(responsive.padding(16)),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(responsive.radius(16)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: responsive.radius(10),
                      offset: Offset(0, responsive.height(2)),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(responsive.radius(16)),
                            topRight: Radius.circular(responsive.radius(16)),
                          ),
                          child: _getBanner(responsive.height(140)),
                        ),
                        if (_isEditing)
                          Positioned(
                            right: responsive.width(12),
                            top: responsive.height(12),
                            child: GestureDetector(
                              onTap: _uploadBannerImage,
                              child: Container(
                                padding: EdgeInsets.all(responsive.padding(8)),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: responsive.iconSize(18),
                                  color: const Color(0xFFFF4D8D),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: -responsive.height(50),
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Stack(
                              children: [
                                GestureDetector(
                                  onTap: _isEditing ? _uploadProfilePicture : null,
                                  child: Container(
                                    padding: EdgeInsets.all(responsive.padding(4)),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                                          blurRadius: responsive.radius(10),
                                          offset: Offset(0, responsive.height(4)),
                                        ),
                                      ],
                                    ),
                                    child: _getProfileImage(responsive.width(50), responsive),
                                  ),
                                ),
                                Positioned(
                                  bottom: responsive.height(4),
                                  right: responsive.width(4),
                                  child: Container(
                                    width: responsive.width(18),
                                    height: responsive.width(18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CD964),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.cardColor,
                                        width: responsive.width(3),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: responsive.height(58)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: responsive.padding(20)),
                      child: Column(
                        children: [
                          Text(
                            _userProfile?['name'] ?? 'Your Name',
                            style: TextStyle(
                              fontSize: responsive.fontSize(22),
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: responsive.height(6)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.remove_red_eye_outlined,
                                  size: responsive.iconSize(14), color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                              SizedBox(width: responsive.width(4)),
                              Text(
                                'Profile visibility standard',
                                style: TextStyle(
                                  fontSize: responsive.fontSize(12),
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: responsive.height(16)),
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(responsive.radius(8)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 0),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: responsive.padding(12)),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 0 ? theme.cardColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                                ),
                                child: Text(
                                  'Personal Summary',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: responsive.fontSize(13),
                                    fontWeight: _selectedTab == 0 ? FontWeight.w600 : FontWeight.normal,
                                    color: _selectedTab == 0
                                        ? theme.textTheme.bodyLarge?.color
                                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedTab = 1),
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: responsive.padding(12)),
                                decoration: BoxDecoration(
                                  color: _selectedTab == 1 ? theme.cardColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                                ),
                                child: Text(
                                  'Career History',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: responsive.fontSize(13),
                                    fontWeight: _selectedTab == 1 ? FontWeight.w600 : FontWeight.normal,
                                    color: _selectedTab == 1
                                        ? theme.textTheme.bodyLarge?.color
                                        : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: responsive.height(20)),
                  ],
                ),
              ),
              if (_selectedTab == 0) ...[
                _buildModernResumeSection(responsive),
                _buildModernAboutSection(responsive),
                _buildModernContactSection(responsive),
                // Custom Sections
                ..._buildCustomSections(responsive),
              ] else ...[
                _buildModernCareerSection(responsive),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCustomSections(ResponsiveHelper responsive) {
    if (_customSections.isEmpty && !_isEditing) {
      return [];
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return _customSections.asMap().entries.map((entry) {
      final index = entry.key;
      final section = entry.value;

      return Container(
        margin: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
        padding: EdgeInsets.all(responsive.padding(16)),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(responsive.radius(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
              blurRadius: responsive.radius(8),
              offset: Offset(0, responsive.height(2)),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  section['title']!,
                  style: TextStyle(
                    fontSize: responsive.fontSize(16),
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                if (_isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, size: responsive.iconSize(18),
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
                        onPressed: () => _editCustomSection(index),
                        tooltip: 'Edit Section',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: responsive.iconSize(18),
                            color: Colors.red[400]),
                        onPressed: () => _deleteCustomSection(index),
                        tooltip: 'Delete Section',
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: responsive.height(12)),
            Text(
              section['content']!,
              style: TextStyle(
                fontSize: responsive.fontSize(14),
                height: 1.5,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildModernResumeSection(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(responsive.radius(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: responsive.radius(8),
            offset: Offset(0, responsive.height(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resume',
            style: TextStyle(
              fontSize: responsive.fontSize(16),
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: responsive.height(12)),
          if (hasResumeInProfile())
            Container(
              padding: EdgeInsets.all(responsive.padding(12)),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(responsive.radius(8)),
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: responsive.width(40),
                    height: responsive.width(40),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(responsive.radius(8)),
                    ),
                    child: Icon(Icons.picture_as_pdf, color: Colors.red, size: responsive.iconSize(24)),
                  ),
                  SizedBox(width: responsive.width(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userProfile?['resumeFileName'] ?? 'resume.pdf',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: responsive.fontSize(13),
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: responsive.height(2)),
                        Text(
                          // FIXED: Real-time date and file size without intl package
                          '${_formatUploadDate(_userProfile?['resumeUploadDate'])} • ${_formatFileSize(_userProfile?['resumeFileSize'] ?? 0)}',
                          style: TextStyle(
                            fontSize: responsive.fontSize(11),
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isEditing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.upload_outlined, size: responsive.iconSize(20), color: const Color(0xFFFF4D8D)),
                          onPressed: _uploadResume,
                          tooltip: 'Replace Resume',
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: responsive.iconSize(20),
                              color: Colors.red[400]),
                          onPressed: _deleteResume,
                          tooltip: 'Delete Resume',
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: Icon(Icons.download_outlined, size: responsive.iconSize(20),
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)),
                      onPressed: _downloadResume,
                    ),
                ],
              ),
            )
          else
            GestureDetector(
              onTap: _uploadResume,
              child: Container(
                padding: EdgeInsets.all(responsive.padding(16)),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                  border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, style: BorderStyle.solid),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), size: responsive.iconSize(24)),
                    SizedBox(width: responsive.width(8)),
                    Text(
                      'Upload Resume',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: responsive.fontSize(14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernAboutSection(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(responsive.radius(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: responsive.radius(8),
            offset: Offset(0, responsive.height(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: responsive.fontSize(16),
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: responsive.height(12)),
          if (_isEditing)
            TextField(
              controller: _aboutController,
              maxLines: 4,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: responsive.fontSize(14)),
              decoration: InputDecoration(
                hintText: 'Tell us about yourself...',
                hintStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4), fontSize: responsive.fontSize(14)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                  borderSide: const BorderSide(color: Color(0xFFFF4D8D)),
                ),
                contentPadding: EdgeInsets.all(responsive.padding(12)),
              ),
            )
          else
            Text(
              _aboutController.text.isEmpty
                  ? 'No information added yet'
                  : _aboutController.text,
              style: TextStyle(
                fontSize: responsive.fontSize(14),
                height: 1.5,
                color: _aboutController.text.isEmpty
                    ? theme.textTheme.bodyMedium?.color?.withOpacity(0.5)
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernContactSection(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(responsive.radius(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: responsive.radius(8),
            offset: Offset(0, responsive.height(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact & Social',
            style: TextStyle(
              fontSize: responsive.fontSize(16),
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: responsive.height(16)),
          _buildCompactInfoRow(Icons.email_outlined, 'Email', _emailController, responsive, isReadOnly: true),
          SizedBox(height: responsive.height(12)),
          _buildCompactInfoRow(Icons.phone_outlined, 'Phone', _phoneController, responsive, isPhone: true),
          SizedBox(height: responsive.height(12)),
          _buildCompactInfoRow(Icons.location_on_outlined, 'Location', _locationController, responsive),
          SizedBox(height: responsive.height(16)),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
          SizedBox(height: responsive.height(16)),
          _buildCompactInfoRow(Icons.code, 'GitHub', _githubController, responsive),
          SizedBox(height: responsive.height(12)),
          _buildCompactInfoRow(Icons.business_outlined, 'LinkedIn', _linkedinController, responsive),
          SizedBox(height: responsive.height(12)),
          _buildCompactInfoRow(Icons.language, 'Portfolio', _portfolioController, responsive),
        ],
      ),
    );
  }

  Widget _buildModernCareerSection(ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final careers = _userProfile?['career'] is List
        ? List<Map<String, dynamic>>.from(_userProfile!['career'])
        : <Map<String, dynamic>>[];

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(responsive.radius(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: responsive.radius(8),
            offset: Offset(0, responsive.height(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Career History',
                style: TextStyle(
                  fontSize: responsive.fontSize(16),
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFFFF4D8D)),
                  onPressed: () {
                    // Add career dialog logic here
                  },
                ),
            ],
          ),
          SizedBox(height: responsive.height(12)),
          if (careers.isEmpty)
            Container(
              padding: EdgeInsets.all(responsive.padding(20)),
              child: Center(
                child: Text(
                  'No career history added yet',
                  style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      fontSize: responsive.fontSize(14)),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: careers.length,
              separatorBuilder: (context, index) => Divider(
                  height: responsive.height(24),
                  color: isDark ? Colors.grey[800] : Colors.grey[200]),
              itemBuilder: (context, index) {
                final career = careers[index];
                return _buildCareerItem(career, responsive);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCareerItem(Map<String, dynamic> career, ResponsiveHelper responsive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final title = career['title'] ?? 'Position Title';
    final company = career['company'] ?? 'Company Name';
    final duration = career['duration'] ?? 'Duration';
    final years = career['years'] ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: responsive.width(40),
          height: responsive.width(40),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            borderRadius: BorderRadius.circular(responsive.radius(8)),
          ),
          child: Center(
            child: Text(
              company.isNotEmpty ? company[0].toUpperCase() : 'C',
              style: TextStyle(
                fontSize: responsive.fontSize(18),
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
            ),
          ),
        ),
        SizedBox(width: responsive.width(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: responsive.fontSize(15),
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              SizedBox(height: responsive.height(4)),
              Text(
                company,
                style: TextStyle(
                  fontSize: responsive.fontSize(13),
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              SizedBox(height: responsive.height(2)),
              Text(
                '$duration${years.isNotEmpty ? " • $years" : ""}',
                style: TextStyle(
                  fontSize: responsive.fontSize(12),
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        if (_isEditing)
          IconButton(
            icon: Icon(Icons.more_horiz, size: responsive.iconSize(20),
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
            onPressed: () {
              // Edit/Delete career options
            },
          ),
      ],
    );
  }

  Widget _buildCompactInfoRow(IconData icon, String label, TextEditingController controller, ResponsiveHelper responsive, {bool isPhone = false, bool isReadOnly = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (_isEditing && !isReadOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: responsive.fontSize(12),
              fontWeight: FontWeight.w500,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          SizedBox(height: responsive.height(6)),
          TextField(
            controller: controller,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: responsive.fontSize(14)),
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            onChanged: isPhone ? _validateAndUpdatePhone : null,
            readOnly: isReadOnly,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: responsive.iconSize(18),
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
              hintText: 'Enter $label',
              hintStyle: TextStyle(fontSize: responsive.fontSize(13),
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4)),
              contentPadding: EdgeInsets.symmetric(horizontal: responsive.padding(12), vertical: responsive.padding(10)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.radius(8)),
                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.radius(8)),
                borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(responsive.radius(8)),
                borderSide: BorderSide(
                  color: _phoneError != null ? Colors.red : const Color(0xFFFF4D8D),
                ),
              ),
              errorText: isPhone ? _phoneError : null,
              errorStyle: TextStyle(fontSize: responsive.fontSize(12)),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(icon, size: responsive.iconSize(18), color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
        SizedBox(width: responsive.width(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: responsive.fontSize(11),
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
              ),
              SizedBox(height: responsive.height(2)),
              Text(
                controller.text.isEmpty ? 'Not specified' : controller.text,
                style: TextStyle(
                  fontSize: responsive.fontSize(13),
                  color: controller.text.isEmpty
                      ? theme.textTheme.bodyMedium?.color?.withOpacity(0.4)
                      : theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool hasResumeInProfile() {
    final resumeBase64 = _userProfile?['resumeBase64'] as String?;
    return resumeBase64 != null && resumeBase64.isNotEmpty;
  }

  Widget _buildCreateProfile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final responsive = ResponsiveHelper(context);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(responsive.padding(32)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: responsive.width(120),
              height: responsive.width(120),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D8D).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_add_outlined,
                size: responsive.iconSize(60),
                color: const Color(0xFFFF4D8D),
              ),
            ),
            SizedBox(height: responsive.height(24)),
            Text(
              'Create Your Profile',
              style: TextStyle(
                fontSize: responsive.fontSize(24),
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: responsive.height(12)),
            Text(
              'Start building your professional profile to unlock all features and connect with opportunities',
              style: TextStyle(
                fontSize: responsive.fontSize(15),
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: responsive.height(32)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4D8D),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: responsive.padding(16)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Create Profile',
                  style: TextStyle(
                    fontSize: responsive.fontSize(16),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            SizedBox(height: responsive.height(16)),
            Container(
              padding: EdgeInsets.all(responsive.padding(20)),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(responsive.radius(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What you can do:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: responsive.fontSize(14),
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: responsive.height(12)),
                  _buildBenefitItem(Icons.work_outline, 'Apply to jobs instantly', responsive),
                  SizedBox(height: responsive.height(8)),
                  _buildBenefitItem(Icons.description_outlined, 'Upload your resume', responsive),
                  SizedBox(height: responsive.height(8)),
                  _buildBenefitItem(Icons.star_outline, 'Showcase your skills', responsive),
                  SizedBox(height: responsive.height(8)),
                  _buildBenefitItem(Icons.link, 'Share your social profiles', responsive),
                  SizedBox(height: responsive.height(8)),
                  _buildBenefitItem(Icons.add_circle_outline, 'Add custom sections', responsive),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text, ResponsiveHelper responsive) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(responsive.padding(6)),
          decoration: BoxDecoration(
            color: const Color(0xFFFF4D8D).withOpacity(0.1),
            borderRadius: BorderRadius.circular(responsive.radius(6)),
          ),
          child: Icon(
            icon,
            size: responsive.iconSize(16),
            color: const Color(0xFFFF4D8D),
          ),
        ),
        SizedBox(width: responsive.width(12)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: responsive.fontSize(14),
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class GeometricPatternPainter extends CustomPainter {
  final bool isDark;

  const GeometricPatternPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Draw some abstract shapes
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.2, size.width * 0.3, size.height * 0.4),
        const Radius.circular(12),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.5, size.height * 0.1, size.width * 0.25, size.height * 0.3),
        const Radius.circular(12),
      ),
      paint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.5, size.width * 0.2, size.height * 0.35),
        const Radius.circular(12),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}