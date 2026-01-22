import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/google_auth_service.dart';
import '../../services/notification_service.dart';
import '../../navigation/main_navigation_screen.dart';
import 'forgot_password_screen.dart';
import 'package:major_project/providers/role_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/responsive_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false; // Add this for Google sign-in loading state

  // Add GoogleAuthService instance
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Email/Password Login (Your original logic - unchanged)
  // Email/Password Login
  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        print('Login successful: ${userCredential.user!.email}');

        if (mounted) {
          // ⭐ CRITICAL: Refresh role before navigation (ONLY ONCE)
          final roleProvider = Provider.of<RoleProvider>(context, listen: false);
          await roleProvider.refreshUser();

          print('🔐 Login: Role refreshed - ${roleProvider.userRole?.displayName}');

          // ✅ CRITICAL FIX: Explicitly save FCM token after login (defense in depth)
          try {
            final notificationService = NotificationService();
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              await notificationService.saveTokenAfterLogin(token);
              print('✅ FCM token saved after email login');
            } else {
              print('⚠️ FCM token is null after email login');
            }
          } catch (e) {
            print('❌ Error saving FCM token after email login: $e');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Color(0xFFFF2D55),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          );
        }

      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'user-not-found') {
          errorMessage = 'No user found with this email.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Wrong password provided.';
        } else {
          errorMessage = e.message ?? 'Login failed. Please try again.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final userCredential = await _googleAuthService.signInWithGoogle();

      if (userCredential != null && mounted) {
        print('✅ Google sign-in successful: ${userCredential.user?.email}');

        // 🔥 FIX: Check if user is new FIRST
        final isNewUser = await _googleAuthService.isNewUser(userCredential.user!.uid);

        if (isNewUser) {
          // 🔥 CRITICAL: Show role selection for NEW users
          final selectedRole = await _showGoogleSignInRoleSelectionDialog(context);

          if (selectedRole == null) {
            // User cancelled - sign them out
            await _googleAuthService.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a role to continue'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return;
          }

          print('📝 Selected role: $selectedRole');

          // Save role to Firestore with verification
          await _googleAuthService.saveUserRole(
            uid: userCredential.user!.uid,
            email: userCredential.user!.email!,
            displayName: userCredential.user!.displayName ?? '',
            role: selectedRole,
          );

          print('✅ Role saved and verified');
        } else {
          print('ℹ️ Existing user - role already set');
        }

        // Refresh role provider
        if (mounted) {
          final roleProvider = Provider.of<RoleProvider>(context, listen: false);
          await roleProvider.forceRefresh();

          print('✅ Role loaded: ${roleProvider.userRole?.displayName}');

          // ✅ CRITICAL FIX: Explicitly save FCM token after Google login (defense in depth)
          try {
            final notificationService = NotificationService();
            final token = await FirebaseMessaging.instance.getToken();
            if (token != null) {
              await notificationService.saveTokenAfterLogin(token);
              print('✅ FCM token saved after Google login');
            } else {
              print('⚠️ FCM token is null after Google login');
            }
          } catch (e) {
            print('❌ Error saving FCM token after Google login: $e');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome back!'),
              backgroundColor: Color(0xFFFF2D55),
            ),
          );

          // Navigate to main screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                (route) => false,
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign-in cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Google sign-in error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

// Add this new method to show role selection dialog:
  Future<String?> _showGoogleSignInRoleSelectionDialog(BuildContext context) async {
    String? selectedRole;
    bool isRecruiter = true;
    final TextEditingController companyController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Your Role'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please choose how you want to use HireHubb:',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Role Selection Toggle (same as signup screen)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            alignment: isRecruiter ? Alignment.centerLeft : Alignment.centerRight,
                            child: FractionallySizedBox(
                              widthFactor: 0.5,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF2D55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                height: 44,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isRecruiter = true;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    color: Colors.transparent,
                                    child: Text(
                                      'Recruiter',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: isRecruiter ? Colors.white : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                        fontWeight: isRecruiter ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isRecruiter = false;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    color: Colors.transparent,
                                    child: Text(
                                      'Job Seeker',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: !isRecruiter ? Colors.white : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                        fontWeight: !isRecruiter ? FontWeight.w600 : FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Company field for recruiters
                    if (isRecruiter)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company Name (Optional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: companyController,
                            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Enter your company name',
                              hintStyle: TextStyle(color: isDarkMode ? const Color(0xFF6A6A6A) : Colors.grey.shade400),
                              filled: true,
                              fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade200),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFFFF2D55), width: 2),
                              ),
                              prefixIcon: const Icon(Icons.business_outlined, color: Color(0xFFFF2D55)),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    selectedRole = isRecruiter ? 'recruiter' : 'job_seeker';
                    Navigator.pop(context, selectedRole);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2D55),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFFFF2D55),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.responsive.padding(24)),
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Column(
                children: [
                  const SizedBox(height: 20),

                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: _buildHeader(isDarkMode),
                    ),
                  ),

                  const SizedBox(height: 48),

                  Transform.translate(
                    offset: Offset(0, _slideAnimation.value * 0.7),
                    child: Opacity(
                      opacity: _fadeAnimation.value,
                      child: _buildLoginForm(isDarkMode),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          width: context.responsive.width(80),
          height: context.responsive.height(80),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF2D55), Color(0xFFFF6B9D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF2D55).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.work_outline,
            color: Colors.white,
            size: context.responsive.iconSize(40),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: context.responsive.fontSize(32),
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Sign in to your HireHubb account',
          style: TextStyle(
            fontSize: context.responsive.fontSize(16),
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isDarkMode) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email Field
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFF2D55)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF2D55), width: 2),
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 20),

          // Password Field
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isDarkMode ? Colors.black : Colors.grey).withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF2D55)),
                suffixIcon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: IconButton(
                    key: ValueKey<bool>(_isPasswordVisible),
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF2D55), width: 2),
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
          ),

          const SizedBox(height: 16),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF2D55),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[300],
                  thickness: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Or continue with',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: isDarkMode ? const Color(0xFF3A3A3A) : Colors.grey[300],
                  thickness: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Google Login Button - NOW FUNCTIONAL!
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: _isGoogleLoading ? null : _signInWithGoogle, // UPDATED
              style: OutlinedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.white : Colors.black,
                foregroundColor: isDarkMode ? Colors.black : Colors.white,
                side: BorderSide(color: isDarkMode ? Colors.white : Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: _isGoogleLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDarkMode ? Colors.black : Colors.white,
                  ),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Image.network(
                      'https://www.google.com/favicon.ico',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.g_mobiledata,
                          color: Colors.blue,
                          size: 20,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Login with Google',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Sign Up Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignUpScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Color(0xFFFF2D55),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}