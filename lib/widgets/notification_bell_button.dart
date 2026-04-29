import 'package:flutter/material.dart';

import '../screens/notifications_screen.dart';
import '../services/notifications_inbox_service.dart';
import '../theme/colors.dart';
import 'animated_press.dart';
import 'page_transitions.dart';

/// A bell icon button that shows the live unread notification count.
///
/// Style matches the home-screen map-button (46x46, dark frosted card) when
/// [variant] is [NotificationBellVariant.mapButton], and an AppBar IconButton
/// look when [variant] is [NotificationBellVariant.appBar].
enum NotificationBellVariant { mapButton, appBar }

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    this.variant = NotificationBellVariant.mapButton,
    this.iconColor,
  });

  final NotificationBellVariant variant;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final inbox = NotificationsInboxService.instance;

    return AnimatedBuilder(
      animation: inbox,
      builder: (context, _) {
        final count = inbox.unreadCount;
        final hasUnread = count > 0;

        switch (variant) {
          case NotificationBellVariant.mapButton:
            return _MapButtonBell(
              count: count,
              hasUnread: hasUnread,
              onTap: () => _open(context),
            );
          case NotificationBellVariant.appBar:
            return _AppBarBell(
              count: count,
              hasUnread: hasUnread,
              iconColor: iconColor,
              onTap: () => _open(context),
            );
        }
      },
    );
  }

  void _open(BuildContext context) {
    Navigator.push(
      context,
      SlideUpRoute(page: const NotificationsScreen()),
    );
  }
}

class _MapButtonBell extends StatelessWidget {
  const _MapButtonBell({
    required this.count,
    required this.hasUnread,
    required this.onTap,
  });

  final int count;
  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedPress(
          onTap: onTap,
          scaleDown: 0.9,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.bgCard.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasUnread
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              hasUnread
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: hasUnread
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: _UnreadBadge(count: count),
          ),
      ],
    );
  }
}

class _AppBarBell extends StatelessWidget {
  const _AppBarBell({
    required this.count,
    required this.hasUnread,
    required this.onTap,
    this.iconColor,
  });

  final int count;
  final bool hasUnread;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(
            hasUnread
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: hasUnread ? AppColors.primary : color,
          ),
          tooltip: 'Bildirimler',
        ),
        if (hasUnread)
          Positioned(
            top: 6,
            right: 6,
            child: IgnorePointer(child: _UnreadBadge(count: count)),
          ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgMain, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}
