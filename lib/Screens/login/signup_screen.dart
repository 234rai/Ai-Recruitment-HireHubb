import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart'; // ADD THIS
import '../../models/user_role.dart'; // ADD THIS
import 'package:provider/provider.dart';
import '../../providers/role_provider.dart';
import '../../utils/responsive_helper.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String _userType = 'recruiter';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final UserService _userService = UserService(); // ADD THIS

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
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
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  // UPDATED: Sign Up with Role
  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Create Firebase Auth account
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Update display name
        await userCredential.user!.updateDisplayName(_fullNameController.text.trim());

        // Determine user role
        final UserRole role = _userType == 'recruiter'
            ? UserRole.recruiter
            : UserRole.jobSeeker;

        // Create user profile with role in Firestore
        await _userService.createUserProfile(
          uid: userCredential.user!.uid,
          email: _emailController.text.trim(),
          role: role,
          displayName: _fullNameController.text.trim(),
          companyName: _userType == 'recruiter' ? _companyController.text.trim() : null,
        );

        print('✅ User created: ${userCredential.user!.uid} as ${role.displayName}');

        if (mounted) {
          final roleProvider = Provider.of<RoleProvider>(context, listen: false);
          await roleProvider.refreshUser();

          print('📝 Signup: Role refreshed - ${roleProvider.userRole?.displayName}');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Account created successfully as ${role.displayName}!'),
              backgroundColor: const Color(0xFFFF2D55),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }

      } on FirebaseAuthException catch (e) {
        String errorMessage;
        if (e.code == 'weak-password') {
          errorMessage = 'Password is too weak.';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = 'An account already exists with this email.';
        } else {
          errorMessage = e.message ?? 'Registration failed. Please try again.';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
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
        title: Text(
          'Create Account',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
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

                  const SizedBox(height: 32),

                  Opacity(
                    opacity: _fadeAnimation.value,
                    child: _buildUserTypeSelector(isDarkMode),
                  ),

                  const SizedBox(height: 24),

                  _buildSignUpForm(isDarkMode),
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
        Container(
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
        const SizedBox(height: 16),
        Text(
          'Join HireHubb',
          style: TextStyle(
            fontSize: context.responsive.fontSize(28),
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find your perfect job',
          style: TextStyle(
            fontSize: 15,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildUserTypeSelector(bool isDarkMode) {
    return Container(
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
            alignment: _userType == 'recruiter' ? Alignment.centerLeft : Alignment.centerRight,
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
                      _userType = 'recruiter';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: Colors.transparent,
                    child: Text(
                      'Recruiter',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _userType == 'recruiter' ? Colors.white : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                        fontWeight: _userType == 'recruiter' ? FontWeight.w600 : FontWeight.w500,
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
                      _userType = 'job_seeker';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: Colors.transparent,
                    child: Text(
                      'Job Seeker',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _userType == 'job_seeker' ? Colors.white : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                        fontWeight: _userType == 'job_seeker' ? FontWeight.w600 : FontWeight.w500,
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
    );
  }

  Widget _buildSignUpForm(bool isDarkMode) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name Field
          Text(
            'Full Name',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fullNameController,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
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
              prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFFF2D55)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              if (value.length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Email Field
          Text(
            'Email',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Enter your email',
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
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFFF2D55)),
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

          const SizedBox(height: 20),

          // Company Field (only for recruiters)
          if (_userType == 'recruiter') ...[
            Text(
              'Company Name',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyController,
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
              validator: (value) {
                if (_userType == 'recruiter' && (value == null || value.isEmpty)) {
                  return 'Please enter your company name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],

          // Password Field
          Text(
            'Password',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Create a password',
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
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF2D55)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Confirm Password Field
          Text(
            'Confirm Password',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isConfirmPasswordVisible,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: 'Confirm your password',
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
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFF2D55)),
              suffixIcon: IconButton(
                icon: Icon(
                  _isConfirmPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 30),

          // Sign Up Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
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
                'Sign Up',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Login Link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                  fontSize: 15,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    color: Color(0xFFFF2D55),
                    fontSize: 15,
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