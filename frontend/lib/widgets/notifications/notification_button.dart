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
    final unreadCount = context.select<NotificationsState, int>(
      (state) => state.unreadCount,
    );
    final hasUnread = unreadCount > 0;

    return Tooltip(
      message: 'Notificaciones',
      child: Semantics(
        label: 'Notificaciones',
        button: true,
        child: IconButton(
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen10,
            foregroundColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(
              borderRadius: AppTheme.radiusLGBorder,
            ),
          ),
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
      ),
    );
  }

  Widget _buildBellIcon(bool hasUnread) {
    final bell = Icon(
      Icons.notifications_rounded,
      color: AppTheme.primaryGreen,
      size: AppTheme.iconLG,
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
    final width = displayCount.length > 2 ? 22.0 : (displayCount.length > 1 ? 20.0 : 18.0);

    return Positioned(
      right: -4,
      top: -4,
      child: AnimatedContainer(
        duration: AppTheme.animationSlow,
        curve: Curves.easeOutBack,
        width: width,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: AppTheme.surfaceColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.redAccent25,
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
