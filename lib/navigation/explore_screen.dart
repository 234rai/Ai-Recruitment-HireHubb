// lib/navigation/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/role_provider.dart';
import '../models/job_model.dart';
import '../services/firestore_service.dart';
import '../services/application_service.dart';
import 'job_detail_screen.dart';
import '../utils/responsive_helper.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApplicationService _applicationService = ApplicationService();

  // Search mode: 'jobs' or 'people'
  String _searchMode = 'jobs';

  // Filter states for jobs
  bool _remoteOnly = false;
  bool _fullTimeOnly = false;
  bool _highSalaryOnly = false;
  String _selectedLocation = 'Any';
  String _selectedJobType = 'Any';

  // Filter states for people
  String _selectedUserType = 'Any';
  String _selectedSkills = 'Any';

  // New filter states for recruiters
  String _selectedExperience = 'Any';
  bool _openToWorkOnly = false;

  Stream<QuerySnapshot> get _jobsStream {
    // Get ALL jobs (new + old) for explore
    Query query = _firestore.collection('jobs')
        .orderBy('postedAt', descending: true)
        .limit(100); // Limit to 100 for performance

    // Apply search filter if present
    if (_searchController.text.isNotEmpty) {
      query = _firestore.collection('jobs')
          .where('searchKeywords', arrayContains: _searchController.text.toLowerCase())
          .orderBy('postedAt', descending: true)
          .limit(100);
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> get _usersStream {
    Query query = _firestore.collection('users');

    if (_searchController.text.isNotEmpty) {
      query = query.where('searchKeywords',
          arrayContains: _searchController.text.toLowerCase());
    }

    if (_selectedCategory != 'All') {
      if (_selectedCategory == 'Developers') {
        query = query.where('skills',
            arrayContainsAny: ['flutter', 'developer', 'programming']);
      } else if (_selectedCategory == 'Designers') {
        query = query.where('skills',
            arrayContainsAny: ['design', 'ui/ux', 'figma']);
      } else if (_selectedCategory == 'Managers') {
        query = query.where('skills',
            arrayContainsAny: ['management', 'leadership']);
      } else if (_selectedCategory == 'Recruiters') {
        query = query.where('userType', isEqualTo: 'recruiter');
      } else if (_selectedCategory == 'Students') {
        query = query.where('userType', isEqualTo: 'student');
      }
    }

    if (_selectedUserType != 'Any') {
      query = query.where('userType', isEqualTo: _selectedUserType.toLowerCase());
    }

    return query.snapshots();
  }

  Stream<QuerySnapshot> get _candidatesStream {
    Query query = _firestore.collection('users')
        .where('userType', whereIn: ['job_seeker', 'student']);

    if (_searchController.text.isNotEmpty) {
      query = query.where('searchKeywords',
          arrayContains: _searchController.text.toLowerCase());
    }

    if (_selectedCategory != 'All') {
      if (_selectedCategory == 'Developers') {
        query = query.where('skills',
            arrayContainsAny: ['flutter', 'developer', 'programming']);
      } else if (_selectedCategory == 'Designers') {
        query = query.where('skills',
            arrayContainsAny: ['design', 'ui/ux', 'figma']);
      } else if (_selectedCategory == 'Managers') {
        query = query.where('skills',
            arrayContainsAny: ['management', 'leadership']);
      } else if (_selectedCategory == 'Students') {
        query = query.where('userType', isEqualTo: 'student');
      }
    }

    if (_selectedSkills != 'Any') {
      query = query.where('skills', arrayContains: _selectedSkills.toLowerCase());
    }

    if (_selectedExperience != 'Any') {
      query = query.where('experienceLevel', isEqualTo: _selectedExperience.toLowerCase());
    }

    if (_openToWorkOnly) {
      query = query.where('openToWork', isEqualTo: true);
    }

    return query.snapshots();
  }

  // ADD THESE METHODS FROM HOME SCREEN
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Save job error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving job: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job removed from saved'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Unsave job error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing job: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        recruiterId: job.recruiterId ?? '',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Applied to ${job.position} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh UI to show "Applied" status
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

  void _showJobDetails(Job job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailScreen(jobId: job.id, job: job),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final roleProvider = Provider.of<RoleProvider>(context);

    // For recruiters, default to candidate search
    if (roleProvider.isRecruiter && _searchMode == 'jobs') {
      _searchMode = 'people';
    }

    ResponsiveHelper responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Search
            Padding(
              padding: EdgeInsets.fromLTRB(
                responsive.padding(16), 
                responsive.padding(16), 
                responsive.padding(16), 
                responsive.padding(12)
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleProvider.isRecruiter ? 'Find Candidates' : 'Explore',
                    style: TextStyle(
                      fontSize: responsive.fontSize(24),
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  SizedBox(height: responsive.height(16)),

                  // Expanded Search Bar
                  _buildExpandedSearchBar(isDarkMode, roleProvider, responsive),
                ],
              ),
            ),

            // Active Filters Summary
            _buildActiveFiltersSummary(isDarkMode, responsive),

            SizedBox(height: responsive.height(12)),

            // Results header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
              child: _buildResultsHeader(isDarkMode, roleProvider, responsive),
            ),

            SizedBox(height: responsive.height(12)),

            // Content List - ROLE-BASED CONTENT
            Expanded(
              child: roleProvider.isRecruiter
                  ? _buildCandidatesList(isDarkMode, responsive)
                  : (_searchMode == 'jobs'
                  ? _buildJobsListFromFirestore(isDarkMode, responsive)
                  : _buildUsersListFromFirestore(isDarkMode, responsive)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSearchBar(bool isDarkMode, RoleProvider roleProvider, ResponsiveHelper responsive) {
    return Row(
      children: [
        // Search Field
        Expanded(
          child: Container(
            height: responsive.height(50),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(responsive.radius(12)),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: responsive.fontSize(16),
              ),
              decoration: InputDecoration(
                hintText: roleProvider.isRecruiter
                    ? 'Search candidates by skills, experience...'
                    : 'Search jobs, people, companies...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: responsive.fontSize(16),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  size: responsive.iconSize(22),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: responsive.iconSize(20),
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: responsive.padding(16), 
                    vertical: responsive.padding(14)
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
        ),

        SizedBox(width: responsive.width(12)),

        // Filter Button
        GestureDetector(
          onTap: () => roleProvider.isRecruiter
              ? _showRecruiterFilterBottomSheet()
              : _showFilterBottomSheet(),
          child: Container(
            height: responsive.height(50),
            width: responsive.height(50),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55),
              borderRadius: BorderRadius.circular(responsive.radius(12)),
            ),
            child: Icon(
              Icons.filter_list,
              size: responsive.iconSize(22),
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersSummary(bool isDarkMode, ResponsiveHelper responsive) {
    final List<String> activeFilters = [];

    // Add search mode
    final roleProvider = Provider.of<RoleProvider>(context, listen: false);
    if (!roleProvider.isRecruiter) {
      activeFilters.add(_searchMode == 'jobs' ? 'Jobs' : 'People');
    } else {
      activeFilters.add('Candidates');
    }

    // Add category if not 'All'
    if (_selectedCategory != 'All') {
      activeFilters.add(_selectedCategory);
    }

    // Add job filters
    if (!roleProvider.isRecruiter && _searchMode == 'jobs') {
      if (_remoteOnly) activeFilters.add('Remote');
      if (_fullTimeOnly) activeFilters.add('Full-time');
      if (_highSalaryOnly) activeFilters.add('High Salary');
      if (_selectedJobType != 'Any') activeFilters.add(_selectedJobType);
      if (_selectedLocation != 'Any') activeFilters.add(_selectedLocation);
    } else if (roleProvider.isRecruiter) {
      // Add recruiter filters
      if (_selectedSkills != 'Any') activeFilters.add(_selectedSkills);
      if (_selectedExperience != 'Any') activeFilters.add(_selectedExperience);
      if (_openToWorkOnly) activeFilters.add('Open to Work');
    } else {
      // Add people filters
      if (_selectedUserType != 'Any') activeFilters.add(_selectedUserType);
      if (_selectedSkills != 'Any') activeFilters.add(_selectedSkills);
    }

    if (activeFilters.isEmpty) return const SizedBox();

    return SizedBox(
      height: responsive.height(40),
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
        scrollDirection: Axis.horizontal,
        children: [
          // Clear All button
          Container(
            margin: EdgeInsets.only(right: responsive.width(8)),
            padding: EdgeInsets.symmetric(
                horizontal: responsive.padding(12), 
                vertical: responsive.padding(6)
            ),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(responsive.radius(20)),
            ),
            child: GestureDetector(
              onTap: _clearAllFilters,
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: responsive.iconSize(14), color: isDarkMode ? Colors.white : Colors.black),
                  SizedBox(width: responsive.width(4)),
                  Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: responsive.fontSize(12),
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Active filters
          ...activeFilters.map((filter) => Container(
            margin: EdgeInsets.only(right: responsive.width(8)),
            padding: EdgeInsets.symmetric(
                horizontal: responsive.padding(12), 
                vertical: responsive.padding(6)
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withOpacity(0.1),
              borderRadius: BorderRadius.circular(responsive.radius(20)),
              border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Text(
                  filter,
                  style: TextStyle(
                    fontSize: responsive.fontSize(12),
                    color: const Color(0xFFFF2D55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: responsive.width(4)),
                GestureDetector(
                  onTap: () => _removeFilter(filter),
                  child: Icon(Icons.close, size: responsive.iconSize(14), color: const Color(0xFFFF2D55)),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  void _removeFilter(String filter) {
    setState(() {
      final roleProvider = Provider.of<RoleProvider>(context, listen: false);

      if (filter == 'Jobs' || filter == 'People' || filter == 'Candidates') {
        // Don't remove the main search mode
        return;
      } else if (filter == _selectedCategory) {
        _selectedCategory = 'All';
      } else if (filter == 'Remote') {
        _remoteOnly = false;
      } else if (filter == 'Full-time') {
        _fullTimeOnly = false;
      } else if (filter == 'High Salary') {
        _highSalaryOnly = false;
      } else if (filter == _selectedJobType) {
        _selectedJobType = 'Any';
      } else if (filter == _selectedLocation) {
        _selectedLocation = 'Any';
      } else if (filter == _selectedUserType) {
        _selectedUserType = 'Any';
      } else if (filter == _selectedSkills) {
        _selectedSkills = 'Any';
      } else if (filter == _selectedExperience) {
        _selectedExperience = 'Any';
      } else if (filter == 'Open to Work') {
        _openToWorkOnly = false;
      }
    });
  }

  Widget _buildResultsHeader(bool isDarkMode, RoleProvider roleProvider, ResponsiveHelper responsive) {
    return StreamBuilder<QuerySnapshot>(
      stream: roleProvider.isRecruiter
          ? _candidatesStream
          : (_searchMode == 'jobs' ? _jobsStream : _usersStream),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        final resultText = roleProvider.isRecruiter
            ? '$count candidates found'
            : _searchMode == 'jobs'
            ? '$count jobs found'
            : '$count people found';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              resultText,
              style: TextStyle(
                fontSize: responsive.fontSize(15),
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            if (count > 0)
              Text(
                roleProvider.isRecruiter
                    ? 'Showing candidates'
                    : 'Showing ${_searchMode == 'jobs' ? 'jobs' : 'people'}',
                style: TextStyle(
                  fontSize: responsive.fontSize(12),
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCandidatesList(bool isDarkMode, ResponsiveHelper responsive) {
    return StreamBuilder<QuerySnapshot>(
      stream: _candidatesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading candidates',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode, responsive: responsive, isRecruiter: true);
        }

        final candidates = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
          itemCount: candidates.length,
          itemBuilder: (context, index) {
            final doc = candidates[index];
            final candidate = doc.data() as Map<String, dynamic>;
            return _buildCandidateCard(doc.id, candidate, isDarkMode, responsive);
          },
        );
      },
    );
  }

  Widget _buildJobsListFromFirestore(bool isDarkMode, ResponsiveHelper responsive) {
    return StreamBuilder<QuerySnapshot>(
      stream: _jobsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading jobs',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode, responsive: responsive);
        }

        final jobs = snapshot.data!.docs;

        List<QueryDocumentSnapshot> filteredJobs = jobs;
        if (_highSalaryOnly) {
          filteredJobs = jobs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final salary = data['salary'] ?? '';
            return salary.toString().contains('\$100,000') ||
                salary.toString().contains('100k') ||
                salary.toString().contains('120,000') ||
                salary.toString().contains('120k');
          }).toList();
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
          itemCount: filteredJobs.length,
          itemBuilder: (context, index) {
            final doc = filteredJobs[index];
            final jobData = doc.data() as Map<String, dynamic>;

            // ✅ FIXED: Convert Firestore document to Job model
            final job = Job(
              id: doc.id,
              position: jobData['position'] ?? '',
              company: jobData['company'] ?? '',
              logo: jobData['logo'] ?? '',
              logoColor: jobData['logoColor'] ?? 0xFFFF2D55,
              country: jobData['country'] ?? '',
              location: jobData['location'] ?? 'Remote',
              isRemote: jobData['isRemote'] ?? false,
              salary: jobData['salary'] ?? '',
              skills: jobData['skills'] is List
                  ? List<String>.from(jobData['skills'])
                  : [],
              // ❌ REMOVE THIS LINE: postedTime: _getTimeAgo((jobData['postedAt'] as Timestamp).toDate()),
              postedAt: jobData['postedAt'] as Timestamp?, // ✅ ADD THIS - Pass the timestamp
              isFeatured: jobData['isFeatured'] ?? false,
              recruiterId: jobData['recruiterId'] ?? '',
              companyDescription: jobData['companyDescription'] ?? '',
              description: jobData['description'] ?? '',
              requirements: jobData['requirements'] is List
                  ? List<String>.from(jobData['requirements'])
                  : [],
              searchKeywords: jobData['searchKeywords'] is List
                  ? List<String>.from(jobData['searchKeywords'])
                  : [],
              type: jobData['type'] ?? 'Full-time',
              jobType: jobData['jobType'] ?? jobData['type'] ?? 'Full-time',
              status: jobData['status'] ?? 'active',
              applications: jobData['applications'] ?? 0,
            );

            return _buildJobCard(job, isDarkMode, responsive);
          },
        );
      },
    );
  }

  Widget _buildUsersListFromFirestore(bool isDarkMode, ResponsiveHelper responsive) {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading users',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(isDarkMode, responsive: responsive);
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final user = doc.data() as Map<String, dynamic>;
            if (doc.id == _auth.currentUser?.uid) {
              return const SizedBox.shrink();
            }
            return _buildUserCard(doc.id, user, isDarkMode, responsive);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode, {bool isRecruiter = false, required ResponsiveHelper responsive}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: responsive.iconSize(56),
            color: Colors.grey.shade400,
          ),
          SizedBox(height: responsive.height(12)),
          Text(
            isRecruiter ? 'No candidates found'
                : (_searchMode == 'jobs' ? 'No jobs found' : 'No people found'),
            style: TextStyle(
              fontSize: responsive.fontSize(16),
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: responsive.height(6)),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: responsive.fontSize(13),
              color: Colors.grey.shade500,
            ),
          ),
          SizedBox(height: responsive.height(16)),
          ElevatedButton(
            onPressed: _clearAllFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D55),
              padding: EdgeInsets.symmetric(
                  horizontal: responsive.padding(24), 
                  vertical: responsive.padding(12)
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(responsive.radius(10)),
              ),
            ),
            child: const Text(
              'Clear Filters',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Job Card with save and apply functionality
  // UPDATED: Job Card with save and apply functionality
  Widget _buildJobCard(Job job, bool isDarkMode, ResponsiveHelper responsive) {
    return GestureDetector(
      onTap: () => _showJobDetails(job),
      child: Container(
        margin: EdgeInsets.only(bottom: responsive.height(12)),
        padding: EdgeInsets.all(responsive.padding(14)),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(responsive.radius(14)),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
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
                // Logo
                Container(
                  width: responsive.width(38),
                  height: responsive.width(38),
                  decoration: BoxDecoration(
                    color: Color(job.logoColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(responsive.radius(10)),
                  ),
                  child: Center(
                    child: Text(
                      job.logo.isNotEmpty ? job.logo : job.company.isNotEmpty ? job.company[0].toUpperCase() : 'C',
                      style: TextStyle(
                        fontSize: responsive.fontSize(16),
                        fontWeight: FontWeight.bold,
                        color: Color(job.logoColor),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: responsive.width(10)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.position,
                        style: TextStyle(
                          fontSize: responsive.fontSize(15),
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: responsive.height(2)),
                      Text(
                        job.company,
                        style: TextStyle(
                          fontSize: responsive.fontSize(13),
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Save/Bookmark button
                StreamBuilder<bool>(
                  stream: Stream.fromFuture(FirestoreService.isJobSaved(job.id)),
                  builder: (context, snapshot) {
                    final isSaved = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: () => isSaved ? _unsaveJob(job.id) : _saveJob(job.id),
                      child: Container(
                        padding: EdgeInsets.all(responsive.padding(8)),
                        decoration: BoxDecoration(
                          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(responsive.radius(8)),
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_outline,
                          size: responsive.iconSize(20),
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
            SizedBox(height: responsive.height(10)),

            // Location and Type
            Wrap(
              spacing: responsive.width(8),
              runSpacing: responsive.height(6),
              children: [
                _buildInfoChip(Icons.location_on_outlined, job.country, isDarkMode, responsive),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: responsive.padding(8), 
                      vertical: responsive.padding(4)
                  ),
                  decoration: BoxDecoration(
                    color: job.isRemote
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(responsive.radius(6)),
                  ),
                  child: Text(
                    job.location,
                    style: TextStyle(
                      fontSize: responsive.fontSize(10),
                      fontWeight: FontWeight.w600,
                      color: job.isRemote ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            // Skills
            if (job.skills.isNotEmpty) ...[
              SizedBox(height: responsive.height(8)),
              Wrap(
                spacing: responsive.width(6),
                runSpacing: responsive.height(6),
                children: job.skills.take(3).map((skill) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: responsive.padding(8), 
                        vertical: responsive.padding(4)
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(responsive.radius(6)),
                    ),
                    child: Text(
                      skill,
                      style: TextStyle(
                        fontSize: responsive.fontSize(10),
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            SizedBox(height: responsive.height(10)),

            // Salary, Time, and Apply Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.paid_outlined,
                      size: responsive.iconSize(14),
                      color: const Color(0xFFFF2D55),
                    ),
                    SizedBox(width: responsive.width(4)),
                    Text(
                      job.salary,
                      style: TextStyle(
                        fontSize: responsive.fontSize(13),
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFF2D55),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      job.postedTime,
                      style: TextStyle(
                        fontSize: responsive.fontSize(11),
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(width: responsive.width(12)),
                    // Apply Button
                    FutureBuilder<bool>(
                      future: _applicationService.hasApplied(job.id),
                      builder: (context, snapshot) {
                        final hasApplied = snapshot.data ?? false;
                        return GestureDetector(
                          onTap: hasApplied ? null : () => _applyForJob(job),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: responsive.padding(16), 
                                vertical: responsive.padding(8)
                            ),
                            decoration: BoxDecoration(
                              color: hasApplied
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFFF2D55),
                              borderRadius: BorderRadius.circular(responsive.radius(8)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasApplied ? Icons.check : Icons.send,
                                  size: responsive.iconSize(14),
                                  color: Colors.white,
                                ),
                                SizedBox(width: responsive.width(4)),
                                Text(
                                  hasApplied ? 'Applied' : 'Apply',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: responsive.fontSize(12),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateCard(String userId, Map<String, dynamic> candidate, bool isDarkMode, ResponsiveHelper responsive) {
    final name = candidate['name']?.toString().trim() ?? 'Unknown Candidate';
    final title = candidate['title']?.toString().trim() ?? 'No title';
    final skills = candidate['skills'] is List
        ? (candidate['skills'] as List).take(3).map((s) => s.toString()).toList()
        : [];
    final experience = candidate['experience']?.toString() ?? 'Not specified';
    final openToWork = candidate['openToWork'] == true;
    final location = candidate['location']?.toString() ?? 'Location not specified';

    return GestureDetector(
      onTap: () => _showCandidateProfile(userId, candidate, isDarkMode),
      child: Container(
        margin: EdgeInsets.only(bottom: responsive.height(12)),
        padding: EdgeInsets.all(responsive.padding(14)),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(responsive.radius(14)),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
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
                Container(
                  width: responsive.width(45),
                  height: responsive.width(45),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF2D55).withOpacity(0.1),
                  ),
                  child: candidate['profileImage'] != null
                      ? CircleAvatar(backgroundImage: NetworkImage(candidate['profileImage']!))
                      : Icon(Icons.person, size: responsive.iconSize(22), color: const Color(0xFFFF2D55)),
                ),
                SizedBox(width: responsive.width(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: responsive.fontSize(15),
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: responsive.height(2)),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: responsive.fontSize(13),
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildInfoChip(Icons.work_outline, experience, isDarkMode, responsive),
                          SizedBox(width: responsive.width(12)),
                          _buildInfoChip(Icons.location_on_outlined, location, isDarkMode, responsive),
                        ],
                      ),
                    ],
                  ),
                ),
                if (openToWork)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Open to work',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ),
              ],
            ),

            if (skills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Skills:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: skills.map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      skill,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.blue.shade200 : Colors.blue.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _messageCandidate(candidate),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    side: const BorderSide(color: Color(0xFFFF2D55)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.message_outlined,
                        size: 14,
                        color: const Color(0xFFFF2D55),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Message',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFFFF2D55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _viewFullProfile(candidate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'View Profile',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
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

  Widget _buildInfoChip(IconData icon, String text, bool isDarkMode, ResponsiveHelper responsive) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: responsive.iconSize(14),
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        SizedBox(width: responsive.width(4)),
        Text(
          text,
          style: TextStyle(
            fontSize: responsive.fontSize(11),
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> user, bool isDarkMode, ResponsiveHelper responsive) {
    final name = user['name']?.toString().trim() ?? 'Unknown User';
    final title = user['title']?.toString().trim() ?? 'No title';
    final userType = user['userType']?.toString().trim() ?? 'user';

    return GestureDetector(
      onTap: () => _showUserProfile(userId, user, isDarkMode),
      child: Container(
        margin: EdgeInsets.only(bottom: responsive.height(12)),
        padding: EdgeInsets.all(responsive.padding(14)),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(responsive.radius(14)),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: responsive.width(45),
              height: responsive.width(45),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF2D55).withOpacity(0.1),
              ),
              child: user['profileImage'] != null
                  ? CircleAvatar(backgroundImage: NetworkImage(user['profileImage']!))
                  : Icon(Icons.person, size: responsive.iconSize(22), color: const Color(0xFFFF2D55)),
            ),
            SizedBox(width: responsive.width(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: responsive.fontSize(15),
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.height(2)),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: responsive.fontSize(13),
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: responsive.height(6)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: responsive.padding(8), 
                        vertical: responsive.padding(3)
                    ),
                    decoration: BoxDecoration(
                      color: _getUserTypeColor(userType).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(responsive.radius(6)),
                    ),
                    child: Text(
                      userType.toUpperCase(),
                      style: TextStyle(
                        fontSize: responsive.fontSize(9),
                        color: _getUserTypeColor(userType),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: responsive.iconSize(14),
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Color _getUserTypeColor(String userType) {
    switch (userType.toLowerCase()) {
      case 'recruiter':
        return Colors.green;
      case 'job_seeker':
        return Colors.blue;
      case 'student':
        return Colors.orange;
      default:
        return const Color(0xFFFF2D55);
    }
  }

  void _showRecruiterFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        ResponsiveHelper responsive = ResponsiveHelper(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(responsive.radius(20))),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: EdgeInsets.only(top: responsive.height(10), bottom: responsive.height(10)),
                        width: responsive.width(40),
                        height: responsive.height(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(responsive.radius(2)),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: responsive.padding(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Candidates',
                              style: TextStyle(
                                fontSize: responsive.fontSize(20),
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _clearAllFilters();
                                setModalState(() {});
                              },
                              child: const Text(
                                'Clear All',
                                style: TextStyle(color: Color(0xFFFF2D55)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Content
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: responsive.padding(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Categories
                              _buildFilterSection('Categories', [
                                _buildFilterChip(
                                  'All',
                                  _selectedCategory == 'All',
                                      () {
                                    setState(() => _selectedCategory = 'All');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Developers',
                                  _selectedCategory == 'Developers',
                                      () {
                                    setState(() => _selectedCategory = 'Developers');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Designers',
                                  _selectedCategory == 'Designers',
                                      () {
                                    setState(() => _selectedCategory = 'Designers');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Managers',
                                  _selectedCategory == 'Managers',
                                      () {
                                    setState(() => _selectedCategory = 'Managers');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Students',
                                  _selectedCategory == 'Students',
                                      () {
                                    setState(() => _selectedCategory = 'Students');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                              ], responsive),

                              SizedBox(height: responsive.height(24)),

                              // Skills
                              _buildFilterSection('Skills', [
                                _buildFilterChip(
                                  'Any',
                                  _selectedSkills == 'Any',
                                      () {
                                    setState(() => _selectedSkills = 'Any');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Flutter',
                                  _selectedSkills == 'Flutter',
                                      () {
                                    setState(() => _selectedSkills = 'Flutter');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'React',
                                  _selectedSkills == 'React',
                                      () {
                                    setState(() => _selectedSkills = 'React');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'UI/UX',
                                  _selectedSkills == 'UI/UX',
                                      () {
                                    setState(() => _selectedSkills = 'UI/UX');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Python',
                                  _selectedSkills == 'Python',
                                      () {
                                    setState(() => _selectedSkills = 'Python');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Java',
                                  _selectedSkills == 'Java',
                                      () {
                                    setState(() => _selectedSkills = 'Java');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                              ], responsive),

                              SizedBox(height: responsive.height(24)),

                              // Experience Level
                              _buildFilterSection('Experience Level', [
                                _buildFilterChip(
                                  'Any',
                                  _selectedExperience == 'Any',
                                      () {
                                    setState(() => _selectedExperience = 'Any');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Entry Level',
                                  _selectedExperience == 'Entry Level',
                                      () {
                                    setState(() => _selectedExperience = 'Entry Level');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Mid Level',
                                  _selectedExperience == 'Mid Level',
                                      () {
                                    setState(() => _selectedExperience = 'Mid Level');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                                _buildFilterChip(
                                  'Senior Level',
                                  _selectedExperience == 'Senior Level',
                                      () {
                                    setState(() => _selectedExperience = 'Senior Level');
                                    setModalState(() {});
                                  },
                                  responsive,
                                ),
                              ], responsive),

                              SizedBox(height: responsive.height(20)),

                              // Additional Options
                              _buildFilterOption(
                                'Only show open to work',
                                _openToWorkOnly,
                                    (value) {
                                  setState(() => _openToWorkOnly = value!);
                                  setModalState(() {});
                                },
                                responsive,
                              ),

                              const SizedBox(height: 70),
                            ],
                          ),
                        ),
                      ),

                      // Apply Button
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          responsive.padding(20),
                          responsive.padding(10),
                          responsive.padding(20),
                          MediaQuery.of(context).padding.bottom + responsive.padding(10),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: responsive.radius(8),
                              offset: Offset(0, -responsive.height(2)),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2D55),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: responsive.fontSize(15),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        ResponsiveHelper responsive = ResponsiveHelper(context);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(responsive.radius(20))),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: EdgeInsets.only(top: responsive.height(10), bottom: responsive.height(10)),
                        width: responsive.width(40),
                        height: responsive.height(4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(responsive.radius(2)),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: responsive.padding(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: responsive.fontSize(20),
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _clearAllFilters();
                                setModalState(() {});
                              },
                              child: const Text(
                                'Clear All',
                                style: TextStyle(color: Color(0xFFFF2D55)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: responsive.height(16)),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: responsive.padding(20)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search Mode Selection
                              _buildFilterSection('Search For', [
                                _buildModeOption('Jobs', Icons.work_outline, _searchMode == 'jobs', () {
                                  setState(() => _searchMode = 'jobs');
                                  setModalState(() {});
                                }, responsive),
                                _buildModeOption('People', Icons.people_outline, _searchMode == 'people', () {
                                  setState(() => _searchMode = 'people');
                                  setModalState(() {});
                                }, responsive),
                              ], responsive),

                              SizedBox(height: responsive.height(24)),

                              // Categories based on search mode
                              if (_searchMode == 'jobs')
                                _buildJobCategories(setModalState, responsive)
                              else
                                _buildPeopleCategories(setModalState, responsive),

                              SizedBox(height: responsive.height(24)),

                              // Additional filters based on search mode
                              if (_searchMode == 'jobs')
                                ..._buildJobSpecificFilters(setModalState, responsive)
                              else
                                ..._buildPeopleSpecificFilters(setModalState, responsive),

                              SizedBox(height: responsive.height(70)),
                            ],
                          ),
                        ),
                      ),

                      // Apply Button
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          responsive.padding(20),
                          responsive.padding(10),
                          responsive.padding(20),
                          MediaQuery.of(context).padding.bottom + responsive.padding(10),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2D55),
                            minimumSize: Size(double.infinity, responsive.height(48)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: responsive.fontSize(15),
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSection(String title, List<Widget> options, ResponsiveHelper responsive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: responsive.fontSize(16),
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: responsive.height(12)),
        Wrap(
          spacing: responsive.width(12),
          runSpacing: responsive.height(12),
          children: options,
        ),
      ],
    );
  }

  Widget _buildModeOption(String label, IconData icon, bool isSelected, VoidCallback onTap, ResponsiveHelper responsive) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: responsive.width(120),
        padding: EdgeInsets.all(responsive.padding(12)),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(responsive.radius(12)),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: responsive.iconSize(24),
            ),
            SizedBox(height: responsive.height(8)),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.fontSize(14),
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCategories(StateSetter? setModalState, ResponsiveHelper responsive) {
    final jobCategories = ['All', 'Tech', 'Design', 'Marketing', 'Finance', 'Remote'];

    return _buildFilterSection('Job Categories', [
      ...jobCategories.map((category) => _buildFilterChip(
        category,
        _selectedCategory == category,
            () {
          setState(() => _selectedCategory = category);
          setModalState?.call(() {});
        }, responsive
      )).toList(),
    ], responsive);
  }

  Widget _buildPeopleCategories(StateSetter? setModalState, ResponsiveHelper responsive) {
    final peopleCategories = ['All', 'Developers', 'Designers', 'Managers', 'Recruiters', 'Students'];

    return _buildFilterSection('People Categories', [
      ...peopleCategories.map((category) => _buildFilterChip(
        category,
        _selectedCategory == category,
            () {
          setState(() => _selectedCategory = category);
          setModalState?.call(() {});
        }, responsive
      )).toList(),
    ], responsive);
  }

  List<Widget> _buildJobSpecificFilters(StateSetter? setModalState, ResponsiveHelper responsive) {
    return [
      _buildFilterSection('Job Type', [
        _buildFilterChip('Any', _selectedJobType == 'Any', () {
          setState(() => _selectedJobType = 'Any');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Full-time', _selectedJobType == 'Full-time', () {
          setState(() => _selectedJobType = 'Full-time');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Part-time', _selectedJobType == 'Part-time', () {
          setState(() => _selectedJobType = 'Part-time');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Contract', _selectedJobType == 'Contract', () {
          setState(() => _selectedJobType = 'Contract');
          setModalState?.call(() {});
        }, responsive),
      ], responsive),
      SizedBox(height: responsive.height(20)),
      _buildFilterSection('Location', [
        _buildFilterChip('Any', _selectedLocation == 'Any', () {
          setState(() => _selectedLocation = 'Any');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Remote', _selectedLocation == 'Remote', () {
          setState(() => _selectedLocation = 'Remote');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('On-site', _selectedLocation == 'On-site', () {
          setState(() => _selectedLocation = 'On-site');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Hybrid', _selectedLocation == 'Hybrid', () {
          setState(() => _selectedLocation = 'Hybrid');
          setModalState?.call(() {});
        }, responsive),
      ], responsive),
      SizedBox(height: responsive.height(20)),
      _buildFilterOption('Remote Jobs Only', _remoteOnly, (value) {
        setState(() => _remoteOnly = value!);
        setModalState?.call(() {});
      }, responsive),
      _buildFilterOption('High Salary Jobs', _highSalaryOnly, (value) {
        setState(() => _highSalaryOnly = value!);
        setModalState?.call(() {});
      }, responsive),
    ];
  }

  List<Widget> _buildPeopleSpecificFilters(StateSetter? setModalState, ResponsiveHelper responsive) {
    return [
      _buildFilterSection('User Type', [
        _buildFilterChip('Any', _selectedUserType == 'Any', () {
          setState(() => _selectedUserType = 'Any');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Recruiter', _selectedUserType == 'Recruiter', () {
          setState(() => _selectedUserType = 'Recruiter');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Job Seeker', _selectedUserType == 'Job Seeker', () {
          setState(() => _selectedUserType = 'Job Seeker');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Student', _selectedUserType == 'Student', () {
          setState(() => _selectedUserType = 'Student');
          setModalState?.call(() {});
        }, responsive),
      ], responsive),
      SizedBox(height: responsive.height(20)),
      _buildFilterSection('Skills', [
        _buildFilterChip('Any', _selectedSkills == 'Any', () {
          setState(() => _selectedSkills = 'Any');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Flutter', _selectedSkills == 'Flutter', () {
          setState(() => _selectedSkills = 'Flutter');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('UI/UX', _selectedSkills == 'UI/UX', () {
          setState(() => _selectedSkills = 'UI/UX');
          setModalState?.call(() {});
        }, responsive),
        _buildFilterChip('Management', _selectedSkills == 'Management', () {
          setState(() => _selectedSkills = 'Management');
          setModalState?.call(() {});
        }, responsive),
      ], responsive),
    ];
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, ResponsiveHelper responsive) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: responsive.padding(16), 
            vertical: responsive.padding(10)
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(responsive.radius(20)),
          border: Border.all(
            color: selected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: responsive.fontSize(14),
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, bool value, ValueChanged<bool?> onChanged, ResponsiveHelper responsive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: responsive.padding(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: responsive.fontSize(15),
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFFF2D55),
          ),
        ],
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = 'All';
      _searchController.clear();
      _remoteOnly = false;
      _fullTimeOnly = false;
      _highSalaryOnly = false;
      _selectedLocation = 'Any';
      _selectedJobType = 'Any';
      _selectedUserType = 'Any';
      _selectedSkills = 'Any';
      _selectedExperience = 'Any';
      _openToWorkOnly = false;
    });
  }

  void _showUserProfile(String userId, Map<String, dynamic> user, bool isDarkMode) {
    print('Show user profile: ${user['name']}');
  }

  void _showCandidateProfile(String userId, Map<String, dynamic> candidate, bool isDarkMode) {
    print('Show candidate profile: ${candidate['name']}');
  }

  void _messageCandidate(Map<String, dynamic> candidate) {
    print('Message candidate: ${candidate['name']}');
    // Implement messaging functionality
  }

  void _viewFullProfile(Map<String, dynamic> candidate) {
    print('View full profile of: ${candidate['name']}');
    // Navigate to full profile screen
  }
}