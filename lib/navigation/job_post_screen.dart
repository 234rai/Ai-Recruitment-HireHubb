import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class JobPostScreen extends StatefulWidget {
  const JobPostScreen({super.key});

  @override
  State<JobPostScreen> createState() => _JobPostScreenState();
}

class _JobPostScreenState extends State<JobPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form controllers
  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _requirementsController = TextEditingController();
  final TextEditingController _skillsController = TextEditingController();

  // Form values
  String _jobType = 'Full-time';
  bool _isRemote = false;
  bool _isFeatured = false;
  List<String> _skills = [];
  final List<String> _jobTypes = [
    'Full-time',
    'Part-time',
    'Contract',
    'Internship',
    'Freelance'
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate company name if available
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _companyController.text = data['company'] ?? '';
          });
        }
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  void _addSkill() {
    final skill = _skillsController.text.trim();
    if (skill.isNotEmpty && !_skills.contains(skill)) {
      setState(() {
        _skills.add(skill);
        _skillsController.clear();
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _skills.remove(skill);
    });
  }

  String _generateLogo(String company) {
    if (company.isEmpty) return '💼';
    return company.substring(0, 1).toUpperCase();
  }

  int _generateLogoColor(String company) {
    // Generate a consistent color based on company name
    if (company.isEmpty) return 0xFF2D55FF;

    int hash = 0;
    for (int i = 0; i < company.length; i++) {
      hash = company.codeUnitAt(i) + ((hash << 5) - hash);
    }

    // Predefined color palette
    final colors = [
      0xFFFF2D55, // Red
      0xFF2D55FF, // Blue
      0xFF2DCE89, // Green
      0xFFFF9500, // Orange
      0xFF5AC8FA, // Light Blue
      0xFF5856D6, // Purple
      0xFFFFCC00, // Yellow
      0xFF007AFF, // iOS Blue
    ];

    return colors[hash.abs() % colors.length];
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to post a job'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get user profile for company info
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() as Map<String, dynamic>;
      final companyName = _companyController.text.trim();
      final logo = _generateLogo(companyName);
      final logoColor = _generateLogoColor(companyName);

      // Create job ID
      final jobId = const Uuid().v4();

      // Create job object
      final job = {
        'id': jobId,
        'position': _positionController.text.trim(),
        'company': companyName,
        'location': _locationController.text.trim(),
        'country': _countryController.text.trim(),
        'logo': logo,
        'logoColor': logoColor,
        'postedTime': 'Just now',
        'isRemote': _isRemote,
        'salary': _salaryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'skills': _skills,
        'jobType': _jobType,
        'isFeatured': _isFeatured,
        'recruiterId': user.uid,
        'recruiterName': userData['name'] ?? 'Recruiter',
        'recruiterEmail': userData['email'] ?? user.email,
        'postedAt': FieldValue.serverTimestamp(), // ⭐ IMPORTANT
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'applications': 0,
        'views': 0,
        'status': 'active',
        'type': _jobType,
        'experienceLevel': 'Mid-level',
        'educationLevel': 'Bachelor\'s',
        'searchKeywords': [ // FIX: Properly create array
          _positionController.text.trim().toLowerCase(),
          companyName.toLowerCase(),
          _locationController.text.trim().toLowerCase(),
          _countryController.text.trim().toLowerCase(),
          ..._skills.map((s) => s.toLowerCase()).toList(),
        ],
      };

      // Save to Firestore
      await _firestore.collection('jobs').doc(jobId).set(job);

      // Update recruiter's job count
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({
        'postedJobs': FieldValue.increment(1),
        'lastJobPosted': FieldValue.serverTimestamp(),
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Job posted successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      );

      // Clear form
      _formKey.currentState!.reset();
      setState(() {
        _skills.clear();
        _isSubmitting = false;
      });

      // Go back after a delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      print('Error posting job: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error posting job: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _countryController.dispose();
    _salaryController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
        child: Scaffold(
      appBar: AppBar(
        title: const Text('Post a New Job'),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              // TODO: Implement save as draft
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16, // FIX: Add keyboard padding
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Information
                _buildSectionHeader('Basic Information'),
                const SizedBox(height: 12),

                // Position
                TextFormField(
                  controller: _positionController,
                  decoration: InputDecoration(
                    labelText: 'Job Position*',
                    hintText: 'e.g., Senior Flutter Developer',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter job position';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Company
                TextFormField(
                  controller: _companyController,
                  decoration: InputDecoration(
                    labelText: 'Company Name*',
                    hintText: 'e.g., TechCorp Inc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.business_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter company name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Location & Country Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'Location*',
                          hintText: 'e.g., New York',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter location';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _countryController,
                        decoration: InputDecoration(
                          labelText: 'Country*',
                          hintText: 'e.g., United States',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.flag_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter country';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Job Type & Remote
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _jobType,
                        decoration: InputDecoration(
                          labelText: 'Job Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.schedule_outlined),
                        ),
                        items: _jobTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _jobType = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.grey.shade700
                                : Colors.grey.shade400,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Remote Work',
                              style: TextStyle(
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                            Switch(
                              value: _isRemote,
                              onChanged: (value) {
                                setState(() {
                                  _isRemote = value;
                                });
                              },
                              activeColor: const Color(0xFFFF2D55),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Compensation
                _buildSectionHeader('Compensation'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _salaryController,
                  decoration: InputDecoration(
                    labelText: 'Salary*',
                    hintText: 'e.g., \$80,000 - \$100,000 per year',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.attach_money_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter salary range';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Job Description
                _buildSectionHeader('Job Description'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Job Description*',
                    hintText: 'Describe the role, responsibilities, and impact...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter job description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _requirementsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Requirements & Qualifications',
                    hintText: 'List the requirements and qualifications...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // Skills
                _buildSectionHeader('Required Skills'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _skillsController,
                        decoration: InputDecoration(
                          labelText: 'Add Skills',
                          hintText: 'e.g., Flutter, Dart, Firebase',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.code_outlined),
                        ),
                        onFieldSubmitted: (_) => _addSkill(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addSkill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2D55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Skills Chips
                if (_skills.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills.map((skill) {
                      return Chip(
                        label: Text(skill),
                        backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeSkill(skill),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_skills.length} skill${_skills.length == 1 ? '' : 's'} added',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode
                          ? Colors.grey.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Featured Job Option
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? const Color(0xFF2A2A2A)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.star,
                                color: _isFeatured
                                    ? const Color(0xFFFFB800)
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Feature this Job',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Get more visibility and applicants',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                        activeColor: const Color(0xFFFF2D55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitJob,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2D55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Post Job Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Draft Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: Implement save as draft
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: isDarkMode
                            ? Colors.grey.shade700
                            : Colors.grey.shade400,
                      ),
                    ),
                    child: Text(
                      'Save as Draft',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
        ));
  }

  Widget _buildSectionHeader(String title) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }
}