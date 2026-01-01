import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/realtime_database_service.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart'; // NEW: Import presence service
import 'package:firebase_messaging/firebase_messaging.dart';

// Import theme
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/role_provider.dart';

// Import screens
import 'screens/home/home_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/signup_screen.dart';
import 'navigation/drawer_navigation/profile_screen.dart';
import 'navigation/main_navigation_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('🔥🔥🔥 FCM TOKEN: $fcmToken 🔥🔥🔥');
      } catch (e) {
        print('❌ Notification Service error: $e');
      }
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

    // STEP 5: Initialize Presence Service (for online status & typing)
    if (!kIsWeb) {
      try {
        print('🟢 Initializing Presence Service...');
        final presenceService = PresenceService();
        await presenceService.initialize();
        print('✅ Presence Service ready');
      } catch (e) {
        print('⚠️ Presence Service error: $e');
      }
    }

    print('✅ App initialization complete');
  } catch (e) {
    print('❌ Initialization error: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => RoleProvider(), // RoleProvider will auto-initialize
        ),
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
          navigatorKey: navigatorKey, // 🚀 ADD THIS LINE
          title: 'HireHubb',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          initialRoute: '/',
          routes: {
            '/': (context) => const AppLifecycleWrapper(),
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

class AppLifecycleWrapper extends StatefulWidget {
  const AppLifecycleWrapper({super.key});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 AppLifecycleWrapper: State changed to $state');

    final presenceService = PresenceService();

    if (state == AppLifecycleState.resumed) {
      // User is back - set online
      presenceService.setOnline();
      
      // CRITICAL FIX: More aggressive refresh with longer delay
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        print('🔄 App resumed - forcing role refresh...');
        await Future.delayed(const Duration(milliseconds: 800)); // Longer delay

        if (mounted) {
          final roleProvider = context.read<RoleProvider>();
          await roleProvider.forceRefresh();
          print('✅ Role force refreshed after app resume');
        }
      });
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive ||
               state == AppLifecycleState.detached) {
      // User left - set offline and stop typing
      presenceService.setOffline();
      presenceService.stopCurrentTyping();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    print('🔍 AuthWrapper: Building...');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        print('🔍 AuthWrapper: Auth state - ${authSnapshot.connectionState}');

        // Show loading while checking auth
        if (authSnapshot.connectionState == ConnectionState.waiting) {
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

        if (authSnapshot.hasError) {
          print('❌ AuthWrapper: Error - ${authSnapshot.error}');
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${authSnapshot.error}',
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

        // User is authenticated
        if (authSnapshot.hasData && authSnapshot.data != null) {
          print('✅ AuthWrapper: User authenticated - ${authSnapshot.data!.uid}');

          // CRITICAL FIX: Use Consumer instead of just reading once
          return Consumer<RoleProvider>(
            builder: (context, roleProvider, child) {
              print('🔍 AuthWrapper: RoleProvider state:');
              print('   - isLoading: ${roleProvider.isLoading}');
              print('   - userRole: ${roleProvider.userRole?.displayName}');
              print('   - isRecruiter: ${roleProvider.isRecruiter}');

              // Show loading while role is being fetched
              if (roleProvider.isLoading) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFFFF2D55)),
                        SizedBox(height: 16),
                        Text(
                          'Loading your profile...',
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

              // CRITICAL: Check if role is actually loaded
              if (roleProvider.currentUser == null) {
                print('⚠️ Role loaded but user is null, refreshing...');
                // Trigger a refresh if user is null
                Future.delayed(Duration.zero, () {
                  roleProvider.forceRefresh();
                });

                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF2D55)),
                  ),
                );
              }

              // Role loaded successfully, show main screen
              print('✅ AuthWrapper: Showing MainNavigationScreen for ${roleProvider.userRole?.displayName}');
              return const MainNavigationScreen();
            },
          );
        }

        // No user, show welcome screen
        print('ℹ️ AuthWrapper: No user, showing HomeScreen');
        return const HomeScreen();
      },
    );
  }
}