// lib/screens/job_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/application_service.dart'; // ADD THIS
import '../models/job_model.dart';

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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF34C759).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF34C759),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Application Submitted!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your application for ${job.position} at ${job.company} has been submitted successfully.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              'You can track your application progress in the Applications tab.',
              style: TextStyle(
                fontSize: 12,
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
      ),
    );
  }

  // ADD: Error dialog
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFFF3B30),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Application Failed')),
          ],
        ),
        content: const Text(
          'You have already applied to this position or there was an error. Please try again later.',
          style: TextStyle(fontSize: 14),
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
      ),
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
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Application Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildStatusInfo(application),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
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
        ),
      );
    }
  }

  // ADD: Build status info widget
  Widget _buildStatusInfo(dynamic application) {
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current Stage: $currentStage',
                  style: TextStyle(
                    fontSize: 14,
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
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading job details',
                      style: TextStyle(
                        fontSize: 18,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                      ),
                      child: const Text('Go Back'),
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
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: _isSaved ? const Color(0xFFFF2D55) : (isDarkMode ? Colors.white : Colors.black),
                      ),
                      onPressed: _isSaved ? _unsaveJob : _saveJob,
                    ),
                  ],
                  expandedHeight: 200,
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
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Color(job.logoColor).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              job.logo,
                              style: TextStyle(
                                fontSize: 32,
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.position,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          job.company,
                          style: TextStyle(
                            fontSize: 18,
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildJobMetaInfo(job, isDarkMode),
                        const SizedBox(height: 24),
                        _buildSectionTitle('About the Job', isDarkMode),
                        const SizedBox(height: 12),
                        _buildDescription(job.description ?? 'No description available', isDarkMode),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Requirements', isDarkMode),
                        const SizedBox(height: 12),
                        _buildRequirements(job.requirements ?? [], isDarkMode),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Required Skills', isDarkMode),
                        const SizedBox(height: 12),
                        _buildSkills(job.skills, isDarkMode),
                        const SizedBox(height: 24),
                        _buildSectionTitle('About Company', isDarkMode),
                        const SizedBox(height: 12),
                        _buildDescription(job.companyDescription ?? 'No company description available', isDarkMode),
                        const SizedBox(height: 40),
                        // UPDATED: Pass job object to _buildApplyButton
                        _buildApplyButton(job, isDarkMode),
                        const SizedBox(height: 20),
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

  Widget _buildJobMetaInfo(Job job, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildMetaItem(
                Icons.work_outline,
                job.type ?? 'Full-time',
                isDarkMode,
              ),
              _buildMetaItem(
                Icons.location_on_outlined,
                '${job.location ?? 'Location not specified'}, ${job.country ?? 'Country not specified'}',
                isDarkMode,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetaItem(
                Icons.paid_outlined,
                job.salary ?? 'Salary not specified',
                isDarkMode,
              ),
              _buildMetaItem(
                Icons.access_time_outlined,
                job.postedTime ?? 'Recently',
                isDarkMode,
              ),
            ],
          ),
          if (job.isRemote) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.work_outline,
                    size: 14,
                    color: Colors.green,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Remote Work Available',
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _buildMetaItem(IconData icon, String text, bool isDarkMode) {
    return Expanded(
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
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

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildDescription(String description, bool isDarkMode) {
    return Text(
      description,
      style: TextStyle(
        fontSize: 16,
        height: 1.6,
        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
      ),
    );
  }

  Widget _buildRequirements(List<String> requirements, bool isDarkMode) {
    if (requirements.isEmpty) {
      return Text(
        'No specific requirements listed.',
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: requirements.map((requirement) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Color(0xFFFF2D55),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  requirement,
                  style: TextStyle(
                    fontSize: 16,
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

  Widget _buildSkills(List<String> skills, bool isDarkMode) {
    if (skills.isEmpty) {
      return Text(
        'No specific skills listed.',
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF2D55).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFF2D55).withOpacity(0.3),
            ),
          ),
          child: Text(
            skill,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFFF2D55),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }

  // UPDATED: Apply button with loading state
  Widget _buildApplyButton(Job job, bool isDarkMode) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_hasApplied || _isApplying) ? null : () => _applyForJob(job),
        style: ElevatedButton.styleFrom(
          backgroundColor: _hasApplied
              ? const Color(0xFF34C759)
              : const Color(0xFFFF2D55),
          disabledBackgroundColor: _hasApplied
              ? const Color(0xFF34C759)
              : Colors.grey,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isApplying
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _hasApplied ? Icons.check_circle : Icons.send,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              _hasApplied ? 'Applied - View Status' : 'Apply Now',
              style: const TextStyle(
                fontSize: 16,
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