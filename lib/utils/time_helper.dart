// lib/utils/time_helper.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TimeHelper {
  /// Convert Firestore Timestamp to relative time (e.g., "2 hours ago", "Just now")
  static String getRelativeTime(dynamic timestamp) {
    if (timestamp == null) return 'Recently';

    DateTime dateTime;

    // Handle both Timestamp and DateTime
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Recently';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }

  /// Format timestamp to readable date (e.g., "Jan 15, 2025")
  static String formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime dateTime;

    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown';
    }

    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  /// Format timestamp to date and time (e.g., "Jan 15, 2025 at 3:45 PM")
  static String formatDateTime(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime dateTime;

    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      return 'Unknown';
    }

    return DateFormat('MMM dd, yyyy \'at\' h:mm a').format(dateTime);
  }
}