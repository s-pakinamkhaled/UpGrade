import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/notification_provider.dart';
import 'sidebar_rail_icon.dart';

enum NotificationBellStyle { appBar, rail }

class NotificationBellButton extends StatelessWidget {
  final Color? iconColor;
  final NotificationBellStyle style;

  const NotificationBellButton({
    super.key,
    this.iconColor,
    this.style = NotificationBellStyle.appBar,
  });

  Future<void> _openNotifications(BuildContext context) async {
    await Navigator.of(context).pushNamed(AppConstants.routeNotifications);
    if (!context.mounted) return;
    await context.read<NotificationProvider>().refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = context.watch<NotificationProvider>().unreadCount;

    if (style == NotificationBellStyle.rail) {
      return SidebarRailIcon(
        tooltip: 'Notifications',
        icon: Icons.notifications_outlined,
        badgeCount: unreadCount,
        onTap: () => _openNotifications(context),
      );
    }

    final color = iconColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppTheme.darkText);

    return IconButton(
      tooltip: 'Notifications',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      onPressed: () => _openNotifications(context),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        backgroundColor: AppTheme.errorRed,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: const TextStyle(
            color: AppTheme.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Icon(Icons.notifications_outlined, color: color),
      ),
    );
  }
}
