// lib/navigation/analytics/job_performance_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/responsive_helper.dart';

class JobPerformanceScreen extends StatefulWidget {
  const JobPerformanceScreen({super.key});

  @override
  State<JobPerformanceScreen> createState() => _JobPerformanceScreenState();
}

class _JobPerformanceScreenState extends State<JobPerformanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  // Cache for jobs data to prevent reload between sections
  List<Map<String, dynamic>>? _cachedJobsData;
  List<QueryDocumentSnapshot>? _lastJobs;

  @override
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Job Performance',
          style: TextStyle(
            fontSize: responsive.fontSize(18),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: false,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: responsive.iconSize(24)),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: _userId == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: responsive.iconSize(64),
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: responsive.height(16)),
            Text(
              'Please log in to view performance',
              style: TextStyle(
                fontSize: responsive.fontSize(16),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      )
          : StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('jobs')
            .where('recruiterId', isEqualTo: _userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _cachedJobsData == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF2D55)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: responsive.iconSize(64),
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  SizedBox(height: responsive.height(16)),
                  Text(
                    'Error loading job data',
                    style: TextStyle(
                      fontSize: responsive.fontSize(16),
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final jobs = snapshot.data?.docs ?? [];
          final performanceData = _calculatePerformanceData(jobs);

          // Check if jobs changed to refresh cache
          final jobsChanged = _lastJobs == null ||
              _lastJobs!.length != jobs.length ||
              (jobs.isNotEmpty && _lastJobs!.isNotEmpty &&
                  jobs.first.id != _lastJobs!.first.id);

          if (jobsChanged) {
            _lastJobs = jobs;
            // Fetch jobs data in background and update cache
            _getJobsWithApplications(jobs).then((data) {
              if (mounted) {
                setState(() {
                  _cachedJobsData = data;
                });
              }
            });
          }

          // Use cached data or empty list while loading
          final jobsData = _cachedJobsData ?? [];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Performance Overview Cards
                _buildPerformanceOverview(isDarkMode, performanceData, responsive),

                SizedBox(height: responsive.height(12)),

                // Top Performing Jobs
                _buildTopPerformingJobs(isDarkMode, jobsData, responsive),

                SizedBox(height: responsive.height(12)),

                // Applications Distribution
                _buildApplicationsDistribution(isDarkMode, performanceData, responsive),

                SizedBox(height: responsive.height(12)),

                // Recent Jobs List
                _buildActiveJobsList(isDarkMode, jobsData, responsive),

                SizedBox(height: responsive.height(16)),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _calculatePerformanceData(List<QueryDocumentSnapshot> jobs) {
    int activeJobs = 0;
    int closedJobs = 0;
    int draftJobs = 0;
    int totalApplications = 0;
    List<int> applicationCounts = [];

    for (var doc in jobs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString().toLowerCase() ?? 'active';

      switch (status) {
        case 'active':
          activeJobs++;
          break;
        case 'closed':
        case 'completed':
          closedJobs++;
          break;
        case 'draft':
          draftJobs++;
          break;
        default:
          activeJobs++;
      }

      final apps = data['applicationCount'] ?? 0;
      if (apps is int) {
        totalApplications += apps;
        applicationCounts.add(apps);
      }
    }

    final totalJobs = jobs.length;
    final avgApplications = totalJobs > 0 ? (totalApplications / totalJobs) : 0.0;
    applicationCounts.sort((a, b) => b.compareTo(a));
    final topApplications = applicationCounts.isNotEmpty ? applicationCounts.first : 0;

    return {
      'totalJobs': totalJobs,
      'activeJobs': activeJobs,
      'closedJobs': closedJobs,
      'draftJobs': draftJobs,
      'totalApplications': totalApplications,
      'avgApplications': avgApplications,
      'topApplications': topApplications,
      'applicationCounts': applicationCounts,
    };
  }

  Widget _buildPerformanceOverview(bool isDarkMode, Map<String, dynamic> data, ResponsiveHelper responsive) {
    return Container(
      margin: EdgeInsets.fromLTRB(responsive.padding(16), responsive.padding(16), responsive.padding(16), 0),
      padding: EdgeInsets.all(responsive.padding(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFF007AFF), const Color(0xFF0055B3)]
              : [const Color(0xFF007AFF), const Color(0xFF5AC8FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withOpacity(0.25),
            blurRadius: responsive.radius(12),
            offset: Offset(0, responsive.height(4)),
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
                'Total Jobs Posted',
                style: TextStyle(
                  fontSize: responsive.fontSize(14),
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              Container(
                padding: EdgeInsets.all(responsive.padding(8)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(responsive.radius(10)),
                ),
                child: Icon(Icons.work_outline, color: Colors.white, size: responsive.iconSize(20)),
              ),
            ],
          ),
          SizedBox(height: responsive.height(12)),
          Text(
            (data['totalJobs'] as int).toString(),
            style: TextStyle(
              fontSize: responsive.fontSize(40),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: responsive.height(16)),
          Row(
            children: [
              _buildOverviewStat(
                'Active',
                (data['activeJobs'] as int).toString(),
                Icons.check_circle_outline,
                responsive,
              ),
              SizedBox(width: responsive.width(16)),
              Container(width: 1, height: responsive.height(24), color: Colors.white24),
              SizedBox(width: responsive.width(16)),
              _buildOverviewStat(
                'Closed',
                (data['closedJobs'] as int).toString(),
                Icons.cancel_outlined,
                responsive,
              ),
              SizedBox(width: responsive.width(16)),
              Container(width: 1, height: responsive.height(24), color: Colors.white24),
              SizedBox(width: responsive.width(16)),
              _buildOverviewStat(
                'Applicants',
                (data['totalApplications'] as int).toString(),
                Icons.people_outline,
                responsive,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String label, String value, IconData icon, ResponsiveHelper responsive) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: responsive.iconSize(16)),
        SizedBox(width: responsive.width(6)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: responsive.fontSize(14),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: responsive.fontSize(10),
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildTopPerformingJobs(bool isDarkMode, List<Map<String, dynamic>> jobsData, ResponsiveHelper responsive) {
    if (jobsData.isEmpty) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
        padding: EdgeInsets.all(responsive.padding(20)),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(responsive.radius(16)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart_outlined,
              size: responsive.iconSize(48),
              color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
            SizedBox(height: responsive.height(12)),
            Text(
              'No job performance data',
              style: TextStyle(
                fontSize: responsive.fontSize(14),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final topJobs = jobsData.take(3).toList();
    final maxApps = topJobs.isNotEmpty
        ? topJobs.map((j) => j['applications'] as int).reduce((a, b) => a > b ? a : b)
        : 1;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
      padding: EdgeInsets.all(responsive.padding(18)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.05),
            blurRadius: responsive.radius(8),
            offset: Offset(0, responsive.height(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up_outlined,
                size: responsive.iconSize(20),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              SizedBox(width: responsive.width(8)),
              Text(
                'Top Performing Jobs',
                style: TextStyle(
                  fontSize: responsive.fontSize(16),
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(4)),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                ),
                child: Text(
                  'Top 3',
                  style: TextStyle(
                    fontSize: responsive.fontSize(11),
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.height(20)),
          ...topJobs.map((job) {
            final apps = job['applications'] as int;
            final percentage = maxApps > 0 ? (apps / maxApps) : 0.0;
            final isActive = job['status'] == 'active';

            return Padding(
              padding: EdgeInsets.only(bottom: responsive.padding(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          job['position'] as String,
                          style: TextStyle(
                            fontSize: responsive.fontSize(14),
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: responsive.width(8)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(4)),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF34C759).withOpacity(0.1)
                              : const Color(0xFFFF9500).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(responsive.radius(6)),
                          border: Border.all(
                            color: isActive
                                ? const Color(0xFF34C759).withOpacity(0.3)
                                : const Color(0xFFFF9500).withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Closed',
                          style: TextStyle(
                            fontSize: responsive.fontSize(10),
                            fontWeight: FontWeight.w600,
                            color: isActive ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.height(8)),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(responsive.radius(4)),
                        child: LinearProgressIndicator(
                          value: percentage,
                          minHeight: responsive.height(8),
                          backgroundColor:
                              isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: responsive.height(6)),
                  Text(
                    '$apps applicants',
                    style: TextStyle(
                      fontSize: responsive.fontSize(12),
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildApplicationsDistribution(bool isDarkMode, Map<String, dynamic> data, ResponsiveHelper responsive) {
    final totalApps = data['totalApplications'] as int;
    final totalJobs = data['totalJobs'] as int;
    final avgPerJob = totalJobs > 0 ? (totalApps / totalJobs) : 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
      padding: EdgeInsets.all(responsive.padding(18)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.05),
            blurRadius: responsive.radius(8),
            offset: Offset(0, responsive.height(2)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: responsive.iconSize(20),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              SizedBox(width: responsive.width(8)),
              Text(
                'Applications Distribution',
                style: TextStyle(
                  fontSize: responsive.fontSize(16),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.height(16)),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          avgPerJob.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: responsive.fontSize(32),
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                            height: 1.1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: responsive.padding(4), left: responsive.padding(2)),
                          child: Text(
                            'per job',
                            style: TextStyle(
                              fontSize: responsive.fontSize(14),
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: responsive.height(6)),
                    Text(
                      'Average applications across all jobs',
                      style: TextStyle(
                        fontSize: responsive.fontSize(13),
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: responsive.width(80),
                height: responsive.width(80),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: responsive.width(80),
                      height: responsive.width(80),
                      child: CircularProgressIndicator(
                        value: totalApps > 0 ? 0.75 : 0,
                        strokeWidth: responsive.width(8),
                        backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalApps.toString(),
                          style: TextStyle(
                            fontSize: responsive.fontSize(18),
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'total',
                          style: TextStyle(
                            fontSize: responsive.fontSize(11),
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobsList(bool isDarkMode, List<Map<String, dynamic>> jobsData, ResponsiveHelper responsive) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
      padding: EdgeInsets.all(responsive.padding(18)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.1 : 0.05),
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
              Row(
                children: [
                  Icon(
                    Icons.list_alt,
                    size: responsive.iconSize(20),
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  SizedBox(width: responsive.width(8)),
                  Text(
                    'Recent Jobs',
                    style: TextStyle(
                      fontSize: responsive.fontSize(16),
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(4)),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                ),
                child: Text(
                  'Latest 5',
                  style: TextStyle(
                    fontSize: responsive.fontSize(11),
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.height(16)),
          if (jobsData.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: responsive.padding(32)),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: responsive.iconSize(48),
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  SizedBox(height: responsive.height(12)),
                  Text(
                    'No jobs posted yet',
                    style: TextStyle(
                      fontSize: responsive.fontSize(14),
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: responsive.height(4)),
                  Text(
                    'Create your first job post',
                    style: TextStyle(
                      fontSize: responsive.fontSize(12),
                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobsData.take(5).length,
              separatorBuilder: (_, __) => Divider(
                height: responsive.height(16),
                thickness: 0.5,
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final job = jobsData[index];
                final isActive = job['status'] == 'active';
                final postedAt = job['postedAt'] as Timestamp?;
                final position = job['position'] as String;
                final company = job['company'] as String;
                final applications = job['applications'] as int;

                return InkWell(
                  onTap: () {
                    // Navigate to job details
                  },
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: responsive.padding(8)),
                    child: Row(
                      children: [
                        Container(
                          width: responsive.width(42),
                          height: responsive.width(42),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF007AFF).withOpacity(0.8),
                                const Color(0xFF007AFF).withOpacity(0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(responsive.radius(12)),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.work_outline,
                              color: Colors.white,
                              size: responsive.iconSize(20),
                            ),
                          ),
                        ),
                        SizedBox(width: responsive.width(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                position,
                                style: TextStyle(
                                  fontSize: responsive.fontSize(14),
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: responsive.height(3)),
                              Text(
                                company,
                                style: TextStyle(
                                  fontSize: responsive.fontSize(12),
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
                        SizedBox(width: responsive.width(8)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(4)),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF34C759).withOpacity(0.12)
                                    : const Color(0xFFFF9500).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(responsive.radius(6)),
                                border: Border.all(
                                  color: isActive
                                      ? const Color(0xFF34C759).withOpacity(0.3)
                                      : const Color(0xFFFF9500).withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: responsive.iconSize(10),
                                    color: isActive
                                        ? const Color(0xFF34C759)
                                        : const Color(0xFFFF9500),
                                  ),
                                  SizedBox(width: responsive.width(4)),
                                  Text(
                                    applications.toString(),
                                    style: TextStyle(
                                      fontSize: responsive.fontSize(10),
                                      fontWeight: FontWeight.w600,
                                      color: isActive
                                          ? const Color(0xFF34C759)
                                          : const Color(0xFFFF9500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (postedAt != null) ...[
                              SizedBox(height: responsive.height(4)),
                              Text(
                                DateFormat('MMM d').format(postedAt.toDate()),
                                style: TextStyle(
                                  fontSize: responsive.fontSize(11),
                                  color: isDarkMode
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getJobsWithApplications(
      List<QueryDocumentSnapshot> jobs) async {
    List<Map<String, dynamic>> jobsData = [];

    for (var doc in jobs) {
      final data = doc.data() as Map<String, dynamic>;
      final appSnapshot = await _firestore
          .collection('applications')
          .where('jobId', isEqualTo: doc.id)
          .get();

      jobsData.add({
        'id': doc.id,
        'position': data['position'] ?? 'Unknown Position',
        'company': data['company'] ?? 'Unknown Company',
        'applications': appSnapshot.docs.length,
        'status': data['status'] ?? 'active',
        'postedAt': data['postedAt'],
      });
    }

    // Sort by posted date (most recent first)
    jobsData.sort((a, b) {
      final aDate = a['postedAt'] as Timestamp?;
      final bDate = b['postedAt'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    return jobsData;
  }
}