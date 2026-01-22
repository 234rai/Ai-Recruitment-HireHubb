// lib/navigation/analytics/hiring_metrics_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../utils/responsive_helper.dart';

class HiringMetricsScreen extends StatefulWidget {
  const HiringMetricsScreen({super.key});

  @override
  State<HiringMetricsScreen> createState() => _HiringMetricsScreenState();
}

class _HiringMetricsScreenState extends State<HiringMetricsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Hiring Metrics',
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
              'Please log in to view metrics',
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
            .collection('applications')
            .where('recruiterId', isEqualTo: _userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
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
                    'Error loading data',
                    style: TextStyle(
                      fontSize: responsive.fontSize(16),
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          final applications = snapshot.data?.docs ?? [];
          final metrics = _calculateMetrics(applications);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overview Card
                _buildOverviewCard(isDarkMode, metrics, responsive),

                SizedBox(height: responsive.height(12)),

                // Status Breakdown
                _buildStatusBreakdown(isDarkMode, metrics, responsive),

                SizedBox(height: responsive.height(12)),

                // Conversion Metrics
                _buildConversionMetrics(isDarkMode, metrics, responsive),

                SizedBox(height: responsive.height(12)),

                // Recent Applications
                _buildRecentApplications(isDarkMode, applications, responsive),

                SizedBox(height: responsive.height(16)),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<String, dynamic> _calculateMetrics(List<QueryDocumentSnapshot> applications) {
    int pending = 0;
    int inReview = 0;
    int shortlisted = 0;
    int hired = 0;
    int rejected = 0;

    for (var doc in applications) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status']?.toString().toLowerCase() ?? 'applied';

      switch (status) {
        case 'applied':
        case 'pending':
          pending++;
          break;
        case 'inprocess':
        case 'in_process':
        case 'reviewed':
          inReview++;
          break;
        case 'shortlisted':
          shortlisted++;
          break;
        case 'completed':
        case 'hired':
          hired++;
          break;
        case 'rejected':
          rejected++;
          break;
        default:
          pending++;
      }
    }

    final total = applications.length;
    final conversionRate = total > 0 ? (hired / total * 100) : 0.0;
    final activeApplications = pending + inReview + shortlisted;

    return {
      'total': total,
      'pending': pending,
      'inReview': inReview,
      'shortlisted': shortlisted,
      'hired': hired,
      'rejected': rejected,
      'conversionRate': conversionRate,
      'activeApplications': activeApplications,
    };
  }

  Widget _buildOverviewCard(bool isDarkMode, Map<String, dynamic> metrics, ResponsiveHelper responsive) {
    final total = metrics['total'] as int;
    final activeApplications = metrics['activeApplications'] as int;

    return Container(
      margin: EdgeInsets.fromLTRB(responsive.padding(16), responsive.padding(16), responsive.padding(16), 0),
      padding: EdgeInsets.all(responsive.padding(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [const Color(0xFFFF2D55), const Color(0xFFD81B43)]
              : [const Color(0xFFFF2D55), const Color(0xFFFF5A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2D55).withOpacity(0.25),
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
                'Total Applications',
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
                child: Icon(Icons.people_outline, color: Colors.white, size: responsive.iconSize(20)),
              ),
            ],
          ),
          SizedBox(height: responsive.height(12)),
          Text(
            total.toString(),
            style: TextStyle(
              fontSize: responsive.fontSize(40),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          SizedBox(height: responsive.height(4)),
          Text(
            '$activeApplications active • ${metrics['hired']} hired',
            style: TextStyle(
              fontSize: responsive.fontSize(13),
              color: Colors.white70,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown(bool isDarkMode, Map<String, dynamic> metrics, ResponsiveHelper responsive) {
    final total = metrics['total'] as int;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
      padding: EdgeInsets.all(responsive.padding(18)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
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
                Icons.analytics_outlined,
                size: responsive.iconSize(20),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              SizedBox(width: responsive.width(8)),
              Text(
                'Application Pipeline',
                style: TextStyle(
                  fontSize: responsive.fontSize(16),
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.height(20)),

          // Funnel Chart Representation
          _buildFunnelItem(
            'Pending Review',
            metrics['pending'] as int,
            total,
            const Color(0xFFFFB800),
            Icons.schedule_outlined,
            isDarkMode,
            1.0,
            responsive,
          ),
          SizedBox(height: responsive.height(8)),
          _buildFunnelItem(
            'In Review',
            metrics['inReview'] as int,
            total,
            const Color(0xFF007AFF),
            Icons.visibility_outlined,
            isDarkMode,
            0.85,
            responsive,
          ),
          SizedBox(height: responsive.height(8)),
          _buildFunnelItem(
            'Shortlisted',
            metrics['shortlisted'] as int,
            total,
            const Color(0xFF5856D6),
            Icons.star_outline,
            isDarkMode,
            0.70,
            responsive,
          ),
          SizedBox(height: responsive.height(8)),
          _buildFunnelItem(
            'Hired',
            metrics['hired'] as int,
            total,
            const Color(0xFF34C759),
            Icons.check_circle_outline,
            isDarkMode,
            0.55,
            responsive,
          ),
          SizedBox(height: responsive.height(8)),
          _buildFunnelItem(
            'Rejected',
            metrics['rejected'] as int,
            total,
            const Color(0xFFFF3B30),
            Icons.cancel_outlined,
            isDarkMode,
            0.40,
            responsive,
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelItem(
      String label,
      int count,
      int total,
      Color color,
      IconData icon,
      bool isDarkMode,
      double widthFactor,
      ResponsiveHelper responsive,
      ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      children: [
        // Label and Count Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsive.padding(4), vertical: responsive.padding(2)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: responsive.iconSize(16)),
                  SizedBox(width: responsive.width(6)),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: responsive.fontSize(13),
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: responsive.fontSize(11),
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(width: responsive.width(8)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(3)),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(responsive.radius(6)),
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: responsive.fontSize(13),
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: responsive.height(6)),

        // Funnel Bar
        Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(
              height: responsive.height(36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.8),
                    color.withOpacity(0.5),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(responsive.radius(8)),
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Stack(
                children: [
                  // Animated Progress Bar
                  if (count > 0)
                    FractionallySizedBox(
                      widthFactor: percentage / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color,
                              color.withOpacity(0.7),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(responsive.radius(7)),
                        ),
                      ),
                    ),

                  // Dot pattern overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(responsive.radius(8)),
                      child: CustomPaint(
                        painter: DotPatternPainter(
                          color: color,
                          isDarkMode: isDarkMode,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildConversionMetrics(bool isDarkMode, Map<String, dynamic> metrics, ResponsiveHelper responsive) {
    final rate = metrics['conversionRate'] as double;
    final hired = metrics['hired'] as int;
    final total = metrics['total'] as int;
    final isGoodRate = rate > 10;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
      padding: EdgeInsets.all(responsive.padding(18)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
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
                Icons.trending_up,
                size: responsive.iconSize(20),
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
              SizedBox(width: responsive.width(8)),
              Text(
                'Conversion Rate',
                style: TextStyle(
                  fontSize: responsive.fontSize(16),
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
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
                          rate.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: responsive.fontSize(36),
                            fontWeight: FontWeight.bold,
                            color: isGoodRate ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                            height: 1.1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: responsive.padding(4), left: responsive.padding(2)),
                          child: Text(
                            '%',
                            style: TextStyle(
                              fontSize: responsive.fontSize(20),
                              fontWeight: FontWeight.w600,
                              color: isGoodRate ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: responsive.height(6)),
                    Text(
                      '$hired hired from $total applications',
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
                width: responsive.width(70),
                height: responsive.width(70),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: responsive.width(70),
                      height: responsive.width(70),
                      child: CircularProgressIndicator(
                        value: rate / 100,
                        strokeWidth: responsive.width(6),
                        backgroundColor: isDarkMode
                            ? Colors.grey.shade800
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isGoodRate ? const Color(0xFF34C759) : const Color(0xFFFF9500),
                        ),
                      ),
                    ),
                    Icon(
                      isGoodRate ? Icons.trending_up : Icons.trending_flat,
                      size: responsive.iconSize(24),
                      color: isGoodRate ? const Color(0xFF34C759) : const Color(0xFFFF9500),
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

  Widget _buildRecentApplications(bool isDarkMode, List<QueryDocumentSnapshot> applications, ResponsiveHelper responsive) {
    final sortedApps = List<QueryDocumentSnapshot>.from(applications);
    sortedApps.sort((a, b) {
      final aDate = (a.data() as Map)['appliedDate'] as Timestamp?;
      final bDate = (b.data() as Map)['appliedDate'] as Timestamp?;
      if (aDate == null || bDate == null) return 0;
      return bDate.compareTo(aDate);
    });

    final recentApps = sortedApps.take(5).toList();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: responsive.padding(16)),
      padding: EdgeInsets.all(responsive.padding(18)),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(responsive.radius(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.04),
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
                    Icons.history,
                    size: responsive.iconSize(20),
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                  SizedBox(width: responsive.width(8)),
                  Text(
                    'Recent Applications',
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
                  color: isDarkMode
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                ),
                child: Text(
                  'Last 5',
                  style: TextStyle(
                    fontSize: responsive.fontSize(12),
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: responsive.height(16)),
          if (recentApps.isEmpty)
            Container(
              padding: EdgeInsets.symmetric(vertical: responsive.padding(32)),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: responsive.iconSize(48),
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                  SizedBox(height: responsive.height(12)),
                  Text(
                    'No applications yet',
                    style: TextStyle(
                      fontSize: responsive.fontSize(14),
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: responsive.height(4)),
                  Text(
                    'Applications will appear here',
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
              itemCount: recentApps.length,
              separatorBuilder: (_, __) => Divider(
                height: responsive.height(20),
                thickness: 0.5,
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final data = recentApps[index].data() as Map<String, dynamic>;
                final name = data['jobSeekerName'] ?? 'Unknown Applicant';
                final jobTitle = data['jobTitle'] ?? 'Unknown Position';
                final status = data['status'] ?? 'applied';
                final appliedDate = data['appliedDate'] as Timestamp?;

                return InkWell(
                  onTap: () {
                    // Navigate to application details
                  },
                  borderRadius: BorderRadius.circular(responsive.radius(8)),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: responsive.padding(4)),
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
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: TextStyle(
                                fontSize: responsive.fontSize(16),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
                                name,
                                style: TextStyle(
                                  fontSize: responsive.fontSize(14),
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: responsive.height(3)),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      jobTitle,
                                      style: TextStyle(
                                        fontSize: responsive.fontSize(12),
                                        color: isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600,
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
                        SizedBox(width: responsive.width(8)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildStatusChip(status, isDarkMode, responsive),
                            if (appliedDate != null) ...[
                              SizedBox(height: responsive.height(4)),
                              Text(
                                DateFormat('MMM d').format(appliedDate.toDate()),
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

  Widget _buildStatusChip(String status, bool isDarkMode, ResponsiveHelper responsive) {
    Color color;
    String label;

    switch (status.toLowerCase()) {
      case 'applied':
      case 'pending':
        color = const Color(0xFFFFB800);
        label = 'Pending';
        break;
      case 'inprocess':
      case 'reviewed':
        color = const Color(0xFF007AFF);
        label = 'Review';
        break;
      case 'shortlisted':
        color = const Color(0xFF5856D6);
        label = 'Shortlisted';
        break;
      case 'completed':
      case 'hired':
        color = const Color(0xFF34C759);
        label = 'Hired';
        break;
      case 'rejected':
        color = const Color(0xFFFF3B30);
        label = 'Rejected';
        break;
      default:
        color = const Color(0xFFFFB800);
        label = 'Pending';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(4)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(responsive.radius(6)),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: responsive.fontSize(10),
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// Custom painter for dot pattern - MOVED OUTSIDE THE CLASS
class DotPatternPainter extends CustomPainter {
  final Color color;
  final bool isDarkMode;

  DotPatternPainter({required this.color, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 8.0;
    const dotRadius = 1.0;

    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}