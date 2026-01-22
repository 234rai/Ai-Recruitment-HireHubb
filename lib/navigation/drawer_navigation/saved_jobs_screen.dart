import 'package:flutter/material.dart';
import '../../models/job_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/responsive_helper.dart';

class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  void _unsaveJob(String jobId) async {
    try {
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

  void _applyForJob(String jobId) async {
    try {
      await FirestoreService.applyForJob(jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying for job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
            size: responsive.iconSize(24),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Jobs',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: responsive.fontSize(20),
          ),
        ),
      ),
      body: StreamBuilder<List<Job>>(
        stream: FirestoreService.getSavedJobs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: const Color(0xFFFF2D55),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(responsive.padding(20)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: responsive.iconSize(64),
                      color: Colors.red,
                    ),
                    SizedBox(height: responsive.height(16)),
                    Text(
                      'Error loading saved jobs',
                      style: TextStyle(
                        fontSize: responsive.fontSize(18),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: responsive.height(8)),
                    Text(
                      '${snapshot.error}',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: responsive.fontSize(14),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(responsive.padding(20)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bookmark_outline,
                      size: responsive.iconSize(80),
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                    ),
                    SizedBox(height: responsive.height(16)),
                    Text(
                      'No Saved Jobs Yet',
                      style: TextStyle(
                        fontSize: responsive.fontSize(20),
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: responsive.height(8)),
                    Text(
                      'Start saving jobs you\'re interested in\nto view them here later',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: responsive.fontSize(14),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: responsive.height(24)),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.search, size: responsive.iconSize(24)),
                      label: Text('Browse Jobs', style: TextStyle(fontSize: responsive.fontSize(16))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.padding(24),
                          vertical: responsive.padding(12),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(responsive.radius(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final savedJobs = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.all(responsive.padding(20)),
            itemCount: savedJobs.length,
            itemBuilder: (context, index) {
              final job = savedJobs[index];
              return _buildSavedJobCard(job, isDarkMode, responsive);
            },
          );
        },
      ),
    );
  }

  Widget _buildSavedJobCard(Job job, bool isDarkMode, ResponsiveHelper responsive) {
    return Container(
      margin: EdgeInsets.only(bottom: responsive.height(16)),
      padding: EdgeInsets.all(responsive.padding(16)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        border: job.isFeatured
            ? Border.all(color: const Color(0xFFFF2D55).withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
            blurRadius: responsive.radius(12),
            offset: Offset(0, responsive.height(4)),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Logo and Remove Bookmark
          Row(
            children: [
              // Company Logo
              Container(
                width: responsive.width(48),
                height: responsive.width(48),
                decoration: BoxDecoration(
                  color: Color(job.logoColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(responsive.radius(12)),
                ),
                child: Center(
                  child: Text(
                    job.logo,
                    style: TextStyle(
                      fontSize: responsive.fontSize(24),
                      fontWeight: FontWeight.bold,
                      color: Color(job.logoColor),
                    ),
                  ),
                ),
              ),
              SizedBox(width: responsive.width(12)),

              // Company and Time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.company,
                      style: TextStyle(
                        fontSize: responsive.fontSize(14),
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: responsive.height(2)),
                    Text(
                      job.postedTime,
                      style: TextStyle(
                        fontSize: responsive.fontSize(12),
                        color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),

              // Remove Bookmark Icon
              GestureDetector(
                onTap: () => _unsaveJob(job.id),
                child: Container(
                  padding: EdgeInsets.all(responsive.padding(8)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(responsive.radius(8)),
                  ),
                  child: Icon(
                    Icons.bookmark,
                    size: responsive.iconSize(20),
                    color: const Color(0xFFFF2D55),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: responsive.height(12)),

          // Job Position
          Text(
            job.position,
            style: TextStyle(
              fontSize: responsive.fontSize(18),
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),

          SizedBox(height: responsive.height(8)),

          // Location and Type
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: responsive.iconSize(16),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              SizedBox(width: responsive.width(4)),
              Text(
                job.country,
                style: TextStyle(
                  fontSize: responsive.fontSize(13),
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
              SizedBox(width: responsive.width(12)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(4)),
                decoration: BoxDecoration(
                  color: job.isRemote
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(responsive.radius(6)),
                ),
                child: Text(
                  job.location,
                  style: TextStyle(
                    fontSize: responsive.fontSize(11),
                    fontWeight: FontWeight.w600,
                    color: job.isRemote ? const Color(0xFF10B981) : Colors.orange,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: responsive.height(12)),

          // Salary and Apply Button
          Row(
            children: [
              Icon(
                Icons.paid_outlined,
                size: responsive.iconSize(16),
                color: const Color(0xFFFF2D55),
              ),
              SizedBox(width: responsive.width(4)),
              Text(
                job.salary,
                style: TextStyle(
                  fontSize: responsive.fontSize(14),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF2D55),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _applyForJob(job.id),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: responsive.padding(16), vertical: responsive.padding(8)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2D55),
                    borderRadius: BorderRadius.circular(responsive.radius(8)),
                  ),
                  child: Text(
                    'Apply Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.fontSize(12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: responsive.height(12)),

          // Skills
          Wrap(
            spacing: responsive.width(8),
            runSpacing: responsive.height(8),
            children: job.skills.map((skill) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: responsive.padding(10), vertical: responsive.padding(6)),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                ),
                child: Text(
                  skill,
                  style: TextStyle(
                    fontSize: responsive.fontSize(11),
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
              );
            }).toList(),
          ),

          // Featured Badge
          if (job.isFeatured) ...[
            SizedBox(height: responsive.height(12)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: responsive.padding(10), vertical: responsive.padding(6)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E6),
                borderRadius: BorderRadius.circular(responsive.radius(8)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    size: responsive.iconSize(14),
                    color: const Color(0xFFFFB800),
                  ),
                  SizedBox(width: responsive.width(4)),
                  Text(
                    'FEATURED JOB',
                    style: TextStyle(
                      fontSize: responsive.fontSize(10),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFFB800),
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
}