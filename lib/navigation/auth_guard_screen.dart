import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/role_provider.dart';
import 'main_navigation_screen.dart';
import '../Screens/home/home_screen.dart';

class AuthGuardScreen extends StatelessWidget {
  const AuthGuardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final roleProvider = Provider.of<RoleProvider>(context);

    // If no Firebase user, go to home
    if (firebaseUser == null) {
      return const HomeScreen();
    }

    // If RoleProvider is still loading
    if (roleProvider.isLoading) {
      return _buildLoadingScreen();
    }

    // If RoleProvider has error
    if (roleProvider.error != null && roleProvider.currentUser == null) {
      return _buildErrorScreen(context, roleProvider.error!);
    }

    // If user exists, proceed to main navigation
    if (roleProvider.currentUser != null) {
      return const MainNavigationScreen();
    }

    // Default fallback (should not reach here)
    return _buildLoadingScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFF2D55)),
            const SizedBox(height: 20),
            Text(
              'Preparing your dashboard...',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This may take a moment',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(BuildContext context, String error) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              'Authentication Issue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Try to refresh
                final roleProvider = Provider.of<RoleProvider>(
                  context,
                  listen: false,
                );
                roleProvider.refreshUser(force: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
              ),
              child: const Text('Retry'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/welcome',
                      (route) => false,
                );
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}