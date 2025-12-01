// lib/navigation/main_navigation_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ADD THIS
import '../providers/role_provider.dart'; // ADD THIS
import 'home_screen.dart';
import 'explore_screen.dart';
import 'application_screen.dart';
import 'notification_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
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
    final isDarkMode = Theme
        .of(context)
        .brightness == Brightness.dark;
    final roleProvider = Provider.of<RoleProvider>(context);

    // Show loading while role is being fetched
    if (roleProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF2D55)),
        ),
      );
    }

    // ROLE-BASED SCREENS: Different screens for different roles
    final List<Widget> screens = roleProvider.isRecruiter
        ? _getRecruiterScreens()
        : _getJobSeekerScreens();

    return Scaffold(
      body: FadeTransition(
        opacity: _animation,
        child: screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
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
      ),
    );
  }

  // JOB SEEKER SCREENS
  List<Widget> _getJobSeekerScreens() {
    return const [
      HomeScreen(), // Job Feed
      ExploreScreen(), // Explore Jobs
      ApplicationsScreen(), // My Applications
      NotificationsScreen(), // Notifications
    ];
  }

  // RECRUITER SCREENS
  List<Widget> _getRecruiterScreens() {
    return const [
      HomeScreen(), // Dashboard (will show recruiter view)
      ExploreScreen(), // Find Candidates
      ApplicationsScreen(), // Manage Applications (will show recruiter view)
      NotificationsScreen(), // Notifications
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
      _buildNavItem(
        icon: Icons.notifications_none_sharp,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        index: 3,
        isDarkMode: isDarkMode,
        showBadge: true,
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
        showBadge: true, // Show badge for new applications
      ),
      _buildNavItem(
        icon: Icons.notifications_none_sharp,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        index: 3,
        isDarkMode: isDarkMode,
        showBadge: true,
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
                      : (isDarkMode ? Colors.grey.shade400 : Colors.grey
                      .shade600),
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
} 