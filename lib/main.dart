import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/realtime_database_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/notification_manager_service.dart';

// Import theme
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/role_provider.dart'; // ADD THIS

// Import screens
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/signup_screen.dart';
import 'navigation/drawer_navigation/profile_screen.dart';
import 'navigation/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // STEP 1: Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized');

    // STEP 2: Initialize Notification Service (ONLY if not web)
    if (!kIsWeb) {
      try {
        print('🔔 Initializing Notification Service...');
        final notificationService = NotificationService();
        await notificationService.initialize();
        print('✅ Notification Service ready');
        final notificationManager = NotificationManagerService();
        notificationManager.initializeNotificationListener();
        print('✅ Notification Manager ready');
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('🔥🔥🔥 FCM TOKEN: $fcmToken 🔥🔥🔥');
      } catch (e) {
        print('❌ Notification Service error: $e');
      }
    } else {
      print('ℹ️ Web platform - notifications not supported');
    }

    // STEP 3: Enable Firebase Realtime Database offline persistence (mobile only)
    if (!kIsWeb) {
      try {
        FirebaseDatabase.instance.setPersistenceEnabled(true);
        FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
        print('✅ Offline persistence enabled');
      } catch (e) {
        print('⚠️ Could not enable persistence: $e');
      }
    }

    // STEP 4: Test database connection
    print('🚀 Testing Realtime Database...');
    final dbService = RealtimeDatabaseService();
    final isConnected = await dbService.testConnection();

    if (isConnected) {
      print('✅ Realtime Database connected');
    } else {
      print('⚠️ Realtime Database connection issues');
    }

    print('✅ App initialization complete');
  } catch (e) {
    print('❌ Initialization error: $e');
  }

  runApp(
    // UPDATED: Add both providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => RoleProvider()), // ADD THIS
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'HireHubb',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/welcome': (context) => const HomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/signup': (context) => const SignUpScreen(),
            '/main': (context) => const MainNavigationScreen(),
            '/profile': (context) => const ProfileScreen(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF2D55)),
                  SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Color(0xFFFF2D55),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                            (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainNavigationScreen();
        }

        return const HomeScreen();
      },
    );
  }
}