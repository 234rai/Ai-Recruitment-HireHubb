// lib/navigation/main_navigation_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart'; // NEW
import '../providers/role_provider.dart';
import '../services/messaging_service.dart'; // NEW
import 'home_screen.dart';
import 'explore_screen.dart';
import 'application_screen.dart';
import 'notification_screen.dart';
import 'messaging/conversations_screen.dart';
import 'drawer_navigation/job_management_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // NEW: Services for real badge counts
  final MessagingService _messagingService = MessagingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    // Log initial role on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final roleProvider = Provider.of<RoleProvider>(context, listen: false);
      print('🏠 MainNavigationScreen initialized:');
      print('   - Role: ${roleProvider.userRole?.displayName}');
      print('   - isRecruiter: ${roleProvider.isRecruiter}');
      print('   - isJobSeeker: ${roleProvider.isJobSeeker}');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 MainNavigationScreen Lifecycle: $state');

    if (state == AppLifecycleState.resumed) {
      // When app comes back to foreground, force refresh and rebuild
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        print('🔄 App resumed - refreshing role...');
        final roleProvider = Provider.of<RoleProvider>(context, listen: false);

        // Force refresh the role
        await roleProvider.forceRefresh();

        // Force rebuild the entire screen
        if (mounted) {
          setState(() {
            // This will trigger a rebuild with the refreshed role
          });
          print('✅ Role refreshed: ${roleProvider.userRole?.displayName}');
          print('   - isRecruiter: ${roleProvider.isRecruiter}');
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<RoleProvider>(
      builder: (context, roleProvider, child) {
        print('🔄 MainNavigationScreen - Status:');
        print('   - Firebase User: ${FirebaseAuth.instance.currentUser?.uid}');
        print('   - RoleProvider User: ${roleProvider.currentUser?.uid}');
        print('   - isLoading: ${roleProvider.isLoading}');
        print('   - Role: ${roleProvider.userRole?.displayName}');

        // 🔥 CRITICAL: If user is null but Firebase user exists
        if (FirebaseAuth.instance.currentUser != null &&
            roleProvider.currentUser == null &&
            !roleProvider.isLoading) {

          print('⚠️ Inconsistent state detected - forcing refresh');

          // Try to force refresh once
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await roleProvider.forceRefresh();

            // If still null after refresh, show error
            if (roleProvider.currentUser == null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please sign in again'),
                  backgroundColor: Colors.orange,
                ),
              );

              // Sign out and redirect
              await FirebaseAuth.instance.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/welcome',
                      (route) => false
              );
            }
          });

          return _buildLoadingScreen(isDarkMode);
        }

        // Normal loading state
        if (roleProvider.isLoading) {
          return _buildLoadingScreen(isDarkMode);
        }

        // 🔥 NEW: Gracefully handle null user
        if (roleProvider.currentUser == null) {
          return _buildFallbackScreen(isDarkMode);
        }

        // Everything is good, show the app
        final List<Widget> screens = roleProvider.isRecruiter
            ? _getRecruiterScreens()
            : _getJobSeekerScreens();

        print('✅ Showing ${roleProvider.isRecruiter ? "RECRUITER" : "JOB SEEKER"} screens');

        return Scaffold(
          body: FadeTransition(
            opacity: _animation,
            child: screens[_currentIndex],
          ),
          bottomNavigationBar: _buildBottomNavBar(isDarkMode, roleProvider),
        );
      },
    );
  }

