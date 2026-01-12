// lib/navigation/home_screen.dart - UPDATED VERSION
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../services/realtime_database_service.dart';
import '../navigation/drawer_navigation/profile_screen.dart';
import '../models/job_model.dart';
import 'job_detail_screen.dart';
import '../navigation/drawer_navigation/ai_resume_checker_screen.dart';
import '../services/application_service.dart';
import 'application_screen.dart';
import 'drawer_navigation/saved_jobs_screen.dart';
import 'chatbot_screen.dart';
import 'settings_screen.dart';
import '../providers/role_provider.dart';
import 'job_post_screen.dart'; // Add this import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RealtimeDatabaseService _databaseService = RealtimeDatabaseService();
  final ApplicationService _applicationService = ApplicationService();
  String _searchQuery = '';
  Map<String, dynamic>? _userProfile;

  late AnimationController _drawerAnimationController;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    _drawerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _databaseService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  void _openChatAssistant() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotScreen()),
    );
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ChatbotScreen()),
    );
  }

  Widget _getProfileAvatar(double radius) {
    final base64Image = _userProfile?['photoBase64']?.toString();

    if (base64Image != null && base64Image.isNotEmpty) {
      try {
        final bytes = base64.decode(base64Image);
        return CircleAvatar(
          radius: radius,
          backgroundColor: Colors.grey[200],
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        print('Error loading base64 image: $e');
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user?.photoURL != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
        child: ClipOval(
          child: Image.network(
            user!.photoURL!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.person,
                color: const Color(0xFFFF2D55),
                size: radius,
              );
            },
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
      child: Icon(
        Icons.person,
        color: const Color(0xFFFF2D55),
        size: radius,
      ),
    );
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    } catch (e) {
      print('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openProfile() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    ).then((_) {
      _loadUserProfile();
    });
  }

  void _openApplications() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApplicationsScreen()),
    );
  }

  void _openJobPostScreen() {
    Navigator.pop(context); // Close drawer if open
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JobPostScreen()),
    );
  }

  void _openSettings() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _openSavedJobs() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedJobsScreen()),
    );
  }

  void _showJobDetails(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(jobId: job.id, job: job),
      ),
    );
  }

  void _openAIResumeChecker() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AIResumeCheckerScreen()),
    );
  }

  void _saveJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to save jobs'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await FirestoreService.saveJob(jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Save job error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving job: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _unsaveJob(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to manage saved jobs'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await FirestoreService.unsaveJob(jobId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job removed from saved'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Unsave job error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing job: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _applyForJob(Job job) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to apply for jobs'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final hasApplied = await _applicationService.hasApplied(job.id);
      if (hasApplied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied to this job'),
            backgroundColor: Colors.blue,
          ),
        );
        return;
      }

      final success = await _applicationService.applyForJob(
        jobId: job.id,
        jobTitle: job.position,
        company: job.company,
        companyLogo: job.logo,
        recruiterId: job.recruiterId ?? '', // Pass recruiterId from job object
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied to ${job.position} successfully!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                _openApplications();
              },
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit application. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Apply job error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying for job: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _drawerAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final roleProvider = Provider.of<RoleProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawerScrimColor: Colors.black.withOpacity(0.5),
      drawerEnableOpenDragGesture: true,
      drawer: _buildDrawer(context, user, isDarkMode, roleProvider),
      onDrawerChanged: (isOpened) {
        if (isOpened) {
          _drawerAnimationController.forward();
        } else {
          _drawerAnimationController.reverse();
        }
      },
      body: Stack(
        children: [
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '👋 Hi, ${_userProfile?['name']?.toString().split(' ')[0] ?? user?.displayName?.split(' ')[0] ?? 'User'}',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  roleProvider.isRecruiter
                                      ? 'Find your ideal candidate today!'
                                      : 'Find your dream job today!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                _scaffoldKey.currentState?.openDrawer();
                              },
                              child: _getProfileAvatar(24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                _searchQuery = value;
                              });
                            },
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: roleProvider.isRecruiter
                                  ? 'Search candidates or jobs...'
                                  : 'Start your job search',
                              hintStyle: TextStyle(
                                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              suffixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2D55),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.tune,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              roleProvider.isRecruiter ? 'Dashboard' : 'Job Feed',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              roleProvider.isRecruiter
                                  ? 'Your hiring activities'
                                  : 'Jobs based on your activity',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ROLE-BASED CONTENT
                roleProvider.isRecruiter
                    ? _buildRecruiterContent(isDarkMode)
                    : _buildJobSeekerContent(isDarkMode),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: _openChatbot,
              backgroundColor: const Color(0xFFFF2D55),
              child: const Icon(Icons.smart_toy, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // NEW METHOD: Recruiter Dashboard Content
  Widget _buildRecruiterContent(bool isDarkMode) {
    // For now, we'll show a placeholder message
    // Later you can implement actual recruiter dashboard
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome Back,',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recruiter!',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 6),
                            Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildRecruiterStat(
                        icon: Icons.work_outline,
                        value: '0',
                        label: 'Jobs Posted',
                        isDarkMode: isDarkMode,
                      ),
                      _buildRecruiterStat(
                        icon: Icons.people_outline,
                        value: '0',
                        label: 'Applicants',
                        isDarkMode: isDarkMode,
                      ),
                      _buildRecruiterStat(
                        icon: Icons.trending_up,
                        value: '0',
                        label: 'Interviews',
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3,
                    children: [
                      _buildRecruiterAction(
                        icon: Icons.add_box_outlined,
                        label: 'Post New Job',
                        onTap: _openJobPostScreen,
                        isDarkMode: isDarkMode,
                      ),
                      _buildRecruiterAction(
                        icon: Icons.people_outline,
                        label: 'View Candidates',
                        onTap: () {
                          // TODO: Navigate to candidates screen
                        },
                        isDarkMode: isDarkMode,
                      ),
                      _buildRecruiterAction(
                        icon: Icons.description_outlined,
                        label: 'Applications',
                        onTap: _openApplications,
                        isDarkMode: isDarkMode,
                      ),
                      _buildRecruiterAction(
                        icon: Icons.analytics_outlined,
                        label: 'Analytics',
                        onTap: () {
                          // TODO: Navigate to analytics
                        },
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Feature Coming Soon',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecruiterStat({
    required IconData icon,
    required String value,
    required String label,
    required bool isDarkMode,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2D55).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFFF2D55),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecruiterAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFF2D55),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // Job Seeker Content (your existing job feed)
  Widget _buildJobSeekerContent(bool isDarkMode) {
    return StreamBuilder<List<Job>>(
      stream: FirestoreService.getLatestJobFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFFF2D55),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Error loading jobs: ${snapshot.error}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 64,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No jobs available',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Check back later for new opportunities',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final jobs = snapshot.data!;
        List<Job> filteredJobs = jobs;

        if (_searchQuery.isNotEmpty) {
          filteredJobs = jobs.where((job) {
            return job.position.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                job.company.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                job.skills.any((skill) => skill.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) {
                final job = filteredJobs[index];
                return _buildJobCard(job, isDarkMode);
              },
              childCount: filteredJobs.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, User? user, bool isDarkMode, RoleProvider roleProvider) {
    return Drawer(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      elevation: 16,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _drawerAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -20 * (1 - _drawerAnimationController.value)),
                  child: Opacity(
                    opacity: _drawerAnimationController.value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _getProfileAvatar(28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userProfile?['name'] ?? user?.displayName ?? 'User Name',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${roleProvider.userRole?.displayName ?? 'User'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: const Color(0xFFFF2D55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _userProfile?['email'] ?? user?.email ?? 'user@example.com',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _openProfile,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: AnimatedBuilder(
                animation: _drawerAnimationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - _drawerAnimationController.value)),
                    child: Opacity(
                      opacity: _drawerAnimationController.value,
                      child: child,
                    ),
                  );
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      // ROLE-BASED DRAWER ITEMS
                      if (roleProvider.isJobSeeker) ...[
                        _buildDrawerItem(
                          icon: Icons.person_outline,
                          title: 'My Profile',
                          onTap: _openProfile,
                          isDarkMode: isDarkMode,
                        ),
                        _buildDrawerItem(
                          icon: Icons.work_outline,
                          title: 'My Applications',
                          onTap: _openApplications,
                          isDarkMode: isDarkMode,
                        ),
                        _buildDrawerItem(
                          icon: Icons.favorite_outline,
                          title: 'Saved Jobs',
                          onTap: _openSavedJobs,
                          isDarkMode: isDarkMode,
                        ),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.auto_awesome_outlined,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              size: 20,
                            ),
                            title: Text(
                              'AI Features',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            collapsedIconColor:
                            isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            iconColor: isDarkMode ? Colors.white : const Color(0xFFFF2D55),
                            childrenPadding: const EdgeInsets.only(left: 50, bottom: 8, right: 16),
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.description_outlined,
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  size: 18,
                                ),
                                title: Text(
                                  'AI Resume Checker',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                onTap: _openAIResumeChecker,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                              ),
                              ListTile(
                                leading: Icon(
                                  Icons.chat_outlined,
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  size: 18,
                                ),
                                title: Text(
                                  'Chat Assistant',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                onTap: _openChatAssistant,
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ] else if (roleProvider.isRecruiter) ...[
                        _buildDrawerItem(
                          icon: Icons.dashboard_outlined,
                          title: 'Dashboard',
                          onTap: () {},
                          isDarkMode: isDarkMode,
                        ),
                        _buildDrawerItem(
                          icon: Icons.add_box_outlined,
                          title: 'Post a Job',
                          onTap: _openJobPostScreen,
                          isDarkMode: isDarkMode,
                        ),
                        _buildDrawerItem(
                          icon: Icons.people_outline,
                          title: 'Candidates Pool',
                          onTap: () {},
                          isDarkMode: isDarkMode,
                        ),
                        _buildDrawerItem(
                          icon: Icons.assignment_outlined,
                          title: 'Applications',
                          onTap: _openApplications,
                          isDarkMode: isDarkMode,
                        ),
                        _buildDrawerItem(
                          icon: Icons.business_outlined,
                          title: 'Company Profile',
                          onTap: _openProfile,
                          isDarkMode: isDarkMode,
                        ),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.analytics_outlined,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              size: 20,
                            ),
                            title: Text(
                              'Analytics',
                              style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            collapsedIconColor:
                            isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            iconColor: isDarkMode ? Colors.white : const Color(0xFFFF2D55),
                            childrenPadding: const EdgeInsets.only(left: 50, bottom: 8, right: 16),
                            children: [
                              ListTile(
                                leading: Icon(
                                  Icons.bar_chart_outlined,
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  size: 18,
                                ),
                                title: Text(
                                  'Job Performance',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                onTap: () {},
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                              ),
                              ListTile(
                                leading: Icon(
                                  Icons.trending_up_outlined,
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                  size: 18,
                                ),
                                title: Text(
                                  'Hiring Metrics',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black,
                                  ),
                                ),
                                onTap: () {},
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ],

                      // COMMON ITEMS FOR BOTH ROLES
                      _buildDrawerItem(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        onTap: _openSettings,
                        isDarkMode: isDarkMode,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            AnimatedBuilder(
              animation: _drawerAnimationController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - _drawerAnimationController.value)),
                  child: Opacity(
                    opacity: _drawerAnimationController.value,
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDarkMode ? Colors.red.shade800 : Colors.red,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Sign Out',
                    onTap: _signOut,
                    isDarkMode: isDarkMode,
                    isSignOut: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isDarkMode,
    bool isSignOut = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSignOut
            ? (isDarkMode ? Colors.red.shade400 : Colors.red)
            : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
        size: 20,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSignOut
              ? (isDarkMode ? Colors.red.shade400 : Colors.red)
              : (isDarkMode ? Colors.white : Colors.black),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      minLeadingWidth: 0,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildJobCard(Job job, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _showJobDetails(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: job.isFeatured
              ? Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(job.logoColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      job.logo,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(job.logoColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.company,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        job.postedTime,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<bool>(
                  stream: Stream.fromFuture(FirestoreService.isJobSaved(job.id)),
                  builder: (context, snapshot) {
                    final isSaved = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: () => isSaved ? _unsaveJob(job.id) : _saveJob(job.id),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_outline,
                          size: 20,
                          color: isSaved
                              ? const Color(0xFFFF2D55)
                              : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              job.position,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  job.country,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: job.isRemote
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.location,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: job.isRemote ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.paid_outlined,
                  size: 16,
                  color: const Color(0xFFFF2D55),
                ),
                const SizedBox(width: 4),
                Text(
                  job.salary,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF2D55),
                  ),
                ),
                const Spacer(),
                FutureBuilder<bool>(
                  future: _applicationService.hasApplied(job.id),
                  builder: (context, snapshot) {
                    final hasApplied = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: hasApplied ? null : () => _applyForJob(job),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: hasApplied
                              ? const Color(0xFF34C759)
                              : const Color(0xFFFF2D55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              hasApplied ? Icons.check : Icons.send,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasApplied ? 'Applied' : 'Apply Now',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.skills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    skill,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
            if (job.isFeatured) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Color(0xFFFFB800),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'POTENTIAL FIT BASED ON YOUR EXPERIENCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFB800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}