// lib/widgets/online_status_badge.dart
// Online/offline status indicator widget

import 'package:flutter/material.dart';
import '../services/presence_service.dart';

class OnlineStatusBadge extends StatelessWidget {
  final bool isOnline;
  final double size;
  final bool showBorder;

  const OnlineStatusBadge({
    super.key,
    required this.isOnline,
    this.size = 12.0,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              )
            : null,
      ),
    );
  }
}

// Online status with stream (auto-updates)
class OnlineStatusStreamBadge extends StatelessWidget {
  final String userId;
  final double size;

  const OnlineStatusStreamBadge({
    super.key,
    required this.userId,
    this.size = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final presenceService = PresenceService();

    return StreamBuilder<Map<String, dynamic>>(
      stream: presenceService.getUserPresenceStream(userId),
      builder: (context, snapshot) {
        final isOnline = snapshot.data?['online'] ?? false;
        return OnlineStatusBadge(isOnline: isOnline, size: size);
      },
    );
  }
}

// Online status with last seen text
class OnlineStatusWithText extends StatelessWidget {
  final String userId;
  final TextStyle? textStyle;

  const OnlineStatusWithText({
    super.key,
    required this.userId,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final presenceService = PresenceService();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Map<String, dynamic>>(
      stream: presenceService.getUserPresenceStream(userId),
      builder: (context, snapshot) {
        final isOnline = snapshot.data?['online'] ?? false;
        final lastSeen = snapshot.data?['lastSeen'] as DateTime?;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OnlineStatusBadge(isOnline: isOnline, size: 8, showBorder: false),
            const SizedBox(width: 6),
            Text(
              isOnline ? 'Online' : PresenceService.formatLastSeen(lastSeen),
              style: textStyle ??
                  TextStyle(
                    fontSize: 12,
                    color: isOnline
                        ? Colors.green
                        : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
            ),
          ],
        );
      },
    );
  }
}

// Avatar with online status overlay
class AvatarWithStatus extends StatelessWidget {
  final String userId;
  final String? imageUrl;
  final String fallbackText;
  final double radius;
  final Color? backgroundColor;

  const AvatarWithStatus({
    super.key,
    required this.userId,
    this.imageUrl,
    required this.fallbackText,
    this.radius = 24,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? const Color(0xFFFF2D55).withOpacity(0.1),
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
          child: imageUrl == null
              ? Text(
                  fallbackText.isNotEmpty ? fallbackText[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: const Color(0xFFFF2D55),
                    fontWeight: FontWeight.bold,
                    fontSize: radius * 0.8,
                  ),
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: OnlineStatusStreamBadge(
            userId: userId,
            size: radius * 0.4,
          ),
        ),
      ],
    );
  }
}
