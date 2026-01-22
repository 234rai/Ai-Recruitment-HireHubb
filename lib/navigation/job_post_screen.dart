import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../utils/responsive_helper.dart';

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
  final TextEditingController _companyDescriptionController = TextEditingController();

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

  // Currency selection
  String _selectedCurrency = '\$'; // Default to Dollar
  final List<String> _currencies = ['\$', '₹', '¥', '€', '£'];

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

  // 🚀 Selection Rounds Logic
  final TextEditingController _selectionRoundController = TextEditingController();
  List<String> _selectionRounds = [];

  void _addSelectionRound() {
    final round = _selectionRoundController.text.trim();
    if (round.isNotEmpty && !_selectionRounds.contains(round)) {
      setState(() {
        _selectionRounds.add(round);
        _selectionRoundController.clear();
      });
    }
  }

  void _removeSelectionRound(String round) {
    setState(() {
      _selectionRounds.remove(round);
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
        // 'postedTime': 'Just now',  ❌ REMOVE THIS - postedTime is now calculated dynamically
        'isRemote': _isRemote,
        'salary': '${_selectedCurrency}${_salaryController.text.trim()}',
        'description': _descriptionController.text.trim(),
        'companyDescription': _companyDescriptionController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'skills': _skills,
        'jobType': _jobType,
        'isFeatured': _isFeatured,
        'recruiterId': user.uid,
        'recruiterName': userData['name'] ?? 'Recruiter',
        'recruiterEmail': userData['email'] ?? user.email,
        'postedAt': FieldValue.serverTimestamp(), // ✅ This is the ONLY time field needed
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'applications': 0,
        'views': 0,
        'status': 'active',
        'type': _jobType,
        'experienceLevel': 'Mid-level',
        'educationLevel': 'Bachelor\'s',
        'searchKeywords': [
          _positionController.text.trim().toLowerCase(),
          companyName.toLowerCase(),
          _locationController.text.trim().toLowerCase(),
          _countryController.text.trim().toLowerCase(),
          _countryController.text.trim().toLowerCase(),
          ..._skills.map((s) => s.toLowerCase()).toList(),
        ],
        'selectionRounds': _selectionRounds, // ADD THIS
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
        _selectionRounds.clear(); // ADD THIS
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
    _companyDescriptionController.dispose(); // ADD THIS
    _requirementsController.dispose();
    _skillsController.dispose();
    _selectionRoundController.dispose(); // ADD THIS
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final responsive = ResponsiveHelper(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              'Post a New Job',
              style: TextStyle(fontSize: responsive.fontSize(20)),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, size: responsive.iconSize(24)),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.save, size: responsive.iconSize(24)),
              onPressed: () {
                // TODO: Implement save as draft
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(responsive.padding(16)),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information
                        _buildSectionHeader('Basic Information', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),

                        // Position
                        TextFormField(
                          controller: _positionController,
                          decoration: InputDecoration(
                            labelText: 'Job Position*',
                            hintText: 'e.g., Senior Flutter Developer',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            prefixIcon: Icon(Icons.work_outline, size: responsive.iconSize(24)),
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: responsive.padding(12), vertical: responsive.padding(16)),
                            labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                            hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: responsive.height(12)),

                        // Company
                        TextFormField(
                          controller: _companyController,
                          decoration: InputDecoration(
                            labelText: 'Company Name*',
                            hintText: 'e.g., TechCorp Inc.',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            prefixIcon: Icon(Icons.business_outlined, size: responsive.iconSize(24)),
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: responsive.padding(12), vertical: responsive.padding(16)),
                            labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                            hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: responsive.height(12)),

                        // Location & Country Row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _locationController,
                                decoration: InputDecoration(
                                  labelText: 'Location*',
                                  hintText: 'City',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  prefixIcon: Icon(Icons.location_on_outlined, size: responsive.iconSize(24)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(8), vertical: responsive.padding(16)),
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                                  hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: responsive.width(8)),
                            Expanded(
                              child: TextFormField(
                                controller: _countryController,
                                decoration: InputDecoration(
                                  labelText: 'Country*',
                                  hintText: 'Country',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  prefixIcon: Icon(Icons.flag_outlined, size: responsive.iconSize(24)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(8), vertical: responsive.padding(16)),
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                                  hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.height(12)),

                        // Job Type & Remote
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _jobType,
                                decoration: InputDecoration(
                                  labelText: 'Job Type',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  prefixIcon: Icon(Icons.schedule_outlined, size: responsive.iconSize(24)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(12), vertical: responsive.padding(12)),
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                                ),
                                items: _jobTypes.map((type) {
                                  return DropdownMenuItem(
                                    value: type,
                                    child: Text(type, style: TextStyle(fontSize: responsive.fontSize(14))),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _jobType = value!;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: responsive.width(8)),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: responsive.padding(8), vertical: responsive.padding(8)),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade400,
                                  ),
                                  borderRadius: BorderRadius.circular(responsive.radius(12)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Remote',
                                      style: TextStyle(
                                        fontSize: responsive.fontSize(14),
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
                                      materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.height(16)),

                        // Compensation
                        _buildSectionHeader('Compensation', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),

                        // Currency & Salary Row
                        Row(
                          children: [
                            Container(
                              width: responsive.width(80),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCurrency,
                                decoration: InputDecoration(
                                  labelText: 'Currency',
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(14)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(8), vertical: responsive.padding(12)),
                                ),
                                items: _currencies.map((currency) {
                                  return DropdownMenuItem(
                                    value: currency,
                                    child: Text(currency, style: TextStyle(fontSize: responsive.fontSize(16))),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCurrency = value!;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: responsive.width(8)),
                            Expanded(
                              child: TextFormField(
                                controller: _salaryController,
                                decoration: InputDecoration(
                                  labelText: 'Salary Range*',
                                  hintText: '80,000 - 100,000/year',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(12), vertical: responsive.padding(16)),
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                                  hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.height(16)),

                        // Job Description
                        _buildSectionHeader('Job Description', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),

                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Job Description*',
                            hintText: 'Role responsibilities...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            alignLabelWithHint: true,
                            contentPadding: EdgeInsets.all(responsive.padding(12)),
                            labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                            hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: responsive.height(12)),

                        // ADD: Company Description
                        TextFormField(
                          controller: _companyDescriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Company Description',
                            hintText: 'About the company...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            alignLabelWithHint: true,
                            contentPadding: EdgeInsets.all(responsive.padding(12)),
                            labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                            hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                          ),
                        ),
                        SizedBox(height: responsive.height(12)),

                        TextFormField(
                          controller: _requirementsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Requirements',
                            hintText: 'Qualifications...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(responsive.radius(12)),
                            ),
                            alignLabelWithHint: true,
                            contentPadding: EdgeInsets.all(responsive.padding(12)),
                            labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                            hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                          ),
                        ),
                        SizedBox(height: responsive.height(16)),

                        // Skills
                        _buildSectionHeader('Required Skills', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _skillsController,
                                decoration: InputDecoration(
                                  labelText: 'Add Skills',
                                  hintText: 'Flutter, Dart...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  prefixIcon: Icon(Icons.code_outlined, size: responsive.iconSize(24)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(12), vertical: responsive.padding(16)),
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                                  hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                                ),
                                onFieldSubmitted: (_) => _addSkill(),
                              ),
                            ),
                            SizedBox(width: responsive.width(8)),
                            ElevatedButton(
                              onPressed: _addSkill,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF2D55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(responsive.radius(12)),
                                ),
                                padding: EdgeInsets.all(responsive.padding(16)),
                                minimumSize: Size(responsive.width(48), responsive.width(48)),
                              ),
                              child: Icon(Icons.add, color: Colors.white, size: responsive.iconSize(24)),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.height(12)),

                        // Skills Chips
                        if (_skills.isNotEmpty) ...[
                          Wrap(
                            spacing: responsive.width(6),
                            runSpacing: responsive.height(6),
                            children: _skills.map((skill) {
                              return Chip(
                                label: Text(skill, style: TextStyle(fontSize: responsive.fontSize(12))),
                                backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
                                deleteIcon: Icon(Icons.close, size: responsive.iconSize(14)),
                                onDeleted: () => _removeSkill(skill),
                                visualDensity: VisualDensity.compact,
                                padding:
                                EdgeInsets.symmetric(horizontal: responsive.padding(6), vertical: responsive.padding(2)),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: responsive.height(16)),

                        // 🚀 Selection Rounds Input
                        _buildSectionHeader('Selection Process', isDarkMode, responsive),
                        SizedBox(height: responsive.height(12)),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _selectionRoundController,
                                decoration: InputDecoration(
                                  labelText: 'Add Selection Round',
                                  hintText: 'e.g., Technical Interview',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(responsive.radius(12)),
                                  ),
                                  prefixIcon: Icon(Icons.list_alt, size: responsive.iconSize(24)),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: responsive.padding(12), vertical: responsive.padding(16)),
                                  labelStyle: TextStyle(fontSize: responsive.fontSize(16)),
                                  hintStyle: TextStyle(fontSize: responsive.fontSize(14)),
                                ),
                                onFieldSubmitted: (_) => _addSelectionRound(),
                              ),
                            ),
                            SizedBox(width: responsive.width(8)),
                            ElevatedButton(
                              onPressed: _addSelectionRound,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF2D55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(responsive.radius(12)),
                                ),
                                padding: EdgeInsets.all(responsive.padding(16)),
                                minimumSize: Size(responsive.width(48), responsive.width(48)),
                              ),
                              child: Icon(Icons.add, color: Colors.white, size: responsive.iconSize(24)),
                            ),
                          ],
                        ),
                        SizedBox(height: responsive.height(12)),

                        // Selection Rounds Chips
                        if (_selectionRounds.isNotEmpty) ...[
                          Wrap(
                            spacing: responsive.width(6),
                            runSpacing: responsive.height(6),
                            children: _selectionRounds.asMap().entries.map((entry) {
                              final index = entry.key;
                              final round = entry.value;
                              return Chip(
                                avatar: CircleAvatar(
                                  backgroundColor: const Color(0xFFFF2D55).withOpacity(0.8),
                                  child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                                ),
                                label: Text(round, style: TextStyle(fontSize: responsive.fontSize(12))),
                                backgroundColor: const Color(0xFFFF2D55).withOpacity(0.1),
                                deleteIcon: Icon(Icons.close, size: responsive.iconSize(14)),
                                onDeleted: () => _removeSelectionRound(round),
                                visualDensity: VisualDensity.compact,
                                padding:
                                EdgeInsets.symmetric(horizontal: responsive.padding(6), vertical: responsive.padding(2)),
                              );
                            }).toList(),
                          ),
                          SizedBox(height: responsive.height(8)),
                        ],

                        // Featured Job Option
                        Container(
                          padding: EdgeInsets.all(responsive.padding(12)),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? const Color(0xFF2A2A2A)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(responsive.radius(12)),
                            border: Border.all(
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: _isFeatured
                                        ? const Color(0xFFFFB800)
                                        : Colors.grey,
                                    size: responsive.iconSize(18),
                                  ),
                                  SizedBox(width: responsive.width(8)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Feature Job',
                                        style: TextStyle(
                                          fontSize: responsive.fontSize(14),
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      Text(
                                        'More visibility',
                                        style: TextStyle(
                                          fontSize: responsive.fontSize(11),
                                          color: isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
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
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: responsive.height(20)),
                      ],
                    ]),
                  ),
                ),
              ),

              // Bottom buttons - Fixed outside scroll
              Container(
                padding: EdgeInsets.all(responsive.padding(16)),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: responsive.radius(8),
                      offset: Offset(0, -responsive.height(2)),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: responsive.height(50),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF2D55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(responsive.radius(12)),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                          width: responsive.width(20),
                          height: responsive.width(20),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: responsive.width(2),
                          ),
                        )
                            : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.send, color: Colors.white, size: responsive.iconSize(18)),
                            SizedBox(width: responsive.width(8)),
                            Text(
                              'Post Job Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: responsive.fontSize(15),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDarkMode, ResponsiveHelper responsive) {
    return Text(
      title,
      style: TextStyle(
        fontSize: responsive.fontSize(18),
        fontWeight: FontWeight.bold,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }
}