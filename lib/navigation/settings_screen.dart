// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _jobAlerts = true;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _emailNotifications = prefs.getBool('emailNotifications') ?? true;
      _jobAlerts = prefs.getBool('jobAlerts') ?? true;
      _language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('emailNotifications', _emailNotifications);
    await prefs.setBool('jobAlerts', _jobAlerts);
    await prefs.setString('language', _language);
  }

  // Method to handle logout
  void _handleLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // Navigate to welcome screen and remove all previous routes
      Navigator.pushNamedAndRemoveUntil(
          context,
          '/welcome',
              (route) => false
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to change password
  void _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to change password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show dialog to enter email for password reset
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2A2A2A)
            : Colors.white,
        title: Text(
          'Reset Password',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We will send a password reset link to your email:',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? 'No email found',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE91E63),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendPasswordResetEmail(user.email!);
            },
            child: const Text(
              'Send Reset Link',
              style: TextStyle(color: Color(0xFFE91E63)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset link sent to $email'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to convert ThemeMode to boolean for switch
  bool _isDarkModeEnabled(ThemeMode themeMode, bool currentIsDarkMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return currentIsDarkMode;
    }
  }

  // Helper method to get theme mode description
  String _getThemeModeDescription(ThemeMode themeMode, bool currentIsDarkMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return 'Dark theme enabled';
      case ThemeMode.light:
        return 'Light theme enabled';
      case ThemeMode.system:
        return 'Using system theme (${currentIsDarkMode ? 'Dark' : 'Light'})';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDarkMode ? Colors.white : const Color(0xFFE91E63),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance', isDarkMode),
          _buildSettingsCard(
            isDarkMode: isDarkMode,
            child: Column(
              children: [
                // Dark Mode Switch using ThemeProvider
                _buildSwitchTile(
                  icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  title: 'Dark Mode',
                  subtitle: _getThemeModeDescription(themeProvider.themeMode, isDarkMode),
                  value: _isDarkModeEnabled(themeProvider.themeMode, isDarkMode),
                  onChanged: (value) {
                    // Toggle between dark and light mode
                    final newThemeMode = value ? ThemeMode.dark : ThemeMode.light;
                    themeProvider.setThemeMode(newThemeMode);
                  },
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.language,
                  title: 'Language',
                  subtitle: _language,
                  onTap: () => _showLanguageDialog(isDarkMode),
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader('Notifications', isDarkMode),
          _buildSettingsCard(
            isDarkMode: isDarkMode,
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications,
                  title: 'Push Notifications',
                  subtitle: 'Receive push notifications',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                    _saveSettings();
                  },
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.email,
                  title: 'Email Notifications',
                  subtitle: 'Receive updates via email',
                  value: _emailNotifications,
                  onChanged: (value) {
                    setState(() {
                      _emailNotifications = value;
                    });
                    _saveSettings();
                  },
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  icon: Icons.work_outline,
                  title: 'Job Alerts',
                  subtitle: 'Get notified about new job matches',
                  value: _jobAlerts,
                  onChanged: (value) {
                    setState(() {
                      _jobAlerts = value;
                    });
                    _saveSettings();
                  },
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Account Section
          _buildSectionHeader('Account', isDarkMode),
          _buildSettingsCard(
            isDarkMode: isDarkMode,
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.person,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    // Navigate to profile edit screen
                    Navigator.pushNamed(context, '/profile');
                  },
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.lock,
                  title: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: _changePassword,
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.privacy_tip,
                  title: 'Privacy',
                  subtitle: 'Manage your privacy settings',
                  onTap: () {
                    _showComingSoonSnackbar();
                  },
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Support Section
          _buildSectionHeader('Support', isDarkMode),
          _buildSettingsCard(
            isDarkMode: isDarkMode,
            child: Column(
              children: [
                _buildListTile(
                  icon: Icons.help_outline,
                  title: 'Help Center',
                  subtitle: 'Get help and support',
                  onTap: () {
                    _showComingSoonSnackbar();
                  },
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.feedback,
                  title: 'Send Feedback',
                  subtitle: 'Share your thoughts with us',
                  onTap: () {
                    _showComingSoonSnackbar();
                  },
                  isDarkMode: isDarkMode,
                ),
                const Divider(height: 1),
                _buildListTile(
                  icon: Icons.info_outline,
                  title: 'About',
                  subtitle: 'App version 1.0.0',
                  onTap: () {
                    _showAboutDialog(isDarkMode);
                  },
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Logout Button
          _buildSettingsCard(
            isDarkMode: isDarkMode,
            child: _buildListTile(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              onTap: () {
                _showLogoutDialog(isDarkMode);
              },
              textColor: Colors.red,
              iconColor: Colors.red,
              isDarkMode: isDarkMode,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required Widget child, required bool isDarkMode}) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.pink.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDarkMode,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE91E63).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFFE91E63),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFE91E63),
        activeTrackColor: const Color(0xFFE91E63).withOpacity(0.3),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDarkMode,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFFE91E63)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: iconColor ?? const Color(0xFFE91E63),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: textColor ?? (isDarkMode ? Colors.white : Colors.black87),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  void _showLanguageDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Select Language',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption('English', isDarkMode),
            _buildLanguageOption('Spanish', isDarkMode),
            _buildLanguageOption('French', isDarkMode),
            _buildLanguageOption('German', isDarkMode),
            _buildLanguageOption('Hindi', isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(String language, bool isDarkMode) {
    return RadioListTile<String>(
      title: Text(
        language,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      value: language,
      groupValue: _language,
      activeColor: const Color(0xFFE91E63),
      onChanged: (value) {
        setState(() {
          _language = value!;
        });
        _saveSettings();
        Navigator.pop(context);
      },
    );
  }

  void _showAboutDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'About Hire Hubb',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(
                Icons.work,
                size: 64,
                color: const Color(0xFFE91E63),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your trusted platform for finding the perfect job match.',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFE91E63)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Logout',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: TextStyle(
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: _handleLogout,
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon!'),
        backgroundColor: Color(0xFFE91E63),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}