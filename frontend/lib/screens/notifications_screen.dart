import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/app_notification.dart';
import '../providers/notification_provider.dart';
import '../widgets/dashboard_secondary_shell.dart';
import '../widgets/upgrade_visual_system.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static final _fullDateFormat = DateFormat('MMM d, yyyy · h:mm a');
  static final _shortTimeFormat = DateFormat('h:mm a');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationProvider>().refresh();
    });
  }

  Future<void> _onRefresh() async {
    await context.read<NotificationProvider>().refresh();
  }

  Future<void> _onTapNotification(AppNotification notification) async {
    if (notification.isRead) return;
    await context.read<NotificationProvider>().markAsRead(notification.id);
  }

  Future<void> _onMarkAllAsRead() async {
    final provider = context.read<NotificationProvider>();
    if (provider.unreadCount == 0) return;
    await provider.markAllAsRead();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  double _contentMaxWidth(double bodyWidth) {
    if (bodyWidth <= 0) return 640;
    if (bodyWidth < 640) return bodyWidth;
    if (bodyWidth < 1024) {
      return (bodyWidth - 40).clamp(560.0, 820.0);
    }
    return (bodyWidth - 48).clamp(720.0, 960.0);
  }

  String _relativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime.toLocal());
  }

  Widget _buildPage(BuildContext context, double width) {
    final provider = context.watch<NotificationProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rem = UpGradeRem(width);
    final onSurface = theme.colorScheme.onSurface;
    final secondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final isCompact = width < 640;
    final totalCount = provider.items.length;
    final unreadCount = provider.unreadCount;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _contentMaxWidth(width)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111827).withOpacity(0.94)
                : AppTheme.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _NotificationsHeader(
                  rem: rem,
                  isDark: isDark,
                  isCompact: isCompact,
                  unreadCount: unreadCount,
                  isLoading: provider.isLoading,
                  onRefresh: _onRefresh,
                  onMarkAllAsRead: _onMarkAllAsRead,
                ),
                _NotificationsSummary(
                  isDark: isDark,
                  isCompact: isCompact,
                  totalCount: totalCount,
                  unreadCount: unreadCount,
                ),
                Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE2E8F0),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: provider.isLoading && provider.items.isEmpty
                      ? const Padding(
                          key: ValueKey('loading'),
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : provider.error != null && provider.items.isEmpty
                          ? _NotificationsEmptyState(
                              key: const ValueKey('error'),
                              isDark: isDark,
                              icon: Icons.cloud_off_rounded,
                              title: 'Unable to load notifications',
                              subtitle:
                                  'Check that the backend is running, then use Refresh above.',
                              detail: provider.error,
                            )
                          : provider.items.isEmpty
                              ? _NotificationsEmptyState(
                                  key: const ValueKey('empty'),
                                  isDark: isDark,
                                  icon: Icons.notifications_none_rounded,
                                  title: 'No notifications yet',
                                  subtitle:
                                      'When deadlines approach or tasks need attention, alerts from your study planner will appear here.',
                                )
                              : _NotificationsList(
                                  key: ValueKey('list-$totalCount'),
                                  items: provider.items,
                                  onSurface: onSurface,
                                  secondary: secondary,
                                  isDark: isDark,
                                  isCompact: isCompact,
                                  onTap: _onTapNotification,
                                  relativeTime: _relativeTime,
                                  fullDateFormat: _fullDateFormat,
                                  shortTimeFormat: _shortTimeFormat,
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body(double width) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              constraints.maxWidth < 640 ? 12 : 20,
              10,
              constraints.maxWidth < 640 ? 12 : 20,
              16,
            ),
            child: _buildPage(context, constraints.maxWidth),
          );
        },
      );
    }

    final narrow = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Text('Notifications'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: body(MediaQuery.sizeOf(context).width),
    );

    return DashboardSecondaryShell(
      narrow: narrow,
      wideBody: body(MediaQuery.sizeOf(context).width),
      wideAppBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
          tooltip: 'Back',
        ),
        title: const Text('Notifications'),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final UpGradeRem rem;
  final bool isDark;
  final bool isCompact;
  final int unreadCount;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onMarkAllAsRead;

  const _NotificationsHeader({
    required this.rem,
    required this.isDark,
    required this.isCompact,
    required this.unreadCount,
    required this.isLoading,
    required this.onRefresh,
    required this.onMarkAllAsRead,
  });

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final actions = _HeaderActions(
      isLoading: isLoading,
      showMarkAll: unreadCount > 0,
      onRefresh: onRefresh,
      onMarkAllAsRead: onMarkAllAsRead,
      expanded: isCompact,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 16 : 22, 16, isCompact ? 16 : 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: UpGradeGradientTitle(
                            'Notifications',
                            rem: rem,
                            isDark: isDark,
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$unreadCount new',
                              style: const TextStyle(
                                color: AppTheme.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deadline reminders and study alerts',
                      style: TextStyle(
                        fontSize: rem.pageSubtitle,
                        color: secondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 12),
                actions,
              ],
            ],
          ),
          if (isCompact) ...[
            const SizedBox(height: 12),
            actions,
          ],
        ],
      ),
    );
  }
}

