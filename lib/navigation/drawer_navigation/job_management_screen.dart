import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/job_model.dart';
import '../../../services/firestore_service.dart';
import '../job_post_screen.dart';
import '../../../utils/responsive_helper.dart';

class JobManagementScreen extends StatefulWidget {
  const JobManagementScreen({super.key});

  @override
  State<JobManagementScreen> createState() => _JobManagementScreenState();
}

class _JobManagementScreenState extends State<JobManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filter = 'all';

  @override
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Jobs', style: TextStyle(fontSize: responsive.fontSize(20))),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            padding: EdgeInsets.symmetric(horizontal: responsive.padding(20), vertical: responsive.padding(12)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('All', 'all', isDarkMode, responsive),
                  SizedBox(width: responsive.width(8)),
                  _buildFilterTab('Active', 'active', isDarkMode, responsive),
                  SizedBox(width: responsive.width(8)),
                  _buildFilterTab('Closed', 'closed', isDarkMode, responsive),
                  SizedBox(width: responsive.width(8)),
                  _buildFilterTab('Draft', 'draft', isDarkMode, responsive),
                ],
              ),
            ),
          ),

          // Jobs List
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: FirestoreService.getRecruiterJobs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFFF2D55)));
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final jobs = snapshot.data ?? [];
                final filteredJobs = _filterJobs(jobs);

                if (filteredJobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: responsive.iconSize(64),
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        SizedBox(height: responsive.height(16)),
                        Text(
                          'No jobs found',
                          style: TextStyle(
                            fontSize: responsive.fontSize(18),
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(responsive.padding(20)),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    return _buildJobCard(job, isDarkMode, responsive);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const JobPostScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFFFF2D55),
        child: Icon(Icons.add, color: Colors.white, size: responsive.iconSize(24)),
      ),
    );
  }

  Widget _buildFilterTab(String label, String value, bool isDarkMode, ResponsiveHelper responsive) {
    final isSelected = _filter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filter = value;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF2D55)
              : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(responsive.radius(20)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
            fontWeight: FontWeight.w600,
            fontSize: responsive.fontSize(14),
          ),
        ),
      ),
    );
  }

  List<Job> _filterJobs(List<Job> jobs) {
    switch (_filter) {
      case 'active':
        return jobs.where((job) => job.status == 'active').toList();
      case 'closed':
        return jobs.where((job) => job.status == 'closed').toList();
      case 'draft':
        return jobs.where((job) => job.status == 'draft').toList();
      default:
        return jobs;
    }
  }

  Widget _buildJobCard(Job job, bool isDarkMode, ResponsiveHelper responsive) {
    return Card(
      margin: EdgeInsets.only(bottom: responsive.height(12)),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(responsive.radius(12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(responsive.padding(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: responsive.width(40),
                  height: responsive.width(40),
                  decoration: BoxDecoration(
                    color: Color(job.logoColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(responsive.radius(10)),
                  ),
                  child: Center(
                    child: Text(
                      job.logo,
                      style: TextStyle(
                        fontSize: responsive.fontSize(18),
                        fontWeight: FontWeight.bold,
                        color: Color(job.logoColor),
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
                        job.position,
                        style: TextStyle(
                          fontSize: responsive.fontSize(16),
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      SizedBox(height: responsive.height(4)),
                      Text(
                        job.company,
                        style: TextStyle(
                          fontSize: responsive.fontSize(13),
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildStatusBadge(job.status ?? 'active', responsive),
              ],
            ),
            SizedBox(height: responsive.height(12)),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: responsive.iconSize(16),
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                SizedBox(width: responsive.width(4)),
                Text(
                  job.location,
                  style: TextStyle(
                    fontSize: responsive.fontSize(13),
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
                SizedBox(width: responsive.width(16)),
                Icon(
                  Icons.attach_money_outlined,
                  size: responsive.iconSize(16),
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                SizedBox(width: responsive.width(4)),
                Text(
                  job.salary,
                  style: TextStyle(
                    fontSize: responsive.fontSize(13),
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            SizedBox(height: responsive.height(12)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StreamBuilder<int>(
                  stream: FirestoreService.getJobApplicationsCountStream(job.id),
                  builder: (context, snapshot) {
                    // Debug logs
                    if (snapshot.hasError) {
                      print('❌ Stream error for job ${job.id}: ${snapshot.error}');
                    }

                    // Show loading indicator only initially
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return Row(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: responsive.iconSize(16),
                            color: const Color(0xFFFF2D55),
                          ),
                          SizedBox(width: responsive.width(4)),
                          SizedBox(
                            width: responsive.width(16),
                            height: responsive.width(16),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
                            ),
                          ),
                        ],
                      );
                    }

                    final count = snapshot.data ?? 0;
                    print('🎯 Displaying count for job ${job.id}: $count');

                    return Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: responsive.iconSize(16),
                          color: const Color(0xFFFF2D55),
                        ),
                        SizedBox(width: responsive.width(4)),
                        Text(
                          '$count applicant${count != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: responsive.fontSize(13),
                            color: const Color(0xFFFF2D55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        _showJobActions(job);
                      },
                      icon: Icon(
                        Icons.more_vert,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        size: responsive.iconSize(24),
                      ),
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

  Widget _buildStatusBadge(String status, ResponsiveHelper responsive) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = const Color(0xFF34C759);
        label = 'Active';
        break;
      case 'closed':
        color = Colors.grey;
        label = 'Closed';
        break;
      case 'draft':
        color = Colors.orange;
        label = 'Draft';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: responsive.padding(12), vertical: responsive.padding(4)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(responsive.radius(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: responsive.fontSize(12),
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _showJobActions(Job job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined, color: Color(0xFFFF2D55)),
                title: const Text('View Job'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to job details
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFFFF2D55)),
                title: const Text('Edit Job'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to edit job screen
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Color(0xFFFF2D55)),
                title: const Text('View Applicants'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to applicants screen
                },
              ),
              if (job.status == 'active')
                ListTile(
                  leading: const Icon(Icons.pause_outlined, color: Colors.orange),
                  title: const Text('Close Job'),
                  onTap: () {
                    Navigator.pop(context);
                    _closeJob(job.id);
                  },
                ),
              if (job.status == 'closed')
                ListTile(
                  leading: const Icon(Icons.play_arrow_outlined, color: Colors.green),
                  title: const Text('Reopen Job'),
                  onTap: () {
                    Navigator.pop(context);
                    _reopenJob(job.id);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Job',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteJob(job.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _closeJob(String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close Job'),
        content: const Text('Are you sure you want to close this job posting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirestoreService.updateJob(jobId, {'status': 'closed'});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job closed successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Close Job'),
          ),
        ],
      ),
    );
  }

  void _reopenJob(String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen Job'),
        content: const Text('Are you sure you want to reopen this job posting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirestoreService.updateJob(jobId, {'status': 'active'});
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job reopened successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Reopen Job'),
          ),
        ],
      ),
    );
  }

  void _deleteJob(String jobId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content: const Text('Are you sure you want to delete this job? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await FirestoreService.deleteJob(jobId);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Job deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}