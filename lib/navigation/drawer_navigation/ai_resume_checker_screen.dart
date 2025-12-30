// lib/screens/ai_resume_checker_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AIResumeCheckerScreen extends StatefulWidget {
  const AIResumeCheckerScreen({super.key});

  @override
  State<AIResumeCheckerScreen> createState() => _AIResumeCheckerScreenState();
}

class _AIResumeCheckerScreenState extends State<AIResumeCheckerScreen> {
  bool _isAnalyzing = false;
  String _selectedFileName = '';
  String? _selectedFilePath;
  Map<String, dynamic>? _analysisResult;

  // API endpoint from your friend's code
  final String apiUrl =
      "https://katherina-homophonic-unmalignantly.ngrok-free.dev/upload-resume";

  void _pickAndAnalyzeResume() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], // Changed to PDF only as per server requirement
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        PlatformFile file = result.files.single;

        setState(() {
          _selectedFileName = file.name;
          _selectedFilePath = file.path;
          _analysisResult = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startAnalysis() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      await _uploadAndAnalyzeResume(_selectedFilePath!);
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing resume: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadAndAnalyzeResume(String filePath) async {
    try {
      File file = File(filePath);

      // Create multipart request
      var request = http.MultipartRequest("POST", Uri.parse(apiUrl));
      request.files.add(await http.MultipartFile.fromPath("file", file.path));

      // Send request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var data = jsonDecode(responseBody);

        // Transform API response to match your UI structure
        setState(() {
          _isAnalyzing = false;
          _analysisResult = _transformApiResponse(data);
        });
      } else {
        throw Exception("Server Error: ${response.statusCode}\n$responseBody");
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to analyze resume: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Transform the API response to match your UI's expected structure
  Map<String, dynamic> _transformApiResponse(Map<String, dynamic> apiData) {
    // Extract ATS score (assuming it's a number or string like "85/100")
    int atsScore = 0;
    if (apiData['ats_score'] != null) {
      String atsScoreStr = apiData['ats_score'].toString();
      // Try to extract number from string like "85/100" or just "85"
      RegExp regex = RegExp(r'\d+');
      var match = regex.firstMatch(atsScoreStr);
      if (match != null) {
        atsScore = int.tryParse(match.group(0)!) ?? 75;
      }
    }

    // Calculate overall score (you can adjust this formula)
    int overallScore = atsScore;

    // Extract improvements as a list
    List<String> improvements = [];
    if (apiData['improvements'] != null && apiData['improvements'] is List) {
      improvements = (apiData['improvements'] as List)
          .map((item) => item.toString())
          .toList();
    }

    // Create strengths based on what's good in the resume
    List<String> strengths = [];
    if (apiData['resume_summary'] != null) {
      strengths.add('Resume summary available: ${apiData['resume_summary']}');
    }
    if (apiData['suggested_job_title'] != null) {
      strengths.add('Suitable for: ${apiData['suggested_job_title']}');
    }
    if (atsScore >= 70) {
      strengths.add('Good ATS compatibility score');
    }

    // Return transformed data
    return {
      'score': overallScore,
      'atsScore': atsScore,
      'skillsMatch': (atsScore * 0.9).round(), // Estimate skills match
      'readabilityScore': (atsScore * 0.95).round(), // Estimate readability
      'strengths': strengths,
      'improvements': improvements,
      'resumeSummary': apiData['resume_summary'],
      'suggestedJobTitle': apiData['suggested_job_title'],
      'extractedData': apiData['extracted_data'],
    };
  }

  void _resetAnalysis() {
    setState(() {
      _selectedFileName = '';
      _selectedFilePath = null;
      _analysisResult = null;
    });
  }

  void _viewDocument() {
    if (_selectedFilePath != null) {
      // Show document in a dialog or navigate to a PDF viewer
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('View Document'),
          content: Text('Opening: $_selectedFileName\n\nPath: $_selectedFilePath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Color(0xFFFF2D55)),
              ),
            ),
          ],
        ),
      );

      // TODO: Integrate a PDF viewer package like flutter_pdfview or syncfusion_flutter_pdfviewer
      // Example: Navigator.push(context, MaterialPageRoute(builder: (context) => PdfViewerScreen(path: _selectedFilePath!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('AI Resume Checker'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'AI-Powered Resume Analysis',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get instant feedback on your resume from our AI analyzer',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),

            if (_analysisResult == null && !_isAnalyzing) ..._buildUploadSection(isDarkMode),
            if (_isAnalyzing) ..._buildAnalysisProgress(isDarkMode),
            if (_analysisResult != null) ..._buildAnalysisResult(_analysisResult!, isDarkMode),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildUploadSection(bool isDarkMode) {
    return [
      // Keep the same container but change content based on file selection
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: _selectedFileName.isEmpty
            ? Column(
          children: [
            Icon(
              Icons.upload_file,
              size: 64,
              color: const Color(0xFFFF2D55),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Your Resume',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Supported format: PDF\nMax file size: 10MB',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickAndAnalyzeResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Choose File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        )
            : Column(
          children: [
            // Big animated checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981), // Green color for success
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 64,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Resume Uploaded!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFileName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            // Change File button
            ElevatedButton(
              onPressed: _pickAndAnalyzeResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFFFF2D55),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Color(0xFFFF2D55),
                    width: 1,
                  ),
                ),
              ),
              child: const Text(
                'Change File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF2D55),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),

      // Show selected filename and analyze button if file is selected
      if (_selectedFileName.isNotEmpty && _analysisResult == null) ...[
        // Analyze button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _startAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF2D55),
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.analytics, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Analyze Resume',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  List<Widget> _buildFileSelectedSection(bool isDarkMode) {
    return [
    // File selected indicator
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.description,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'File Selected',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedFileName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _resetAnalysis,
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 24),

    // Analyze button
    SizedBox(
    width: double.infinity,
    child: ElevatedButton(
    onPressed: _startAnalysis,
    style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFF2D55),
    padding: const EdgeInsets.symmetric(vertical: 18),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    ),
    elevation: 0,
    ),
    child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
    Icon(Icons.analytics, color: Colors.white),
    SizedBox(width: 12),
    Text(
    'Analyze Resume',
    style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    ),
    ),
    ],
    ),
    ),
    ),
    const SizedBox(height: 16),

    // Info card
    Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
    color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
    borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
    children: [
    Icon(
    Icons.info_outline,
    color: const Color(0xFFFF2D55),
    size: 20,
    ),
    const SizedBox(width: 12),
    Expanded(
    child: Text(
    'Click "Analyze Resume" to get AI-powered insights',
    style: TextStyle(
    fontSize: 14,
    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
    ),
    ),
    ),
    ],
    ),
    )];
  }

  List<Widget> _buildAnalysisProgress(bool isDarkMode) {
    return [
      Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(
              color: Color(0xFFFF2D55),
              strokeWidth: 8,
            ),
            const SizedBox(height: 20),
            Text(
              'Analyzing your resume...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Processing with AI model',
              style: TextStyle(
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildAnalysisResult(Map<String, dynamic> result, bool isDarkMode) {
    return [
      // Overall Score
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFF2D55).withOpacity(0.1),
              const Color(0xFFFF2D55).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              'Overall Score',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: result['score'] / 100,
                    color: const Color(0xFFFF2D55),
                    strokeWidth: 12,
                    backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                  ),
                ),
                Text(
                  '${result['score']}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF2D55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('ATS Score', result['atsScore'], isDarkMode),
                    _buildMetric('Skills Match', result['skillsMatch'], isDarkMode),
                    _buildMetric('Readability', result['readabilityScore'], isDarkMode),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      // Strengths
      if (result['strengths'] != null && result['strengths'].isNotEmpty)
        _buildSection('Strengths', result['strengths'], Icons.check_circle, const Color(0xFF10B981), isDarkMode),
      if (result['strengths'] != null && result['strengths'].isNotEmpty) const SizedBox(height: 24),

      // Improvements
      if (result['improvements'] != null && result['improvements'].isNotEmpty)
        _buildSection('Areas for Improvement', result['improvements'], Icons.lightbulb_outline, const Color(0xFFFFB800), isDarkMode),
      if (result['improvements'] != null && result['improvements'].isNotEmpty) const SizedBox(height: 32),

      // Action Buttons
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _resetAnalysis,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Done',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _viewDocument,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D55),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'View Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildMetric(String title, int score, bool isDarkMode) {
    return Flexible(
      child: Column(
        children: [
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFF2D55),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, IconData icon, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 8,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showDetailedAnalysis(Map<String, dynamic> result, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
        title: Text(
          'Detailed Analysis',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result['resumeSummary'] != null) ...[
                Text(
                  'Resume Summary:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result['resumeSummary'],
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (result['suggestedJobTitle'] != null) ...[
                Text(
                  'Suggested Job Title:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result['suggestedJobTitle'],
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFFF2D55)),
            ),
          ),
        ],
      ),
    );
  }
}