// Add these helper methods:
  Widget _buildLoadingScreen(bool isDarkMode) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF2D55)),
            const SizedBox(height: 20),
            Text(
              'Loading your dashboard...',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackScreen(bool isDarkMode) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off,
              size: 64,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(height: 20),
            Text(
              'User session expired',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please sign in again',
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/welcome',
                        (route) => false
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(bool isDarkMode, RoleProvider roleProvider) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: roleProvider.isRecruiter
                ? _getRecruiterNavItems(isDarkMode)
                : _getJobSeekerNavItems(isDarkMode),
          ),
        ),
      ),
    );
  }

  // JOB SEEKER SCREENS
  List<Widget> _getJobSeekerScreens() {
    return [
      HomeScreen(), // Job Feed
      ExploreScreen(), // Explore Jobs
      ApplicationsScreen(), // My Applications
      NotificationsScreen(), // Notifications
      ConversationsScreen(), // NEW: Messages
    ];
  }

  // RECRUITER SCREENS
  List<Widget> _getRecruiterScreens() {
    return [
      HomeScreen(), // Dashboard
      JobManagementScreen(), // Job Management (replaces ExploreScreen)
      ApplicationsScreen(), // Manage Applications
      NotificationsScreen(), // Notifications
      ConversationsScreen(), // Messages
    ];
  }

  // JOB SEEKER NAV ITEMS
  List<Widget> _getJobSeekerNavItems(bool isDarkMode) {
    return [
      _buildNavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
        index: 0,
        isDarkMode: isDarkMode,
      ),
      _buildNavItem(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore,
        label: 'Explore',
        index: 1,
        isDarkMode: isDarkMode,
      ),
      _buildNavItem(
        icon: Icons.work_outline,
        selectedIcon: Icons.work,
        label: 'Applications',
        index: 2,
        isDarkMode: isDarkMode,
      ),
      // NEW: Notification with real count
      _buildNavItemWithBadge(
        icon: Icons.notifications_none_sharp,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        index: 3,
        isDarkMode: isDarkMode,
        badgeStream: _getNotificationCountStream(),
      ),
      // NEW: Messages with real count
      _buildNavItemWithBadge(
        icon: Icons.message_outlined,
        selectedIcon: Icons.message,
        label: 'Messages',
        index: 4,
        isDarkMode: isDarkMode,
        badgeStream: _messagingService.getUnreadConversationCount(),
      ),
    ];
  }

  // RECRUITER NAV ITEMS
  List<Widget> _getRecruiterNavItems(bool isDarkMode) {
    return [
      _buildNavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
        index: 0,
        isDarkMode: isDarkMode,
      ),
      _buildNavItem(
        icon: Icons.people_outline,
        selectedIcon: Icons.people,
        label: 'Candidates',
        index: 1,
        isDarkMode: isDarkMode,
      ),
      _buildNavItem(
        icon: Icons.description_outlined,
        selectedIcon: Icons.description,
        label: 'Applications',
        index: 2,
        isDarkMode: isDarkMode,
      ),
      // NEW: Notification with real count
      _buildNavItemWithBadge(
        icon: Icons.notifications_none_sharp,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        index: 3,
        isDarkMode: isDarkMode,
        badgeStream: _getNotificationCountStream(),
      ),
      // NEW: Messages with real count
      _buildNavItemWithBadge(
        icon: Icons.message_outlined,
        selectedIcon: Icons.message,
        label: 'Messages',
        index: 4,
        isDarkMode: isDarkMode,
        badgeStream: _messagingService.getUnreadConversationCount(),
      ),
    ];
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isDarkMode,
    bool showBadge = false,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF2D55).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? const Color(0xFFFF2D55)
                      : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                  size: 24,
                ),
                if (showBadge && !isSelected)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF2D55),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFF2D55),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // NEW: Get notification count stream
  Stream<int> _getNotificationCountStream() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // NEW: Build nav item with stream-based badge
  Widget _buildNavItemWithBadge({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required bool isDarkMode,
    required Stream<int> badgeStream,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF2D55).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<int>(
              stream: badgeStream,
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? selectedIcon : icon,
                      color: isSelected
                          ? const Color(0xFFFF2D55)
                          : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      size: 24,
                    ),
                    // Show badge with count if > 0
                    if (count > 0 && !isSelected)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2D55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFF2D55),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}