class _HeaderActions extends StatelessWidget {
  final bool isLoading;
  final bool showMarkAll;
  final VoidCallback onRefresh;
  final VoidCallback onMarkAllAsRead;
  final bool expanded;

  const _HeaderActions({
    required this.isLoading,
    required this.showMarkAll,
    required this.onRefresh,
    required this.onMarkAllAsRead,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final refreshButton = IconButton.filledTonal(
      onPressed: isLoading ? null : onRefresh,
      tooltip: 'Refresh',
      icon: isLoading
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : const Icon(Icons.refresh_rounded, size: 20),
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );

    final children = <Widget>[refreshButton];

    if (showMarkAll) {
      children.add(const SizedBox(width: 8));
      children.add(
        expanded
            ? Expanded(
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onMarkAllAsRead,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: const Text('Mark all as read'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
            : FilledButton.icon(
                onPressed: isLoading ? null : onMarkAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Mark all as read'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
      );
    }

    return Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: children,
    );
  }
}

class _NotificationsSummary extends StatelessWidget {
  final bool isDark;
  final bool isCompact;
  final int totalCount;
  final int unreadCount;

  const _NotificationsSummary({
    required this.isDark,
    required this.isCompact,
    required this.totalCount,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 16 : 22, 0, isCompact ? 16 : 22, 12),
      child: isCompact
          ? Column(
              children: [
                _SummaryStat(
                  isDark: isDark,
                  label: 'Total',
                  value: '$totalCount',
                  icon: Icons.inbox_rounded,
                  accent: AppTheme.primaryBlue,
                ),
                const SizedBox(height: 8),
                _SummaryStat(
                  isDark: isDark,
                  label: 'Unread',
                  value: '$unreadCount',
                  icon: Icons.mark_email_unread_rounded,
                  accent: unreadCount > 0
                      ? AppTheme.warningOrange
                      : AppTheme.successGreen,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    isDark: isDark,
                    label: 'Total notifications',
                    value: '$totalCount',
                    icon: Icons.inbox_rounded,
                    accent: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryStat(
                    isDark: isDark,
                    label: 'Unread notifications',
                    value: '$unreadCount',
                    icon: Icons.mark_email_unread_rounded,
                    accent: unreadCount > 0
                        ? AppTheme.warningOrange
                        : AppTheme.successGreen,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final bool isDark;
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryStat({
    required this.isDark,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.18 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: isDark ? Colors.white : AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsEmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? detail;

  const _NotificationsEmptyState({
    super.key,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final secondary =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          AppTheme.primaryBlue.withOpacity(0.24),
                          AppTheme.secondaryPurple.withOpacity(0.18),
                        ]
                      : [
                          const Color(0xFFDBEAFE),
                          const Color(0xFFEDE9FE),
                        ],
                ),
              ),
              child: Icon(
                icon,
                size: 52,
                color: isDark ? AppTheme.white : AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.35,
              color: isDark ? Colors.white : AppTheme.darkText,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: secondary,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 10),
            Text(
              detail!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: secondary.withOpacity(0.85)),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final List<AppNotification> items;
  final Color onSurface;
  final Color secondary;
  final bool isDark;
  final bool isCompact;
  final void Function(AppNotification) onTap;
  final String Function(DateTime) relativeTime;
  final DateFormat fullDateFormat;
  final DateFormat shortTimeFormat;

  const _NotificationsList({
    super.key,
    required this.items,
    required this.onSurface,
    required this.secondary,
    required this.isDark,
    required this.isCompact,
    required this.onTap,
    required this.relativeTime,
    required this.fullDateFormat,
    required this.shortTimeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final notification = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 180 + (index * 30).clamp(0, 150)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, (1 - value) * 8),
              child: child,
            ),
          ),
          child: _NotificationCard(
            notification: notification,
            onSurface: onSurface,
            secondary: secondary,
            isDark: isDark,
            isCompact: isCompact,
            onTap: () => onTap(notification),
            relativeTime: relativeTime,
            fullDateFormat: fullDateFormat,
            shortTimeFormat: shortTimeFormat,
          ),
        );
      },
    );
  }
}

class _NotificationVisual {
  final IconData icon;
  final Color accent;
  final String label;

  const _NotificationVisual({
    required this.icon,
    required this.accent,
    required this.label,
  });

  static _NotificationVisual forType(String type, bool isDark) {
    if (type.contains('overdue')) {
      return const _NotificationVisual(
        icon: Icons.error_outline_rounded,
        accent: AppTheme.errorRed,
        label: 'Overdue',
      );
    }
    if (type.contains('6h')) {
      return const _NotificationVisual(
        icon: Icons.schedule_rounded,
        accent: AppTheme.warningOrange,
        label: 'Due soon',
      );
    }
    if (type.contains('24h')) {
      return const _NotificationVisual(
        icon: Icons.access_time_rounded,
        accent: AppTheme.warningOrange,
        label: 'Due today',
      );
    }
    if (type.contains('3d') || type.contains('deadline')) {
      return const _NotificationVisual(
        icon: Icons.event_rounded,
        accent: AppTheme.primaryBlue,
        label: 'Upcoming',
      );
    }
    return _NotificationVisual(
      icon: Icons.notifications_rounded,
      accent: isDark ? AppTheme.primaryBlue : AppTheme.secondaryPurple,
      label: 'Alert',
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final Color onSurface;
  final Color secondary;
  final bool isDark;
  final bool isCompact;
  final VoidCallback onTap;
  final String Function(DateTime) relativeTime;
  final DateFormat fullDateFormat;
  final DateFormat shortTimeFormat;

  const _NotificationCard({
    required this.notification,
    required this.onSurface,
    required this.secondary,
    required this.isDark,
    required this.isCompact,
    required this.onTap,
    required this.relativeTime,
    required this.fullDateFormat,
    required this.shortTimeFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final visual = _NotificationVisual.forType(notification.type, isDark);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: isDark
                ? (isUnread
                    ? AppTheme.primaryBlue.withOpacity(0.07)
                    : const Color(0xFF0F172A))
                : (isUnread ? const Color(0xFFF8FAFF) : const Color(0xFFFCFCFD)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? visual.accent.withOpacity(0.2)
                  : (isDark
                      ? Colors.white.withOpacity(0.06)
                      : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8, right: 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: visual.accent,
                    ),
                  ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: visual.accent.withOpacity(isDark ? 0.16 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(visual.icon, color: visual.accent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: onSurface,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            relativeTime(notification.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _TypeChip(
                            label: visual.label,
                            color: visual.accent,
                            isDark: isDark,
                          ),
                          Text(
                            isCompact
                                ? shortTimeFormat
                                    .format(notification.createdAt.toLocal())
                                : fullDateFormat
                                    .format(notification.createdAt.toLocal()),
                            style: TextStyle(fontSize: 12, color: secondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _TypeChip({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
