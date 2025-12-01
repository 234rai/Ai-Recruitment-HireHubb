// lib/utils/role_aware_widget.dart - NEW FILE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/role_provider.dart';
import '/models/user_role.dart';

/// Mixin to add role-aware functionality to any widget
mixin RoleAwareWidget on Widget {
  /// Quick access to role provider
  static RoleProvider getRoleProvider(BuildContext context, {bool listen = true}) {
    return Provider.of<RoleProvider>(context, listen: listen);
  }

  /// Check if current user is recruiter
  static bool isRecruiter(BuildContext context, {bool listen = true}) {
    return getRoleProvider(context, listen: listen).isRecruiter;
  }

  /// Check if current user is job seeker
  static bool isJobSeeker(BuildContext context, {bool listen = true}) {
    return getRoleProvider(context, listen: listen).isJobSeeker;
  }

  /// Get current user role
  static UserRole? getUserRole(BuildContext context, {bool listen = true}) {
    return getRoleProvider(context, listen: listen).userRole;
  }

  /// Conditional builder based on role
  static Widget buildRoleBased({
    required BuildContext context,
    required Widget Function() jobSeekerBuilder,
    required Widget Function() recruiterBuilder,
    bool listen = true,
  }) {
    final isRecruiter = getRoleProvider(context, listen: listen).isRecruiter;

    return isRecruiter ? recruiterBuilder() : jobSeekerBuilder();
  }
}

/// Convenient widget for role-based conditional rendering
class RoleBasedWidget extends StatelessWidget {
  final Widget Function() jobSeekerBuilder;
  final Widget Function() recruiterBuilder;
  final bool listen;

  const RoleBasedWidget({
    Key? key,
    required this.jobSeekerBuilder,
    required this.recruiterBuilder,
    this.listen = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RoleAwareWidget.buildRoleBased(
      context: context,
      jobSeekerBuilder: jobSeekerBuilder,
      recruiterBuilder: recruiterBuilder,
      listen: listen,
    );
  }
}