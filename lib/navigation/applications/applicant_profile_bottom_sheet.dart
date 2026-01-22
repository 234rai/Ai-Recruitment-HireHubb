import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/services/realtime_database_service.dart';

class ApplicantProfileBottomSheet extends StatefulWidget {
  final String userId;
  final String applicationId;
  final ScrollController scrollController;

  const ApplicantProfileBottomSheet({
    super.key,
    required this.userId,
    required this.applicationId,
    required this.scrollController,
  });

  @override
  State<ApplicantProfileBottomSheet> createState() => _ApplicantProfileBottomSheetState();
}

class _ApplicantProfileBottomSheetState extends State<ApplicantProfileBottomSheet> {
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadApplicantProfile();
  }

  Future<void> _loadApplicantProfile() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      print('🔄 Loading applicant profile for user ID: ${widget.userId}');

      // Load from Realtime Database
      final profile = await _databaseService.getUserProfileById(widget.userId);

      print('📊 Profile loaded: ${profile != null}');

      if (profile != null) {
        print('🔑 Profile keys: ${profile.keys.toList()}');
        print('📝 Profile data: $profile');
      }

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading applicant profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _getProfileImage(double radius) {
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
      child: Icon(
        Icons.person,
        size: radius * 0.8,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
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
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
        );
      } catch (e) {
        print('Error loading banner base64: $e');
      }
    }

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF667eea), const Color(0xFF764ba2), const Color(0xFFf093fb)]
              : [const Color(0xFFFF9A8B), const Color(0xFFFF6A88), const Color(0xFFFF99AC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Applicant Profile',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.iconTheme.color),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
              child: CircularProgressIndicator(
                color: const Color(0xFFFF2D55),
              ),
            )
                : _userProfile == null
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off_outlined,
                    size: 60,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Profile not found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The applicant\'s profile could not be loaded\nfrom Realtime Database',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadApplicantProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                children: [
                  // Profile Header Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              child: _getBanner(120),
                            ),
                            Positioned(
                              bottom: -40,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.cardColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isDark ? 0.5 : 0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _getProfileImage(45),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 50),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Text(
                                _userProfile?['name'] ?? 'Unknown Applicant',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _userProfile?['email'] ?? 'No email provided',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tab Selector
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[900] : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _selectedTab = 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 0 ? theme.cardColor : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Profile Info',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
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
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedTab == 1 ? theme.cardColor : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Skills & Resume',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),

                  // Content based on selected tab
                  if (_selectedTab == 0) ...[
                    _buildAboutSection(isDark, theme),
                    _buildContactSection(isDark, theme),
                  ] else ...[
                    _buildSkillsSection(isDark, theme),
                    _buildResumeSection(isDark, theme),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(bool isDark, ThemeData theme) {
    final about = _userProfile?['about']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 18,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'About',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            about.isNotEmpty ? about : 'No about information available',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: about.isEmpty
                  ? theme.textTheme.bodyMedium?.color?.withOpacity(0.5)
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection(bool isDark, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.contact_page_outlined,
                size: 18,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Contact Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_outlined, 'Email', _userProfile?['email'] ?? 'Not specified', isDark, theme),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone_outlined, 'Phone', _userProfile?['phone'] ?? 'Not specified', isDark, theme),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on_outlined, 'Location', _userProfile?['location'] ?? 'Not specified', isDark, theme),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.code, 'GitHub', _userProfile?['github'] ?? 'Not specified', isDark, theme),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.business_outlined, 'LinkedIn', _userProfile?['linkedin'] ?? 'Not specified', isDark, theme),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.language, 'Portfolio', _userProfile?['portfolio'] ?? 'Not specified', isDark, theme),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark, ThemeData theme) {
    final isNotSpecified = value == 'Not specified';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: isNotSpecified
                  ? theme.textTheme.bodyMedium?.color?.withOpacity(0.4)
                  : const Color(0xFF007AFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isNotSpecified
                        ? theme.textTheme.bodyMedium?.color?.withOpacity(0.4)
                        : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(bool isDark, ThemeData theme) {
    final skills = _userProfile?['skills'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_outlined,
                size: 18,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Skills',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (skills.isEmpty)
            Text(
              'No skills listed',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                fontSize: 14,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skills.map((skill) {
                final skillText = skill.toString();
                return Chip(
                  label: Text(
                    skillText,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF007AFF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
                  side: BorderSide(
                    color: const Color(0xFF007AFF).withOpacity(0.3),
                    width: 0.5,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildResumeSection(bool isDark, ThemeData theme) {
    final hasResume = _userProfile?['resumeBase64'] != null &&
        (_userProfile?['resumeBase64'] as String).isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 18,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Resume',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasResume)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userProfile?['resumeFileName'] ?? 'resume.pdf',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ready for download',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.download_outlined, size: 20,
                        color: const Color(0xFF007AFF)),
                    onPressed: () async {
                      try {
                        final resumeBytes = await _databaseService.downloadResumeForUser(widget.userId);
                        if (resumeBytes != null) {
                          // You can implement resume download logic here
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Resume downloaded (${resumeBytes.length} bytes)'),
                              backgroundColor: const Color(0xFF34C759),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Resume not available'),
                              backgroundColor: Color(0xFFFF9500),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error downloading resume: $e'),
                            backgroundColor: const Color(0xFFFF3B30),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description_outlined,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5)),
                  const SizedBox(width: 8),
                  Text(
                    'No resume uploaded',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}