import 'package:cloud_firestore/cloud_firestore.dart';

class InterviewModel {
  final String id;
  final String applicationId;
  final String jobId;
  final String jobTitle;
  final String applicantId;
  final String applicantName;
  final String recruiterId;
  final String recruiterName;
  final DateTime interviewDate;
  final String interviewType;
  final String interviewLink;
  final String notes;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isConfirmed;

  InterviewModel({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.applicantId,
    required this.applicantName,
    required this.recruiterId,
    required this.recruiterName,
    required this.interviewDate,
    required this.interviewType,
    required this.interviewLink,
    required this.notes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.isConfirmed = false,
  });

  factory InterviewModel.fromMap(Map<String, dynamic> data, String id) {
    return InterviewModel(
      id: id,
      applicationId: data['applicationId'] ?? '',
      jobId: data['jobId'] ?? '',
      jobTitle: data['jobTitle'] ?? '',
      applicantId: data['applicantId'] ?? '',
      applicantName: data['applicantName'] ?? 'Applicant',
      recruiterId: data['recruiterId'] ?? '',
      recruiterName: data['recruiterName'] ?? 'Recruiter',
      interviewDate: (data['interviewDate'] as Timestamp).toDate(),
      interviewType: data['interviewType'] ?? 'video_call',
      interviewLink: data['interviewLink'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'scheduled',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      isConfirmed: data['isConfirmed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'applicationId': applicationId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'applicantId': applicantId,
      'applicantName': applicantName,
      'recruiterId': recruiterId,
      'recruiterName': recruiterName,
      'interviewDate': Timestamp.fromDate(interviewDate),
      'interviewType': interviewType,
      'interviewLink': interviewLink,
      'notes': notes,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isConfirmed': isConfirmed,
    };
  }
}