// lib/navigation/explore_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/role_provider.dart'; // ADD THIS

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
    Query query = _firestore.collection('jobs');

    if (_searchController.text.isNotEmpty) {
      query = query.where('searchKeywords',
          arrayContains: _searchController.text.toLowerCase());
    }

    if (_selectedCategory != 'All') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }

    if (_remoteOnly) {
      query = query.where('isRemote', isEqualTo: true);
    }

    if (_selectedJobType != 'Any') {
      query = query.where('type', isEqualTo: _selectedJobType);
    }

    if (_selectedLocation != 'Any') {
      query = query.where('location', isEqualTo: _selectedLocation);
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final roleProvider = Provider.of<RoleProvider>(context); // ADD THIS

    // For recruiters, default to candidate search
    if (roleProvider.isRecruiter && _searchMode == 'jobs') {
      _searchMode = 'people';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleProvider.isRecruiter ? 'Find Candidates' : 'Explore', // ROLE-BASED TITLE
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Expanded Search Bar
                  _buildExpandedSearchBar(isDarkMode, roleProvider),
                ],
              ),
            ),

            // Active Filters Summary
            _buildActiveFiltersSummary(isDarkMode),

            const SizedBox(height: 12),

            // Results header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildResultsHeader(isDarkMode, roleProvider),
            ),

            const SizedBox(height: 12),

            // Content List - ROLE-BASED CONTENT
            Expanded(
              child: roleProvider.isRecruiter
                  ? _buildCandidatesList(isDarkMode)
                  : (_searchMode == 'jobs'
                  ? _buildJobsListFromFirestore(isDarkMode)
                  : _buildUsersListFromFirestore(isDarkMode)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSearchBar(bool isDarkMode, RoleProvider roleProvider) {
    return Row(
      children: [
        // Search Field
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: roleProvider.isRecruiter
                    ? 'Search candidates by skills, experience...'
                    : 'Search jobs, people, companies...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 20,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Filter Button
        GestureDetector(
          onTap: () => roleProvider.isRecruiter
              ? _showRecruiterFilterBottomSheet()
              : _showFilterBottomSheet(),
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.filter_list,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFiltersSummary(bool isDarkMode) {
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
      height: 40,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          // Clear All button
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: GestureDetector(
              onTap: _clearAllFilters,
              child: Row(
                children: [
                  Icon(Icons.clear_all, size: 14, color: isDarkMode ? Colors.white : Colors.black),
                  const SizedBox(width: 4),
                  Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Active filters
          ...activeFilters.map((filter) => Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFF2D55).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Text(
                  filter,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFFF2D55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _removeFilter(filter),
                  child: Icon(Icons.close, size: 14, color: const Color(0xFFFF2D55)),
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

  Widget _buildResultsHeader(bool isDarkMode, RoleProvider roleProvider) {
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
                fontSize: 15,
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
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCandidatesList(bool isDarkMode) {
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
          return _buildEmptyState(isDarkMode, isRecruiter: true);
        }

        final candidates = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: candidates.length,
          itemBuilder: (context, index) {
            final doc = candidates[index];
            final candidate = doc.data() as Map<String, dynamic>;
            return _buildCandidateCard(doc.id, candidate, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildJobsListFromFirestore(bool isDarkMode) {
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
          return _buildEmptyState(isDarkMode);
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filteredJobs.length,
          itemBuilder: (context, index) {
            final doc = filteredJobs[index];
            final job = doc.data() as Map<String, dynamic>;
            return _buildJobCard(doc.id, job, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildUsersListFromFirestore(bool isDarkMode) {
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
          return _buildEmptyState(isDarkMode);
        }

        final users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final doc = users[index];
            final user = doc.data() as Map<String, dynamic>;
            if (doc.id == _auth.currentUser?.uid) {
              return const SizedBox.shrink();
            }
            return _buildUserCard(doc.id, user, isDarkMode);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDarkMode, {bool isRecruiter = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            isRecruiter ? 'No candidates found'
                : (_searchMode == 'jobs' ? 'No jobs found' : 'No people found'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _clearAllFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D55),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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

  Widget _buildCandidateCard(String userId, Map<String, dynamic> candidate, bool isDarkMode) {
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF2D55).withOpacity(0.1),
                  ),
                  child: candidate['profileImage'] != null
                      ? CircleAvatar(backgroundImage: NetworkImage(candidate['profileImage']!))
                      : const Icon(Icons.person, size: 22, color: Color(0xFFFF2D55)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildInfoChip(Icons.work_outline, experience, isDarkMode),
                          const SizedBox(width: 12),
                          _buildInfoChip(Icons.location_on_outlined, location, isDarkMode),
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

  Widget _buildJobCard(String docId, Map<String, dynamic> job, bool isDarkMode) {
    final title = job['position']?.toString().trim() ?? 'No Title';
    final company = job['company']?.toString().trim() ?? 'Unknown Company';
    final salary = job['salary']?.toString().trim() ?? 'Not specified';
    final location = job['country']?.toString().trim() ?? 'Location not specified';
    final isRemote = job['isRemote'] == true;
    final locationType = job['location']?.toString() ?? (isRemote ? 'Remote' : 'On-site');

    final postedDate = job['postedAt'] != null
        ? (job['postedAt'] as Timestamp).toDate()
        : DateTime.now();
    final timeAgo = _getTimeAgo(postedDate);

    return GestureDetector(
      onTap: () => _showJobDetails(job, isDarkMode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: job['logoColor'] != null
                        ? Color(job['logoColor']).withOpacity(0.1)
                        : const Color(0xFFFF2D55).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      job['logo']?.toString() ??
                          (company.isNotEmpty ? company[0].toUpperCase() : 'C'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: job['logoColor'] != null
                            ? Color(job['logoColor'])
                            : const Color(0xFFFF2D55),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        company,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.bookmark_border,
                  size: 20,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Location and Type
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildInfoChip(Icons.location_on_outlined, location, isDarkMode),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRemote
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    locationType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isRemote ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),

            // Skills
            if (job['skills'] != null && job['skills'] is List && (job['skills'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (job['skills'] as List).take(3).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      skill.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 10),

            // Salary and Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.paid_outlined,
                      size: 14,
                      color: const Color(0xFFFF2D55),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      salary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF2D55),
                      ),
                    ),
                  ],
                ),
                Text(
                  timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(String userId, Map<String, dynamic> user, bool isDarkMode) {
    final name = user['name']?.toString().trim() ?? 'Unknown User';
    final title = user['title']?.toString().trim() ?? 'No title';
    final userType = user['userType']?.toString().trim() ?? 'user';

    return GestureDetector(
      onTap: () => _showUserProfile(userId, user, isDarkMode),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF2D55).withOpacity(0.1),
              ),
              child: user['profileImage'] != null
                  ? CircleAvatar(backgroundImage: NetworkImage(user['profileImage']!))
                  : const Icon(Icons.person, size: 22, color: Color(0xFFFF2D55)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getUserTypeColor(userType).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      userType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
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
              size: 14,
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Candidates',
                              style: TextStyle(
                                fontSize: 20,
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
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                ),
                                _buildFilterChip(
                                  'Developers',
                                  _selectedCategory == 'Developers',
                                      () {
                                    setState(() => _selectedCategory = 'Developers');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Designers',
                                  _selectedCategory == 'Designers',
                                      () {
                                    setState(() => _selectedCategory = 'Designers');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Managers',
                                  _selectedCategory == 'Managers',
                                      () {
                                    setState(() => _selectedCategory = 'Managers');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Students',
                                  _selectedCategory == 'Students',
                                      () {
                                    setState(() => _selectedCategory = 'Students');
                                    setModalState(() {});
                                  },
                                ),
                              ]),

                              const SizedBox(height: 24),

                              // Skills
                              _buildFilterSection('Skills', [
                                _buildFilterChip(
                                  'Any',
                                  _selectedSkills == 'Any',
                                      () {
                                    setState(() => _selectedSkills = 'Any');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Flutter',
                                  _selectedSkills == 'Flutter',
                                      () {
                                    setState(() => _selectedSkills = 'Flutter');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'React',
                                  _selectedSkills == 'React',
                                      () {
                                    setState(() => _selectedSkills = 'React');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'UI/UX',
                                  _selectedSkills == 'UI/UX',
                                      () {
                                    setState(() => _selectedSkills = 'UI/UX');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Python',
                                  _selectedSkills == 'Python',
                                      () {
                                    setState(() => _selectedSkills = 'Python');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Java',
                                  _selectedSkills == 'Java',
                                      () {
                                    setState(() => _selectedSkills = 'Java');
                                    setModalState(() {});
                                  },
                                ),
                              ]),

                              const SizedBox(height: 24),

                              // Experience Level
                              _buildFilterSection('Experience Level', [
                                _buildFilterChip(
                                  'Any',
                                  _selectedExperience == 'Any',
                                      () {
                                    setState(() => _selectedExperience = 'Any');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Entry Level',
                                  _selectedExperience == 'Entry Level',
                                      () {
                                    setState(() => _selectedExperience = 'Entry Level');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Mid Level',
                                  _selectedExperience == 'Mid Level',
                                      () {
                                    setState(() => _selectedExperience = 'Mid Level');
                                    setModalState(() {});
                                  },
                                ),
                                _buildFilterChip(
                                  'Senior Level',
                                  _selectedExperience == 'Senior Level',
                                      () {
                                    setState(() => _selectedExperience = 'Senior Level');
                                    setModalState(() {});
                                  },
                                ),
                              ]),

                              const SizedBox(height: 20),

                              // Additional Options
                              _buildFilterOption(
                                'Only show open to work',
                                _openToWorkOnly,
                                    (value) {
                                  setState(() => _openToWorkOnly = value!);
                                  setModalState(() {});
                                },
                              ),

                              const SizedBox(height: 70),
                            ],
                          ),
                        ),
                      ),

                      // Apply Button
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          10,
                          20,
                          MediaQuery.of(context).padding.bottom + 10,
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
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 15,
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filters',
                              style: TextStyle(
                                fontSize: 20,
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
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Search Mode Selection
                              _buildFilterSection('Search For', [
                                _buildModeOption('Jobs', Icons.work_outline, _searchMode == 'jobs', () {
                                  setState(() => _searchMode = 'jobs');
                                  setModalState(() {});
                                }),
                                _buildModeOption('People', Icons.people_outline, _searchMode == 'people', () {
                                  setState(() => _searchMode = 'people');
                                  setModalState(() {});
                                }),
                              ]),

                              const SizedBox(height: 24),

                              // Categories based on search mode
                              if (_searchMode == 'jobs')
                                _buildJobCategories(setModalState)
                              else
                                _buildPeopleCategories(setModalState),

                              const SizedBox(height: 24),

                              // Additional filters based on search mode
                              if (_searchMode == 'jobs')
                                ..._buildJobSpecificFilters(setModalState)
                              else
                                ..._buildPeopleSpecificFilters(setModalState),

                              const SizedBox(height: 70),
                            ],
                          ),
                        ),
                      ),

                      // Apply Button
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          10,
                          20,
                          MediaQuery.of(context).padding.bottom + 10,
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
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              fontSize: 15,
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

  Widget _buildFilterSection(String title, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options,
        ),
      ],
    );
  }

  Widget _buildModeOption(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCategories(StateSetter? setModalState) {
    final jobCategories = ['All', 'Tech', 'Design', 'Marketing', 'Finance', 'Remote'];

    return _buildFilterSection('Job Categories', [
      ...jobCategories.map((category) => _buildFilterChip(
        category,
        _selectedCategory == category,
            () {
          setState(() => _selectedCategory = category);
          setModalState?.call(() {});
        },
      )).toList(),
    ]);
  }

  Widget _buildPeopleCategories(StateSetter? setModalState) {
    final peopleCategories = ['All', 'Developers', 'Designers', 'Managers', 'Recruiters', 'Students'];

    return _buildFilterSection('People Categories', [
      ...peopleCategories.map((category) => _buildFilterChip(
        category,
        _selectedCategory == category,
            () {
          setState(() => _selectedCategory = category);
          setModalState?.call(() {});
        },
      )).toList(),
    ]);
  }

  List<Widget> _buildJobSpecificFilters(StateSetter? setModalState) {
    return [
      _buildFilterSection('Job Type', [
        _buildFilterChip('Any', _selectedJobType == 'Any', () {
          setState(() => _selectedJobType = 'Any');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Full-time', _selectedJobType == 'Full-time', () {
          setState(() => _selectedJobType = 'Full-time');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Part-time', _selectedJobType == 'Part-time', () {
          setState(() => _selectedJobType = 'Part-time');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Contract', _selectedJobType == 'Contract', () {
          setState(() => _selectedJobType = 'Contract');
          setModalState?.call(() {});
        }),
      ]),
      const SizedBox(height: 20),
      _buildFilterSection('Location', [
        _buildFilterChip('Any', _selectedLocation == 'Any', () {
          setState(() => _selectedLocation = 'Any');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Remote', _selectedLocation == 'Remote', () {
          setState(() => _selectedLocation = 'Remote');
          setModalState?.call(() {});
        }),
        _buildFilterChip('On-site', _selectedLocation == 'On-site', () {
          setState(() => _selectedLocation = 'On-site');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Hybrid', _selectedLocation == 'Hybrid', () {
          setState(() => _selectedLocation = 'Hybrid');
          setModalState?.call(() {});
        }),
      ]),
      const SizedBox(height: 20),
      _buildFilterOption('Remote Jobs Only', _remoteOnly, (value) {
        setState(() => _remoteOnly = value!);
        setModalState?.call(() {});
      }),
      _buildFilterOption('High Salary Jobs', _highSalaryOnly, (value) {
        setState(() => _highSalaryOnly = value!);
        setModalState?.call(() {});
      }),
    ];
  }

  List<Widget> _buildPeopleSpecificFilters(StateSetter? setModalState) {
    return [
      _buildFilterSection('User Type', [
        _buildFilterChip('Any', _selectedUserType == 'Any', () {
          setState(() => _selectedUserType = 'Any');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Recruiter', _selectedUserType == 'Recruiter', () {
          setState(() => _selectedUserType = 'Recruiter');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Job Seeker', _selectedUserType == 'Job Seeker', () {
          setState(() => _selectedUserType = 'Job Seeker');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Student', _selectedUserType == 'Student', () {
          setState(() => _selectedUserType = 'Student');
          setModalState?.call(() {});
        }),
      ]),
      const SizedBox(height: 20),
      _buildFilterSection('Skills', [
        _buildFilterChip('Any', _selectedSkills == 'Any', () {
          setState(() => _selectedSkills = 'Any');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Flutter', _selectedSkills == 'Flutter', () {
          setState(() => _selectedSkills = 'Flutter');
          setModalState?.call(() {});
        }),
        _buildFilterChip('UI/UX', _selectedSkills == 'UI/UX', () {
          setState(() => _selectedSkills = 'UI/UX');
          setModalState?.call(() {});
        }),
        _buildFilterChip('Management', _selectedSkills == 'Management', () {
          setState(() => _selectedSkills = 'Management');
          setModalState?.call(() {});
        }),
      ]),
    ];
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFFFF2D55) : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String title, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
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

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showJobDetails(Map<String, dynamic> job, bool isDarkMode) {
    // Navigate to job details
    print('Show job details: ${job['position']}');
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