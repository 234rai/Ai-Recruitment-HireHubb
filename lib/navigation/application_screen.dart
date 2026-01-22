// lib/screens/applications/applications_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:major_project/providers/role_provider.dart';
import 'applications/applicant_profile_bottom_sheet.dart';
import '../utils/responsive_helper.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _selectedFilter = 'All Jobs';
  String _selectedStatusFilter = 'All Status';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final userId = _auth.currentUser?.uid;
    final roleProvider = Provider.of<RoleProvider>(context); // ADD THIS

    if (userId == null) {
      return Scaffold(
        body: Center(
          child: Text('Please log in to view applications'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          roleProvider.isRecruiter ? 'Manage Applications' : 'My Applications',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!roleProvider.isRecruiter) ...[
                // Header for Job Seeker
                Text(
                  'Track your job applications and interview progress',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),

                // Statistics Row - Real-time (Job Seeker only)
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('applications')
                      .where('userId', isEqualTo: userId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error loading statistics');
                    }

                    final applications = snapshot.data?.docs ?? [];
                    return _buildStatisticsRow(applications, isDarkMode);
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Filters for Recruiter
              if (roleProvider.isRecruiter) ...[
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', 'All Status', isDarkMode),
                      const SizedBox(width: 8),
                      _buildFilterChip('Pending', 'Pending', isDarkMode),
                      const SizedBox(width: 8),
                      _buildFilterChip('In Review', 'Reviewed', isDarkMode),
                      const SizedBox(width: 8),
                      _buildFilterChip('Shortlisted', 'Shortlisted', isDarkMode),
                      const SizedBox(width: 8),
                      _buildFilterChip('Hired', 'Hired', isDarkMode),
                      const SizedBox(width: 8),
                      _buildFilterChip('Rejected', 'Rejected', isDarkMode),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Applications List - Real-time
              Expanded(
                child: roleProvider.isRecruiter
                    ? _buildRecruiterApplications(isDarkMode, theme)
                    : _buildJobSeekerApplications(isDarkMode, theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecruiterApplications(bool isDarkMode, ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('applications')
          .where('recruiterId', isEqualTo: _auth.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading applications: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFFF2D55),
            ),
          );
        }

        final allApplications = snapshot.data?.docs ?? [];

        // Apply status filter
        final filteredApplications = allApplications.where((doc) {
          if (_selectedStatusFilter == 'All Status') return true;
          final status = doc['status'] as String?;
          switch (_selectedStatusFilter) {
            case 'Pending':
              return status == 'applied' || status == 'pending';
            case 'Reviewed':
              return status == 'inProcess';
            case 'Shortlisted':
              return status == 'shortlisted';
            case 'Hired':
              return status == 'completed';
            case 'Rejected':
              return status == 'rejected';
            default:
              return true;
          }
        }).toList();

        if (filteredApplications.isEmpty) {
          return _buildEmptyStateForRecruiter(isDarkMode);
        }

        return ListView.builder(
          itemCount: filteredApplications.length,
          itemBuilder: (context, index) {
            final doc = filteredApplications[index];
            final application = Application.fromFirestore(doc);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildRecruiterApplicationCard(
                  application, isDarkMode, theme),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDarkMode) {
    final isSelected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatusFilter = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF2D55)
              : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF2D55)
                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildJobSeekerApplications(bool isDarkMode, ThemeData theme) {
    final userId = _auth.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .orderBy('appliedDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading applications: ${snapshot.error}'),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFFF2D55),
            ),
          );
        }

        final allApplications = snapshot.data?.docs ?? [];

        if (allApplications.isEmpty) {
          return _buildEmptyState(isDarkMode);
        }

        // Separate active and completed applications
        final activeApplications = allApplications.where((doc) {
          final status = doc['status'] as String?;
          return status != 'completed' && status != 'rejected';
        }).toList();

        final completedApplications = allApplications.where((doc) {
          final status = doc['status'] as String?;
          return status == 'completed' || status == 'rejected';
        }).toList();

        return ListView(
          children: [
            // Active Applications Section
            if (activeApplications.isNotEmpty) ...[
              Text(
                'Active Applications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              ...activeApplications.map((doc) {
                final application = Application.fromFirestore(doc);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildApplicationCard(application, isDarkMode, theme),
                );
              }).toList(),
            ],

            // Completed Applications Section
            if (completedApplications.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Completed Applications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),
              ...completedApplications.map((doc) {
                final application = Application.fromFirestore(doc);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildApplicationCard(application, isDarkMode, theme),
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRecruiterApplicationCard(
      Application application, bool isDarkMode, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, color: Color(0xFF007AFF), size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.jobSeekerName ?? 'Applicant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Applied for: ${application.jobTitle}',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(application.status, isDarkMode),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.business,
                  size: 16,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    application.company,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM dd').format(application.appliedDate),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _viewApplicationDetails(application),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF007AFF),
                      side: const BorderSide(color: Color(0xFF007AFF)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_red_eye, size: 16),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'View',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateApplicationStatus(application),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Update',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ApplicationStatus status, bool isDarkMode) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case ApplicationStatus.applied:
        backgroundColor = const Color(0xFFFFB800).withOpacity(0.1);
        textColor = const Color(0xFFFFB800);
        text = 'Pending';
        break;
      case ApplicationStatus.inProcess:
        backgroundColor = const Color(0xFF007AFF).withOpacity(0.1);
        textColor = const Color(0xFF007AFF);
        text = 'In Review';
        break;
      case ApplicationStatus.shortlisted:
        backgroundColor = const Color(0xFF5856D6).withOpacity(0.1);
        textColor = const Color(0xFF5856D6);
        text = 'Shortlisted';
        break;
      case ApplicationStatus.completed:
        backgroundColor = const Color(0xFF34C759).withOpacity(0.1);
        textColor = const Color(0xFF34C759);
        text = 'Hired';
        break;
      case ApplicationStatus.rejected:
        backgroundColor = const Color(0xFFFF3B30).withOpacity(0.1);
        textColor = const Color(0xFFFF3B30);
        text = 'Rejected';
        break;
    }

    return Chip(
      label: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      backgroundColor: backgroundColor,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _viewApplicationDetails(Application application) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ApplicantProfileBottomSheet(
            userId: application.userId,
            applicationId: application.id,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  Widget _buildProfileContent(Map<String, dynamic> userData, Application application) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Header
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF007AFF).withOpacity(0.1),
                child: Text(
                  (userData['name'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 32,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                userData['name'] ?? 'Unknown',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userData['email'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF007AFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Applied for: ${application.jobTitle}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Contact Information Section
        _buildSectionTitle('Contact Information', Icons.contact_phone),
        const SizedBox(height: 12),
        _buildInfoCard(
          icon: Icons.phone,
          label: 'Phone',
          value: userData['phone'] ?? 'Not provided',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoCard(
          icon: Icons.email,
          label: 'Email',
          value: userData['email'] ?? 'Not provided',
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 8),
        _buildInfoCard(
          icon: Icons.location_on,
          label: 'Location',
          value: userData['location'] ?? 'Not provided',
          isDarkMode: isDarkMode,
        ),

        const SizedBox(height: 24),

        // Additional sections - yaha aap apne profile screen ka content add kar sakte ho
        _buildSectionTitle('Skills', Icons.psychology),
        const SizedBox(height: 12),
        _buildSkillsSection(userData['skills'] as List<dynamic>? ?? []),

        const SizedBox(height: 24),

        _buildSectionTitle('Experience', Icons.work),
        const SizedBox(height: 12),
        Text(
          userData['experience'] ?? 'No experience added',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),

        const SizedBox(height: 24),

        _buildSectionTitle('Education', Icons.school),
        const SizedBox(height: 12),
        Text(
          userData['education'] ?? 'No education added',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: const Color(0xFFFF2D55),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: const Color(0xFF007AFF),
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
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection(List<dynamic> skills) {
    if (skills.isEmpty) {
      return Text(
        'No skills added',
        style: TextStyle(
          color: Colors.grey[600],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF007AFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF007AFF).withOpacity(0.3),
            ),
          ),
          child: Text(
            skill.toString(),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF007AFF),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  void _updateApplicationStatus(Application application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Application Status'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption('Pending', ApplicationStatus.applied, application),
              _buildStatusOption('In Review', ApplicationStatus.inProcess, application),
              _buildStatusOption('Shortlisted', ApplicationStatus.shortlisted, application),
              _buildStatusOption('Hired', ApplicationStatus.completed, application),
              _buildStatusOption('Rejected', ApplicationStatus.rejected, application),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.blue),
                title: const Text('Manage Rounds'),
                subtitle: const Text('Add, Edit, or Remove Interview Rounds'),
                onTap: () {
                  Navigator.pop(context);
                  _showManageRoundsDialog(application);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(String label, ApplicationStatus status, Application application) {
    final isCurrentStatus = application.status == status;
    return ListTile(
      leading: Icon(
        isCurrentStatus ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isCurrentStatus ? const Color(0xFFFF2D55) : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isCurrentStatus ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () async {
        try {
          await _firestore.collection('applications').doc(application.id).update({
            'status': status.name,
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to $label'),
              backgroundColor: const Color(0xFF34C759),
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status'),
              backgroundColor: const Color(0xFFFF3B30),
            ),
          );
        }
      },
    );
  }

  // 🚀 NEW: Manage Rounds Dialog
  void _showManageRoundsDialog(Application application) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Interview Rounds'),
        content: SizedBox(
          width: double.maxFinite,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...application.rounds.asMap().entries.map((entry) {
                    final index = entry.key;
                    final round = entry.value;
                    return ListTile(
                      title: Text(round.name),
                      subtitle: Text(
                        round.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getRoundStatusColor(round.status),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Change Status Button
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            onPressed: () => _updateRoundStatus(application, index),
                          ),
                          // Delete Button
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () async {
                              final updatedRounds = List<InterviewRound>.from(application.rounds);
                              updatedRounds.removeAt(index);
                              
                              await _firestore.collection('applications').doc(application.id).update({
                                'rounds': updatedRounds.map((r) => r.toMap()).toList(),
                              });
                              
                              // Refresh local state (hacky but works for dialog)
                              application.rounds.removeAt(index);
                              setState(() {}); 
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAddRoundDialog(application),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Round'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Helper to get color for round status
  Color _getRoundStatusColor(RoundStatus status) {
    switch (status) {
      case RoundStatus.completed: return Colors.green;
      case RoundStatus.current: return const Color(0xFFFF2D55);
      case RoundStatus.upcoming: return Colors.grey;
      case RoundStatus.rejected: return Colors.red;
    }
  }

  // Add New Round
  void _showAddRoundDialog(Application application) {
    final TextEditingController roundNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Round'),
        content: TextField(
          controller: roundNameController,
          decoration: const InputDecoration(
            labelText: 'Round Name (e.g., Coding Round 2)',
            hintText: 'Enter round name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (roundNameController.text.isNotEmpty) {
                final newRound = InterviewRound(
                  name: roundNameController.text.trim(),
                  status: RoundStatus.upcoming,
                );
                
                final updatedRounds = List<InterviewRound>.from(application.rounds)..add(newRound);
                
                await _firestore.collection('applications').doc(application.id).update({
                  'rounds': updatedRounds.map((r) => r.toMap()).toList(),
                });
                
                Navigator.pop(context); // Close Add Dialog
                Navigator.pop(context); // Close Manage Dialog (force refresh)
                _showManageRoundsDialog(Application(
                  // Re-construct application with new rounds to refresh UI
                  // Ideally we should use a Stream or Provider, but this mimics a quick refresh
                  id: application.id,
                  recruiterId: application.recruiterId,
                  jobSeekerName: application.jobSeekerName,
                  jobTitle: application.jobTitle,
                  company: application.company,
                  companyLogo: application.companyLogo,
                  appliedDate: application.appliedDate,
                  status: application.status,
                  currentStage: application.currentStage,
                  nextRound: application.nextRound,
                  rounds: updatedRounds, // UPDATED
                  userId: application.userId,
                ));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // Update Round Status
  void _updateRoundStatus(Application application, int index) {
      showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Status: ${application.rounds[index].name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RoundStatus.values.map((status) {
            return ListTile(
              title: Text(status.name.toUpperCase()),
              onTap: () async {
                final updatedRounds = List<InterviewRound>.from(application.rounds);
                // Create new round instance with updated status
                updatedRounds[index] = InterviewRound(
                  name: updatedRounds[index].name,
                  status: status,
                  date: updatedRounds[index].date,
                );

                await _firestore.collection('applications').doc(application.id).update({
                  'rounds': updatedRounds.map((r) => r.toMap()).toList(),
                });

                Navigator.pop(context); // Close status selector
                Navigator.pop(context); // Close list (refresh)
                 _showManageRoundsDialog(Application(
                  id: application.id,
                  recruiterId: application.recruiterId,
                  jobSeekerName: application.jobSeekerName,
                  jobTitle: application.jobTitle,
                  company: application.company,
                  companyLogo: application.companyLogo,
                  appliedDate: application.appliedDate,
                  status: application.status,
                  currentStage: application.currentStage,
                  nextRound: application.nextRound,
                  rounds: updatedRounds, // UPDATED
                  userId: application.userId,
                ));
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getStatusText(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return 'Pending';
      case ApplicationStatus.inProcess:
        return 'In Review';
      case ApplicationStatus.shortlisted:
        return 'Shortlisted';
      case ApplicationStatus.completed:
        return 'Hired';
      case ApplicationStatus.rejected:
        return 'Rejected';
    }
  }

  Widget _buildStatisticsRow(List<QueryDocumentSnapshot> applications, bool isDarkMode) {
    final inProcessCount = applications.where((doc) {
      final status = doc['status'] as String?;
      return status == 'inProcess';
    }).length;

    final appliedCount = applications.where((doc) {
      final status = doc['status'] as String?;
      return status == 'applied';
    }).length;

    final completedCount = applications.where((doc) {
      final status = doc['status'] as String?;
      return status == 'completed';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'In Process',
            inProcessCount.toString(),
            const Color(0xFFFFB800),
            isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Applied',
            appliedCount.toString(),
            const Color(0xFF007AFF),
            isDarkMode,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Completed',
            completedCount.toString(),
            const Color(0xFF34C759),
            isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String count, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationCard(Application application, bool isDarkMode, ThemeData theme) {
    final currentStage = _getCurrentStage(application);
    final nextRound = _getNextRound(application);

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      application.companyLogo,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.jobTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        application.company,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(application.status, isDarkMode),
              ],
            ),
            const SizedBox(height: 16),
            _buildProgressTimeline(application, isDarkMode),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Stage',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        currentStage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Next Round',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.end,
                      ),
                      Text(
                        nextRound,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Applied ${DateFormat('MMM dd, yyyy').format(application.appliedDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to dynamically get current stage
  String _getCurrentStage(Application application) {
    // Find the current round
    final currentRound = application.rounds.firstWhere(
          (round) => round.status == RoundStatus.current,
      orElse: () {
        // If no current round, check if all completed
        final allCompleted = application.rounds.every(
              (round) => round.status == RoundStatus.completed,
        );
        if (allCompleted && application.rounds.isNotEmpty) {
          return application.rounds.last; // Return last round if all completed
        }
        // Otherwise return first upcoming or first round
        return application.rounds.firstWhere(
              (round) => round.status == RoundStatus.upcoming,
          orElse: () => application.rounds.isNotEmpty
              ? application.rounds.first
              : InterviewRound(name: 'Not Started', status: RoundStatus.upcoming),
        );
      },
    );

    return currentRound.name;
  }

  // Helper method to dynamically get next round
  String _getNextRound(Application application) {
    // Find the current round index
    final currentIndex = application.rounds.indexWhere(
          (round) => round.status == RoundStatus.current,
    );

    if (currentIndex == -1) {
      // No current round found
      final firstUpcoming = application.rounds.firstWhere(
            (round) => round.status == RoundStatus.upcoming,
        orElse: () => InterviewRound(name: 'None', status: RoundStatus.upcoming),
      );
      return firstUpcoming.name;
    }

    // Check if there's a next round
    if (currentIndex < application.rounds.length - 1) {
      return application.rounds[currentIndex + 1].name;
    }

    // This is the last round
    return 'Final Round';
  }

  Widget _buildStatusBadge(ApplicationStatus status, bool isDarkMode) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case ApplicationStatus.applied:
        backgroundColor = const Color(0xFF007AFF).withOpacity(0.1);
        textColor = const Color(0xFF007AFF);
        text = 'Applied';
        break;
      case ApplicationStatus.inProcess:
        backgroundColor = const Color(0xFFFFB800).withOpacity(0.1);
        textColor = const Color(0xFFFFB800);
        text = 'In Process';
        break;
      case ApplicationStatus.shortlisted:  // ADD THIS CASE
        backgroundColor = const Color(0xFF5856D6).withOpacity(0.1);
        textColor = const Color(0xFF5856D6);
        text = 'Shortlisted';
        break;
      case ApplicationStatus.completed:
        backgroundColor = const Color(0xFF34C759).withOpacity(0.1);
        textColor = const Color(0xFF34C759);
        text = 'Completed';
        break;
      case ApplicationStatus.rejected:
        backgroundColor = const Color(0xFFFF3B30).withOpacity(0.1);
        textColor = const Color(0xFFFF3B30);
        text = 'Rejected';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildProgressTimeline(Application application, bool isDarkMode) {
    return Column(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final completed = _calculateCompletedRounds(application);
              final total = application.rounds.length;
              return Row(
                children: [
                  if (completed > 0)
                    Container(
                      width: constraints.maxWidth * (completed / total),
                      decoration: BoxDecoration(
                        color: _getProgressColor(application.status),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: application.rounds.map((r) => _buildRoundIndicator(r, isDarkMode)).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: application.rounds.map((r) {
            return Flexible(
              child: Text(
                r.name.split(' ').first,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: r.status == RoundStatus.current ? FontWeight.bold : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoundIndicator(InterviewRound round, bool isDarkMode) {
    Color color;
    IconData icon;
    String tooltip = '';

    switch (round.status) {
      case RoundStatus.completed:
        color = const Color(0xFF34C759);
        icon = Icons.check;
        tooltip = 'Completed';
        break;
      case RoundStatus.current:
        color = const Color(0xFFFF2D55);
        icon = Icons.circle;
        tooltip = 'Current';
        break;
      case RoundStatus.upcoming:
        color = isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
        icon = Icons.radio_button_unchecked;
        tooltip = 'Upcoming';
        break;
      case RoundStatus.rejected:
        color = const Color(0xFFFF3B30);
        icon = Icons.close;
        tooltip = 'Rejected';
        break;
    }

    return Tooltip(
      message: '${round.name} - $tooltip${round.date != null ? '\n${DateFormat('MMM dd, HH:mm').format(round.date!)}' : ''}',
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 12,
          color: Colors.white,
        ),
      ),
    );
  }

  int _calculateCompletedRounds(Application application) {
    return application.rounds.where((round) => round.status == RoundStatus.completed).length;
  }

  Color _getProgressColor(ApplicationStatus status) {
    switch (status) {
      case ApplicationStatus.applied:
        return const Color(0xFF007AFF);
      case ApplicationStatus.inProcess:
        return const Color(0xFFFFB800);
      case ApplicationStatus.shortlisted:  // ADD THIS CASE
        return const Color(0xFF5856D6);
      case ApplicationStatus.completed:
        return const Color(0xFF34C759);
      case ApplicationStatus.rejected:
        return const Color(0xFFFF3B30);
    }
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 80,
            color: const Color(0xFFFF2D55).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Applications Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start applying to jobs to track your progress here',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D55),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Browse Jobs'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateForRecruiter(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: const Color(0xFF007AFF).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Applications Received',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Applicants will appear here when they apply to your job posts',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Data Models with Firestore Support
enum ApplicationStatus { applied, inProcess, completed, rejected, shortlisted }
enum RoundStatus { completed, current, upcoming, rejected }

class Application {
  final String id;
  final String jobTitle;
  final String company;
  final String companyLogo;
  final DateTime appliedDate;
  final ApplicationStatus status;
  final String currentStage;
  final String nextRound;
  final List<InterviewRound> rounds;
  final String userId;
  final String? recruiterId; // ADD THIS
  final String? jobSeekerName; // ADD THIS for recruiter view

  Application({
    required this.id,
    required this.jobTitle,
    required this.company,
    required this.companyLogo,
    required this.appliedDate,
    required this.status,
    required this.currentStage,
    required this.nextRound,
    required this.rounds,
    required this.userId,
    this.recruiterId, // ADD THIS
    this.jobSeekerName, // ADD THIS
  });

  // Convert Firestore document to Application object
  factory Application.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Application(
      id: doc.id,
      jobTitle: data['jobTitle'] ?? '',
      company: data['company'] ?? '',
      companyLogo: data['companyLogo'] ?? '🏢',
      appliedDate: (data['appliedDate'] as Timestamp).toDate(),
      status: _parseStatus(data['status']),
      currentStage: data['currentStage'] ?? '',
      nextRound: data['nextRound'] ?? '',
      rounds: (data['rounds'] as List<dynamic>?)
          ?.map((round) => InterviewRound.fromMap(round as Map<String, dynamic>))
          .toList() ?? [],
      userId: data['userId'] ?? '',
      recruiterId: data['recruiterId'] as String?,
      jobSeekerName: data['jobSeekerName'] ?? data['userName'] ?? data['userEmail'] as String?,
    );
  }

  static ApplicationStatus _parseStatus(String? status) {
    switch (status) {
      case 'applied':
        return ApplicationStatus.applied;
      case 'inProcess':
        return ApplicationStatus.inProcess;
      case 'shortlisted':
        return ApplicationStatus.shortlisted;
      case 'completed':
        return ApplicationStatus.completed;
      case 'rejected':
        return ApplicationStatus.rejected;
      default:
        return ApplicationStatus.applied;
    }
  }

  // Convert Application to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'jobTitle': jobTitle,
      'company': company,
      'companyLogo': companyLogo,
      'appliedDate': Timestamp.fromDate(appliedDate),
      'status': status.name,
      'currentStage': currentStage,
      'nextRound': nextRound,
      'rounds': rounds.map((round) => round.toMap()).toList(),
      'userId': userId,
      if (recruiterId != null) 'recruiterId': recruiterId, // ADD THIS
      if (jobSeekerName != null) 'jobSeekerName': jobSeekerName, // ADD THIS
    };
  }
}

class InterviewRound {
  final String name;
  final RoundStatus status;
  final DateTime? date;

  InterviewRound({
    required this.name,
    required this.status,
    this.date,
  });

  factory InterviewRound.fromMap(Map<String, dynamic> map) {
    return InterviewRound(
      name: map['name'] ?? '',
      status: _parseRoundStatus(map['status']),
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : null,
    );
  }

  static RoundStatus _parseRoundStatus(String? status) {
    switch (status) {
      case 'completed':
        return RoundStatus.completed;
      case 'current':
        return RoundStatus.current;
      case 'upcoming':
        return RoundStatus.upcoming;
      case 'rejected':
        return RoundStatus.rejected;
      default:
        return RoundStatus.upcoming;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'status': status.name,
      'date': date != null ? Timestamp.fromDate(date!) : null,
    };
  }
}