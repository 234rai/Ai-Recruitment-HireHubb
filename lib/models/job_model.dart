// lib/models/job_model.dart - UPDATED WITH DYNAMIC TIME
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/time_helper.dart'; // ADD THIS IMPORT

class Job {
  final String id;
  final String company;
  final String logo;
  final int logoColor;
  final String position;
  final String type;
  final String location;
  final String country;
  final String salary;
  final Timestamp? postedAt; // CHANGED: Now nullable and stores actual timestamp
  final bool isRemote;
  final bool isFeatured;
  final List<String> skills;
  final String description;
  final List<String> requirements;
  final String companyDescription;
  final List<String> searchKeywords;
  final List<String> selectionRounds; // ADD THIS

  // Recruiter fields
  final String? recruiterId;
  final String? recruiterName;
  final String? recruiterEmail;

  final String? status;           // 'active', 'closed', 'draft'
  final int? applications;        // Application count
  final String jobType;          // 'Full-time', 'Part-time', etc.

  Job({
    required this.id,
    required this.company,
    required this.logo,
    required this.logoColor,
    required this.position,
    required this.type,
    required this.location,
    required this.country,
    required this.salary,
    this.postedAt, // CHANGED: Now optional
    required this.isRemote,
    required this.isFeatured,
    required this.skills,
    required this.description,
    required this.requirements,
    required this.companyDescription,
    required this.searchKeywords,
    this.selectionRounds = const [], // ADD THIS
    this.recruiterId,
    this.recruiterName,
    this.recruiterEmail,
    this.status,
    this.applications,
    this.jobType = 'Full-time',
  });

  // ADD THIS GETTER: Dynamic posted time calculation
  String get postedTime => TimeHelper.getRelativeTime(postedAt);

  factory Job.fromMap(Map<String, dynamic> data, String id) {
    return Job(
      id: id,
      company: data['company'] ?? 'Unknown Company',
      logo: data['logo'] ?? '?',
      logoColor: data['logoColor'] ?? 0xFFFF2D55,
      position: data['position'] ?? 'No Position',
      type: data['type'] ?? 'Full-time',
      location: data['location'] ?? 'Unknown Location',
      country: data['country'] ?? 'Unknown Country',
      salary: data['salary'] ?? 'Salary not specified',
      postedAt: data['postedAt'] as Timestamp?, // CHANGED: Get actual timestamp
      isRemote: data['isRemote'] ?? false,
      isFeatured: data['isFeatured'] ?? false,
      skills: (data['skills'] is List)
          ? List<String>.from(data['skills'])
          : (data['skills'] is String)
          ? [data['skills'] as String]
          : [],
      description: data['description'] ?? 'No description available.',
      requirements: (data['requirements'] is List)
          ? List<String>.from(data['requirements'])
          : (data['requirements'] is String)
          ? [data['requirements'] as String]
          : [],
      companyDescription: data['companyDescription'] ?? 'No company description available.',
      searchKeywords: (data['searchKeywords'] is List)
          ? List<String>.from(data['searchKeywords'])
          : [],
      selectionRounds: (data['selectionRounds'] is List) // ADD THIS
          ? List<String>.from(data['selectionRounds'])
          : [],
      recruiterId: data['recruiterId'],
      recruiterName: data['recruiterName'],
      recruiterEmail: data['recruiterEmail'],
      status: data['status'] ?? 'active',
      applications: data['applications'] ?? 0,
      jobType: data['jobType'] ?? data['type'] ?? 'Full-time',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'company': company,
      'logo': logo,
      'logoColor': logoColor,
      'position': position,
      'type': type,
      'location': location,
      'country': country,
      'salary': salary,
      'postedAt': postedAt, // CHANGED: Save timestamp, not string
      'isRemote': isRemote,
      'isFeatured': isFeatured,
      'skills': skills,
      'description': description,
      'requirements': requirements,
      'companyDescription': companyDescription,
      'searchKeywords': searchKeywords,
      'recruiterId': recruiterId,
      'recruiterName': recruiterName,
      'recruiterEmail': recruiterEmail,
      'status': status,
      'applications': applications,
      'jobType': jobType,
      'selectionRounds': selectionRounds, // ADD THIS
    };
  }
}