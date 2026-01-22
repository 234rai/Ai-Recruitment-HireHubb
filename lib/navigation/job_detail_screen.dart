// lib/screens/job_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/application_service.dart'; // ADD THIS
import '../models/job_model.dart';
import '../utils/responsive_helper.dart';

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  final Job? job;

  const JobDetailScreen({
    super.key,
    required this.jobId,
    this.job,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<Job> _jobFuture;
  final ApplicationService _applicationService = ApplicationService(); // ADD THIS
  bool _isSaved = false;
  bool _hasApplied = false;
  bool _isApplying = false; // ADD THIS

  @override
  void initState() {
    super.initState();
    _jobFuture = FirestoreService.getJobById(widget.jobId);
    _checkIfSaved();
    _checkIfApplied();
  }

  void _checkIfSaved() async {
    final isSaved = await FirestoreService.isJobSaved(widget.jobId);
    if (mounted) {
      setState(() {
        _isSaved = isSaved;
      });
    }
  }

  void _checkIfApplied() async {
    // UPDATED: Use ApplicationService instead of FirestoreService
    final hasApplied = await _applicationService.hasApplied(widget.jobId);
    if (mounted) {
      setState(() {
        _hasApplied = hasApplied;
      });
    }
  }

  void _saveJob() async {
    try {
      await FirestoreService.saveJob(widget.jobId);
      if (mounted) {
        setState(() {
          _isSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _unsaveJob() async {
    try {
      await FirestoreService.unsaveJob(widget.jobId);
      if (mounted) {
        setState(() {
          _isSaved = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job removed from saved'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // UPDATED: New apply method using ApplicationService
  void _applyForJob(Job job) async {
    // 🚀 VALIDATION: Ensure recruiterId exists
    if (job.recruiterId == null || job.recruiterId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot apply: Job has missing recruiter information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_hasApplied) {
      _showApplicationStatus();
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      final success = await _applicationService.applyForJob(
        jobId: widget.jobId,
        jobTitle: job.position,
        company: job.company,
        companyLogo: job.logo,
        recruiterId: job.recruiterId ?? '', // Pass recruiterId from job object
        interviewRounds: null, // Will use default rounds
      );

      if (mounted) {
        setState(() {
          _isApplying = false;
        });

        if (success) {
          setState(() {
            _hasApplied = true;
          });
          _showSuccessDialog(job);
        } else {
          _showErrorDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying for job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ADD: Success dialog
  void _showSuccessDialog(Job job) {
    showDialog(
      context: context,
      builder: (context) {
        ResponsiveHelper responsive = ResponsiveHelper(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(responsive.radius(16))),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.padding(8)),
                decoration: BoxDecoration(
                  color: const Color(0xFF34C759).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: const Color(0xFF34C759),
                  size: responsive.iconSize(24),
                ),
              ),
              SizedBox(width: responsive.width(12)),
              const Expanded(child: Text('Application Submitted!')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your application for ${job.position} at ${job.company} has been submitted successfully.',
                style: TextStyle(fontSize: responsive.fontSize(14)),
              ),
              SizedBox(height: responsive.height(16)),
              Text(
                'You can track your application progress in the Applications tab.',
                style: TextStyle(
                  fontSize: responsive.fontSize(12),
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to applications screen
                Navigator.pushNamed(context, '/applications');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
              ),
              child: const Text('View Application'),
            ),
          ],
        );
      },
    );
  }

  // ADD: Error dialog
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) {
        ResponsiveHelper responsive = ResponsiveHelper(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(responsive.radius(16))),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(responsive.padding(8)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: const Color(0xFFFF3B30),
                  size: responsive.iconSize(24),
                ),
              ),
              SizedBox(width: responsive.width(12)),
              const Expanded(child: Text('Application Failed')),
            ],
          ),
          content: Text(
            'You have already applied to this position or there was an error. Please try again later.',
            style: TextStyle(fontSize: responsive.fontSize(14)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ADD: Show application status
  Future<void> _showApplicationStatus() async {
    final application = await _applicationService.getApplicationForJob(widget.jobId);
    if (application != null && mounted) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          ResponsiveHelper responsive = ResponsiveHelper(context);
          return Container(
            padding: EdgeInsets.all(responsive.padding(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: responsive.width(40),
                  height: responsive.height(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(responsive.radius(2)),
                  ),
                ),
                SizedBox(height: responsive.height(20)),
                Text(
                  'Application Status',
                  style: TextStyle(
                    fontSize: responsive.fontSize(20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: responsive.height(16)),
                _buildStatusInfo(application, responsive),
                SizedBox(height: responsive.height(20)),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                    SizedBox(width: responsive.width(12)),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/applications');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2D55),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('View Details'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  // ADD: Build status info widget
  Widget _buildStatusInfo(dynamic application, ResponsiveHelper responsive) {
    final data = application.data() as Map<String, dynamic>;
    final status = data['status'] as String;
    final currentStage = data['currentStage'] as String;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'applied':
        statusColor = const Color(0xFF007AFF);
        statusIcon = Icons.send;
        statusText = 'Application Submitted';
        break;
      case 'inProcess':
        statusColor = const Color(0xFFFFB800);
        statusIcon = Icons.pending;
        statusText = 'In Review';
        break;
      case 'completed':
        statusColor = const Color(0xFF34C759);
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'rejected':
        statusColor = const Color(0xFFFF3B30);
        statusIcon = Icons.cancel;
        statusText = 'Not Selected';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(responsive.radius(12)),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: responsive.iconSize(32)),
          SizedBox(width: responsive.width(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: responsive.fontSize(16),
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                SizedBox(height: responsive.height(4)),
                Text(
                  'Current Stage: $currentStage',
                  style: TextStyle(
                    fontSize: responsive.fontSize(14),
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: FutureBuilder<Job>(
          future: _jobFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2D55)),
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: responsive.iconSize(64),
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: responsive.height(16)),
                    Text(
                      'Error loading job details',
                      style: TextStyle(
                        fontSize: responsive.fontSize(18),
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: responsive.height(20)),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                      ),
                      child: Text('Go Back', style: TextStyle(fontSize: responsive.fontSize(14))),
                    ),
                  ],
                ),
              );
            }

            final job = snapshot.data!;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, size: responsive.iconSize(24)),
                    onPressed: () => Navigator.pop(context),
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: _isSaved ? const Color(0xFFFF2D55) : (isDarkMode ? Colors.white : Colors.black),
                        size: responsive.iconSize(24),
                      ),
                      onPressed: _isSaved ? _unsaveJob : _saveJob,
                    ),
                  ],
                  expandedHeight: responsive.height(200),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFFF2D55).withOpacity(0.1),
                            const Color(0xFFFF2D55).withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: responsive.width(80),
                          height: responsive.width(80),
                          decoration: BoxDecoration(
                            color: Color(job.logoColor).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(responsive.radius(16)),
                          ),
                          child: Center(
                            child: Text(
                              job.logo,
                              style: TextStyle(
                                fontSize: responsive.fontSize(32),
                                fontWeight: FontWeight.bold,
                                color: Color(job.logoColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(responsive.padding(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.position,
                          style: TextStyle(
                            fontSize: responsive.fontSize(28),
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        SizedBox(height: responsive.height(8)),
                        Text(
                          job.company,
                          style: TextStyle(
                            fontSize: responsive.fontSize(18),
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: responsive.height(20)),
                        _buildJobMetaInfo(job, isDarkMode, responsive),
                        SizedBox(height: responsive.height(24)),
                        _buildSectionTitle('About the Job', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),
                        _buildDescription(job.description ?? 'No description available', isDarkMode, responsive),
                        SizedBox(height: responsive.height(24)),
                        _buildSectionTitle('Requirements', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),
                        _buildRequirements(job.requirements ?? [], isDarkMode, responsive),
                        SizedBox(height: responsive.height(24)),
                        
                        // 🚀 Selection Process Section
                        _buildSectionTitle('Selection Process', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),
                        _buildSelectionProcess(job.selectionRounds, isDarkMode, responsive),
                        SizedBox(height: responsive.height(24)),

                        _buildSectionTitle('Required Skills', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),
                        _buildSkills(job.skills, isDarkMode, responsive),
                        SizedBox(height: responsive.height(24)),
                        _buildSectionTitle('About Company', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),
                        _buildDescription(job.companyDescription ?? 'No company description available', isDarkMode, responsive),
                        SizedBox(height: responsive.height(40)),
                        _buildApplyButton(job, isDarkMode, responsive),
                        SizedBox(height: responsive.height(20)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobMetaInfo(Job job, bool isDarkMode, ResponsiveHelper responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(responsive.radius(12)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetaItem(
                Icons.work_outline,
                job.type ?? 'Full-time',
                isDarkMode,
                responsive,
              ),
              _buildMetaItem(
                Icons.location_on_outlined,
                '${job.location ?? 'Location not specified'}, ${job.country ?? 'Country not specified'}',
                isDarkMode,
                responsive,
              ),
            ],
          ),
          SizedBox(height: responsive.height(12)),
          Row(
            children: [
              _buildMetaItem(
                Icons.paid_outlined,
                job.salary ?? 'Salary not specified',
                isDarkMode,
                responsive,
              ),
              _buildMetaItem(
                Icons.access_time_outlined,
                job.postedTime ?? 'Recently',
                isDarkMode,
                responsive,
              ),
            ],
          ),
          if (job.isRemote) ...[
            SizedBox(height: responsive.height(12)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: responsive.padding(12), vertical: responsive.padding(6)),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(responsive.radius(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: responsive.iconSize(14),
                    color: Colors.green,
                  ),
                  SizedBox(width: responsive.width(4)),
                  Text(
                    'Remote Work Available',
                    style: TextStyle(
                      fontSize: responsive.fontSize(12),
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text, bool isDarkMode, ResponsiveHelper responsive) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: responsive.iconSize(16),
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          SizedBox(width: responsive.width(8)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: responsive.fontSize(14),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode, ResponsiveHelper responsive) {
    return Text(
      title,
      style: TextStyle(
        fontSize: responsive.fontSize(20),
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildDescription(String description, bool isDarkMode, ResponsiveHelper responsive) {
    return Text(
      description,
      style: TextStyle(
        fontSize: responsive.fontSize(16),
        height: 1.6,
        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
      ),
    );
  }

  Widget _buildRequirements(List<String> requirements, bool isDarkMode, ResponsiveHelper responsive) {
    if (requirements.isEmpty) {
      return Text(
        'No specific requirements listed.',
        style: TextStyle(
          fontSize: responsive.fontSize(16),
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: requirements.map((requirement) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: responsive.padding(4)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: responsive.iconSize(16),
                color: const Color(0xFFFF2D55),
              ),
              SizedBox(width: responsive.width(8)),
              Expanded(
                child: Text(
                  requirement,
                  style: TextStyle(
                  fontSize: responsive.fontSize(16),
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 🚀 New Method: Build Selection Process
  Widget _buildSelectionProcess(List<String> rounds, bool isDarkMode, ResponsiveHelper responsive) {
    if (rounds.isEmpty) {
       return Text(
        'No specific selection process listed.',
        style: TextStyle(
          fontSize: responsive.fontSize(16),
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rounds.asMap().entries.map((entry) {
        final index = entry.key;
        final round = entry.value;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: responsive.padding(8)),
          child: Row(
            children: [
              Container(
                width: responsive.width(28),
                height: responsive.width(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2D55).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: const Color(0xFFFF2D55),
                      fontWeight: FontWeight.bold,
                      fontSize: responsive.fontSize(14),
                    ),
                  ),
                ),
              ),
              SizedBox(width: responsive.width(12)),
              Expanded(
                child: Text(
                  round,
                  style: TextStyle(
                    fontSize: responsive.fontSize(16),
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkills(List<String> skills, bool isDarkMode, ResponsiveHelper responsive) {
    if (skills.isEmpty) {
      return Text(
        'No specific skills listed.',
        style: TextStyle(
          fontSize: responsive.fontSize(16),
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: responsive.width(8),
      runSpacing: responsive.height(8),
      children: skills.map((skill) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: responsive.padding(12), vertical: responsive.padding(8)),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2D55).withOpacity(0.1),
            borderRadius: BorderRadius.circular(responsive.radius(8)),
            border: Border.all(
              color: const Color(0xFFFF2D55).withOpacity(0.3),
            ),
          ),
          child: Text(
            skill,
            style: TextStyle(
              fontSize: responsive.fontSize(14),
              color: const Color(0xFFFF2D55),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // UPDATED: Apply button with loading state
  Widget _buildApplyButton(Job job, bool isDarkMode, ResponsiveHelper responsive) {
    return SizedBox(
      width: double.infinity,
      height: responsive.height(54),
      child: ElevatedButton(
        onPressed: (_hasApplied || _isApplying) ? null : () => _applyForJob(job),
        style: ElevatedButton.styleFrom(
          backgroundColor: _hasApplied
              ? const Color(0xFF34C759)
              : const Color(0xFFFF2D55),
          disabledBackgroundColor: _hasApplied
              ? const Color(0xFF34C759)
              : Colors.grey,
          padding: EdgeInsets.symmetric(vertical: responsive.padding(16)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(responsive.radius(12)),
          ),
        ),
        child: _isApplying
            ? SizedBox(
          height: responsive.height(20),
          width: responsive.height(20),
          child: const CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasApplied ? Icons.check_circle : Icons.send,
              size: responsive.iconSize(20),
              color: Colors.white,
            ),
            SizedBox(width: responsive.width(8)),
            Text(
              _hasApplied ? 'Applied - View Status' : 'Apply Now',
              style: TextStyle(
                fontSize: responsive.fontSize(16),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}