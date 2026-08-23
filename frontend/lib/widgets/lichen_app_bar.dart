import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'notifications/notification_button.dart';

class LichenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;

  const LichenAppBar({super.key, this.onMenuPressed});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: AppTheme.spaceXS,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen10,
            borderRadius: AppTheme.radiusMDBorder,
          ),
          child: Center(
            child: Image.asset(
              'assets/logo/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              semanticLabel: 'Lichen Dreams logo',
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.eco_rounded,
                  color: AppTheme.primaryGreen,
                  size: AppTheme.iconLG,
                );
              },
            ),
          ),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lichen Dreams',
            style: textTheme.titleLarge,
          ),
          Text(
            'Lee el aire, entiende tu entorno',
            style: textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        const NotificationBellButton(),
        const SizedBox(width: AppTheme.spaceSM),
        Semantics(
          label: 'Menú',
          button: true,
          child: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppTheme.primaryGreen,
                ),
                tooltip: 'Menú',
                onPressed: onMenuPressed ??
                    () {
                      Scaffold.of(context).openEndDrawer();
                    },
              );
            },
          ),
        ),
      ],
    );
  }
}
