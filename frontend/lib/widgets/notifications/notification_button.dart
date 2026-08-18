import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../state/notifications_state.dart';
import '../app_theme.dart';
import 'notification_sheet.dart';

class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationsState = context.watch<NotificationsState>();
    final unreadCount = notificationsState.unreadCount;
    final bool hasUnread = unreadCount > 0;
    debugPrint('NotificationBellButton build: unreadCount=$unreadCount, hasUnread=$hasUnread, loading=${notificationsState.loading}, error=${notificationsState.error}, total=${notificationsState.notifications.length}');

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IconButton(
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            _buildBellIcon(hasUnread),
            if (hasUnread) _Badge(count: unreadCount),
          ],
        ),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const NotificationSheet(),
          );
        },
      ),
    );
  }

  Widget _buildBellIcon(bool hasUnread) {
    final bell = Icon(
      Icons.notifications_rounded,
      color: AppTheme.primaryGreen,
      size: 22,
    );
    if (!hasUnread) return bell;
    return bell
        .animate(
          onPlay: (controller) =>
              controller.repeat(reverse: true, period: 2000.ms),
        )
        .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 1000.ms)
        .then(delay: 100.ms);
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final displayCount = count > 99 ? '99+' : count.toString();
    final isDoubleDigit = displayCount.length > 1;

    return Positioned(
      right: -4,
      top: -4,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        width: isDoubleDigit ? 20 : 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.surfaceColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            displayCount,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
